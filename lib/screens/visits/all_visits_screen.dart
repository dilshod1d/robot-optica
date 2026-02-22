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
      body: Column(
        children: [
          SizedBox(height: 16,),
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
              child: provider.visits.isEmpty && !provider.isLoading
                  ? const EmptyState()
                  : ListView.builder(
                controller: _scrollController,
                itemCount: provider.visits.length +
                    (provider.hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= provider.visits.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: AppLoader(
                        size: 80,
                        fill: false,
                      ),
                    );
                  }

                  final visit = provider.visits[i];

                  return VisitCard(
                    visit: visit,
                    onMore: () => _showActions(context, visit),
                    showCustomerName: true,
                  );
                },
              ),
            ),
          ),
        ],
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
