import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/visit_model.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/visits/visit_action_sheet.dart';
import '../../widgets/visits/visit_card.dart';
import '../../widgets/visits/visit_filter_bar.dart';
import '../../widgets/visits/reschedule_visit_sheet.dart';
import '../../widgets/common/responsive_frame.dart';


class AllVisitsScreen extends StatefulWidget {
  final String opticaId;
  final String initialFilter;

  const AllVisitsScreen({
    super.key,
    required this.opticaId,
    this.initialFilter = 'all',
  });

  @override
  State<AllVisitsScreen> createState() => _AllVisitsScreenState();
}

class _AllVisitsScreenState extends State<AllVisitsScreen> {
  final _scrollController = ScrollController();
  late String _selectedFilter;


  final Map<String, String> filterLabels = {
    'all': 'Barchasi',
    'pending': 'Kutilmoqda',
    'visited': 'Tashrif buyurildi',
    'lateVisited': 'Kech tashrif',
    'notVisited': 'Tashrif qilinmadi',
    'today': 'Bugun',
    'week': 'Oxirgi 7 kun',
    'month': 'Oxirgi 30 kun',
  };

  final filters = [ 'all', 'pending', 'visited', 'lateVisited', 'notVisited', 'today', 'week', 'month', ];

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
    _selectedFilter = filters.contains(widget.initialFilter)
        ? widget.initialFilter
        : 'all';
    Future.microtask(() => _fetch());

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<VisitProvider>().fetchFilteredVisits(
          widget.opticaId,
          _selectedFilter,
          loadMore: true,
        );
      }
    });
  }

  void _fetch() {
    context.read<VisitProvider>().reset();
    context.read<VisitProvider>().fetchFilteredVisits(
      widget.opticaId,
      _selectedFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitProvider>();
    final title = _selectedFilter == 'today'
        ? "Bugungi tashriflar"
        : "Barcha tashriflar";

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ResponsiveFrame(
        child: Column(
          children: [
            const SizedBox(height: 16),
            VisitFilterBar(
              selected: _selectedFilter,
              filters: filters,
              labels: filterLabels,
              onChanged: (f) {
                setState(() => _selectedFilter = f);
                _fetch();
              },
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _fetch(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (provider.visits.isEmpty && provider.isLoading) {
                    return const AppLoader();
                  }

                  if (provider.visits.isEmpty && !provider.isLoading) {
                    return const EmptyState();
                  }

                  final availableWidth =
                      constraints.maxWidth - (12 * 2);
                  final columns = _columnsForWidth(availableWidth);
                  const spacing = 12.0;
                  final itemWidth =
                      (availableWidth - (spacing * (columns - 1))) /
                          columns;

                  return SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: provider.visits.map((visit) {
                            return SizedBox(
                              width: itemWidth,
                              child: VisitCard(
                                visit: visit,
                                onMore: () => _showActions(context, visit),
                                showCustomerName: true,
                                margin: columns <= 1 ? const EdgeInsets.symmetric(horizontal: 2, vertical: 8) : EdgeInsets.zero,
                              ),
                            );
                          }).toList(),
                        ),
                        if (provider.hasMore)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: AppLoader(
                              size: 80,
                              fill: false,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
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
