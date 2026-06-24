import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/report_model.dart';
import '../models/test_result_model.dart';
import '../models/patient_model.dart';
import '../database/db_helper.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Color palette
// ──────────────────────────────────────────────────────────────────────────────
const _primaryColor    = PdfColor(0.04, 0.11, 0.24); // Navy Blue
const _brandColor      = PdfColor.fromInt(0xFFFF4500); // Bright Red-Orange
const _accentColor     = PdfColor(0.92, 0.92, 0.92);
const _headerBg        = PdfColors.white;
const _altRowBg        = PdfColor(1.0, 1.0, 1.0);
const _borderColor     = PdfColor(0.80, 0.84, 0.92);
const _footerLineColor = PdfColor(0.04, 0.11, 0.24);

const _phoneSvg  = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C43B0" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg>''';
const _emailSvg  = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1C43B0" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path><polyline points="22,6 12,13 2,6"></polyline></svg>''';

class PreviousReportData {
  final String date;
  final Map<String, String> resultsByTestName;
  PreviousReportData({required this.date, required this.resultsByTestName});
}

String _capitalizeWords(String str) {
  if (str.isEmpty) return str;
  return str.split('\n').map((line) {
    return line.split(' ').map((word) {
      if (word.isEmpty) return '';
      int firstLetterIdx = word.codeUnits.indexWhere(
              (u) => (u >= 65 && u <= 90) || (u >= 97 && u <= 122));
      if (firstLetterIdx == -1) return word;
      final prefix = word.substring(0, firstLetterIdx);
      final letter =
      word.substring(firstLetterIdx, firstLetterIdx + 1).toUpperCase();
      final suffix = word.substring(firstLetterIdx + 1);
      return prefix + letter + suffix;
    }).join(' ');
  }).join('\n');
}

// ──────────────────────────────────────────────────────────────────────────────
// Robust abnormal detection for multi-range normal values
// ──────────────────────────────────────────────────────────────────────────────
bool _isAbnormalValue(String result, String normalRange, String gender) {
  if (result.isEmpty || result == '-') return false;

  final resLower = result.trim().toLowerCase();
  if (resLower == 'positive') return true;
  if (resLower == 'negative') return false;

  final resultNum = double.tryParse(result.trim());
  if (resultNum == null) return false;

  String normalize(String s) =>
      s.replaceAll('—', '-').replaceAll('–', '-').trim();

  bool inRange(String rangeStr) {
    final cleaned =
    normalize(rangeStr).replaceAll(RegExp(r'[^0-9.\-]'), ' ').trim();
    final parts = cleaned.split(RegExp(r'\s*-\s*'));
    if (parts.length >= 2) {
      final lo = double.tryParse(parts[0].trim());
      final hi = double.tryParse(parts[1].trim());
      if (lo != null && hi != null) {
        return resultNum >= lo && resultNum <= hi;
      }
    }
    final normStr = normalize(rangeStr).replaceAll(' ', '');
    if (normStr.startsWith('<')) {
      final max = double.tryParse(
          normStr.substring(1).replaceAll(RegExp(r'[^0-9.]'), ''));
      if (max != null) return resultNum < max;
    }
    if (normStr.startsWith('>')) {
      final min = double.tryParse(
          normStr.substring(1).replaceAll(RegExp(r'[^0-9.]'), ''));
      if (min != null) return resultNum > min;
    }
    final single = double.tryParse(cleaned);
    if (single != null) return resultNum == single;
    return false;
  }

  final normalized = normalRange.replaceAll(' | ', '\n');
  final lines = normalized
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final genderUpper = gender.toUpperCase();
  bool foundGenderLine = false;
  for (final line in lines) {
    final colonIdx = line.indexOf(':');
    if (colonIdx > 0) {
      foundGenderLine = true;
      final prefix = line.substring(0, colonIdx).trim().toUpperCase();
      final rangeStr = line.substring(colonIdx + 1).trim();
      if (prefix == 'M' && genderUpper.startsWith('M')) {
        return !inRange(rangeStr);
      } else if (prefix == 'F' && genderUpper.startsWith('F')) {
        return !inRange(rangeStr);
      } else if (prefix == 'C' &&
          (genderUpper == 'C' || genderUpper == 'CHILD')) {
        return !inRange(rangeStr);
      } else if (prefix == 'A') {
        return !inRange(rangeStr);
      }
    }
  }

  if (foundGenderLine && lines.isNotEmpty) {
    final firstLine = lines.first;
    final colonIdx = firstLine.indexOf(':');
    if (colonIdx > 0) {
      return !inRange(firstLine.substring(colonIdx + 1).trim());
    }
  }

  if (lines.length == 1) return !inRange(lines.first);
  if (lines.length > 1 && !foundGenderLine) {
    return lines.every((l) => !inRange(l));
  }

  return false;
}

// ──────────────────────────────────────────────────────────────────────────────
// Arrow direction helper
// ──────────────────────────────────────────────────────────────────────────────
String _arrowFor(String result, String normalRange) {
  final resNum = double.tryParse(result.trim());
  if (resNum == null) return '';
  final norm =
      normalRange.replaceAll('—', '-').replaceAll('–', '-').split('\n').first;
  final parts = norm.split(RegExp(r'\s*-\s*'));
  if (parts.length >= 2) {
    final lo =
    double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9.]'), '').trim());
    final hi =
    double.tryParse(parts[1].replaceAll(RegExp(r'[^0-9.]'), '').trim());
    if (hi != null && resNum > hi) return '↑';
    if (lo != null && resNum < lo) return '↓';
  }
  return '';
}

class PdfReportGenerator {
  static const double _sideMargin  = 36;
  static const double _topReserved = 144;
  static const double _categoryGap = 10;

  static Future<void> printReport({
    required ReportModel report,
    required List<TestResultModel> results,
    required Map<String, dynamic> labSettings,
    required bool includeHeaderFooter,
    PatientModel? patient,
    Map<String, dynamic>? invoice,
    List<PreviousReportData> previousReports = const [],
  }) async {
    final pdf = pw.Document();

    final signatures = await DBHelper.getFooterSignatures();
    final labName           = labSettings['labName']           ?? 'MUHAMMAD MEDICAL LABORATORY';
    final address           = labSettings['address']           ?? 'Opp: gate no 01 Professer Medical Center';
    final phone             = labSettings['phone']             ?? '0928-611111 , 03329740305';
    final email             = labSettings['email']             ?? '';
    final ceoName           = labSettings['ceoName']           ?? '';
    final ceoEducation      = labSettings['ceoEducation']      ?? '';
    final inchargeName      = labSettings['inchargeName']      ?? '';
    final inchargeEducation = labSettings['inchargeEducation'] ?? '';
    final watermarkText     = labSettings['watermarkText']     ?? 'MUHAMMAD MEDICAL LABORATORY';
    final registrationNo    = labSettings['registrationNo']    ?? '';
    final headerImagePath   = labSettings['headerImagePath']   ?? '';

    final patientGender = patient?.gender ?? '';

    pw.MemoryImage? headerImage;
    if (headerImagePath.isNotEmpty) {
      try {
        final file = File(headerImagePath);
        if (await file.exists()) {
          headerImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    // ── Grouping by category ──────────────────────────────────────────────
    final useCustomPages = results.any((r) => r.printPage > 0);
    final pageGroups = <dynamic, List<TestResultModel>>{};
    if (useCustomPages) {
      for (var r in results) {
        final p = r.printPage > 0 ? r.printPage : 0;
        pageGroups.putIfAbsent(p, () => []);
        pageGroups[p]!.add(r);
      }
    } else {
      for (var r in results) {
        final cat = r.category.isNotEmpty ? r.category : 'General';
        pageGroups.putIfAbsent(cat, () => []);
        pageGroups[cat]!.add(r);
      }
    }
    final sortedKeys = pageGroups.keys.toList();
    if (useCustomPages) {
      sortedKeys.sort((a, b) => (a as int).compareTo(b as int));
    } else {
      sortedKeys.sort((a, b) {
        final sa = (a as String).toLowerCase();
        final sb = (b as String).toLowerCase();
        if (sa == 'hematology') return -1;
        if (sb == 'hematology') return 1;
        return sa.compareTo(sb);
      });
    }
    final prevSorted = previousReports.reversed.toList();

    // ── QR data ───────────────────────────────────────────────────────────
    final pAge    = patient?.age.toString() ?? '-';
    final pGender = patient?.gender ?? '-';
    final qrData  =
        'Name: ${report.patientName}\nAge: $pAge / $pGender\nTests: ${results.map((e) => e.testName).join(', ')}';

    pw.Widget patientInfoSection() => _buildPatientInfoSection(
      report: report,
      patient: patient,
      invoice: invoice,
    );

    // ── Flatten all category entries ──────────────────────────────────────
    final categoryEntries =
    <({dynamic groupKey, String cat, List<TestResultModel> catResults})>[];
    for (var groupKey in sortedKeys) {
      final groupResults = pageGroups[groupKey]!;
      final catMap = <String, List<TestResultModel>>{};
      for (var r in groupResults) {
        final cat = r.category.isNotEmpty ? r.category : 'General';
        catMap.putIfAbsent(cat, () => []);
        catMap[cat]!.add(r);
      }
      final sortedCats = catMap.keys.toList()
        ..sort((a, b) {
          final la = a.toLowerCase();
          final lb = b.toLowerCase();
          if (la == 'hematology') return -1;
          if (lb == 'hematology') return 1;
          return la.compareTo(lb);
        });
      for (var cat in sortedCats) {
        categoryEntries
            .add((groupKey: groupKey, cat: cat, catResults: catMap[cat]!));
      }
    }

    // ── Watermark wrapper removed (using pageTheme) ────────────────────────

    // ── Build body widgets ────────────────────────────────────────────────
    final bodyWidgets = <pw.Widget>[];

    for (var ei = 0; ei < categoryEntries.length; ei++) {
      final entry      = categoryEntries[ei];
      final cat        = entry.cat;
      final catResults = entry.catResults
          .where((r) => r.result.trim().isNotEmpty || (r.normalRange.trim().isEmpty && r.unit.trim().isEmpty))
          .toList();
      final isLastCat  = ei == categoryEntries.length - 1;

      if (catResults.isNotEmpty) {
        final relevantPrev = prevSorted
            .where((p) => catResults
            .any((r) => p.resultsByTestName.containsKey(r.testName)))
            .toList();

        // ── Format result date/time for this category ─────────────────
        final resultTime  = report.date;
        final displayTime = resultTime.length >= 16
            ? resultTime.substring(0, 16).replaceAll('T', ' ')
            : resultTime;

        // ── Column widths ─────────────────────────────────────────────
        // Columns: TestName | Arrow | Result | Unit | [prev...] | RefValues
        final colWidths = <int, pw.TableColumnWidth>{};
        colWidths[0] = const pw.FlexColumnWidth(2.5); // Test Name
        colWidths[1] = const pw.FixedColumnWidth(14); // Arrow (↑/↓)
        colWidths[2] = const pw.FlexColumnWidth(1.2); // Result
        colWidths[3] = const pw.FlexColumnWidth(0.9); // Unit
        int ci = 4;
        for (int i = 0; i < relevantPrev.length; i++) {
          colWidths[ci++] = const pw.FlexColumnWidth(1.0);
        }
        colWidths[ci] = const pw.FlexColumnWidth(1.8); // Ref values
        final totalCols = ci + 1;

        final tableRows = <pw.TableRow>[];

        // ── Row 0: Category header (matches screenshot exactly) ───────
        // Layout: [Category Name centered] ... [Date/Time centered] ... [UNIT] [REFERENCE VALUES]
        // The screenshot shows: category + date in merged area left/center,
        // then UNIT and REFERENCE VALUES column headers on right
        tableRows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _accentColor),
            children: List.generate(totalCols, (colIdx) {
              // First column: category name
              if (colIdx == 0) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: pw.Text(
                    cat,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                );
              }
              // Arrow column: blank in header
              if (colIdx == 1) {
                return pw.SizedBox(width: 14);
              }
              // Result column: show "Collected By/Date" label
              if (colIdx == 2) {
                return pw.Padding(
                  padding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  child: pw.Text(
                    displayTime,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                );
              }
              // Unit column header
              if (colIdx == 3) {
                return pw.Padding(
                  padding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  child: pw.Text(
                    'UNIT',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                );
              }
              // Previous date columns
              if (colIdx < totalCols - 1) {
                final prevIdx = colIdx - 4;
                if (prevIdx >= 0 && prevIdx < relevantPrev.length) {
                  final d = relevantPrev[prevIdx].date;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 5),
                    child: pw.Text(
                      d.length >= 10 ? d.substring(0, 10) : d,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  );
                }
              }
              // Last column: "REFERENCE VALUES"
              return pw.Padding(
                padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(
                  'REFERENCE VALUES',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              );
            }),
          ),
        );

        // ── Data rows ─────────────────────────────────────────────────
        for (var ri = 0; ri < catResults.length; ri++) {
          final r = catResults[ri];

          final isSubHeader = r.result.trim().isEmpty && r.normalRange.trim().isEmpty && r.unit.trim().isEmpty;

          // Data row
          final isAbnormal = !isSubHeader &&
          _isAbnormalValue(r.result, r.normalRange, patientGender);
          final arrow = isAbnormal ? _arrowFor(r.result, r.normalRange) : '';
          final normalRangeDisplay = r.normalRange.replaceAll(' | ', '\n');

          // Build cell contents list
          final cells = <({String text, bool isBold, bool isArrow})>[];
          if (isSubHeader) {
            cells.add((
            text: r.testName,
            isBold: true,
            isArrow: false,
            ));
            for (int i = 1; i < totalCols; i++) {
              cells.add((
              text: '',
              isBold: false,
              isArrow: false,
              ));
            }
          } else {
            // 0: Test name
            cells.add((
            text: r.testName,
            isBold: r.testName.toUpperCase() == r.testName,
            isArrow: false,
            ));
            // 1: Arrow cell
            cells.add((
            text: arrow,
            isBold: true,
            isArrow: true,
            ));
            // 2: Result
            cells.add((
            text: r.result.isEmpty ? '-' : r.result,
            isBold: isAbnormal,
            isArrow: false,
            ));
            // 3: Unit
            cells.add((
            text: r.unit,
            isBold: false,
            isArrow: false,
            ));
            // Previous results
            for (var prev in relevantPrev) {
              cells.add((
              text: prev.resultsByTestName[r.testName] ?? '-',
              isBold: false,
              isArrow: false,
              ));
            }
            // Reference values
            cells.add((
            text: normalRangeDisplay,
            isBold: false,
            isArrow: false,
            ));
          }

          tableRows.add(
            pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: cells.asMap().entries.map((ce) {
                final isLastRow = ri == catResults.length - 1;
                return pw.Container(
                  padding: pw.EdgeInsets.symmetric(
                    horizontal: ce.key == 1 ? 0 : 6,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey400,
                        width: 0.5,
                        style: pw.BorderStyle.dashed,
                      ),
                    ),
                  ),
                  child: pw.Text(
                    ce.value.text,
                    textAlign: ce.key == 0 ? pw.TextAlign.left : pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: isSubHeader ? 10 : (ce.key == 1 ? 10 : 9),
                      fontWeight: isSubHeader || ce.value.isBold
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: (ce.key == 1 && arrow.isNotEmpty)
                          ? PdfColors.red
                          : PdfColors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }

        // "Result : DATE" footer row at bottom of category (matches screenshot)
        tableRows.add(
          pw.TableRow(
            children: List.generate(totalCols, (colIdx) {
              if (colIdx == totalCols - 1) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: pw.Text(
                    'Result : $displayTime',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                );
              }
              return pw.SizedBox(height: 0);
            }),
          ),
        );

        final categoryTable = pw.Table(
          border: null,
          columnWidths: colWidths,
          children: tableRows,
        );

        final categoryBlock = pw.Inseparable(
          child: pw.Padding(
            padding: ei > 0
                ? const pw.EdgeInsets.only(top: _categoryGap)
                : pw.EdgeInsets.zero,
            child: categoryTable,
          ),
        );

        bodyWidgets.add(categoryBlock);
      }

      // Remarks — after the last category only
      if (isLastCat) {
        if ((report.remarks ?? '').isNotEmpty) {
          bodyWidgets.add(pw.SizedBox(height: 14));
          bodyWidgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _altRowBg,
                border: pw.Border.all(color: _borderColor, width: 0.8),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Remarks:',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _primaryColor)),
                  pw.SizedBox(height: 4),
                  pw.Text(report.remarks!,
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromHex('#333333'))),
                ],
              ),
            ),
          );
        }
      }
    }

    // ── Single MultiPage ──────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: includeHeaderFooter
              ? const pw.EdgeInsets.fromLTRB(_sideMargin, 24, _sideMargin, 16)
              : const pw.EdgeInsets.fromLTRB(_sideMargin, 158.4, _sideMargin, 72),
          buildBackground: (ctx) {
            if (headerImage == null) return pw.SizedBox();
            return pw.Center(
              child: pw.Opacity(
                opacity: 0.08,
                child: pw.Image(headerImage, fit: pw.BoxFit.contain, width: 350, height: 350),
              ),
            );
          },
        ),

        header: (ctx) {
          final hasVerified = (report.verifiedBy ?? '').isNotEmpty;
          final vfText =
          report.verifiedAt != null && report.verifiedAt!.length >= 16
              ? report.verifiedAt!.substring(0, 16).replaceAll('T', ' ')
              : '';

          pw.Widget? verifiedStrip() {
            if (!hasVerified) return null;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Verified by: ${report.verifiedBy}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  if (vfText.isNotEmpty)
                    pw.Text(
                      'Verified at: $vfText',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColor.fromHex('#666666'),
                      ),
                    ),
                ],
              ),
            );
          }

          if (!includeHeaderFooter) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'LABORATORY REPORT',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                patientInfoSection(),
                if (verifiedStrip() != null) verifiedStrip()!,
                pw.SizedBox(height: 10),
              ],
            );
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                labName: labName,
                address: address,
                phone: phone,
                email: email,
                registrationNo: registrationNo,
                headerImage: headerImage,
                qrData: qrData,
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'LABORATORY REPORT',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              patientInfoSection(),
              if (verifiedStrip() != null) verifiedStrip()!,
              pw.SizedBox(height: 10),
            ],
          );
        },

        footer: (ctx) {
          if (!includeHeaderFooter) return pw.SizedBox(height: 0);
          return _buildFooter(
            signatures: signatures,
            address: address,
            phone: phone,
            email: email,
            labName: labName,
            pageNumber: ctx.pageNumber,
            totalPages: ctx.pagesCount,
          );
        },

        build: (context) => bodyWidgets,
      ),
    );

    final repNo = invoice?['id']?.toString() ?? report.id.toString();
    await Printing.layoutPdf(
      name: 'LabReport_${report.patientName}_$repNo',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // ── Patient Info Section ──────────────────────────────────────────────────
  static pw.Widget _buildPatientInfoSection({
    required ReportModel report,
    PatientModel? patient,
    Map<String, dynamic>? invoice,
  }) {
    final pAge    = patient?.age.toString() ?? '-';
    final pGender = patient?.gender ?? '-';
    final pNic    = patient?.nic   ?? '-';
    final pPhone  = patient?.phone ?? '-';
    final String dtText = report.date.length >= 16
        ? report.date.substring(0, 16).replaceAll('T', ' ')
        : report.date;

    final hasVerified = (report.verifiedBy ?? '').isNotEmpty;
    final String vfText =
    report.verifiedAt != null && report.verifiedAt!.length >= 16
        ? report.verifiedAt!.substring(0, 16).replaceAll('T', ' ')
        : dtText;

    final repNo = invoice?['id']?.toString() ?? report.id.toString();
    final pAgeText = (pAge == '0' || pAge.isEmpty || pAge == '-') ? '-' : '$pAge Years';
    final pSpecimen = report.specimen?.isNotEmpty == true ? report.specimen! : 'Blood';

    pw.Widget infoRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.black)),
          ),
        ],
      ),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                infoRow("Patient's Name :", report.patientName),
                infoRow("Ref By :",
                    report.referredBy?.isNotEmpty == true
                        ? report.referredBy!
                        : '-'),
                infoRow("Lab No :", repNo),
                infoRow("NIC # :", pNic),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                infoRow("Age / Sex :", "$pAgeText / $pGender"),
                infoRow("Specimen :", pSpecimen),
                if (hasVerified)
                  infoRow("Verified at :", vfText)
                else
                  infoRow("Report Date :", dtText),
                infoRow("Phone :", pPhone),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String labName,
    required String address,
    required String phone,
    required String email,
    required String registrationNo,
    pw.MemoryImage? headerImage,
    String? qrData,
  }) {
    final displayAddress = _capitalizeWords(
        address.isNotEmpty ? address : 'Opp: gate no 01 Professer Medical Center');
    final displayPhones = (phone.isNotEmpty
        ? phone
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList()
        : ['0928-611111', '03329740305'])
        .map((p) => _capitalizeWords(p))
        .toList();

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (headerImage != null)
            pw.Container(
              width: 60,
              height: 60,
              child: pw.Image(headerImage, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 60,
              height: 60,
              child: pw.Center(
                child: pw.Text('BCL',
                    style: pw.TextStyle(
                        color: _primaryColor,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(labName,
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _brandColor)),
                if (registrationNo.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(registrationNo,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                ],
                pw.SizedBox(height: 4),
                if (displayAddress.isNotEmpty)
                  pw.Text(displayAddress,
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.black)),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    if (displayPhones.isNotEmpty) ...[
                      pw.SvgImage(svg: _phoneSvg, width: 7, height: 7),
                      pw.SizedBox(width: 3),
                      pw.Text(displayPhones.join(', '),
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black)),
                    ],
                    if (displayPhones.isNotEmpty && email.isNotEmpty)
                      pw.Text('  |  ',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey)),
                    if (email.isNotEmpty) ...[
                      pw.SvgImage(svg: _emailSvg, width: 7, height: 7),
                      pw.SizedBox(width: 3),
                      pw.Text(email,
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.black)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (qrData != null)
            pw.Container(
              width: 55,
              height: 55,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                color: _primaryColor,
              ),
            ),
        ],
      ),
    );
  }

  // ── Footer — matches screenshot exactly ────────────────────────────────────
  // Layout from screenshot (left → right):
  //   [Consultant / AZMAT SHAH / Chief Clinical Technologist…]
  //   [M TAIB KHAN / BS MLT (KMU)]
  //   [ABD ULLAH / BS MLT (KMU)]
  //   [NASIM SHAH / DMLT (FPMA KPK)]
  static pw.Widget _buildFooter({
    required List<Map<String, dynamic>> signatures,
    required String address,
    required String phone,
    required String email,
    required String labName,
    int pageNumber = 1,
    int totalPages = 1,
  }) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        // ── Electronically generated notice ──────────────────────────
        pw.Text(
          'This is an electronically generated report, no signature required.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 4),

        // ── Thin separator line above signatures ──────────────────────
        pw.Container(
          height: 0.5,
          color: PdfColors.grey400,
          margin: const pw.EdgeInsets.only(bottom: 8),
        ),

        // ── Signature row (dynamic columns, matching requested individuals) ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: signatures.map((sig) {
            final educationLines = (sig['education'] as String? ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
            return _footerColumn(
              topLabel: sig['designation'] ?? '',
              name: sig['name'] ?? '',
              lines: educationLines,
            );
          }).toList(),
        ),

        pw.SizedBox(height: 8),

        // ── Page number (centered, small) ────────────────────────────
        if (totalPages > 1)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              'Page $pageNumber of $totalPages',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ),

        // ── Solid blue bar at the very bottom ────────────────────────
        pw.Container(
          height: 14,
          width: double.infinity,
          color: _footerLineColor,
        ),
      ],
    );
  }

  /// Single signature column for the footer.
  /// [topLabel] is the small role label above the name (e.g. "Consultant").
  /// [name] is the bold larger name.
  /// [lines] are the smaller qualification/role lines below the name.
  static pw.Widget _footerColumn({
    required String topLabel,
    required String name,
    required List<String> lines,
  }) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Small label above the name
            if (topLabel.isNotEmpty) ...[
              pw.Text(
                topLabel,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 2),
            ] else
              pw.SizedBox(height: 9), // align names vertically across columns

            // Bold name
            pw.Text(
              name,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _brandColor,
              ),
            ),

            pw.SizedBox(height: 3),

            // Qualification / role lines
            for (final line in lines)
              pw.Text(
                line,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 6.5,
                  color: _primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}