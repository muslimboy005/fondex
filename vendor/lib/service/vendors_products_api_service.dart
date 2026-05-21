import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/api_products_response.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/utils/api_talker.dart';

/// Yangi mahsulot: POST multipart → https://storage.fondex.uz/api/products/
class VendorsProductsApiService {
  VendorsProductsApiService._();

  static Uri get _listUri =>
      Uri.parse('${Constant.storageApiBaseUrl}/api/products/');
  static Uri get _createActionUri =>
      Uri.parse('${Constant.storageApiBaseUrl}/api/products/create/');

  static Uri get _createUri => _listUri;

  static Uri _detailUri(int id) =>
      Uri.parse('${Constant.storageApiBaseUrl}/api/products/$id/');

  static String _compactHttpError(int statusCode, String body) {
    final raw = body.trim();
    if (raw.isEmpty) return 'HTTP $statusCode: Xato';

    // Django APPEND_SLASH debug HTML ni foydalanuvchiga to'liq ko'rsatmaymiz.
    if (raw.contains("doesn't end in a slash") ||
        raw.contains('APPEND_SLASH')) {
      return 'HTTP $statusCode: Endpoint slash xatosi (APPEND_SLASH).';
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      if (map != null) {
        final status = map['status'];
        final direct = map['message'] ?? map['detail'] ?? map['error'];
        if (direct != null) return direct.toString();
        final data = map['data'];
        if (data is Map<String, dynamic>) {
          final nested = data['message'] ?? data['detail'] ?? data['error'];
          if (nested != null) return nested.toString();
        }
        if (status == false) {
          return 'HTTP $statusCode: So\'rov bajarilmadi.';
        }
      }
    } catch (_) {}

    const maxLen = 220;
    final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ');
    return 'HTTP $statusCode: '
        '${oneLine.length > maxLen ? oneLine.substring(0, maxLen) : oneLine}';
  }

  static List<Map<String, dynamic>> _backendVariants(
    ItemAttribute itemAttribute,
    List<Map<String, dynamic>> attributes,
  ) {
    final source = itemAttribute.variants ?? const <Variants>[];
    if (source.isEmpty) return const <Map<String, dynamic>>[];

    final out = <Map<String, dynamic>>[];
    for (final v in source) {
      final sku = (v.variantSku ?? '').trim();
      final parts = sku.isEmpty ? const <String>[] : sku.split('-');
      final attributeData = <Map<String, dynamic>>[];
      for (var i = 0; i < attributes.length; i++) {
        final attr = attributes[i];
        final attrId = (attr['attribute_id'] ?? '').toString();
        if (attrId.isEmpty) continue;
        String attributeValue = '';
        if (i < parts.length) {
          attributeValue = parts[i].trim();
        }
        if (attributeValue.isEmpty) {
          final optionsRaw = attr['attribute_options'];
          if (optionsRaw is List && optionsRaw.isNotEmpty) {
            attributeValue = optionsRaw.first.toString();
          }
        }
        attributeData.add(<String, dynamic>{
          'attribute_id': attrId,
          'attribute_value': attributeValue,
        });
      }
      out.add(<String, dynamic>{
        'sku': sku,
        'price': (v.variantPrice ?? '0').toString(),
        'quantity': int.tryParse((v.variantQuantity ?? '0').toString()) ?? 0,
        'attribute_data': attributeData,
      });
    }
    return out;
  }

  static Future<http.Response> _getLogged(Uri uri) async {
    final sw = Stopwatch()..start();
    apiTalker.debug('[API] GET $uri');
    final res = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    sw.stop();
    apiTalker.debug('[API] GET $uri → ${res.statusCode} (${sw.elapsedMilliseconds}ms)');
    final body = res.body;
    if (body.isNotEmpty) {
      const maxBodyLogChars = 20000; // debug uchun ko'proq chiqsin
      apiTalker.verbose(
        body.length > maxBodyLogChars ? body.substring(0, maxBodyLogChars) : body,
      );
    }
    return res;
  }

  /// Muvaffaqiyatda `null`, xato matnida xabar.
  static Future<String?> deleteProduct(int id) async {
    try {
      final sw = Stopwatch()..start();
      apiTalker.debug('[API] DELETE ${_detailUri(id)}');
      final response = await http
          .delete(_detailUri(id))
          .timeout(const Duration(seconds: 30));
      sw.stop();
      apiTalker.debug(
        '[API] DELETE ${_detailUri(id)} → ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      final body = response.body;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }
      try {
        final map = jsonDecode(body) as Map<String, dynamic>?;
        if (map != null) {
          final msg = map['message'] ?? map['detail'] ?? map['error'];
          if (msg != null) return msg.toString();
        }
      } catch (_) {}
      return 'HTTP ${response.statusCode}: ${body.isNotEmpty ? body : "Xato"}';
    } catch (e) {
      return e.toString();
    }
  }

  /// Muvaffaqiyatda `null`, xato matnida xabar. Rasm o‘zgarmasa [imagePath] null.
  /// Backend response’ingizga mos: vendor/category/section hammasi string id.
  static Future<String?> updateProductMultipart({
    required int id,
    required String vendor,
    required String category,
    required String section,
    required String name,
    required String description,
    required String price,
    required String discountPrice,
    required int quantity,
    required bool isPublish,
    String? imagePath,
    String? imageFilename,
    ItemAttribute? itemAttribute,
    List<String>? photosJson,
    Map<String, dynamic>? productSpecification,
  }) async {
    try {
      final attributes = itemAttribute?.attributes
              ?.map((a) => a.toJson())
              .toList() ??
          const <Map<String, dynamic>>[];
      final variants = itemAttribute == null
          ? const <Map<String, dynamic>>[]
          : _backendVariants(itemAttribute, attributes);
      final payload = <String, dynamic>{
        'vendor': vendor,
        'category': category,
        'section': section,
        'name': name,
        'description': description,
        'price': price,
        'discount_price': discountPrice,
        'quantity': quantity,
        'is_publish': isPublish,
        'photos_json': photosJson ?? const <String>[],
        'product_specification': productSpecification,
        'variants': variants,
      };
      final hasLocalImage = imagePath != null && imagePath.isNotEmpty;
      if (hasLocalImage) {
        final uri = _detailUri(id);
        final req = http.MultipartRequest('PATCH', uri);
        req.headers['Accept'] = 'application/json';
        req.fields['vendor'] = vendor;
        req.fields['category'] = category;
        req.fields['section'] = section;
        req.fields['name'] = name;
        req.fields['description'] = description;
        req.fields['price'] = price;
        req.fields['discount_price'] = discountPrice;
        req.fields['quantity'] = '$quantity';
        req.fields['is_publish'] = isPublish ? 'true' : 'false';
        req.fields['variants'] = jsonEncode(variants);
        req.fields['photos_json'] = jsonEncode(photosJson ?? const <String>[]);
        req.fields['product_specification'] = jsonEncode(productSpecification);

        final mainName = imageFilename ?? imagePath.split(RegExp(r'[/\\]')).last;
        final fileName = mainName.isEmpty ? 'photo.jpg' : mainName;
        req.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imagePath,
            filename: fileName,
          ),
        );
        final sw = Stopwatch()..start();
        apiTalker.debug('[API] PATCH $uri');
        apiTalker.debug('[API] multipart fields=${req.fields}');
        apiTalker.debug(
          '[API] multipart files=${req.files.map((f) => 'field=${f.field}, filename=${f.filename}, length=${f.length}').toList()}',
        );
        final streamed = await req.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamed);
        sw.stop();
        apiTalker.debug('[API] PATCH $uri → ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
        final body = response.body;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return null;
        }
        return _compactHttpError(response.statusCode, body);
      }

      final sw = Stopwatch()..start();
      final uri = _detailUri(id);
      apiTalker.debug('[API] PATCH $uri (json)');
      apiTalker.debug('[API] json body=$payload');
      final response = await http
          .patch(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));
      sw.stop();
      apiTalker.debug(
        '[API] PATCH $uri → ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      final body = response.body;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final map = jsonDecode(body) as Map<String, dynamic>?;
          if (map != null && map['status'] == false) {
            return map['message']?.toString() ??
                map['detail']?.toString() ??
                body;
          }
        } catch (_) {}
        return null;
      }

      try {
        final map = jsonDecode(body) as Map<String, dynamic>?;
        if (map != null) {
          final msg = map['message'] ?? map['detail'] ?? map['error'];
          if (msg != null) return msg.toString();
          if (map['non_field_errors'] != null) {
            return map['non_field_errors'].toString();
          }
        }
      } catch (_) {}
      return _compactHttpError(response.statusCode, body);
    } catch (e) {
      return e.toString();
    }
  }

  /// Muvaffaqiyatda `null`, xato matnida xabar.
  /// Backend response’ingizga mos: vendor/category/section hammasi string id.
  static Future<String?> _createProductMultipartOnce({
    required Uri createUri,
    required String vendor,
    required String category,
    required String section,
    required String name,
    required String description,
    required String price,
    required String discountPrice,
    required int quantity,
    required bool isPublish,
    String? imagePath,
    String? imageFilename,
    ItemAttribute? itemAttribute,
    List<String>? photosJson,
    Map<String, dynamic>? productSpecification,
  }) async {
    try {
      final attributes = itemAttribute?.attributes
              ?.map((a) => a.toJson())
              .toList() ??
          const <Map<String, dynamic>>[];
      final variants = itemAttribute == null
          ? const <Map<String, dynamic>>[]
          : _backendVariants(itemAttribute, attributes);
      final payload = <String, dynamic>{
        'vendor': vendor,
        'category': category,
        'section': section,
        'name': name,
        'description': description,
        'price': price,
        'discount_price': discountPrice,
        'quantity': quantity,
        'is_publish': isPublish,
        'photos_json': photosJson ?? const <String>[],
        'product_specification': productSpecification,
        'variants': variants,
      };
      final hasLocalImage = imagePath != null && imagePath.isNotEmpty;
      if (hasLocalImage) {
        final req = http.MultipartRequest('POST', createUri);
        req.headers['Accept'] = 'application/json';
        req.fields['vendor'] = vendor;
        req.fields['category'] = category;
        req.fields['section'] = section;
        req.fields['name'] = name;
        req.fields['description'] = description;
        req.fields['price'] = price;
        req.fields['discount_price'] = discountPrice;
        req.fields['quantity'] = '$quantity';
        req.fields['is_publish'] = isPublish ? 'true' : 'false';
        req.fields['variants'] = jsonEncode(variants);
        req.fields['photos_json'] = jsonEncode(photosJson ?? const <String>[]);
        req.fields['product_specification'] = jsonEncode(productSpecification);

        final mainName = imageFilename ?? imagePath.split(RegExp(r'[/\\]')).last;
        final fileName = mainName.isEmpty ? 'photo.jpg' : mainName;
        req.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imagePath,
            filename: fileName,
          ),
        );
        final sw = Stopwatch()..start();
        apiTalker.debug('[API] POST $createUri');
        apiTalker.debug('[API] multipart fields=${req.fields}');
        apiTalker.debug(
          '[API] multipart files=${req.files.map((f) => 'field=${f.field}, filename=${f.filename}, length=${f.length}').toList()}',
        );
        final streamed = await req.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamed);
        sw.stop();
        apiTalker.debug('[API] POST $createUri → ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
        final body = response.body;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return null;
        }
        return _compactHttpError(response.statusCode, body);
      }

      final sw = Stopwatch()..start();
      apiTalker.debug('[API] POST $createUri (json)');
      apiTalker.debug('[API] json body=$payload');
      final response = await http
          .post(
            createUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));
      sw.stop();
      apiTalker.debug(
        '[API] POST $createUri → ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
      );
      final body = response.body;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final map = jsonDecode(body) as Map<String, dynamic>?;
          if (map != null && map['status'] == false) {
            return map['message']?.toString() ??
                map['detail']?.toString() ??
                body;
          }
        } catch (_) {}
        return null;
      }

      try {
        final map = jsonDecode(body) as Map<String, dynamic>?;
        if (map != null) {
          final msg = map['message'] ?? map['detail'] ?? map['error'];
          if (msg != null) return msg.toString();
          if (map['non_field_errors'] != null) {
            return map['non_field_errors'].toString();
          }
        }
      } catch (_) {}
      return _compactHttpError(response.statusCode, body);
    } catch (e) {
      return e.toString();
    }
  }

  /// Yangi mahsulot yaratish:
  /// - avval standart endpoint
  /// - 405 bo'lsa fallback endpointlar
  static Future<String?> createProductMultipart({
    required String vendor,
    required String category,
    required String section,
    required String name,
    required String description,
    required String price,
    required String discountPrice,
    required int quantity,
    required bool isPublish,
    String? imagePath,
    String? imageFilename,
    ItemAttribute? itemAttribute,
    List<String>? photosJson,
    Map<String, dynamic>? productSpecification,
  }) async {
    final createUris = <Uri>[_createUri, _createActionUri];
    String? lastError;

    for (final uri in createUris) {
      final err = await _createProductMultipartOnce(
        createUri: uri,
        vendor: vendor,
        category: category,
        section: section,
        name: name,
        description: description,
        price: price,
        discountPrice: discountPrice,
        quantity: quantity,
        isPublish: isPublish,
        imagePath: imagePath,
        imageFilename: imageFilename,
        itemAttribute: itemAttribute,
        photosJson: photosJson,
        productSpecification: productSpecification,
      );
      if (err == null) return null;
      lastError = err;
      if (!err.contains('HTTP 405') &&
          !err.contains('Method "POST" not allowed.')) {
        return err;
      }
    }

    return lastError;
  }

  static ProductModel _itemToProductModel(ApiProductItem item) {
    List<dynamic> photos = [];
    if (item.photosJson is List) {
      photos = List<dynamic>.from(item.photosJson as List);
    } else if (item.image != null && item.image!.isNotEmpty) {
      photos = [item.image];
    }
    return ProductModel.fromJson({
      'id': item.id.toString(),
      'vendorID': item.vendor.toString(),
      'categoryID': item.category.toString(),
      'section_id': item.section.toString(),
      'price': item.price,
      'disPrice': item.discountPrice,
      'photo': item.image,
      'photos': photos,
      'name': item.name,
      'description': item.description ?? '',
      'publish': item.isPublish,
      'quantity': item.quantity,
      'item_attribute': item.itemAttribute?.toJson(),
      'addOnsTitle': <dynamic>[],
      'addOnsPrice': <dynamic>[],
      'veg': true,
      'nonveg': false,
    });
  }

  /// Ro‘yxat uchun 1 ta so‘rov: cursor’ni kuzatmaydi.
  ///
  /// - Raqamli vendor: `GET ?vendor=5`
  /// - Firestore vendor hujjat id: `GET ?vendor_id=1ScIEHMF...` (customer ilova bilan bir xil)
  static Future<ApiProductsResponse> fetchVendorProductsFirstPage({
    int? vendor,
    String? vendorFirestoreId,
    int? filterProductId,
    int? filterCategory,
    int? filterSection,
  }) async {
    final q = <String, String>{};
    if (vendorFirestoreId != null && vendorFirestoreId.isNotEmpty) {
      // Sizning backend'da vendor field string bo'lsa, list query'da ham vendor=<id> ishlatamiz
      q['vendor'] = vendorFirestoreId;
    } else if (vendor != null) {
      q['vendor'] = '$vendor';
    } else {
      throw ArgumentError(
        'fetchVendorProductsFirstPage: vendor (int) yoki vendorFirestoreId (string) kerak',
      );
    }
    if (filterProductId != null) q['id'] = '$filterProductId';
    if (filterCategory != null) q['category'] = '$filterCategory';
    if (filterSection != null) q['section'] = '$filterSection';
    final url = _listUri.replace(queryParameters: q);
    final res = await _getLogged(url);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Mahsulotlar API: HTTP ${res.statusCode}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final parsed = ApiProductsResponse.fromJson(map);
    if (!parsed.status) throw Exception('Mahsulotlar API: status false');
    return parsed;
  }

  /// Keyingi sahifani avvalgi javobdagi `next` URL orqali yuklaydi.
  /// `nextUrl` bo'sh yoki null bo'lsa `null` qaytaradi.
  static Future<ApiProductsResponse?> fetchVendorProductsNextPage(
    String? nextUrl,
  ) async {
    if (nextUrl == null || nextUrl.isEmpty) return null;
    try {
      final res = await _getLogged(Uri.parse(nextUrl));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        apiTalker.warning(
          '[API] Products next page HTTP ${res.statusCode}',
        );
        return null;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final parsed = ApiProductsResponse.fromJson(map);
      if (!parsed.status) return null;
      return parsed;
    } catch (e) {
      apiTalker.warning('[API] Products next page error: $e');
      return null;
    }
  }

  static List<ProductModel> toProductModels(ApiProductsResponse response) {
    return response.data.results.map(_itemToProductModel).toList();
  }
}
