import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../services/customer_stats_service.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/customer/customer_general_info.dart';
import '../../widgets/customer/customer_stats.dart';


class CustomerOverviewTab extends StatelessWidget {
  final String opticaId;
  final CustomerModel customer;

  const CustomerOverviewTab({
    super.key,
    required this.opticaId,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: CustomerStatsService().load(
        opticaId: opticaId,
        customerId: customer.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            children: [
              CustomerGeneralInfo(
                customer: customer,
                opticaId: opticaId,
              ),
          
              const SizedBox(height: 20),
          
              CustomerStats(stats: stats,),
            ],
          ),
        );
      },
    );
  }
}
