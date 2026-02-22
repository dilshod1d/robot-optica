String smsSanitize(String text, {bool allowUnicode = false}) {
  final cleaned = text
      .replaceAll("o‘", "o'")
      .replaceAll("g‘", "g'")
      .replaceAll("O‘", "O'")
      .replaceAll("G‘", "G'")
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('ʻ', "'")
      .replaceAll('ʼ', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('×', 'x');

  if (allowUnicode) {
    return cleaned;
  }

  // Remove any remaining non-ASCII characters (emoji, etc)
  return cleaned.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
}
