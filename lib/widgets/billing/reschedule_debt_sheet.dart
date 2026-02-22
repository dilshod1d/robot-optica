import 'package:flutter/material.dart';

class RescheduleDebtResult {
  final DateTime date;
  final bool resetSms;

  const RescheduleDebtResult({
    required this.date,
    required this.resetSms,
  });
}

class RescheduleDebtSheet {
  static Future<RescheduleDebtResult?> show({
    required BuildContext context,
    required DateTime initialDate,
  }) {
    return showModalBottomSheet<RescheduleDebtResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        DateTime selectedDate = initialDate;
        bool resetSms = true;

        return StatefulBuilder(
          builder: (context, setState) {
            final dateLabel =
                MaterialLocalizations.of(context).formatFullDate(selectedDate);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).viewPadding.bottom +
                    20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "To‘lov sanasini ko‘chirish",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text("Yangi sana"),
                    subtitle: Text(dateLabel),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: const Text("Tanlash"),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("SMS sanog‘ini orqaga qaytarish"),
                    subtitle: const Text("Eslatmalar qayta yuboriladi"),
                    value: resetSms,
                    onChanged: (v) => setState(() => resetSms = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Bekor qilish"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                              RescheduleDebtResult(
                                date: selectedDate,
                                resetSms: resetSms,
                              ),
                            );
                          },
                          child: const Text("Saqlash"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
