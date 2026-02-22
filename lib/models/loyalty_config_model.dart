import 'dart:convert';
import 'dart:typed_data';

class LoyaltyConfigModel {
  final String title;
  final String phone;
  final String taplinkUrl;
  final double discountPercent;
  final String? logoBase64;
  final String? frontBackgroundBase64;
  final String? backBackgroundBase64;
  final double frontOverlayOpacity;
  final double backOverlayOpacity;
  final int minPurchasesForDiscount;

  const LoyaltyConfigModel({
    required this.title,
    required this.phone,
    required this.taplinkUrl,
    required this.discountPercent,
    this.logoBase64,
    this.frontBackgroundBase64,
    this.backBackgroundBase64,
    this.frontOverlayOpacity = 0.85,
    this.backOverlayOpacity = 0.85,
    this.minPurchasesForDiscount = 1,
  });

  bool get isEnabled => discountPercent > 0;

  Uint8List? get logoBytes {
    if (logoBase64 == null || logoBase64!.isEmpty) return null;
    try {
      return base64Decode(logoBase64!);
    } catch (_) {
      return null;
    }
  }

  Uint8List? get frontBackgroundBytes {
    if (frontBackgroundBase64 == null || frontBackgroundBase64!.isEmpty) {
      return null;
    }
    try {
      return base64Decode(frontBackgroundBase64!);
    } catch (_) {
      return null;
    }
  }

  Uint8List? get backBackgroundBytes {
    if (backBackgroundBase64 == null || backBackgroundBase64!.isEmpty) {
      return null;
    }
    try {
      return base64Decode(backBackgroundBase64!);
    } catch (_) {
      return null;
    }
  }

  factory LoyaltyConfigModel.fromMap(Map<String, dynamic> data) {
    final rawPercent = data['loyaltyDiscountPercent'];
    final percent = rawPercent is num ? rawPercent.toDouble() : 0.0;
    final frontOverlay = _readOpacity(
      data['loyaltyFrontOverlayOpacity'],
      0.85,
    );
    final backOverlay = _readOpacity(
      data['loyaltyBackOverlayOpacity'],
      0.85,
    );
    final minPurchases = _readInt(
      data['loyaltyMinPurchases'],
      1,
      min: 1,
      max: 999,
    );

    return LoyaltyConfigModel(
      title: (data['loyaltyTitle'] ?? '').toString(),
      phone: (data['loyaltyPhone'] ?? '').toString(),
      taplinkUrl: (data['loyaltyTaplinkUrl'] ?? '').toString(),
      discountPercent: percent,
      logoBase64: data['loyaltyLogoBase64'] as String?,
      frontBackgroundBase64: data['loyaltyFrontBgBase64'] as String?,
      backBackgroundBase64: data['loyaltyBackBgBase64'] as String?,
      frontOverlayOpacity: frontOverlay,
      backOverlayOpacity: backOverlay,
      minPurchasesForDiscount: minPurchases,
    );
  }

  Map<String, dynamic> toMap({bool includeLogo = true}) {
    final data = <String, dynamic>{
      'loyaltyTitle': title,
      'loyaltyPhone': phone,
      'loyaltyTaplinkUrl': taplinkUrl,
      'loyaltyDiscountPercent': discountPercent,
    };

    if (includeLogo) {
      if (logoBase64 == null || logoBase64!.isEmpty) {
        data['loyaltyLogoBase64'] = null;
      } else {
        data['loyaltyLogoBase64'] = logoBase64;
      }
    }

    if (frontBackgroundBase64 == null || frontBackgroundBase64!.isEmpty) {
      data['loyaltyFrontBgBase64'] = null;
    } else {
      data['loyaltyFrontBgBase64'] = frontBackgroundBase64;
    }

    if (backBackgroundBase64 == null || backBackgroundBase64!.isEmpty) {
      data['loyaltyBackBgBase64'] = null;
    } else {
      data['loyaltyBackBgBase64'] = backBackgroundBase64;
    }

    data['loyaltyFrontOverlayOpacity'] = frontOverlayOpacity;
    data['loyaltyBackOverlayOpacity'] = backOverlayOpacity;
    data['loyaltyMinPurchases'] = minPurchasesForDiscount;

    return data;
  }

  static double _readOpacity(dynamic raw, double fallback) {
    final value = raw is num ? raw.toDouble() : fallback;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  static int _readInt(
    dynamic raw,
    int fallback, {
    int min = 0,
    int max = 999,
  }) {
    final value = raw is num ? raw.toInt() : fallback;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
