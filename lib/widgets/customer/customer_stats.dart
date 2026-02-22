import 'package:flutter/material.dart';
import '../../models/customer_stats_model.dart';
import '../common/stat_card.dart';


class CustomerStats extends StatelessWidget {
  final CustomerStatsModel stats;

  const CustomerStats({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Xaridor Statistikasi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            StatCard(
              title: "Yuborilgan SMS",
              value: stats.smsCount.toString(),
              icon: Icons.sms,
            ),
            StatCard(
              title: "Tashriflar",
              value: stats.visitCount.toString(),
              icon: Icons.event,
            ),
            StatCard(
              title: "Jami Qarz",
              value: "${stats.totalDebt.toStringAsFixed(0)} UZS",
              icon: Icons.warning,
            ),
            StatCard(
              title: "Jami Sotuv",
              value: "${stats.totalSales.toStringAsFixed(0)} UZS",
              icon: Icons.attach_money,
            ),
            StatCard(
              title: "Ko'z analizi",
              value: stats.analysisCount.toString(),
              icon: Icons.remove_red_eye,
            ),
            StatCard(
              title: "Retseptlar",
              value: stats.prescriptionCount.toString(),
              icon: Icons.receipt_long,
            ),
          ],
        ),
      ],
    );
  }
}
