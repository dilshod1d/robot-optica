import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/widgets/billing/billing_item_card.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/empty_state.dart';
import '../../models/billing_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/billing_service.dart';
import '../../widgets/billing/pay_bottom_sheet.dart';
import '../../screens/billing/billing_detail_screen.dart';
import '../../widgets/billing/reschedule_debt_sheet.dart';

class BillingListWidget extends StatelessWidget {
  const BillingListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final opticaId = context.watch<AuthProvider>().opticaId;

    if (opticaId == null) {
      return const AppLoader();
    }

    final service = BillingFirebaseService();

    return StreamBuilder<List<BillingModel>>(
      stream: service.watchRecentBillings(opticaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: AppLoader(
              size: 80,
              fill: false,
            ),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text("Nimadir noto'g'ri ketdi")),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 220,
            child: EmptyState(
              title: "Hisob-faktura yo'q",
            ),
          );
        }

        final list = snapshot.data!;

        return Column(
          children: list.map((bill) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BillingItemCard(
                  bill: bill,
                  showCustomerName: true,
                  onPay: bill.remaining > 0
                      ? () => _pay(context, service, opticaId, bill)
                      : null,
                  onEdit: bill.remaining > 0
                      ? () => _reschedule(context, service, opticaId, bill)
                      : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BillingDetailScreen(
                        opticaId: opticaId,
                        billing: bill,
                        service: service,
                      ),
                    ),
                  );
                },

              ),

            );
          }).toList(),
        );
      },
    );
  }

  void _pay(
      BuildContext context,
      BillingFirebaseService service,
      String opticaId,
      BillingModel bill,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PayBottomSheet(
        maxAmount: bill.remaining,
        onConfirm: (amount, note) async {
          await service.applyPayment(
            opticaId: opticaId,
            billing: bill,
            amount: amount,
            note: note,
          );
        },
      ),
    );
  }

  Future<void> _reschedule(
    BuildContext context,
    BillingFirebaseService service,
    String opticaId,
    BillingModel bill,
  ) async {
    final result = await RescheduleDebtSheet.show(
      context: context,
      initialDate: bill.dueDate.toDate(),
    );
    if (result == null) return;
    await service.rescheduleDebt(
      opticaId: opticaId,
      billing: bill,
      newDate: result.date,
      resetSms: result.resetSms,
    );
  }
}
