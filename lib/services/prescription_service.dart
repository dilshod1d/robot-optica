import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../models/care_item.dart';
import '../models/care_plan_model.dart';
import '../models/customer_model.dart';
import '../models/sms_config_model.dart';
import '../services/optica_service.dart';
import 'customer_service.dart';
import 'sms_rule_engine.dart';
import '../utils/device_info_utils.dart';
import '../utils/sms_sanitizer.dart';
import '../utils/sms_template_defaults.dart';
import '../utils/sms_template_engine.dart';
import '../utils/sms_types.dart';

class PrescriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CustomerService _customerService = CustomerService();
  final OpticaService _opticaService = OpticaService();
  final SmsRuleEngine _smsRuleEngine = SmsRuleEngine();

  // ================== COLLECTION HELPERS ==================

  CollectionReference<Map<String, dynamic>> _careItemsRef(String opticaId) {
    return _db
        .collection('opticas')
        .doc(opticaId)
        .collection('care_items');
  }

  CollectionReference<Map<String, dynamic>> _carePlansRef(String opticaId) {
    return _db
        .collection('opticas')
        .doc(opticaId)
        .collection('care_plans');
  }

  void listenForNewPrescriptions(String opticaId) {
    _carePlansRef(opticaId)
        .where('prescriptionSmsPending', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added &&
            change.type != DocumentChangeType.modified) {
          continue;
        }

        final data = change.doc.data();
        if (data == null) continue;

        final plan = CarePlanModel.fromFirestore(
          data,
          change.doc.id,
        );

        final CustomerModel? customer =
        await _customerService.getCustomer(
          opticaId: opticaId,
          customerId: plan.customerId,
        );

        if (customer == null ||
            !customer.visitsSmsEnabled ||
            customer.phone.isEmpty) {
          await _clearPrescriptionSmsPending(opticaId, plan.id);
          continue;
        }

        final SmsConfigModel config = await _opticaService.getSmsConfig(opticaId);
        if (!config.isSmsEnabled || !config.smsForPrescriptions) {
          await _clearPrescriptionSmsPending(opticaId, plan.id);
          continue;
        }

        final localDeviceId = await getDeviceId();
        if (config.smsEnabledDeviceId == null || localDeviceId == null) continue;
        if (config.smsEnabledDeviceId != localDeviceId) continue;

        final message = buildPrescriptionMessage(
          customerFirstName: customer.firstName,
          plan: plan,
          config: config,
        );

        final sent = await _smsRuleEngine.sendPrescriptionSms(
          opticaId: opticaId,
          plan: plan,
          customer: customer,
          message: message,
          config: config,
        );

        if (sent) {
          await _clearPrescriptionSmsPending(opticaId, plan.id);
        }
      }
    });
  }


  String buildPrescriptionMessage({
    required String customerFirstName,
    String? customerLastName,
    required CarePlanModel plan,
    SmsConfigModel? config,
  }) {
    final isCyrillic = config?.isSmsCyrillic ?? false;
    final buffer = StringBuffer();
    final safeLastName = (customerLastName ?? '').trim();

    for (int i = 0; i < plan.items.length; i++) {
      final item = plan.items[i];

      final name = _cleanName(item.title);
      final dosage = item.dosage;
      final duration = item.duration;
      final durationStr = duration > 0 ? duration.toString() : '-';

      buffer.write(
        "${i + 1}) $name ${dosage}x/${isCyrillic ? 'кун' : 'kun'} "
        "${durationStr} ${isCyrillic ? 'кун' : 'kun'}; ",
      );
    }

    final itemsText = buffer.toString().trim();
    final opticaName = config?.opticaName ?? 'Optica';
    final opticaPhone = (config?.opticaPhone ?? '').trim().isEmpty
        ? '933400034'
        : config!.opticaPhone;
    final itemTemplate = config == null
        ? ''
        : (isCyrillic
            ? config.prescriptionItemTemplateCyrillic
            : config.prescriptionItemTemplateLatin);
    final fallbackItemTemplate = isCyrillic
        ? SmsTemplateDefaults.prescriptionItemCyrillic
        : SmsTemplateDefaults.prescriptionItemLatin;
    final effectiveItemTemplate =
        itemTemplate.trim().isEmpty ? fallbackItemTemplate : itemTemplate;

    final template = config == null
        ? ''
        : SmsTemplateEngine.resolveTemplate(
            config: config,
            type: SmsLogTypes.prescriptionCreated,
          );

    final itemLines = plan.items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      final name = _cleanName(item.title);
      final instruction = item.instruction.trim().isEmpty
          ? (isCyrillic ? '-' : '-')
          : item.instruction.trim();
      final dosage = item.dosage > 0 ? item.dosage.toString() : '-';
      final duration = item.duration > 0 ? item.duration.toString() : '-';
      final notes = (item.notes ?? '').trim().isEmpty ? '' : item.notes!.trim();
      final rendered = SmsTemplateEngine.render(
        template: effectiveItemTemplate,
        variables: {
          'index': idx.toString(),
          'itemName': name,
          'itemInstruction': instruction,
          'itemDosage': dosage,
          'itemDuration': duration,
          'itemNotes': notes,
        },
      );
      return rendered.trim();
    }).where((line) => line.isNotEmpty).toList();

    final itemsRendered = itemLines.isEmpty ? itemsText : itemLines.join('\n');

    final rendered = template.isEmpty
        ? "${opticaName}: "
            "${isCyrillic ? 'Ҳурматли' : 'Hurmatli'} $customerFirstName, "
            "${isCyrillic ? 'рецепт тайёр. Дорилар:' : 'retsept tayyor. Dorilar:'} "
            "$itemsRendered ${isCyrillic ? 'Савол:' : 'Savol:'} $opticaPhone"
        : SmsTemplateEngine.render(
            template: template,
            variables: {
              'firstName': customerFirstName,
              'lastName': safeLastName,
              'items': itemsRendered,
              'opticaName': opticaName,
              'opticaPhone': opticaPhone,
            },
          );

    return smsSanitize(rendered, allowUnicode: isCyrillic);
  }


  // ================== CARE ITEM TEMPLATES ==================

  Future<List<CareItem>> fetchCareItems(String opticaId) async {
    final snap = await _careItemsRef(opticaId).get();
    return snap.docs
        .map((d) => CareItem.fromMap(d.data(), d.id))
        .toList();
  }

  Stream<List<CareItem>> streamCareItems(String opticaId) {
    return _careItemsRef(opticaId).snapshots().map(
          (snap) => snap.docs
          .map((d) => CareItem.fromMap(d.data(), d.id))
          .toList(),
    );
  }

  Future<void> createCareItem(
      String opticaId,
      CareItem item,
      ) async {
    await _careItemsRef(opticaId).add(item.toMap());
  }

  Future<void> deleteCareItem(
      String opticaId,
      String id,
      ) async {
    await _careItemsRef(opticaId).doc(id).delete();
  }

  // ================== CARE PLANS / PRESCRIPTIONS ==================

  Future<void> createCarePlan(
      String opticaId,
      CarePlanModel plan,
      {bool sendSms = true}
      ) async {
    final data = plan.toMap();

    if (sendSms) {
      try {
        final config = await _opticaService.getSmsConfig(opticaId);
        if (config.isSmsEnabled && config.smsForPrescriptions) {
          final customer = await _customerService.getCustomer(
            opticaId: opticaId,
            customerId: plan.customerId,
          );

          if (customer != null &&
              customer.visitsSmsEnabled &&
              customer.phone.trim().isNotEmpty) {
            data['prescriptionSmsPending'] = true;
          }
        }
      } catch (_) {
        data['prescriptionSmsPending'] = true;
      }
    }

    await _carePlansRef(opticaId).add(data);
  }

  Future<List<CarePlanModel>> fetchPendingPrescriptions({
    required String opticaId,
    int limit = 50,
  }) async {
    final snapshot = await _carePlansRef(opticaId)
        .where('prescriptionSmsPending', isEqualTo: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((d) => CarePlanModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  Future<void> clearPrescriptionSmsPending(String opticaId, String planId) async {
    await _clearPrescriptionSmsPending(opticaId, planId);
  }

  Future<void> _clearPrescriptionSmsPending(String opticaId, String planId) async {
    await _carePlansRef(opticaId).doc(planId).update({
      'prescriptionSmsPending': false,
    });
  }

  String _cleanName(String title) {
    final parts = title.split(" ");
    return parts.length > 3 ? parts.take(3).join(" ") : title;
  }

  Future<List<CarePlanModel>> fetchCarePlansByCustomer({
    required String opticaId,
    required String customerId,
  }) async {
    final snap = await _carePlansRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((d) => CarePlanModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  Future<List<CarePlanModel>> fetchCarePlansByVisit({
    required String opticaId,
    required String visitId,
  }) async {
    final snap = await _carePlansRef(opticaId)
        .where('visitId', isEqualTo: visitId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((d) => CarePlanModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  Stream<List<CarePlanModel>> streamCarePlansByCustomer({
    required String opticaId,
    required String customerId,
  }) {
    return _carePlansRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
          .map(
            (d) => CarePlanModel.fromFirestore(d.data(), d.id),
      )
          .toList(),
    );
  }

  Stream<List<CarePlanModel>> streamCarePlansByVisit({
    required String opticaId,
    required String visitId,
  }) {
    return _carePlansRef(opticaId)
        .where('visitId', isEqualTo: visitId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
          .map(
            (d) => CarePlanModel.fromFirestore(d.data(), d.id),
      )
          .toList(),
    );
  }

  Future<void> updateCarePlan(
      String opticaId,
      CarePlanModel plan,
      ) async {
    await _carePlansRef(opticaId)
        .doc(plan.id)
        .update(plan.toMap());
  }

  Future<void> deleteCarePlan(
      String opticaId,
      String id,
      ) async {
    await _carePlansRef(opticaId).doc(id).delete();
  }

  // ================== COUNTS ==================

  Future<int?> getCustomerPrescriptionCount({
    required String opticaId,
    required String customerId,
  }) async {
    final snapshot = await _carePlansRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .count()
        .get();

    return snapshot.count;
  }
}
