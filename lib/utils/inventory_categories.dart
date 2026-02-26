const Map<String, String> inventoryCategories = {
  'frame': "Ko'zoynak",
  'lens': 'Linza',
  'contact_lens': 'Kontakt linza',
  'accessory': 'Aksesuar',
  'service': 'Xizmat',
  'other': 'Boshqa',
};

List<String> inventoryCategoryKeys() => inventoryCategories.keys.toList();

String inventoryCategoryLabel(String key) =>
    inventoryCategories[key] ?? inventoryCategories['other'] ?? 'Boshqa';
