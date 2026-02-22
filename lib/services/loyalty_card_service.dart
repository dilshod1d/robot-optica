import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/customer_model.dart';
import '../models/loyalty_config_model.dart';
import '../utils/loyalty_utils.dart';

class LoyaltyCardService {
  static final PdfPageFormat _cardFormat = PdfPageFormat(
    85.6 * PdfPageFormat.mm,
    54 * PdfPageFormat.mm,
  );

  Future<Uint8List> buildLoyaltyCardPdf({
    required LoyaltyConfigModel config,
    required String opticaName,
    required String opticaId,
    required String cardId,
    CustomerModel? customer,
  }) async {
    final doc = pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_5,
    );

    final logoBytes = config.logoBytes;
    final logoImage = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final frontBgBytes = config.frontBackgroundBytes;
    final backBgBytes = config.backBackgroundBytes;
    final frontBgImage =
        frontBgBytes == null ? null : pw.MemoryImage(frontBgBytes);
    final backBgImage = backBgBytes == null ? null : pw.MemoryImage(backBgBytes);
    final frontOverlay = config.frontOverlayOpacity;
    final backOverlay = config.backOverlayOpacity;
    final brand = config.title.trim().isEmpty ? opticaName : config.title.trim();
    final phone = config.phone.trim();
    final taplink = config.taplinkUrl.trim();
    final discount = config.discountPercent;
    final customerName = customer == null
        ? ''
        : "${customer.firstName} ${customer.lastName ?? ""}".trim();
    final loyaltyQr = buildLoyaltyQrData(
      opticaId: opticaId,
      cardId: cardId,
    );

    doc.addPage(
      pw.Page(
        pageFormat: _cardFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => _frontCard(
          brand: brand,
          logo: logoImage,
          background: frontBgImage,
          overlayOpacity: frontOverlay,
          discount: discount,
          customerName: customerName,
          loyaltyQr: loyaltyQr,
        ),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: _cardFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => _backCard(
          brand: brand,
          background: backBgImage,
          overlayOpacity: backOverlay,
          phone: phone,
          taplink: taplink,
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _frontCard({
    required String brand,
    required pw.ImageProvider? logo,
    required pw.ImageProvider? background,
    required double overlayOpacity,
    required double discount,
    required String customerName,
    required String loyaltyQr,
  }) {
    final hasBackground = background != null;
    final content = pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: hasBackground ? null : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _logoBox(logo),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      brand,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "Loyalty Card",
                      style: pw.TextStyle(
                        color: PdfColors.grey600,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              _discountBadge(discount),
            ],
          ),
          pw.Spacer(),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        "Mijoz:",
                        style: pw.TextStyle(
                          color: PdfColors.grey600,
                          fontSize: 9,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          customerName.isEmpty ? "____________________" : customerName,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                width: 54,
                height: 54,
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: loyaltyQr,
                  drawText: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (background == null) return content;

    return pw.Stack(
      children: [
        pw.Positioned.fill(
          child: pw.Image(background, fit: pw.BoxFit.cover),
        ),
        pw.Positioned.fill(
          child: pw.Opacity(
            opacity: overlayOpacity,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        content,
      ],
    );
  }

  pw.Widget _backCard({
    required String brand,
    required pw.ImageProvider? background,
    required double overlayOpacity,
    required String phone,
    required String taplink,
  }) {
    final hasBackground = background != null;
    final content = pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: hasBackground ? null : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  brand,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                if (phone.isNotEmpty)
                  pw.Text(
                    "Telefon: $phone",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                if (taplink.isNotEmpty)
                  pw.Text(
                    taplink,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 72,
                height: 72,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: taplink.isEmpty
                    ? pw.Center(
                        child: pw.Text(
                          "QR",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey500,
                          ),
                        ),
                      )
                    : pw.Stack(
                        children: [
                          pw.Positioned.fill(
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: taplink,
                              drawText: false,
                            ),
                          ),
                          pw.Positioned(
                            bottom: 2,
                            right: 2,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(color: PdfColors.grey300),
                              ),
                              child: pw.Text(
                                "Follow",
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Bizni kuzating",
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (background == null) return content;

    return pw.Stack(
      children: [
        pw.Positioned.fill(
          child: pw.Image(background, fit: pw.BoxFit.cover),
        ),
        pw.Positioned.fill(
          child: pw.Opacity(
            opacity: overlayOpacity,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        content,
      ],
    );
  }

  pw.Widget _logoBox(pw.ImageProvider? logo) {
    return pw.Container(
      width: 36,
      height: 36,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: logo == null
          ? pw.Center(
              child: pw.Text(
                "LOGO",
                style: pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                ),
              ),
            )
          : pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(logo, fit: pw.BoxFit.cover),
            ),
    );
  }

  pw.Widget _discountBadge(double value) {
    final display = value <= 0 ? "0%" : "${value.toStringAsFixed(0)}%";
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.green600,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(
        display,
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}
