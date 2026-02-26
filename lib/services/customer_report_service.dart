import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/care_plan_model.dart';
import '../models/customer_model.dart';
import '../models/eye_measurement.dart';
import '../models/eye_scan_result.dart';
import '../models/eye_side.dart';
import '../models/optica_model.dart';

class CustomerReportService {
  Future<Uint8List> buildCustomerReportPdf({
    required CustomerModel customer,
    required OpticaModel? optica,
    required List<EyeScanResult> analyses,
    required List<CarePlanModel> prescriptions,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final doc = pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_5,
    );

    final theme = await _buildTheme();

    final opticaName = optica?.name.trim().isNotEmpty == true
        ? optica!.name.trim()
        : 'Optica';
    final opticaPhone = optica?.phone.trim() ?? '';
    final reportDate = _formatDate(DateTime.now());

    final analysisTotal = analyses.length;
    final prescriptionTotal = prescriptions.length;
    final analysisList =
        analysisTotal > 2 ? analyses.take(2).toList() : analyses;
    final prescriptionList =
        prescriptionTotal > 2 ? prescriptions.take(2).toList() : prescriptions;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: theme,
          buildBackground: (_) => _watermarkBackground(opticaName),
        ),
        build: (_) => [
          _header(opticaName, opticaPhone, reportDate),
          pw.SizedBox(height: 10),
          _sectionTitle("Mijoz ma'lumotlari"),
          _infoRow("Ism", customer.fullName),
          _infoRow("Telefon", customer.phone),
          _infoRow(
            "Ro'yxatdan o'tgan",
            _formatTimestamp(customer.createdAt.toDate()),
          ),
          pw.SizedBox(height: 8),
          _sectionTitle("Tahlil bo'yicha xulosa"),
          _improvementSummary(analyses),
          pw.SizedBox(height: 10),
          _sectionTitle(
            "Analizlar",
            trailing: _buildCountLabel(analysisTotal, analysisList.length),
          ),
          if (analysisList.isEmpty)
            _emptyText("Analiz ma'lumotlari yo'q")
          else
            ..._analysisBlocks(analysisList),
          pw.SizedBox(height: 10),
          _sectionTitle(
            "Retseptlar",
            trailing:
                _buildCountLabel(prescriptionTotal, prescriptionList.length),
          ),
          if (prescriptionList.isEmpty)
            _emptyText("Retseptlar yo'q")
          else
            ..._prescriptionBlocks(prescriptionList),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(String opticaName, String opticaPhone, String reportDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  opticaName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (opticaPhone.isNotEmpty)
                  pw.Text(
                    opticaPhone,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                "Mijoz hisoboti",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Yaratilgan sana: $reportDate",
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _watermarkBackground(String text) {
    final safe = text.trim().isEmpty ? "OPTICA" : text.trim();
    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      child: pw.Column(
        children: List.generate(4, (_) {
          return pw.Expanded(
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Center(child: _watermarkText(safe))),
                pw.Expanded(child: pw.Center(child: _watermarkText(safe))),
              ],
            ),
          );
        }),
      ),
    );
  }

  pw.Widget _watermarkText(String text) {
    return pw.Opacity(
      opacity: 0.06,
      child: pw.Transform.rotate(
        angle: -0.35,
        child: pw.Text(
          text.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 48,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey500,
          ),
        ),
      ),
    );
  }

  pw.Widget _sectionTitle(String text, {String? trailing}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (trailing != null && trailing.isNotEmpty) ...[
            pw.SizedBox(width: 6),
            pw.Text(
              trailing,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? "-" : value,
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _improvementSummary(List<EyeScanResult> analyses) {
    if (analyses.length < 2) {
      return _emptyText(
        analyses.isEmpty
            ? "Xulosa uchun analiz topilmadi"
            : "Xulosa uchun kamida 2 ta analiz kerak",
      );
    }

    final rightValues = _collectSeValues(analyses, isRight: true);
    final leftValues = _collectSeValues(analyses, isRight: false);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _improvementRow("O'ng ko'z", rightValues),
          pw.SizedBox(height: 4),
          _improvementRow("Chap ko'z", leftValues),
        ],
      ),
    );
  }

  pw.Widget _improvementRow(String label, _SeValues values) {
    if (values.latest == null || values.earliest == null) {
      return pw.Text(
        "$label: yetarli ma'lumot yo'q",
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      );
    }
    final diff = values.earliest! - values.latest!;
    final sign = diff > 0 ? "+" : "";
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          "${_formatSe(values.earliest)} -> ${_formatSe(values.latest)}",
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          "$sign${diff.toStringAsFixed(2)} D",
          style: pw.TextStyle(
            fontSize: 9,
            color: diff >= 0 ? PdfColors.green600 : PdfColors.red600,
          ),
        ),
      ],
    );
  }

  List<pw.Widget> _analysisBlocks(List<EyeScanResult> analyses) {
    return analyses.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final scan = entry.value;
      final dateLabel = scan.date?.trim().isNotEmpty == true
          ? scan.date!.trim()
          : "Sana ko'rsatilmagan";

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Analiz $index - $dateLabel",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            if (scan.pd?.trim().isNotEmpty == true)
              pw.Text(
                "PD: ${scan.pd}",
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            pw.SizedBox(height: 6),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _eyeSideBlock("O'ng ko'z", scan.right)),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _eyeSideBlock("Chap ko'z", scan.left)),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  pw.Widget _eyeSideBlock(String title, EyeSide side) {
    final readings = side.readings;
    final avg = side.avg;
    final seValue = _seValue(side);
    final maxReadings = 2;
    final visibleReadings =
        readings.length > maxReadings ? readings.take(maxReadings).toList() : readings;

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          if (seValue != null)
            pw.Text(
              "SE: ${_formatSe(seValue)}",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          if (avg != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              "O'rtacha: ${_measurementLabel(avg)}",
              style: pw.TextStyle(fontSize: 8),
            ),
          ],
          if (visibleReadings.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              "O'qishlar:",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            ...visibleReadings.asMap().entries.map(
                  (entry) => pw.Text(
                    "${entry.key + 1}. ${_measurementLabel(entry.value)}",
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
            if (readings.length > maxReadings)
              pw.Text(
                "Yana ${readings.length - maxReadings} ta o'qish",
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
          ],
          if (avg == null && readings.isEmpty)
            pw.Text(
              "Ma'lumot yo'q",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  List<pw.Widget> _prescriptionBlocks(List<CarePlanModel> plans) {
    final sorted = [...plans]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    const maxItems = 3;

    return sorted.map((plan) {
      final items = plan.items;
      final visibleItems =
          items.length > maxItems ? items.take(maxItems).toList() : items;
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Retsept - ${_formatDate(plan.createdAt)}",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            if ((plan.generalAdvice ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                _trimLine(plan.generalAdvice!.trim(), 120),
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                maxLines: 2,
              ),
            ],
            pw.SizedBox(height: 4),
            ...visibleItems.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.title,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      "Doza: ${item.dosage}, Muddat: ${item.duration}",
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                    if (item.instruction.trim().isNotEmpty)
                      pw.Text(
                        _trimLine(item.instruction.trim(), 120),
                        style: const pw.TextStyle(fontSize: 8),
                        maxLines: 2,
                      ),
                    if ((item.notes ?? '').trim().isNotEmpty)
                      pw.Text(
                        "Izoh: ${_trimLine(item.notes!.trim(), 120)}",
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
            ),
            if (items.length > maxItems)
              pw.Text(
                "Yana ${items.length - maxItems} ta dori mavjud",
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
          ],
        ),
      );
    }).toList();
  }

  pw.Widget _emptyText(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
    );
  }

  String _measurementLabel(EyeMeasurement measurement) {
    final sph = measurement.sphere.trim();
    final cyl = measurement.cylinder.trim();
    final ax = measurement.axis.trim();
    return "Sph $sph, Cyl $cyl, Ax $ax";
  }

  double? _parse(String v) => double.tryParse(v) ?? 0;

  double? _seValue(EyeSide side) {
    final seRaw = side.se?.trim();
    if (seRaw != null && seRaw.isNotEmpty) {
      return _parse(seRaw);
    }

    final m = side.avg ?? (side.readings.isNotEmpty ? side.readings.first : null);
    if (m == null) return null;

    final sphereRaw = m.sphere.trim();
    final cylinderRaw = m.cylinder.trim();
    if (sphereRaw.isEmpty && cylinderRaw.isEmpty) return null;

    final sphere = _parse(sphereRaw);
    final cylinder = _parse(cylinderRaw);
    return sphere! + (cylinder! / 2);
  }

  _SeValues _collectSeValues(List<EyeScanResult> list, {required bool isRight}) {
    final values = <double>[];
    for (final scan in list) {
      final value = _seValue(isRight ? scan.right : scan.left);
      if (value == null) continue;
      values.add(value);
    }
    if (values.isEmpty) {
      return const _SeValues();
    }
    return _SeValues(
      latest: values.first,
      earliest: values.length > 1 ? values.last : null,
    );
  }

  String _formatSe(double? value) {
    if (value == null) return "--";
    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return "$day.$month.${date.year}";
  }

  String _formatTimestamp(DateTime date) => _formatDate(date);

  String _buildCountLabel(int total, int shown) {
    if (total <= shown) return "";
    return "($shown / $total)";
  }

  String _trimLine(String text, int max) {
    if (text.length <= max) return text;
    return "${text.substring(0, max).trim()}...";
  }

  Future<pw.ThemeData> _buildTheme() async {
    final assetFonts = await _loadAssetFonts();
    if (assetFonts != null) {
      return pw.ThemeData.withFont(
        base: assetFonts.base,
        bold: assetFonts.bold,
      );
    }

    if (Platform.isMacOS) {
      final fonts = await _loadMacFonts();
      return pw.ThemeData.withFont(
        base: fonts.base,
        bold: fonts.bold,
      );
    }

    try {
      final base = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      return pw.ThemeData.withFont(
        base: base,
        bold: bold,
      );
    } catch (_) {
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  Future<_FontPair?> _loadAssetFonts() async {
    try {
      final baseData = await rootBundle.load('assets/fonts/Arial.ttf');
      final boldData = await rootBundle.load('assets/fonts/Arial_Bold.ttf');
      final base = pw.Font.ttf(baseData);
      final bold = pw.Font.ttf(boldData);
      return _FontPair(base: base, bold: bold);
    } catch (_) {
      return null;
    }
  }

  Future<_FontPair> _loadMacFonts() async {
    final base = await _loadFirstFont(const [
          '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
          '/System/Library/Fonts/Supplemental/Arial.ttf',
          '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
          '/System/Library/Fonts/Supplemental/Helvetica.ttf',
          '/System/Library/Fonts/Supplemental/Georgia.ttf',
        ]) ??
        pw.Font.helvetica();

    final bold = await _loadFirstFont(const [
          '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
          '/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf',
          '/System/Library/Fonts/Supplemental/Helvetica Bold.ttf',
          '/System/Library/Fonts/Supplemental/Georgia Bold.ttf',
        ]) ??
        base;

    return _FontPair(base: base, bold: bold);
  }

  Future<pw.Font?> _loadFirstFont(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        return pw.Font.ttf(bytes.buffer.asByteData());
      }
    }
    return null;
  }
}

class _SeValues {
  final double? earliest;
  final double? latest;
  const _SeValues({this.earliest, this.latest});
}

class _FontPair {
  final pw.Font base;
  final pw.Font bold;
  const _FontPair({required this.base, required this.bold});
}
