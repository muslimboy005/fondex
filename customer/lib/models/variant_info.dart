Map<String, dynamic> _variantOptionsFromJson(dynamic value) {
  if (value == null) return <String, dynamic>{};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  if (value is List) {
    final out = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      final e = value[i];
      if (e is Map) {
        for (final entry in e.entries) {
          out[entry.key.toString()] = entry.value;
        }
      } else {
        out['$i'] = e;
      }
    }
    return out;
  }
  return <String, dynamic>{};
}

class VariantInfo {
  String? variantId;
  String? variantPrice;
  String? variantSku;
  String? variant_image;
  Map<String, dynamic>? variant_options;

  VariantInfo({this.variantId, this.variantPrice, this.variant_image, this.variantSku, this.variant_options});

  VariantInfo.fromJson(Map<String, dynamic> json) {
    variantId = json['variantId'] ?? '';
    variantPrice = json['variantPrice'] ?? '';
    variantSku = json['variantSku'] ?? '';
    variant_image = json['variant_image'] ?? '';
    variant_options = _variantOptionsFromJson(json['variant_options']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['variantId'] = variantId;
    data['variantPrice'] = variantPrice;
    data['variantSku'] = variantSku;
    data['variant_image'] = variant_image;
    data['variant_options'] = variant_options;
    return data;
  }
}
