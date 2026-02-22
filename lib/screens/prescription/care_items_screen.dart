import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';

import '../../models/care_item.dart';
import '../../services/prescription_service.dart';
import '../../widgets/prescription/care_item_card.dart';
import '../../widgets/prescription/care_item_sheet.dart';


class CareItemsScreen extends StatelessWidget {
  final String opticaId;
  const CareItemsScreen({super.key, required this.opticaId});

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
      body: StreamBuilder<List<CareItem>>(
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return CareItemCard(item: item, opticaId: opticaId,);
            },
          );
        },
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
