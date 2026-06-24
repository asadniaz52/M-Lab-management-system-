import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfInvoiceSummaryGenerator {
  static Future<void> printInvoiceSummaryReport({
    required List<Map<String, dynamic>> rows,
    required String fromDate,
    required String toDate,
    required Map<String, dynamic> labSettings,
  }) async {
    final pdf = pw.Document();

    final labName = labSettings['labName'] ?? 'MUHAMMAD MEDICAL LABORATORY';
    final address = labSettings['address'] ?? '';
    final phone = labSettings['phone'] ?? '';
    final headerImagePath = labSettings['headerImagePath'] ?? '';

    pw.MemoryImage? headerImage;
    if (headerImagePath.isNotEmpty) {
      try {
        final file = File(headerImagePath);
        if (await file.exists()) {
          headerImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    // Calculate totals
    double totalNet = 0;
    double totalPaid = 0;
    double totalDue = 0;
    double totalDiscount = 0;
    
    for (final r in rows) {
      totalNet += (r['netAmount'] as num?)?.toDouble() ?? 0.0;
      totalPaid += (r['paidAmount'] as num?)?.toDouble() ?? 0.0;
      totalDue += (r['dueAmount'] as num?)?.toDouble() ?? 0.0;
      totalDiscount += (r['discount'] as num?)?.toDouble() ?? 0.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (headerImage != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(headerImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(width: 50, height: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        labName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#FF4500'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      if (address.isNotEmpty) pw.Text(address, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#0A192F'))),
                      if (phone.isNotEmpty) pw.Text('Phone: $phone', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#0A192F'))),
                    ],
                  ),
                  pw.Container(width: 50, height: 50), // spacer
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(height: 1, color: PdfColor.fromHex('#0B1B3D')),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'REVENUE & INVOICES SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0B1B3D'),
                    ),
                  ),
                  pw.Text(
                    'Period: $fromDate to $toDate',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
            ],
          );
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Printed on: ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0B1B3D')),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              headers: ['Date', 'Invoice #', 'Patient Name', 'Net Total', 'Paid', 'Due', 'Discount', 'Status'],
              data: rows.map((r) {
                final date = r['date']?.toString() ?? '';
                final displayDate = date.length >= 10 ? date.substring(0, 10) : date;

                return [
                  displayDate,
                  '#${r['id']}',
                  r['patientName'] ?? '',
                  '${(r['netAmount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  '${(r['paidAmount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  '${(r['dueAmount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  '${(r['discount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  (r['status'] ?? '').toString().toUpperCase(),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F7FAFC'),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      _summaryTotalRow('Total Invoiced:', 'Rs. ${totalNet.toStringAsFixed(0)}'),
                      pw.SizedBox(height: 4),
                      _summaryTotalRow('Total Discount Provided:', 'Rs. ${totalDiscount.toStringAsFixed(0)}'),
                      pw.SizedBox(height: 4),
                      pw.Container(height: 0.5, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      _summaryTotalRow(
                        'Total Unpaid (Due):',
                        'Rs. ${totalDue.toStringAsFixed(0)}',
                        color: PdfColors.red,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(height: 1.0, color: PdfColors.grey500),
                      pw.SizedBox(height: 4),
                      _summaryTotalRow(
                        'Total Collected (Paid):',
                        'Rs. ${totalPaid.toStringAsFixed(0)}',
                        bold: true,
                        color: PdfColor.fromHex('#0B1B3D'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Revenue_Invoices_Summary_${fromDate}_to_${toDate}',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static pw.Widget _summaryTotalRow(String label, String value, {bool bold = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }
}
