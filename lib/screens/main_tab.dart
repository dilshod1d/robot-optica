import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/screens/billing/billing_list_screen.dart';
import 'package:robot_optica/screens/prescription/care_items_screen.dart';
import 'package:robot_optica/screens/settings_screen.dart';
import 'package:robot_optica/screens/visits/all_visits_screen.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/stat_card.dart';

import '../providers/auth_provider.dart';
import '../services/billing_service.dart';
import '../services/customer_service.dart';
import '../services/visit_service.dart';
import '../widgets/today_summary_card.dart';

class MainTab extends StatelessWidget {
  const MainTab({super.key});

  @override
  Widget build(BuildContext context) {
    final BillingFirebaseService _billingService = BillingFirebaseService();
    final CustomerService _customerService = CustomerService();
    final visitService = VisitService();

    final opticaId = context.watch<AuthProvider>().opticaId;

    if (opticaId == null) {
      return const AppLoader();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),

        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          children: [
            // TOTAL SALES
            StreamBuilder<double>(
              stream: _billingService.watchYearTotal(opticaId),
              builder: (context, snapshot) {
                final value = snapshot.data ?? 0;
                return StatCard(
                  title: "Hisob-kitoblar",
                  value: "${value.toStringAsFixed(0)} UZS",
                  icon: Icons.trending_up,
                );
              },
            ),

            // TOTAL DEBTS
            StreamBuilder<double>(
              stream: _billingService.watchTotalDebt(opticaId),
              builder: (context, snapshot) {
                final value = snapshot.data ?? 0;
                return StatCard(
                  title: "Jami Qarzlar",
                  value: "${value.toStringAsFixed(0)} UZS",
                  icon: Icons.warning_amber_rounded,
                );
              },
            ),

            // CUSTOMERS
            StreamBuilder<int>(
              stream: _customerService.watchTotalCustomers(opticaId),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return StatCard(
                  title: "Xaridorlar",
                  value: count.toString(),
                  icon: Icons.people,
                );
              },
            ),

            FutureBuilder<int?>(
              future: visitService.getTotalVisits(opticaId),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return StatCard(
                  title: "Tashriflar",
                  value: count.toString(),
                  icon: Icons.event,
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildSectionTitle(context, "Bugun"),
        const SizedBox(height: 12),
        FutureBuilder<int>(
          future: _billingService.getBillsToCollectTodayCount(opticaId),
          builder: (context, snapshot) {
            return TodaySummaryCard(
              title: "Yig'ish uchun qarzlar",
              count: snapshot.data ?? 0,
              subtitle: "Mijozlar bugun to'lashlari kerak",
              icon: Icons.payments,
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BillingListScreen(
                      dueTodayOnly: true,
                      title: "Bugungi qarzlar",
                    ),
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 12),
        FutureBuilder<int?>(
          future: visitService.getVisitsTodayCount(opticaId),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;

            return TodaySummaryCard(
              title: "Tashriflar Bugun",
              count: count,
              subtitle: "Rejalashtirilgan tashriflar",
              icon: Icons.event_available,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AllVisitsScreen(
                      opticaId: opticaId,
                      initialFilter: 'today',
                    ),
                  ),
                );
              },
            );
          },
        ),



        const SizedBox(height: 24),
        _buildSectionTitle(context, "Harakatlar"),
        const SizedBox(height: 12),

        Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text("Sozlamalar"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CareItemsScreen(opticaId: opticaId),
                    ),
                  );
                },
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text("Parvarish Vositalari"),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
