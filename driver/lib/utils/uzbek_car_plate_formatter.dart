import 'package:flutter/services.dart';

/// Formats Uzbekistan-style car plate values as:
/// - 80 A 760 AA
/// - 80 760 AAA
class UzbekCarPlateFormatter extends TextInputFormatter {
  static final RegExp _alphaNumeric = RegExp(r'[A-Z0-9]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _letter = RegExp(r'[A-Z]');

  static String normalize(String value) {
    final cleaned = value
        .toUpperCase()
        .split('')
        .where((char) => _alphaNumeric.hasMatch(char))
        .join();

    if (cleaned.isEmpty) {
      return '';
    }

    final hasThirdChar = cleaned.length >= 3;
    final thirdCharIsLetter = hasThirdChar && _letter.hasMatch(cleaned[2]);

    if (thirdCharIsLetter) {
      var index = 0;
      final part1 = _consumeMatching(cleaned, _digit, 2, start: index);
      index = part1.nextIndex;
      final part2 = _consumeMatching(cleaned, _letter, 1, start: index);
      index = part2.nextIndex;
      final part3 = _consumeMatching(cleaned, _digit, 3, start: index);
      index = part3.nextIndex;
      final part4 = _consumeMatching(cleaned, _letter, 2, start: index);
      return [part1, part2, part3, part4]
          .map((part) => part.value)
          .where((part) => part.isNotEmpty)
          .join(' ');
    }

    var index = 0;
    final part1 = _consumeMatching(cleaned, _digit, 2, start: index);
    index = part1.nextIndex;
    final part2 = _consumeMatching(cleaned, _digit, 3, start: index);
    index = part2.nextIndex;
    final part3 = _consumeMatching(cleaned, _letter, 3, start: index);
    return [part1, part2, part3]
        .map((part) => part.value)
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  static _ConsumedPart _consumeMatching(
    String input,
    RegExp pattern,
    int maxLength, {
    required int start,
  }) {
    final buffer = StringBuffer();
    var cursor = start;
    while (cursor < input.length && buffer.length < maxLength) {
      final char = input[cursor];
      cursor++;
      if (pattern.hasMatch(char)) {
        buffer.write(char);
      }
    }
    return _ConsumedPart(value: buffer.toString(), nextIndex: cursor);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalize(newValue.text);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }
}

class _ConsumedPart {
  final String value;
  final int nextIndex;

  const _ConsumedPart({
    required this.value,
    required this.nextIndex,
  });
}
