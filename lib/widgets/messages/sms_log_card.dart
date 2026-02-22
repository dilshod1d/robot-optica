import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sms_log_model.dart';
import '../../optica_theme.dart';
import '../../utils/sms_types.dart';

class SmsLogCard extends StatelessWidget {
  final SmsLogModel log;

  const SmsLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM • HH:mm').format(log.sentAt);
    final typeColor = _getTypeColor(log.type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: OpticaColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight( // ✅ critical fix
        child: Row(
          children: [
            /// Left status bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Message text
                    Text(
                      log.message,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: OpticaColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TypeBadge(
                          label: _getTypeLabel(log.type),
                          color: typeColor,
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: OpticaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case SmsLogTypes.debtCreated:
      case SmsLogTypes.debtBefore:
      case SmsLogTypes.debtDue:
      case SmsLogTypes.debtRepeat:
      case SmsLogTypes.debtPaid:
      case SmsLogTypes.debtAfter1:
      case SmsLogTypes.debtAfter2:
      case SmsLogTypes.legacyDebt:
        return type == SmsLogTypes.debtPaid
            ? OpticaColors.visited
            : OpticaColors.missed;
      case SmsLogTypes.prescriptionCreated:
      case SmsLogTypes.legacyPrescription:
        return OpticaColors.primary;
      case SmsLogTypes.visitCreated:
      case SmsLogTypes.visitBefore:
      case SmsLogTypes.visitOnDate:
      case SmsLogTypes.legacyVisit:
        return OpticaColors.pending;
      case SmsLogTypes.legacyVisitFinal:
        return OpticaColors.late;
      case SmsLogTypes.marketing:
        return OpticaColors.visited;
      default:
        return OpticaColors.textSecondary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case SmsLogTypes.debtCreated:
        return "Qarz (yaratildi)";
      case SmsLogTypes.debtBefore:
        return "Qarz (oldin)";
      case SmsLogTypes.debtDue:
        return "Qarz (muddat)";
      case SmsLogTypes.debtRepeat:
        return "Qarz (kechikdi)";
      case SmsLogTypes.debtPaid:
        return "Qarz (to'landi)";
      case SmsLogTypes.debtAfter1:
        return "Qarz (kechikdi 1)";
      case SmsLogTypes.debtAfter2:
        return "Qarz (kechikdi 2)";
      case SmsLogTypes.legacyDebt:
        return "Qarz";
      case SmsLogTypes.prescriptionCreated:
        return "Retsept";
      case SmsLogTypes.legacyPrescription:
        return "Retsept";
      case SmsLogTypes.visitCreated:
        return "Tashrif (yaratildi)";
      case SmsLogTypes.visitBefore:
        return "Tashrif (oldin)";
      case SmsLogTypes.visitOnDate:
        return "Tashrif (kuni)";
      case SmsLogTypes.legacyVisit:
        return "Tashrif";
      case SmsLogTypes.legacyVisitFinal:
        return "Yakuniy";
      case SmsLogTypes.marketing:
        return "Marketing";
      default:
        return "Xabar";
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
