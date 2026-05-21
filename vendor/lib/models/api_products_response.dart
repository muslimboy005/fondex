import 'package:vendor/models/product_model.dart';

/// GET https://storage.fondex.uz/api/vendors/products/
class ApiProductsResponse {
  final bool status;
  final ApiProductsData data;

  ApiProductsResponse({required this.status, required this.data});

  factory ApiProductsResponse.fromJson(Map<String, dynamic> json) {
    return ApiProductsResponse(
      status: json['status'] as bool? ?? false,
      data: ApiProductsData.fromJson(
        (json['data'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}

class ApiProductsData {
  final String? next;
  final String? previous;
  final List<ApiProductItem> results;

  ApiProductsData({
    this.next,
    this.previous,
    required this.results,
  });

  factory ApiProductsData.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    final linksRaw = json['links'];
    final links = linksRaw is Map<String, dynamic> ? linksRaw : const <String, dynamic>{};
    return ApiProductsData(
      next: (links['next'] ?? json['next']) as String?,
      previous: (links['previous'] ?? json['previous']) as String?,
      results: resultsList
          .map((e) => ApiProductItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiProductItem {
  final int id;
  final String? firestoreId;
  /// API dan int yoki string kelishi mumkin.
  final String vendor;
  final String category;
  final String section;
  final String? name;
  final String? description;
  final String price;
  final String discountPrice;
  final int quantity;
  final bool isPublish;
  final String? image;
  final dynamic photosJson;
  final ItemAttribute? itemAttribute;

  ApiProductItem({
    required this.id,
    this.firestoreId,
    required this.vendor,
    required this.category,
    required this.section,
    this.name,
    this.description,
    required this.price,
    required this.discountPrice,
    required this.quantity,
    required this.isPublish,
    this.image,
    this.photosJson,
    this.itemAttribute,
  });

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    return v.toString();
  }

  static ItemAttribute? _itemAttributeFromVariantsOnly(
    List<dynamic> variantsRaw,
  ) {
    if (variantsRaw.isEmpty) return null;

    final attributesMap = <String, Set<String>>{};
    for (final variant in variantsRaw) {
      if (variant is! Map) continue;
      final attributeDataRaw = variant['attribute_data'];
      if (attributeDataRaw is! List) continue;
      for (final row in attributeDataRaw) {
        if (row is! Map) continue;
        final attributeId = row['attribute_id']?.toString() ?? '';
        if (attributeId.isEmpty) continue;
        final bucket = attributesMap.putIfAbsent(attributeId, () => <String>{});

        final optionsRaw = row['attribute_options'];
        if (optionsRaw is List && optionsRaw.isNotEmpty) {
          for (final opt in optionsRaw) {
            final value = opt.toString().trim();
            if (value.isNotEmpty) bucket.add(value);
          }
        }

        final singleValue = row['attribute_value']?.toString().trim() ?? '';
        if (singleValue.isNotEmpty) {
          bucket.add(singleValue);
        }
      }
    }

    final attributes = attributesMap.entries
        .map(
          (e) => <String, dynamic>{
            'attribute_id': e.key,
            'attribute_options': e.value.toList(),
          },
        )
        .toList();

    return ItemAttribute.fromJson({
      'attributes': attributes,
      'variants': variantsRaw,
    });
  }

  factory ApiProductItem.fromJson(Map<String, dynamic> json) {
    ItemAttribute? itemAttribute;
    final itemAttributeRaw = json['item_attribute'];
    if (itemAttributeRaw is Map<String, dynamic>) {
      itemAttribute = ItemAttribute.fromJson(itemAttributeRaw);
    } else {
      final attrsRaw = json['attributes'];
      final variantsRaw = json['variants'];
      if (attrsRaw is List) {
        itemAttribute = ItemAttribute.fromJson({
          'attributes': attrsRaw,
          'variants': variantsRaw is List ? variantsRaw : const [],
        });
      } else if (variantsRaw is List) {
        itemAttribute = _itemAttributeFromVariantsOnly(variantsRaw);
      }
    }
    return ApiProductItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      firestoreId: json['firestore_id'] as String?,
      vendor: _str(json['vendor']),
      category: _str(json['category']),
      section: _str(json['section']),
      name: json['name'] as String?,
      description: json['description'] as String?,
      price: (json['price'] ?? '0').toString(),
      discountPrice: (json['discount_price'] ?? '0.00').toString(),
      quantity: json['quantity'] as int? ?? 0,
      isPublish: json['is_publish'] as bool? ?? false,
      image: json['image'] as String?,
      photosJson: json['photos_json'],
      itemAttribute: itemAttribute,
    );
  }
}
