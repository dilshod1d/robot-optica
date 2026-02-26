import 'package:flutter/material.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'sales_history_screen.dart';
import 'sales_analytics_screen.dart';

class SalesTabScreen extends StatelessWidget {
  final String opticaId;

  const SalesTabScreen({super.key, required this.opticaId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.black,
              tabs: [
                Tab(text: "Inventar"),
                Tab(text: "POS"),
                Tab(text: "Tarix"),
                Tab(text: "Analitika"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                InventoryScreen(opticaId: opticaId),
                PosScreen(opticaId: opticaId),
                SalesHistoryScreen(opticaId: opticaId),
                SalesAnalyticsScreen(opticaId: opticaId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
