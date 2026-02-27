import 'package:flutter/material.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'sales_history_screen.dart';
import 'sales_analytics_screen.dart';

class SalesTabScreen extends StatefulWidget {
  final String opticaId;

  const SalesTabScreen({super.key, required this.opticaId});

  @override
  State<SalesTabScreen> createState() => _SalesTabScreenState();
}

class _SalesTabScreenState extends State<SalesTabScreen> {
  int _index = 0;

  List<_SalesTabItem> get _tabs => [
        _SalesTabItem(
          label: "Inventar",
          icon: Icons.inventory_2,
          child: InventoryScreen(opticaId: widget.opticaId),
        ),
        _SalesTabItem(
          label: "POS",
          icon: Icons.point_of_sale,
          child: PosScreen(opticaId: widget.opticaId),
        ),
        _SalesTabItem(
          label: "Tarix",
          icon: Icons.receipt_long,
          child: SalesHistoryScreen(opticaId: widget.opticaId),
        ),
        _SalesTabItem(
          label: "Analitika",
          icon: Icons.insights,
          child: SalesAnalyticsScreen(opticaId: widget.opticaId),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final tabs = _tabs;

    if (!isDesktop) {
      return DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: Colors.black,
                tabs: tabs.map((t) => Tab(text: t.label)).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: tabs.map((t) => t.child).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 190,
          color: Colors.white,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: tabs.length,
            itemBuilder: (context, i) {
              final tab = tabs[i];
              final active = _index == i;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _index = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.black.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 18,
                          color: active ? Colors.black : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: active ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: tabs.map((t) => t.child).toList(),
          ),
        ),
      ],
    );
  }
}

class _SalesTabItem {
  final String label;
  final IconData icon;
  final Widget child;

  const _SalesTabItem({
    required this.label,
    required this.icon,
    required this.child,
  });
}
