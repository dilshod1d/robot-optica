import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/screens/visits/all_visits_screen.dart';
import '../../models/visit_model.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/responsive_frame.dart';
import '../../widgets/visits/visit_action_sheet.dart';
import '../../widgets/visits/visit_card.dart';
import '../../widgets/visits/reschedule_visit_sheet.dart';

class VisitsDashboardScreen extends StatefulWidget {
  final String opticaId;

  const VisitsDashboardScreen({super.key, required this.opticaId});

  @override
  State<VisitsDashboardScreen> createState() =>
      _VisitsDashboardScreenState();
}

class _VisitsDashboardScreenState extends State<VisitsDashboardScreen> {
  int _columnsForWidth(double width) {
    const minWidth = 360.0;
    const maxColumns = 4;
    if (width <= 0) return 1;
    final count = (width / minWidth).floor();
    return count.clamp(1, maxColumns);
  }
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = context.read<VisitProvider>();
      provider.fetchRecentVisits(widget.opticaId);
      provider.fetchVisitStats(widget.opticaId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitProvider>();

    if (provider.isLoading && provider.recentVisits.isEmpty) {
      return const AppLoader();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchAllVisits(widget.opticaId);
        await provider.fetchVisitStats(widget.opticaId);
      },
      child: ResponsiveFrame(
        child: ListView(
          children: [
            _Stats(provider),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "So'nggi tashriflar",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AllVisitsScreen(opticaId: widget.opticaId),
                      ),
                    );
                  },
                  child: const Text("Barchasini ko'rish"),
                ),
              ],
            ),
          ),

          if (provider.recentVisits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 220,
                child: EmptyState(),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth =
                    constraints.maxWidth - (16 * 2);
                final columns = _columnsForWidth(availableWidth);
                const spacing = 12.0;
                if (columns <= 1) {
                  return Column(
                    children: provider.recentVisits.map((v) {
                      return VisitCard(
                        visit: v,
                        showCustomerName: true,
                        onMore: () => _showActions(context, v),
                      );
                    }).toList(),
                  );
                }

                final itemWidth =
                    (availableWidth - (spacing * (columns - 1))) /
                        columns;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: provider.recentVisits.map((v) {
                      return SizedBox(
                        width: itemWidth,
                        child: VisitCard(
                          visit: v,
                          showCustomerName: true,
                          margin: EdgeInsets.zero,
                          onMore: () => _showActions(context, v),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, VisitModel visit) {
    VisitActionSheet.show(
      context: context,
      onVisited: () {
        Navigator.pop(context);
        context.read<VisitProvider>().markVisited(
          widget.opticaId,
          visit,
        );
      },
      onLateVisited: () {
        Navigator.pop(context);
        context.read<VisitProvider>().updateVisit(
          widget.opticaId,
          visit.copyWith(
            status: VisitStatus.lateVisited,
            visitedDate: DateTime.now(),
          ),
        );
      },
      onNotVisited: () {
        Navigator.pop(context);
        context.read<VisitProvider>().markNotVisited(
          widget.opticaId,
          visit.id,
        );
      },
      onReschedule: () async {
        Navigator.pop(context);
        final result = await RescheduleVisitSheet.show(
          context: context,
          initialDate: visit.visitDate,
        );
        if (result == null) return;
        await context.read<VisitProvider>().rescheduleVisit(
          opticaId: widget.opticaId,
          visit: visit,
          newDate: result.date,
          resetSms: result.resetSms,
        );
      },
      onDelete: () {
        Navigator.pop(context);
        context.read<VisitProvider>().deleteVisit(
          widget.opticaId,
          visit.id,
        );
      },
    );
  }
}




class _Stats extends StatelessWidget {
  final VisitProvider provider;

  const _Stats(this.provider);

  @override
  Widget build(BuildContext context) {
    final isInitialLoading =
        provider.isLoading ||
            provider.isStatsLoading;

    if (isInitialLoading && provider.recentVisits.isEmpty) {
      return const AppLoader();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ===== STATUS STATS =====
          ResponsiveGrid(
            minItemWidth: 200,
            maxCrossAxisCount: 4,
            childAspectRatio: 1.8,
            children: [
              StatCard(
                title: "Kutilmoqda",
                value: provider.pendingCount.toString(),
                icon: Icons.schedule,
              ),
              StatCard(
                title: "Tashrif buyurildi",
                value: provider.visitedCount.toString(),
                icon: Icons.check_circle,
              ),
              StatCard(
                title: "Kech Tashrif buyurildi",
                value: provider.lateCount.toString(),
                icon: Icons.timelapse,
              ),
              StatCard(
                title: "Tashrif o'tkazib yuborildi",
                value: provider.missedCount.toString(),
                icon: Icons.cancel,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ===== TIME STATS =====
          ResponsiveGrid(
            minItemWidth: 200,
            maxCrossAxisCount: 4,
            childAspectRatio: 2.2,
            children: [
              StatCard(
                title: "Bugun",
                value: provider.todayCount.toString(),
                icon: Icons.today,
              ),
              StatCard(
                title: "Oxirgi 7 kun",
                value: provider.last7DaysCount.toString(),
                icon: Icons.calendar_view_week,
              ),
              StatCard(
                title: "Oxirgi 30 kun",
                value: provider.last30DaysCount.toString(),
                icon: Icons.calendar_month,
              ),
              StatCard(
                title: "Bu yil",
                value: provider.yearCount.toString(),
                icon: Icons.event_repeat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
