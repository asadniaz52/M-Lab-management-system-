import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';

class PdfPriceListGenerator {
  static Future<void> printPriceList({
    required List<Map<String, dynamic>> tests,
    required Map<String, dynamic> labSettings,
  }) async {
    final pdf = pw.Document();
    final labName = labSettings['labName'] ?? 'MUHAMMAD MEDICAL LABORATORY';
    final labNameUrdu = labSettings['labNameUrdu'] ?? '';
    final address = labSettings['address'] ?? '';
    final phone = labSettings['phone'] ?? '';
    final headerImagePath = labSettings['headerImagePath'] ?? '';

    pw.MemoryImage? headerImage;
    if (headerImagePath.isNotEmpty) {
      try {
        final file = File(headerImagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          headerImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    // Group by category
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var t in tests) {
      final cat = t['category'] ?? 'General';
      groups.putIfAbsent(cat, () => []);
      groups[cat]!.add(t);
    }

    final sortedCategories = groups.keys.toList()..sort();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#1C4370'), width: 2)),
          ),
          child: pw.Row(
            children: [
              if (headerImage != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(headerImage, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(labName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1C4370'))),
                    if (labNameUrdu.isNotEmpty)
                      pw.Text(labNameUrdu, style: pw.TextStyle(fontSize: 14, color: PdfColor.fromHex('#1C4370'))),
                    if (address.isNotEmpty)
                      pw.Text(address, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#718096'))),
                    if (phone.isNotEmpty)
                      pw.Text('Phone: $phone', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#718096'))),
                  ],
                ),
              ),
              pw.Text('PRICE LIST', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1C4370'))),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.5)),
          ),
          child: pw.Center(
            child: pw.Text(
              '$labName | Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#A0AEC0')),
            ),
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          widgets.add(pw.SizedBox(height: 8));

          int serialNo = 1;
          for (var category in sortedCategories) {
            final catTests = groups[category]!;

            // Category header
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1C4370'),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  category,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ),
            );

            // Tests table
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E0'), width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F7FAFC')),
                cellStyle: pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                headers: ['#', 'Test Name', 'Price (Rs.)'],
                columnWidths: {
                  0: const pw.FixedColumnWidth(35),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FixedColumnWidth(80),
                },
                data: catTests.map((t) {
                  final row = [
                    '${serialNo++}',
                    t['testName'] ?? '',
                    'Rs. ${(t['price'] as num).toStringAsFixed(0)}',
                  ];
                  return row;
                }).toList(),
              ),
            );
          }

          widgets.add(pw.SizedBox(height: 20));
          widgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0FFF4'),
                border: pw.Border.all(color: PdfColor.fromHex('#C6F6D5')),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Total Tests: ${tests.length} | Generated on: ${DateTime.now().toIso8601String().substring(0, 10)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2F855A')),
                textAlign: pw.TextAlign.center,
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
