import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/patient_model.dart';

class PdfPatientSummaryGenerator {
  static Future<void> printPatientSummaryReport({
    required List<PatientModel> patients,
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
                    'PATIENTS SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0B1B3D'),
                    ),
                  ),
                  pw.Text(
                    'Total: ${patients.length}',
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
              headers: ['ID', 'Name', 'Age', 'Gender', 'Phone', 'NIC'],
              data: patients.map((p) {
                return [
                  '#${p.id}',
                  p.name,
                  '${p.age}',
                  p.gender,
                  p.phone,
                  p.nic.isEmpty ? '-' : p.nic,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Patients_Summary',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
