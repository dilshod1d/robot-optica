import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer_model.dart';
import '../../widgets/customer/customer_list_item.dart';
import '../../widgets/customer/edit_customer_info_sheet.dart';
import '../../widgets/common/responsive_frame.dart';
import 'customer_profile_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _query = "";
  int _columnsForWidth(double width) {
    const minWidth = 320.0;
    const maxColumns = 4;
    if (width <= 0) return 1;
    final count = (width / minWidth).floor();
    return count.clamp(1, maxColumns);
  }

  void _openAddCustomerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EditCustomerInfoSheet(
        isEdit: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider?>();
    final opticaId = context.watch<AuthProvider>().opticaId;

    if (opticaId == null) {
      return const AppLoader();
    }

    return ResponsiveFrame(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Ism yoki telefon raqami bo'yicha qidiruv",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<CustomerModel>>(
              stream: _query.isEmpty
                  ? provider?.watchCustomers(opticaId)
                  : provider?.searchCustomers(
                opticaId: opticaId,
                query: _query,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }

                if (snapshot.hasError) {
                  print('Error loading customers ${snapshot.error}');
                  return const Center(child: Text("Nimadir noto'g'ri ketdi"));
                }

                final customers = snapshot.data ?? [];

                if (customers.isEmpty) {
                  return const Center(child: Text("Xaridorlar yo'q"));
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth =
                        constraints.maxWidth - (12 * 2);
                    final columns = _columnsForWidth(availableWidth);
                    if (columns <= 1) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: customers.length,
                        itemBuilder: (_, i) {
                          final c = customers[i];

                          return CustomerListItem(
                            customer: c,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerProfileScreen(customer: c),
                                ),
                              );
                            },
                          );
                        },
                      );
                    }

                    const spacing = 12.0;
                    final itemWidth =
                        (availableWidth - (spacing * (columns - 1))) /
                            columns;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 80,
                      ),
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: customers.map((c) {
                          return SizedBox(
                            width: itemWidth,
                            child: CustomerListItem(
                              customer: c,
                              margin: EdgeInsets.zero,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerProfileScreen(customer: c),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Floating add button (tab-safe)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                onPressed: _openAddCustomerSheet,
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/customer_provider.dart';
// import '../../models/customer_model.dart';
// import '../../widgets/customer/customer_list_item.dart';
// import '../../widgets/customer/edit_client_info_sheet.dart';
// import 'customer_profile_screen.dart';
//
// class CustomerListScreen extends StatefulWidget {
//   const CustomerListScreen({super.key});
//
//   @override
//   State<CustomerListScreen> createState() => _CustomerListScreenState();
// }
//
// class _CustomerListScreenState extends State<CustomerListScreen> {
//   String _query = "";
//
//   void _openAddCustomerSheet() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (_) => const EditClientInfoSheet(
//         isEdit: false,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<CustomerProvider?>();
//     final opticaId = context.watch<AuthProvider>().opticaId;
//
//     if (opticaId == null) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     return Scaffold(
//
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: TextField(
//               decoration: const InputDecoration(
//                 hintText: "Search by name or phone",
//                 prefixIcon: Icon(Icons.search),
//               ),
//               onChanged: (v) => setState(() => _query = v),
//             ),
//           ),
//           Expanded(
//             child: StreamBuilder<List<CustomerModel>>(
//               stream: _query.isEmpty
//                   ? provider?.watchCustomers(opticaId)
//                   : provider?.searchCustomers(
//                 opticaId: opticaId,
//                 query: _query,
//               ),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//
//                 final customers = snapshot.data!;
//
//                 if (customers.isEmpty) {
//                   return const Center(child: Text("No customers"));
//                 }
//
//                 return ListView.builder(
//                   itemCount: customers.length,
//                   itemBuilder: (_, i) {
//                     final c = customers[i];
//
//                     return CustomerListItem(
//                       customer: c,
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) =>
//                                 CustomerProfileScreen(customer: c),
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _openAddCustomerSheet,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
//
//
