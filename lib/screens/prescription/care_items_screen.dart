import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/responsive_frame.dart';

import '../../models/care_item.dart';
import '../../services/prescription_service.dart';
import '../../widgets/prescription/care_item_card.dart';
import '../../widgets/prescription/care_item_sheet.dart';


class CareItemsScreen extends StatelessWidget {
  final String opticaId;
  const CareItemsScreen({super.key, required this.opticaId});

  int _columnsForWidth(double width) {
    const minWidth = 320.0;
    const maxColumns = 3;
    if (width <= 0) return 1;
    final count = (width / minWidth).floor();
    return count.clamp(1, maxColumns);
  }

  @override
  Widget build(BuildContext context) {
    final service = PrescriptionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parvarish vositalari"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateSheet(context),
        child: const Icon(Icons.add),
      ),
      body: ResponsiveFrame(
        child: StreamBuilder<List<CareItem>>(
          stream: service.streamCareItems(opticaId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoader();
            }

            if (snapshot.hasError) {
              print(snapshot.error);
              return const Center(child: Text("Parvarishlash vositalarini yuklashda xatolik yuz berdi"));
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return const EmptyState(title: "Hali parvarish vositalari yo'q");
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = _columnsForWidth(constraints.maxWidth);
                if (columns <= 1) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CareItemCard(item: item, opticaId: opticaId);
                    },
                  );
                }

                const spacing = 12.0;
                final availableWidth = constraints.maxWidth - (16 * 2);
                final itemWidth =
                    (availableWidth - (spacing * (columns - 1))) / columns;

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 80,
                  ),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: items.map((item) {
                      return SizedBox(
                        width: itemWidth,
                        child: CareItemCard(item: item, opticaId: opticaId),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateCareItemSheet(opticaId: opticaId),
    );
  }
}
