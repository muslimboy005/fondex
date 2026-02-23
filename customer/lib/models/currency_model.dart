class CurrencyModel {
  String code;
  int decimal;
  String id;
  bool isactive;
  num rounding;
  String name;
  String symbol;
  bool symbolatright;

  CurrencyModel({
    this.code = '',
    this.decimal = 0,
    this.isactive = false,
    this.id = '',
    this.name = '',
    this.rounding = 0,
    this.symbol = '',
    this.symbolatright = false,
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> parsedJson) {
    // Firestore admin panel "decimalDigits" ishlatadi (driver/vendor bilan bir xil).
    // Eski "decimal_degits" ni ham qo'llab-quvvatlash.
    final int decimalValue =
        parsedJson['decimalDigits'] != null
            ? int.parse(parsedJson['decimalDigits'].toString())
            : (parsedJson['decimal_degits'] != null
                ? int.parse(parsedJson['decimal_degits'].toString())
                : 2);
    return CurrencyModel(
      code: parsedJson['code'] ?? '',
      decimal: decimalValue,
      isactive: parsedJson['isActive'] == true,
      id: parsedJson['id'] ?? '',
      name: parsedJson['name'] ?? '',
      rounding: parsedJson['rounding'] ?? 0,
      symbol: parsedJson['symbol'] ?? '',
      symbolatright: parsedJson['symbolAtRight'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'decimal_degits': decimal,
      'decimalDigits': decimal,
      'isActive': isactive,
      'rounding': rounding,
      'id': id,
      'name': name,
      'symbol': symbol,
      'symbolAtRight': symbolatright,
    };
  }
}
