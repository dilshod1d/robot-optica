import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import '../../models/visit_model.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/visits/visit_action_sheet.dart';
import '../../widgets/visits/visit_card.dart';
import '../../widgets/visits/reschedule_visit_sheet.dart';

class CustomerVisitsScreen extends StatefulWidget {
  final String opticaId;
  final String customerId;
  final String customerName;

  const CustomerVisitsScreen({
    super.key,
    required this.opticaId,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerVisitsScreen> createState() => _CustomerVisitsScreenState();
}

class _CustomerVisitsScreenState extends State<CustomerVisitsScreen> {
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
      context.read<VisitProvider>().fetchVisitsByCustomer(
        widget.opticaId,
        widget.customerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitProvider>();

    if (provider.isLoading) {
      return const AppLoader();
    }

    if (provider.visits.isEmpty) {
      return const EmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(constraints.maxWidth);
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: provider.visits.map((visit) {
              return SizedBox(
                width: itemWidth,
                child: VisitCard(
                  visit: visit,
                  margin: EdgeInsets.zero,
                  onMore: () => _showActions(context, visit),
                ),
              );
            }).toList(),
          ),
        );
      },
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
