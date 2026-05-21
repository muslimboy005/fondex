import 'dart:convert';

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

VariantInfo? _variantInfoFromJson(dynamic raw) {
  if (raw == null || raw == 'null') return null;
  if (raw is String) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return VariantInfo.fromJson(Map<String, dynamic>.from(decoded));
    }
    return null;
  }
  if (raw is Map) {
    return VariantInfo.fromJson(Map<String, dynamic>.from(raw));
  }
  return null;
}

class CartProductModel {
  String? id;
  String? categoryId;
  String? name;
  String? photo;
  String? price;
  String? discountPrice;
  String? vendorID;
  int? quantity;
  String? extrasPrice;
  List<dynamic>? extras;
  VariantInfo? variantInfo;

  CartProductModel({
    this.id,
    this.categoryId,
    this.name,
    this.photo,
    this.price,
    this.discountPrice,
    this.vendorID,
    this.quantity,
    this.extrasPrice,
    this.variantInfo,
    this.extras,
  });

  CartProductModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    categoryId = json['category_id'];
    name = json['name'];
    photo = json['photo'];
    price = json['price'] ?? '0.0';
    discountPrice = json['discountPrice'] ?? '0.0';
    vendorID = json['vendorID'];
    quantity = json['quantity'];
    extrasPrice = json['extras_price'];
    extras = json['extras'];
    variantInfo = _variantInfoFromJson(json['variant_info']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['category_id'] = categoryId;
    data['name'] = name;
    data['photo'] = photo;
    data['price'] = price;
    data['discountPrice'] = discountPrice;
    data['vendorID'] = vendorID;
    data['quantity'] = quantity;
    data['extras_price'] = extrasPrice;
    data['extras'] = extras;
    data['variant_info'] = variantInfo != null ? jsonEncode(variantInfo!.toJson()) : null; // Handle null value
    return data;
  }
}

class VariantInfo {
  String? variantId;
  String? variantPrice;
  String? variantSku;
  String? variantImage;
  Map<String, dynamic>? variantOptions;

  VariantInfo({this.variantId, this.variantPrice, this.variantSku, this.variantImage, this.variantOptions});

  VariantInfo.fromJson(Map<String, dynamic> json) {
    variantId = json['variant_id'] ?? '';
    variantPrice = json['variant_price'] ?? '';
    variantSku = json['variant_sku'] ?? '';
    variantImage = json['variant_image'] ?? '';
    variantOptions = _variantOptionsFromJson(json['variant_options']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['variant_id'] = variantId;
    data['variant_price'] = variantPrice;
    data['variant_sku'] = variantSku;
    data['variant_image'] = variantImage;
    data['variant_options'] = variantOptions;
    return data;
  }
}
