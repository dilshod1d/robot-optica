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


    return Scaffold(
      appBar: AppBar(
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

      body: IndexedStack(
        index: _currentIndex,
        children: [
          const MainTab(),
          const CustomerListScreen(),
          VisitsDashboardScreen(opticaId: opticaId),
          const BillingDashboardScreen(),
          SalesTabScreen(opticaId: opticaId),
          SmsDashboardScreen(opticaId: opticaId,),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
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
}
