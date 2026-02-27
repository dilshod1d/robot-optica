import 'package:flutter/material.dart';
import '../../services/sms_log_service.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/responsive_frame.dart';
import 'sms_log_list_screen.dart';
import 'marketing_sms_screen.dart';

class SmsDashboardScreen extends StatefulWidget {
  final String opticaId;

  const SmsDashboardScreen({super.key, required this.opticaId});

  @override
  State<SmsDashboardScreen> createState() => _SmsDashboardScreenState();
}

class _SmsDashboardScreenState extends State<SmsDashboardScreen> {
  final SmsLogService _service = SmsLogService();

  late Future<_SmsStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_SmsStats> _loadStats() async {
    return _SmsStats(
      visitToday: await _service.getVisitSmsToday(widget.opticaId),
      visit7Days: await _service.getVisitSmsLast7Days(widget.opticaId),
      visit30Days: await _service.getVisitSmsLast30Days(widget.opticaId),
      visitTotal: await _service.getTotalVisitSms(widget.opticaId),

      debtToday: await _service.getDebtSmsToday(widget.opticaId),
      debt7Days: await _service.getDebtSmsLast7Days(widget.opticaId),
      debt30Days: await _service.getDebtSmsLast30Days(widget.opticaId),
      debtTotal: await _service.getTotalDebtSms(widget.opticaId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SmsStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AppLoader();
          }

          final stats = snapshot.data!;

          return ResponsiveFrame(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Tashrif smslari"),
                  const SizedBox(height: 12),
                  _grid([
                  StatCard(title: "Bugun", value: stats.visitToday.toString(), icon: Icons.today),
                  StatCard(title: "Oxirgi 7 kun", value: stats.visit7Days.toString(), icon: Icons.date_range),
                  StatCard(title: "Oxirgi 30 kun", value: stats.visit30Days.toString(), icon: Icons.calendar_month),
                  StatCard(title: "Jami", value: stats.visitTotal.toString(), icon: Icons.all_inbox),
                ]),

                  const SizedBox(height: 32),

                  _sectionTitle("Qarz SMSlari"),
                  const SizedBox(height: 12),
                  _grid([
                  StatCard(title: "Bugun", value: stats.debtToday.toString(), icon: Icons.today),
                  StatCard(title: "Oxirgi 7 kun", value: stats.debt7Days.toString(), icon: Icons.date_range),
                  StatCard(title: "Oxirgi 30 kun", value: stats.debt30Days.toString(), icon: Icons.calendar_month),
                  StatCard(title: "Jami", value: stats.debtTotal.toString(), icon: Icons.all_inbox),
                ]),

                  _sectionTitle("Harakatlar"),
                  const SizedBox(height: 12),

                  _ActionCard(
                    title: "SMS xabarlar",
                    subtitle: "Barcha xabarlarni ko'rish",
                    icon: Icons.list_alt,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SmsLogListScreen(opticaId: widget.opticaId,)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    title: "Marketing SMS",
                    subtitle: "Barcha mijozlarga yuborish",
                    icon: Icons.campaign,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MarketingSmsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
  }

  Widget _grid(List<Widget> children) {
    return ResponsiveGrid(
      minItemWidth: 200,
      maxCrossAxisCount: 4,
      childAspectRatio: 1.8,
      children: children,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SmsStats {
  final int? visitToday;
  final int? visit7Days;
  final int? visit30Days;
  final int? visitTotal;

  final int? debtToday;
  final int? debt7Days;
  final int? debt30Days;
  final int? debtTotal;

  _SmsStats({
    required this.visitToday,
    required this.visit7Days,
    required this.visit30Days,
    required this.visitTotal,
    required this.debtToday,
    required this.debt7Days,
    required this.debt30Days,
    required this.debtTotal,
  });
}


class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

