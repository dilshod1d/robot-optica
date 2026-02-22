class LoyaltyQrData {
  final String opticaId;
  final String cardId;

  const LoyaltyQrData({
    required this.opticaId,
    required this.cardId,
  });
}

const String _loyaltyPrefix = 'LOYALTYCARD:';

String buildLoyaltyQrData({
  required String opticaId,
  required String cardId,
}) {
  return '$_loyaltyPrefix$opticaId:$cardId';
}

LoyaltyQrData? parseLoyaltyQrData(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.startsWith(_loyaltyPrefix)) return null;
  final payload = trimmed.substring(_loyaltyPrefix.length);
  final parts = payload.split(':');
  if (parts.length != 2) return null;
  final opticaId = parts[0].trim();
  final cardId = parts[1].trim();
  if (opticaId.isEmpty || cardId.isEmpty) return null;
  return LoyaltyQrData(opticaId: opticaId, cardId: cardId);
}
