import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/screens/customer/customer_list_screen.dart';
import 'package:robot_optica/screens/messages/sms_dashboard_screen.dart';
import 'package:robot_optica/screens/settings_screen.dart';
import 'package:robot_optica/screens/visits/visits_dashboard_screen.dart';
import 'package:robot_optica/screens/inventory/sales_tab_screen.dart';
import '../providers/auth_provider.dart';
import '../services/optica_service.dart';
import '../services/prescription_service.dart';
import '../services/visit_service.dart';
import '../services/billing_service.dart';
import '../services/sms_scheduler_service.dart';
import '../widgets/common/app_loader.dart';
import 'billing/billing_dashboard_screen.dart';
import 'main_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final VisitService _visitService = VisitService();
  final PrescriptionService _prescriptionService = PrescriptionService();
  final BillingFirebaseService _billingService = BillingFirebaseService();

  bool _startedListening = false;
  bool _startedPrescriptionListening = false;
  bool _startedDebtListening = false;
  bool _startedDebtPaidListening = false;
  bool _schedulerInitialized = false;

  final _titles = [
    "Asosiy",
    "Xaridorlar",
    "Tashriflar",
    "To'lovlar",
    "Savdo",
    "SMS",
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final opticaId = context.watch<AuthProvider>().opticaId;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final extendRail = width >= 1200;

    if (opticaId != null && !_startedListening) {
      _startedListening = true;
      //  Start realtime SMS trigger safely
      _visitService.listenForNewVisits(opticaId);
    }

    if (opticaId != null && !_startedPrescriptionListening) {
      _startedPrescriptionListening = true;
      _prescriptionService.listenForNewPrescriptions(opticaId);
    }

    if (opticaId != null && !_startedDebtListening) {
      _startedDebtListening = true;
      _billingService.listenForNewDebts(opticaId);
    }

    if (opticaId != null && !_startedDebtPaidListening) {
      _startedDebtPaidListening = true;
      _billingService.listenForPaidDebts(opticaId);
    }

    if (opticaId != null && !_schedulerInitialized) {
      _schedulerInitialized = true;
      SmsSchedulerService().syncWithOptica(opticaId);
    }

    if (opticaId == null) {
      return Scaffold(
        body: const AppLoader()
      );
    }


    final content = IndexedStack(
      index: _currentIndex,
      children: [
        const MainTab(),
        const CustomerListScreen(),
        VisitsDashboardScreen(opticaId: opticaId),
        const BillingDashboardScreen(),
        SalesTabScreen(opticaId: opticaId),
        SmsDashboardScreen(opticaId: opticaId),
      ],
    );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(_titles[_currentIndex]),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FutureBuilder(
                    future: OpticaService().getOpticaById(opticaId),
                    builder: (context, snapshot) {
                      final opticaName = snapshot.data?.name;

                      return Row(
                        children: [
                          if (opticaName != null && opticaName.isNotEmpty)
                            SizedBox(
                              child: Text(
                                opticaName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onTabTapped,
                  extended: extendRail,
                  labelType:
                      extendRail ? null : NavigationRailLabelType.all,
                  minWidth: 72,
                  minExtendedWidth: 200,
                  backgroundColor: Colors.white,
                  selectedIconTheme: IconThemeData(
                    color: Theme.of(context).primaryColor,
                  ),
                  selectedLabelTextStyle: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard),
                      label: Text("Asosiy"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people),
                      label: Text("Xaridorlar"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.event),
                      label: Text("Tashriflar"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long),
                      label: Text("To'lovlar"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.point_of_sale),
                      label: Text("Savdo"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.sms),
                      label: Text("SMS"),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _buildDesktopHeader(opticaId),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            )
          : content,
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).primaryColor,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: "Asosiy",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: "Xaridorlar",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event),
                  label: "Tashriflar",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long), // Billing
                  label: "To'lovlar",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.point_of_sale),
                  label: "Savdo",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.sms),
                  label: "SMS",
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopHeader(String opticaId) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Text(
            _titles[_currentIndex],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          FutureBuilder(
            future: OpticaService().getOpticaById(opticaId),
            builder: (context, snapshot) {
              final opticaName = snapshot.data?.name ?? '';
              return Row(
                children: [
                  if (opticaName.isNotEmpty)
                    SizedBox(
                      child: Text(
                        opticaName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
