import 'sms_types.dart';

class SmsTemplateDefaults {
  static const Map<String, String> latin = {
    SmsLogTypes.visitCreated:
        "{opticaName}: Hurmatli {firstName} {lastName}, {visitDate} kuni {visitReason} bo‘yicha tashrifingizni kutamiz. Savol: {opticaPhone}",
    SmsLogTypes.visitBefore:
        "{opticaName}: Hurmatli {firstName} {lastName}, {visitDate} kuni {visitReason} bo‘yicha tashrifingiz eslatmasi. Savol: {opticaPhone}",
    SmsLogTypes.visitOnDate:
        "{opticaName}: Hurmatli {firstName} {lastName}, bugun {visitReason} bo‘yicha tashrifingiz bor. Savol: {opticaPhone}",
    SmsLogTypes.debtCreated:
        "{opticaName}: Hurmatli {firstName} {lastName}, {amount} so'm qarz rasmiylashtirildi. To'lov muddati: {dueDate}. Savol: {opticaPhone}",
    SmsLogTypes.debtBefore:
        "{opticaName}: Hurmatli {firstName} {lastName}, {dueDate} kuni {amount} so'm qarzingizni to'lash muddati yaqinlashmoqda. Savol: {opticaPhone}",
    SmsLogTypes.debtDue:
        "{opticaName}: Hurmatli {firstName} {lastName}, {dueDate} da to'lanishi kerak bo'lgan {amount} so'm qarzingiz bor. Iltimos tezroq to'lov qiling. Savol: {opticaPhone}",
    SmsLogTypes.debtRepeat:
        "{opticaName}: Hurmatli {firstName} {lastName}, qarzingiz muddati o'tgan. {amount} so'm qarzingiz bor. Iltimos to'lov qiling. Savol: {opticaPhone}",
    SmsLogTypes.debtPaid:
        "{opticaName}: Hurmatli {firstName} {lastName}, qarzingiz to'liq to'landi. Summa: {paidAmount} so'm. Rahmat! Savol: {opticaPhone}",
    SmsLogTypes.prescriptionCreated:
        "{opticaName}: Hurmatli {firstName} {lastName}, retsept tayyor. Dorilar: {items} Savol: {opticaPhone}",
  };

  static const Map<String, String> cyrillic = {
    SmsLogTypes.visitCreated:
        "{opticaName}: Ҳурматли {firstName} {lastName}, {visitDate} куни {visitReason} бўйича ташрифингизни кутамиз. Савол: {opticaPhone}",
    SmsLogTypes.visitBefore:
        "{opticaName}: Ҳурматли {firstName} {lastName}, {visitDate} куни {visitReason} бўйича ташрифингизни эслатамиз. Савол: {opticaPhone}",
    SmsLogTypes.visitOnDate:
        "{opticaName}: Ҳурматли {firstName} {lastName}, бугун {visitReason} бўйича ташрифингиз бор. Савол: {opticaPhone}",
    SmsLogTypes.debtCreated:
        "{opticaName}: Ҳурматли {firstName} {lastName}, {amount} сўм қарз яратилди. Тўлов муддати: {dueDate}. Савол: {opticaPhone}",
    SmsLogTypes.debtBefore:
        "{opticaName}: Ҳурматли {firstName} {lastName}, {dueDate} куни {amount} сўм қарзингизни тўлаш муддати яқинлашмоқда. Савол: {opticaPhone}",
    SmsLogTypes.debtDue:
        "{opticaName}: Ҳурматли {firstName} {lastName}, {dueDate} да тўланиши керак бўлган {amount} сўм қарзингиз бор. Илтимос, тезроқ тўлов қилинг. Савол: {opticaPhone}",
    SmsLogTypes.debtRepeat:
        "{opticaName}: Ҳурматли {firstName} {lastName}, қарзингиз муддати ўтган. {amount} сўм қарзингиз бор. Илтимос, тўлов қилинг. Савол: {opticaPhone}",
    SmsLogTypes.debtPaid:
        "{opticaName}: Ҳурматли {firstName} {lastName}, қарзингиз тўлиқ тўланди. Сумма: {paidAmount} сўм. Раҳмат! Савол: {opticaPhone}",
    SmsLogTypes.prescriptionCreated:
        "{opticaName}: Ҳурматли {firstName} {lastName}, рецепт тайёр. Дорилар: {items} Савол: {opticaPhone}",
  };

  static const String prescriptionItemLatin =
      "{index}) {itemName} - {itemInstruction} {itemDosage}x/kun {itemDuration} kun {itemNotes}";

  static const String prescriptionItemCyrillic =
      "{index}) {itemName} - {itemInstruction} {itemDosage}x/кун {itemDuration} кун {itemNotes}";

  static Map<String, String> forLanguage(String language) {
    return language == 'latin' ? latin : cyrillic;
  }
}
