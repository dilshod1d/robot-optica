import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/screens/customer/customer_sms_log_screen.dart';
import 'package:robot_optica/screens/visits/customer_visits_screen.dart';
import 'package:robot_optica/widgets/analyses/add_analysis_sheet.dart';
import 'package:robot_optica/widgets/analyses/patient_eye_analyses_widget.dart';
import 'package:robot_optica/widgets/billing/billing_sheet_widget.dart';
import 'package:robot_optica/widgets/prescription/add_prescription_sheet.dart';
import 'package:robot_optica/widgets/visits/add_visit_sheet.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/customer_report_service.dart';
import '../../services/customer_service.dart';
import '../../services/eye_scan_service.dart';
import '../../services/optica_service.dart';
import '../../services/prescription_service.dart';
import '../../widgets/billing/customer_billing_widget.dart';
import '../../widgets/customer/customer_app_bar.dart';
import '../../widgets/customer/customer_tabs.dart';
import '../../widgets/common/responsive_frame.dart';
import '../../widgets/prescription/customer_prescriptions_widget.dart';
import 'customer_overview_tab.dart';


class CustomerProfileScreen extends StatefulWidget {
  final CustomerModel customer;

  const CustomerProfileScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

enum _ReportAction { print, download }

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool smsEnabled = true;
  int selectedTabIndex = 0;

  final OpticaService _opticaService = OpticaService();
  final EyeScanService _analysisService = EyeScanService();
  final PrescriptionService _prescriptionService = PrescriptionService();
  final CustomerReportService _reportService = CustomerReportService();
  final CustomerService _customerService = CustomerService();

  late CustomerModel customer;

  @override
  void initState() {
    super.initState();
    customer = widget.customer;
  }

  // 👇 PUT THEM HERE
  void _callPatient() async {
    final phoneNumber = "tel:${customer.phone}";

    final uri = Uri.parse(phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open phone app")),
      );
    }
  }


  void _addVisit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddVisitSheet(customer: customer),
    );
  }


  void _addPrescription() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddCarePlanSheet(customer: customer, visitId: '',),
    );
  }


  void _openAddAnalysisSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddAnalysisSheet(customerId: customer.id, opticaId: customer.opticaId,),
    );
  }


  void _addInvoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return BillingSheet(opticaId: customer.opticaId, customer: customer,);
      },
    );
  }

  Future<void> _deleteCustomer() async {
    final opticaId = context.read<AuthProvider>().opticaId;
    if (opticaId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Mijozni o'chirish"),
        content: const Text(
          "Bu mijozni butunlay o'chirasiz. Bu amalni ortga qaytarib bo'lmaydi.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    _showDeletingDialog();

    try {
      await _customerService.deleteCustomerCascade(
        opticaId: opticaId,
        customerId: customer.id,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading
      Navigator.pop(context); // back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mijoz o'chirildi")),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mijozni o'chirishda xatolik")),
      );
    }
  }

  Future<void> _exportCustomerReport() async {
    final action = await _showReportActions();
    if (action == null) return;

    if (!mounted) return;
    _showLoadingDialog();

    try {
      final optica = await _opticaService.getOpticaById(customer.opticaId);
      final analyses = await _analysisService.fetchByCustomer(
        opticaId: customer.opticaId,
        customerId: customer.id,
      );
      final prescriptions = await _prescriptionService.fetchCarePlansByCustomer(
        opticaId: customer.opticaId,
        customerId: customer.id,
      );

      final pdf = await _reportService.buildCustomerReportPdf(
        customer: customer,
        optica: optica,
        analyses: analyses,
        prescriptions: prescriptions,
      );

      final name = _buildReportFileName(customer);
      if (!mounted) return;
      Navigator.pop(context);

      if (action == _ReportAction.print) {
        final info = await Printing.info();
        if (!info.canPrint) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Printer mavjud emas")),
          );
          return;
        }
        await Printing.layoutPdf(
          name: name,
          format: PdfPageFormat.a4,
          dynamicLayout: !Platform.isMacOS,
          onLayout: (_) async => pdf,
        );
      } else {
        await Printing.sharePdf(
          bytes: pdf,
          filename: name,
        );
      }
    } catch (e) {
      print('Error creating pdf $e');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF yaratishda xatolik")),
      );
    }
  }

  Future<_ReportAction?> _showReportActions() {
    return showModalBottomSheet<_ReportAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text("Chop etish"),
              onTap: () => Navigator.pop(context, _ReportAction.print),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text("PDF yuklab olish"),
              onTap: () => Navigator.pop(context, _ReportAction.download),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text("PDF tayyorlanmoqda...")),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeletingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text("Mijoz o'chirilmoqda...")),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildReportFileName(CustomerModel customer) {
    final name = customer.fullName.trim().toLowerCase();
    final safe = name
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (safe.isEmpty) return 'customer_report.pdf';
    return "${safe}_report.pdf";
  }

  Widget _buildFab() {
    switch (selectedTabIndex) {
      case 0:
        return FloatingActionButton(
          key: const ValueKey("call"),
          onPressed: _callPatient,
          backgroundColor: Colors.green,
          child: const Icon(Icons.call),
        );

      case 1:
        return FloatingActionButton(
          key: const ValueKey("visit"),
          onPressed: _addVisit,
          child: const Icon(Icons.add),
        );

      case 2:
        return FloatingActionButton(
          key: const ValueKey("prescription"),
          onPressed: _addPrescription,
          child: const Icon(Icons.description),
        );

      case 3:
        return FloatingActionButton(
          key: const ValueKey("analysis"),
          onPressed: _openAddAnalysisSheet,
          child: const Icon(Icons.remove_red_eye),
        );

      case 4:
        return FloatingActionButton(
          key: const ValueKey("billing"),
          onPressed: _addInvoice,
          child: const Icon(Icons.receipt_long),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTabContent(String opticaId) {
    switch (selectedTabIndex) {
      case 0:
        return CustomerOverviewTab(
          opticaId: opticaId,
          customer: customer,
        );

      case 1:
        return CustomerVisitsScreen(
          opticaId: opticaId,
          customerName: customer.firstName,
          customerId: customer.id,
        );

      case 2:
        return CustomerPrescriptionsWidget(
          customerId: customer.id,
          opticaId: opticaId,
        );

      case 3:
        return PatientEyeAnalysesWidget(customer: customer);

      case 4:
        return CustomerBillingWidget(
          opticaId: opticaId,
          customerId: customer.id,
        );

      case 5:
        return CustomerSmsLogTab(customer: customer);

      default:
        return const SizedBox();
    }
  }



  @override
  Widget build(BuildContext context) {
    final opticaId = context.watch<AuthProvider>().opticaId;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: CustomerAppBar(
        name: "${customer.firstName} ${customer.lastName ?? ""}",
        phone: customer.phone,
        actions: [
          IconButton(
            onPressed: _exportCustomerReport,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
            tooltip: "PDF",
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteCustomer();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text("Mijozni o'chirish"),
              ),
            ],
          ),
        ],
      ),
      body: ResponsiveFrame(
        maxWidth: 1200,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomerTabs(
                      activeIndex: selectedTabIndex,
                      isVertical: true,
                      width: 220,
                      onChanged: (index) {
                        setState(() {
                          selectedTabIndex = index;
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTabContent(opticaId!),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomerTabs(
                      activeIndex: selectedTabIndex,
                      onChanged: (index) {
                        setState(() {
                          selectedTabIndex = index;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    Expanded(
                      child: _buildTabContent(opticaId!),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: _buildFab(),
      ),

    );
  }
}
