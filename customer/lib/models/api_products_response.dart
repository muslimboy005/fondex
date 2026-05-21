/// API response for GET https://storage.fondex.uz/api/products/
/// { "status": true, "data": { "next", "previous", "results" [, "count"] } }
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
  final int count;
  final int totalPages;
  final int pageSize;
  final int currentPage;
  final String? next;
  final String? previous;
  final List<ApiProductItem> results;

  ApiProductsData({
    required this.count,
    this.totalPages = 1,
    this.pageSize = 0,
    this.currentPage = 1,
    this.next,
    this.previous,
    required this.results,
  });

  factory ApiProductsData.fromJson(Map<String, dynamic> json) {
    final links = (json['links'] as Map<String, dynamic>?) ?? const {};
    final resultsList = json['results'] as List<dynamic>? ?? [];
    final totalItemsRaw = json['total_items'];
    final countRaw = json['count'];
    final totalItems =
        totalItemsRaw is int
            ? totalItemsRaw
            : int.tryParse(totalItemsRaw?.toString() ?? '');
    final count =
        countRaw is int
            ? countRaw
            : int.tryParse(countRaw?.toString() ?? '');
    return ApiProductsData(
      count: totalItems ?? count ?? resultsList.length,
      totalPages:
          json['total_pages'] is int
              ? json['total_pages'] as int
              : int.tryParse('${json['total_pages']}') ?? 1,
      pageSize:
          json['page_size'] is int
              ? json['page_size'] as int
              : int.tryParse('${json['page_size']}') ?? resultsList.length,
      currentPage:
          json['current_page'] is int
              ? json['current_page'] as int
              : int.tryParse('${json['current_page']}') ?? 1,
      next: (json['next'] ?? links['next']) as String?,
      previous: (json['previous'] ?? links['previous']) as String?,
      results: resultsList
          .map((e) => ApiProductItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Single product item from API.
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
  final List<ApiProductVariant> variants;

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
    required this.variants,
  });

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    return v.toString();
  }

  factory ApiProductItem.fromJson(Map<String, dynamic> json) {
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
      variants:
          (json['variants'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ApiProductVariant.fromJson)
              .toList(),
    );
  }
}

class ApiProductVariant {
  final String id;
  final String? firestoreId;
  final String price;
  final String sku;
  final int quantity;
  final String? image;
  final List<ApiVariantAttributeData> attributeData;

  ApiProductVariant({
    required this.id,
    this.firestoreId,
    required this.price,
    required this.sku,
    required this.quantity,
    this.image,
    required this.attributeData,
  });

  factory ApiProductVariant.fromJson(Map<String, dynamic> json) {
    final quantityRaw = json['quantity'];
    final parsedQuantity =
        quantityRaw is int
            ? quantityRaw
            : int.tryParse(quantityRaw?.toString() ?? '0') ?? 0;
    final idRaw = json['id'];
    return ApiProductVariant(
      id: idRaw?.toString() ?? '',
      firestoreId: json['firestore_id']?.toString(),
      price: (json['price'] ?? '0').toString(),
      sku: (json['sku'] ?? '').toString(),
      quantity: parsedQuantity,
      image: json['image']?.toString(),
      attributeData:
          (json['attribute_data'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ApiVariantAttributeData.fromJson)
              .toList(),
    );
  }
}

class ApiVariantAttributeData {
  final String attributeId;
  final String attributeName;
  final List<String> attributeOptions;

  ApiVariantAttributeData({
    required this.attributeId,
    required this.attributeName,
    required this.attributeOptions,
  });

  factory ApiVariantAttributeData.fromJson(Map<String, dynamic> json) {
    final fromList = (json['attribute_options'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final value = json['attribute_value']?.toString().trim() ?? '';
    final merged = <String>[...fromList];
    if (value.isNotEmpty && !merged.contains(value)) {
      merged.add(value);
    }
    return ApiVariantAttributeData(
      attributeId: json['attribute_id']?.toString() ?? '',
      attributeName: json['attribute_name']?.toString() ?? '',
      attributeOptions: merged,
    );
  }
}
