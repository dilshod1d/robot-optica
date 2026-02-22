import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/billing_stats_service.dart';
import '../../widgets/billing/billing_list_widget.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/stat_card.dart';
import 'billing_list_screen.dart';

class BillingDashboardScreen extends StatelessWidget {
  const BillingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final opticaId = context.watch<AuthProvider>().opticaId;

    if (opticaId == null) {
      return const AppLoader();
    }

    final statsService = BillingStatsService();

    return StreamBuilder<Map<String, dynamic>>(
      stream: statsService.watchStats(opticaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }

        if (snapshot.hasError) {
          print('Error ${snapshot.error}');
          return const Center(child: Text("Nimadir noto'g'ri ketdi"));
        }

        final data = snapshot.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== STATS GRID =====
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                    title: "Jami to'lov",
                    value: _fmt(data['totalBilled']),
                    icon: Icons.receipt_long,
                  ),
                  StatCard(
                    title: "Yig'ilgan qarzlar",
                    value: _fmt(data['totalCollected']),
                    icon: Icons.check_circle,
                  ),
                  StatCard(
                    title: "Jami To'lanmagan",
                    value: _fmt(data['totalUnpaid']),
                    icon: Icons.warning,
                  ),
                  StatCard(
                    title: "Jami To'langan",
                    value: (data['paidCount'] ?? 0).toString(),
                    icon: Icons.done_all,
                  ),
                  StatCard(
                    title: "Qisman to'langan",
                    value: (data['partialCount'] ?? 0).toString(),
                    icon: Icons.timelapse,
                  ),
                  StatCard(
                    title: "O'tib ketgan",
                    value: (data['overdueCount'] ?? 0).toString(),
                    icon: Icons.error,
                  ),
                  StatCard(
                    title: "To'lanishi Kutilmoqda",
                    value: (data['pendingDueCount'] ?? 0).toString(),
                    icon: Icons.schedule,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ===== HEADER =====
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Oxirgi xisob kitoblar",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BillingListScreen(),
                        ),
                      );
                    },

                    child: const Text("Barchasini ko'rish"),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ===== BILLING LIST (NON-SCROLLABLE) =====
              const BillingListWidget(),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return "—";
    if (v is num) return "${v.toStringAsFixed(0)} so'm";
    return v.toString();
  }
}

