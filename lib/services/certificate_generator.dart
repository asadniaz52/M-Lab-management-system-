import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/employee_model.dart';

class CertificateGenerator {
  static Future<void> generateCertificate({
    required EmployeeModel employee,
    required Map<String, dynamic> labSettings,
  }) async {
    final pdf = pw.Document();
    final labName = labSettings['labName'] ?? 'MUHAMMAD MEDICAL LABORATORY';
    final address = labSettings['address'] ?? '';
    final doctorName = labSettings['doctorName'] ?? '';
    final ceoName = labSettings['ceoName'] ?? '';
    final inchargeName = labSettings['inchargeName'] ?? '';
    final phone = labSettings['phone'] ?? '0928-611111 , 03329740305';
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

    final isInternee = employee.type == 'internee';
    final certTitle = isInternee ? 'INTERNSHIP CERTIFICATE' : 'EXPERIENCE CERTIFICATE';
    final duration = _calcDuration(employee.joinDate, employee.endDate ?? DateTime.now().toIso8601String().substring(0, 10));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (context) {
          return pw.Column(
            children: [
              // Top border
              pw.Container(
                height: 4,
                color: PdfColor.fromHex('#1C4370'),
              ),
              pw.SizedBox(height: 30),

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
                  pw.Container(width: 50, height: 50),
                ],
              ),
              pw.SizedBox(height: 30),

              // Certificate title
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#1C4370'), width: 2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  certTitle,
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1C4370')),
                ),
              ),
              pw.SizedBox(height: 40),

              // Body text
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.RichText(
                  textAlign: pw.TextAlign.justify,
                  text: pw.TextSpan(
                    style: pw.TextStyle(fontSize: 13, lineSpacing: 8),
                    children: [
                      const pw.TextSpan(text: 'This is to certify that '),
                      pw.TextSpan(text: employee.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.TextSpan(
                        text: isInternee
                            ? ' has successfully completed an internship at '
                            : ' has been employed at ',
                      ),
                      pw.TextSpan(text: labName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(
                        text: ' in the ${employee.department.isNotEmpty ? employee.department : "Laboratory"} department.',
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.RichText(
                  textAlign: pw.TextAlign.justify,
                  text: pw.TextSpan(
                    style: pw.TextStyle(fontSize: 13, lineSpacing: 8),
                    children: [
                      pw.TextSpan(
                        text: isInternee
                            ? 'The internship period was from '
                            : 'The period of employment was from ',
                      ),
                      pw.TextSpan(
                        text: employee.joinDate.length >= 10 ? employee.joinDate.substring(0, 10) : employee.joinDate,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      const pw.TextSpan(text: ' to '),
                      pw.TextSpan(
                        text: (employee.endDate?.isNotEmpty == true)
                            ? (employee.endDate!.length >= 10 ? employee.endDate!.substring(0, 10) : employee.endDate!)
                            : 'Present',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.TextSpan(text: ' ($duration).'),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Text(
                  isInternee
                      ? 'During the internship, ${employee.name} demonstrated excellent learning capabilities, professionalism, and dedication toward assigned responsibilities. We wish continued success in future endeavors.'
                      : '${employee.name} has performed duties with dedication, punctuality, and professionalism throughout the employment period. We wish the best for future endeavors.',
                  style: pw.TextStyle(fontSize: 13, lineSpacing: 8),
                  textAlign: pw.TextAlign.justify,
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 150, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 6),
                      if (inchargeName.isNotEmpty) pw.Text(inchargeName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Lab Incharge', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#718096'))),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 150, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 6),
                      if (ceoName.isNotEmpty) pw.Text(ceoName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('CEO / Director', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#718096'))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              if (doctorName.isNotEmpty)
                pw.Center(
                  child: pw.Text('Doctor: $doctorName', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#718096'))),
                ),
              pw.SizedBox(height: 10),

              // Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: ${DateTime.now().toIso8601String().substring(0, 10)}', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#718096'))),
                  pw.Text(labName, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#718096'))),
                ],
              ),

              pw.SizedBox(height: 10),
              // Bottom border
              pw.Container(height: 4, color: PdfColor.fromHex('#1C4370')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static String _calcDuration(String joinDate, String endDate) {
    try {
      final start = DateTime.parse(joinDate);
      final end = DateTime.parse(endDate);
      final diff = end.difference(start);
      final months = (diff.inDays / 30).round();
      if (months < 1) return '${diff.inDays} days';
      if (months < 12) return '$months months';
      final years = (months / 12).floor();
      final remMonths = months % 12;
      if (remMonths == 0) return '$years year${years > 1 ? 's' : ''}';
      return '$years year${years > 1 ? 's' : ''} $remMonths months';
    } catch (_) {
      return 'N/A';
    }
  }
}
