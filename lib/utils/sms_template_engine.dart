import '../models/sms_config_model.dart';
import 'sms_template_defaults.dart';

class SmsTemplateEngine {
  static String resolveTemplate({
    required SmsConfigModel config,
    required String type,
  }) {
    final Map<String, String> custom = config.isSmsCyrillic
        ? config.smsTemplatesCyrillic
        : config.smsTemplatesLatin;

    final customTemplate = custom[type];
    if (customTemplate != null && customTemplate.trim().isNotEmpty) {
      return customTemplate;
    }

    final fallback =
        SmsTemplateDefaults.forLanguage(config.smsLanguage)[type] ?? '';
    return fallback;
  }

  static String render({
    required String template,
    required Map<String, String> variables,
  }) {
    var output = template;
    variables.forEach((key, value) {
      output = output.replaceAll('{$key}', value);
    });
    return output;
  }
}
