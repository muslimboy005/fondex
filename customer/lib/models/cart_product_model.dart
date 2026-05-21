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

class CartProductModel {
  String? id;
  /// Storage API mahsulot raqami (Payme `product_id` uchun; Firestore UUID emas).
  int? apiProductId;
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
    this.apiProductId,
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
    final apiRaw = json['api_product_id'];
    apiProductId =
        apiRaw is int ? apiRaw : int.tryParse(apiRaw?.toString() ?? '');
    categoryId = json['category_id'];
    name = json['name'];
    photo = json['photo'];
    price = json['price'] ?? "0.0";
    discountPrice = json['discountPrice'] ?? "0.0";
    vendorID = json['vendorID'];
    quantity = json['quantity'];
    extrasPrice = json['extras_price'];

    extras = json['extras'] == "null" || json['extras'] == null
        ? null
        : "String" == json['extras'].runtimeType.toString()
            ? List<dynamic>.from(jsonDecode(json['extras']))
            : List<dynamic>.from(json['extras']);

    variantInfo = json['variant_info'] == "null" || json['variant_info'] == null
        ? null
        : "String" == json['variant_info'].runtimeType.toString()
            ? VariantInfo.fromJson(jsonDecode(json['variant_info']))
            : VariantInfo.fromJson(json['variant_info']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['api_product_id'] = apiProductId;
    data['category_id'] = categoryId;
    data['name'] = name;
    data['photo'] = photo;
    data['price'] = price;
    data['discountPrice'] = discountPrice;
    data['vendorID'] = vendorID;
    data['quantity'] = quantity;
    data['extras_price'] = extrasPrice;
    data['extras'] = extras;
    if (variantInfo != null) {
      data['variant_info'] = variantInfo?.toJson(); // Handle null value
    }
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
    variantId = (json['variantId'] ?? json['variant_id'] ?? '').toString();
    variantPrice =
        (json['variantPrice'] ?? json['variant_price'] ?? '').toString();
    variantSku = (json['variantSku'] ?? json['variant_sku'] ?? '').toString();
    variantImage = json['variant_image'] ?? '';
    variantOptions = _variantOptionsFromJson(json['variant_options']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['variantId'] = variantId;
    data['variantPrice'] = variantPrice;
    data['variantSku'] = variantSku;
    data['variant_image'] = variantImage;
    data['variant_options'] = variantOptions;
    return data;
  }
}
