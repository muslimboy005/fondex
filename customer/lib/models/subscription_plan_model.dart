
import 'package:cloud_firestore/cloud_firestore.dart';

Timestamp? _timestampFromDynamic(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is int) {
    if (value.abs() > 10000000000) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }
    return Timestamp.fromMillisecondsSinceEpoch(value * 1000);
  }
  if (value is double) {
    return _timestampFromDynamic(value.round());
  }
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    final asInt = int.tryParse(s);
    if (asInt != null) return _timestampFromDynamic(asInt);
    final dt = DateTime.tryParse(s);
    if (dt != null) return Timestamp.fromDate(dt.toUtc());
    return null;
  }
  if (value is Map) {
    final m = Map<String, dynamic>.from(value);
    final secRaw = m['_seconds'] ?? m['seconds'] ?? m['sec'];
    final nanoRaw = m['_nanoseconds'] ?? m['nanoseconds'] ?? m['nanos'] ?? 0;
    if (secRaw != null) {
      final sec = int.tryParse(secRaw.toString()) ?? 0;
      final nanos = int.tryParse(nanoRaw.toString()) ?? 0;
      return Timestamp(sec, nanos);
    }
  }
  return null;
}

class SubscriptionPlanModel {
  Timestamp? createdAt;
  String? description;
  String? expiryDay;
  Features? features;
  String? id;
  bool? isEnable;
  bool? isCommissionPlan;
  String? itemLimit;
  String? orderLimit;
  String? name;
  String? price;
  String? place;
  String? image;
  String? type;
  String? sectionId;
  List<String>? planPoints;

  SubscriptionPlanModel(
      {this.createdAt,
      this.description,
      this.expiryDay,
      this.features,
      this.id,
      this.isEnable,
      this.isCommissionPlan,
      this.itemLimit,
      this.orderLimit,
      this.name,
      this.price,
      this.place,
      this.image,
      this.type,
      this.sectionId,
      this.planPoints});

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      createdAt: _timestampFromDynamic(json['createdAt']),
      description: json['description'],
      expiryDay: json['expiryDay'],
      features: json['features'] == null ? null : Features.fromJson(json['features']),
      id: json['id'],
      isEnable: json['isEnable'],
      isCommissionPlan: json['isCommissionPlan'],
      itemLimit: json['itemLimit'],
      orderLimit: json['orderLimit'],
      name: json['name'],
      price: json['price'],
      // place: json['place'],
      sectionId: json['sectionId'],
      image: json['image'],
      type: json['type'],
      planPoints: json['plan_points'] == null ? [] : List<String>.from(json['plan_points']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt,
      'description': description,
      'expiryDay': expiryDay.toString(),
      'features': features?.toJson(),
      'id': id,
      'isEnable': isEnable,
      'itemLimit': itemLimit.toString(),
      'orderLimit': orderLimit.toString(),
      'name': name,
      'price': price.toString(),
      'place': place.toString(),
      'image': image.toString(),
      'type': type,
      'sectionId': sectionId,
      'plan_points': planPoints
    };
  }
}

class Features {
  bool? chat;
  bool? qrCodeGenerate;
  bool? ownerMobileApp;
  bool? demo;

  Features({
    this.chat,
    this.qrCodeGenerate,
    this.ownerMobileApp,
    this.demo,
  });

  // Factory constructor to create an instance from JSON
  factory Features.fromJson(Map<String, dynamic> json) {
    return Features(
      chat: json['chat'] ?? false,
      qrCodeGenerate: json['qrCodeGenerate'] ?? false,
      ownerMobileApp: json['ownerMobileApp'] ?? false,
    );
  }

  // Method to convert an instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'chat': chat,
      'qrCodeGenerate': qrCodeGenerate,
      'ownerMobileApp': ownerMobileApp,
    };
  }
}
