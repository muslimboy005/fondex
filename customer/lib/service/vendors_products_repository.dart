import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/api_products_response.dart';
import 'package:customer/models/product_model.dart';
import 'package:dio/dio.dart';

/// Fetches vendor products from storage API with pagination.
/// List: GET https://storage.fondex.uz/api/products/?vendor=&section=&category=
class VendorsProductsRepository {
  VendorsProductsRepository({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() {
    return Dio(BaseOptions(
      baseUrl: Constant.storageApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));
  }

  final Dio _dio;

  static String _normalizeValue(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Fetches one page of products.
  /// Supports either numeric [vendor]/[section] or Firestore IDs [vendorId]/[sectionId].
  /// Firestore ID yuborilganda ham vendor ilovasidek `vendor` va `section`
  /// query paramlari ishlatiladi (`vendor_id`/`section_id` emas).
  /// [category] optional filter, [page] for pagination (1-based).
  Future<ApiProductsResponse> getProducts({
    int? vendor,
    int? section,
    String? vendorId,
    String? sectionId,
    dynamic category,
    int? page,
    int? id,
  }) async {
    final queryParams = <String, dynamic>{};
    if (vendor != null) {
      queryParams['vendor'] = vendor;
      if (section != null) queryParams['section'] = section;
    } else if (vendorId != null && vendorId.isNotEmpty) {
      queryParams['vendor'] = vendorId;
      if (sectionId != null && sectionId.isNotEmpty) {
        queryParams['section'] = sectionId;
      }
    } else {
      throw ArgumentError('Provide vendor (int) or vendorId (string)');
    }
    if (category != null) queryParams['category'] = category.toString();
    if (page != null) queryParams['page'] = page;
    if (id != null) queryParams['id'] = id;

    final response = await _dio.get<Map<String, dynamic>>(
      '/api/products/',
      queryParameters: queryParams,
    );
    log('[API][VendorsProducts] GET ${Constant.storageApiBaseUrl}/api/products/ params=$queryParams');

    final data = response.data;
    if (data == null) {
      log('[API][VendorsProducts] ERROR: empty data');
      throw Exception('Empty response from products API');
    }
    log('[API][VendorsProducts] SUCCESS: responseBody=$data');
    return ApiProductsResponse.fromJson(data);
  }

  /// Fetches next page using the [next] URL from previous response.
  /// Returns null if [nextUrl] is null or empty.
  Future<ApiProductsResponse?> getProductsNextPage(String? nextUrl) async {
    if (nextUrl == null || nextUrl.isEmpty) return null;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ));
      final response = await dio.get<Map<String, dynamic>>(nextUrl);
      final data = response.data;
      if (data == null) return null;
      return ApiProductsResponse.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Fetches one product detail by API id.
  /// Example: GET https://storage.fondex.uz/api/products/2796
  Future<ProductModel?> getProductDetailByApiId(int apiId) async {
    final path = '/api/products/$apiId';
    log('[API][VendorsProducts][DETAIL] GET ${Constant.storageApiBaseUrl}$path');
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data;
      if (data == null) {
        log('[API][VendorsProducts][DETAIL] ERROR: empty response');
        return null;
      }
      log('[API][VendorsProducts][DETAIL] SUCCESS: responseBody=$data');
      final rawItem = data['data'];
      if (rawItem is! Map<String, dynamic>) {
        log('[API][VendorsProducts][DETAIL] ERROR: invalid data format');
        return null;
      }
      return toProductModel(ApiProductItem.fromJson(rawItem));
    } on DioException catch (e) {
      log(
        '[API][VendorsProducts][DETAIL] ERROR: '
        'status=${e.response?.statusCode} body=${e.response?.data}',
      );
      return null;
    } catch (e) {
      log('[API][VendorsProducts][DETAIL] ERROR: $e');
      return null;
    }
  }

  /// Fetches similar products for product detail: same vendor + same category.
  /// Excludes [excludeProductId], returns at most 10 items.
  /// On API error returns empty list.
  Future<List<ProductModel>> getSimilarProducts({
    required String vendorId,
    String? sectionId,
    String? categoryId,
    String? excludeProductId,
  }) async {
    if (vendorId.isEmpty) return [];
    try {
      final rawCat = categoryId?.trim() ?? '';
      final categoryStr = rawCat.isNotEmpty ? rawCat : null;
      final response = await getProducts(
        vendorId: vendorId,
        sectionId: sectionId?.isNotEmpty == true ? sectionId : null,
        category: categoryStr,
      );
      if (!response.status) return [];
      var list = response.data.results
          .map((e) => VendorsProductsRepository.toProductModel(e))
          .where((p) => p.id != excludeProductId)
          .take(10)
          .toList();
      if (list.isEmpty && categoryStr != null) {
        final all = await getProducts(
          vendorId: vendorId,
          sectionId: sectionId?.isNotEmpty == true ? sectionId : null,
        );
        if (all.status) {
          list = all.data.results
              .map((e) => VendorsProductsRepository.toProductModel(e))
              .where(
                (p) =>
                    p.id != excludeProductId &&
                    (p.categoryID?.toString() ?? '') == categoryStr,
              )
              .take(10)
              .toList();
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Converts API product item to app [ProductModel].
  static ProductModel toProductModel(ApiProductItem item) {
    final photos = _extractPhotos(item);
    final itemAttribute = _toItemAttribute(item.variants);
    final map = <String, dynamic>{
      'api_id': item.id,
      'id': item.firestoreId ?? item.id.toString(),
      'vendorID': item.vendor.toString(),
      'categoryID': item.category.toString(),
      'section_id': item.section.toString(),
      'price': item.price,
      'disPrice': item.discountPrice,
      'photo': photos.isNotEmpty ? photos.first.toString() : item.image,
      'photos': photos,
      'name': item.name,
      'description': item.description,
      'publish': item.isPublish,
      'quantity': item.quantity,
      'addOnsTitle': <dynamic>[],
      'addOnsPrice': <dynamic>[],
      'item_attribute': itemAttribute,
    };
    return ProductModel.fromJson(map);
  }

  static List<dynamic> _extractPhotos(ApiProductItem item) {
    if (item.photosJson is List) {
      final raw = List<dynamic>.from(item.photosJson as List);
      final cleaned = raw
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) return cleaned;
    }
    if (item.image != null && item.image!.isNotEmpty) {
      return [item.image!];
    }
    return <dynamic>[];
  }

  static Map<String, dynamic>? _toItemAttribute(List<ApiProductVariant> variants) {
    if (variants.isEmpty) return null;

    final attributesById = <String, Map<String, dynamic>>{};
    final attributeOrder = <String>[];

    for (final variant in variants) {
      for (final attribute in variant.attributeData) {
        if (attribute.attributeId.isEmpty) continue;
        if (!attributesById.containsKey(attribute.attributeId)) {
          attributesById[attribute.attributeId] = <String, dynamic>{
            'attribute_id': attribute.attributeId,
            'attribute_name': attribute.attributeName,
            'attribute_options': <String>[],
          };
          attributeOrder.add(attribute.attributeId);
        }
        final options =
            attributesById[attribute.attributeId]!['attribute_options'] as List<String>;
        for (final option in attribute.attributeOptions) {
          final normalizedOption = _normalizeValue(option);
          if (normalizedOption.isEmpty) continue;
          if (!options.contains(normalizedOption)) {
            options.add(normalizedOption);
          }
        }
      }
    }

    final attributes = attributeOrder
        .map((id) => attributesById[id]!)
        .toList();

    final normalizedVariants = variants.map((variant) {
      final normalizedSku = _normalizeValue(variant.sku);
      return <String, dynamic>{
        'variant_id': variant.firestoreId ?? variant.id,
        'variant_image': variant.image,
        'variant_price': variant.price,
        'variant_quantity': variant.quantity.toString(),
        // Use API sku directly so product detail matches real variant options.
        'variant_sku': normalizedSku,
      };
    }).toList();

    return <String, dynamic>{
      'attributes': attributes,
      'variants': normalizedVariants,
    };
  }
}
