import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_model.dart';
import '../database/db_helper.dart';

class PdfInvoiceGenerator {
  static Future<void> printInvoice({
    required InvoiceModel invoice,
    required List<InvoiceItemModel> items,
    required Map<String, dynamic> labSettings,
  }) async {
    final pdf = pw.Document();

    final signatures = await DBHelper.getFooterSignatures();
    final labName = labSettings['labName'] ?? 'MUHAMMAD MEDICAL LABORATORY';
    final address = labSettings['address'] ?? 'Opp: gate no 01 Professer Medical Center';
    final phone = labSettings['phone'] ?? '0928-611111 , 03329740305';
    final email = labSettings['email'] ?? '';
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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            children: [
              // Pathology Copy
              pw.Expanded(
                child: _buildInvoiceCopy(
                  title: 'PATHOLOGY COPY',
                  invoice: invoice,
                  items: items,
                  labName: labName,
                  address: address,
                  phone: phone,
                  email: email,
                  headerImage: headerImage,
                  signatures: signatures,
                ),
              ),
              
              // Dashed divider
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Row(
                  children: List.generate(
                    40,
                    (index) => pw.Expanded(
                      child: pw.Container(
                        height: 1,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                        color: PdfColors.grey400,
                      ),
                    ),
                  ),
                ),
              ),

              // Patient Copy
              pw.Expanded(
                child: _buildInvoiceCopy(
                  title: 'PATIENT COPY',
                  invoice: invoice,
                  items: items,
                  labName: labName,
                  address: address,
                  phone: phone,
                  email: email,
                  headerImage: headerImage,
                  signatures: signatures,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static pw.Widget _buildInvoiceCopy({
    required String title,
    required InvoiceModel invoice,
    required List<InvoiceItemModel> items,
    required String labName,
    required String address,
    required String phone,
    required String email,
    required List<Map<String, dynamic>> signatures,
    pw.MemoryImage? headerImage,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
              children: [
                pw.Text(labName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#FF4500'))),
                pw.Text(address, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#0A192F'))),
                pw.Text('Phone: $phone', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#0A192F'))),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('Invoice #${invoice.id}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: ${invoice.date.substring(0, 10)}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        // Patient info
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F7FAFC'),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Text('Patient: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(invoice.patientName, style: const pw.TextStyle(fontSize: 9)),
              pw.Spacer(),
              pw.Text('Status: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(invoice.status.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // Items table
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1C4370')),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          headers: ['#', 'Test / Item', 'Price'],
          data: items.asMap().entries.map((entry) {
            return [
              '${entry.key + 1}',
              entry.value.testName,
              'Rs. ${entry.value.price.toStringAsFixed(0)}',
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 6),

        // Totals
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 150,
              child: pw.Column(
                children: [
                  _totalRow('Net Total', 'Rs. ${invoice.netAmount.toStringAsFixed(0)}', bold: true),
                  _totalRow('Paid', 'Rs. ${invoice.paidAmount.toStringAsFixed(0)}'),
                  _totalRow('Due', 'Rs. ${invoice.dueAmount.toStringAsFixed(0)}', bold: true),
                ],
              ),
            ),
          ],
        ),
        
        pw.Spacer(),

        // Footer
        pw.Column(
          children: [
            pw.Container(height: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: signatures.map((sig) {
                final educationLines = (sig['education'] as String? ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
                return _miniFooterColumn(
                  name: sig['name'] ?? '',
                  designation: sig['designation'] ?? '',
                  educationLines: educationLines,
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _miniFooterColumn({required String name, required String designation, required List<String> educationLines}) {
    return pw.Column(
      children: [
        if (designation.isNotEmpty)
          pw.Text(designation, style: pw.TextStyle(fontSize: 6, color: PdfColor.fromHex('#0A192F'))),
        pw.Text(name, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#FF4500'))),
        for (final line in educationLines)
          pw.Text(line, style: pw.TextStyle(fontSize: 5.5, color: PdfColor.fromHex('#0A192F'))),
      ],
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }
}
