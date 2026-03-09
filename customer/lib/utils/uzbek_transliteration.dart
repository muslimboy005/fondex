/// Kirill alifbosidagi matnni lotin o'zbekchaga o'giradi.
/// Yandex ru_RU manzillar uchun ishlatiladi.
/// Ruscha manzil so'zlari (ulitsa, prospekt va h.k.) o'zbekchaga almashtiriladi.
String cyrillicToLatinUzbek(String text) {
  if (text.isEmpty) return text;
  final sb = StringBuffer();
  final runes = text.runes.toList();
  for (int i = 0; i < runes.length; i++) {
    final c = runes[i];
    final ch = String.fromCharCode(c);
    final prev = i > 0 ? text[i - 1] : ' ';
    final atWordStart = i == 0 || ' .,'.contains(prev);

    // O'zbek maxsus: ч→ch, ш→sh, ў→o', ғ→g', қ→q, ҳ→h
    if (ch == 'ч') { sb.write('ch'); continue; }
    if (ch == 'Ч') { sb.write('Ch'); continue; }
    if (ch == 'ш') { sb.write('sh'); continue; }
    if (ch == 'Ш') { sb.write('Sh'); continue; }
    if (ch == 'ў') { sb.write("o'"); continue; }
    if (ch == 'Ў') { sb.write("O'"); continue; }
    if (ch == 'ғ') { sb.write("g'"); continue; }
    if (ch == 'Ғ') { sb.write("G'"); continue; }
    if (ch == 'қ') { sb.write('q'); continue; }
    if (ch == 'Қ') { sb.write('Q'); continue; }
    if (ch == 'ҳ') { sb.write('h'); continue; }
    if (ch == 'Ҳ') { sb.write('H'); continue; }
    if (ch == 'ъ' || ch == 'ь') { sb.write("'"); continue; }
    if (ch == 'ю') { sb.write('yu'); continue; }
    if (ch == 'Ю') { sb.write('Yu'); continue; }
    if (ch == 'я') { sb.write('ya'); continue; }
    if (ch == 'Я') { sb.write('Ya'); continue; }
    if (ch == 'ё') { sb.write('yo'); continue; }
    if (ch == 'Ё') { sb.write('Yo'); continue; }
    if (ch == 'е' && atWordStart) { sb.write('ye'); continue; }
    if (ch == 'Е' && atWordStart) { sb.write('Ye'); continue; }

    final lower = ch.toLowerCase();
    final latin = _cyrToLat[lower];
    if (latin != null) {
      sb.write(ch == lower ? latin : (latin.isNotEmpty ? '${latin[0].toUpperCase()}${latin.substring(1)}' : latin));
    } else {
      sb.write(ch);
    }
  }
  return _rusAddressToUzbek(sb.toString());
}

/// Ruscha manzil atamalarini o'zbekchaga almashtiradi (lotin matnda).
String _rusAddressToUzbek(String latin) {
  if (latin.isEmpty) return latin;
  String r = latin;
  for (final e in _rusToUzbekAddressTerms.entries) {
    final pattern = RegExp(
      r'(^|[\s,\.])' + RegExp.escape(e.key) + r'(\s|[,\.]|$)',
      caseSensitive: false,
    );
    r = r.replaceAllMapped(pattern, (m) => '${m.group(1)}${e.value}${m.group(2) ?? ''}');
  }
  return r;
}

/// Ruscha (lotin transliteratsiyasi) → o'zbekcha manzil so'zlari
const Map<String, String> _rusToUzbekAddressTerms = {
  'ulitsa': "ko'cha",
  'prospekt': 'prospekt',
  'pereulok': "tor ko'cha",
  'ploshchad': 'maydon',
  'bulvar': 'bulvar',
  'gorod': 'shahar',
  'oblast': 'viloyat',
  'rayon': 'tuman',
  'mikrorayon': 'massiv',
  'respublika': 'respublika',
  'selo': "qishloq",
  'posyolok': 'posyolka',
  'strana': 'mamlakat',
  'dom': "uy",
  'zdaniye': 'bino',
};

const Map<String, String> _cyrToLat = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ж': 'j',
  'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
  'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f',
  'х': 'x', 'ц': 'ts', 'ы': 'i', 'э': 'e',
};
