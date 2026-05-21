import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/cashback_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';

class OrderModel {
  ShippingAddress? address;
  String? status;
  String? couponId;
  String? vendorID;
  String? driverID;
  num? discount;
  String? authorID;
  String? estimatedTimeToPrepare;
  Timestamp? createdAt;
  Timestamp? triggerDelivery;
  List<TaxModel>? taxSetting;
  String? paymentMethod;
  List<CartProductModel>? products;
  String? adminCommissionType;
  VendorModel? vendor;
  String? id;
  String? adminCommission;
  String? couponCode;
  String? sectionId;
  Map<String, dynamic>? specialDiscount;
  String? deliveryCharge;
  Timestamp? scheduleTime;
  String? tipAmount;
  String? notes;
  UserModel? author;
  UserModel? driver;
  bool? takeAway;
  List<dynamic>? rejectedByDrivers;
  CashbackModel? cashback;
  String? courierCompanyName;
  String? courierTrackingId;

  OrderModel({
    this.address,
    this.status,
    this.couponId,
    this.vendorID,
    this.driverID,
    this.discount,
    this.authorID,
    this.estimatedTimeToPrepare,
    this.createdAt,
    this.triggerDelivery,
    this.taxSetting,
    this.paymentMethod,
    this.products,
    this.adminCommissionType,
    this.vendor,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.sectionId,
    this.specialDiscount,
    this.deliveryCharge,
    this.scheduleTime,
    this.tipAmount,
    this.notes,
    this.author,
    this.driver,
    this.takeAway,
    this.rejectedByDrivers,
    this.cashback,
    this.courierCompanyName,
    this.courierTrackingId,
  });

  OrderModel.fromJson(Map<String, dynamic> json) {
    String step = '<init>';
    try {
      step = 'address';
      address =
      json['address'] != null
          ? ShippingAddress.fromJson(json['address'])
          : null;
      step = 'status';
      status = json['status'];
      step = 'couponId';
      couponId = json['couponId'];
      step = 'vendorID';
      vendorID = json['vendorID'];
      step = 'driverID';
      driverID = json['driverID'];
      step = 'discount';
      discount = json['discount'];
      step = 'authorID';
      authorID = json['authorID'];
      step = 'estimatedTimeToPrepare';
      estimatedTimeToPrepare = json['estimatedTimeToPrepare'];
      step = 'createdAt';
      createdAt = json['createdAt'];
      step = 'courierCompanyName';
      courierCompanyName = json['courierCompanyName'];
      step = 'courierTrackingId';
      courierTrackingId = json['courierTrackingId'];
      step = 'triggerDelivery';
      triggerDelivery = json['triggerDelevery'] ?? Timestamp.now();
      step = 'taxSetting';
      if (json['taxSetting'] != null) {
        taxSetting = <TaxModel>[];
        json['taxSetting'].forEach((v) {
          taxSetting!.add(TaxModel.fromJson(v));
        });
      }
      step = 'paymentMethod';
      paymentMethod = json['payment_method'];
      step = 'products';
      if (json['products'] != null) {
        products = <CartProductModel>[];
        json['products'].forEach((v) {
          products!.add(CartProductModel.fromJson(v));
        });
      }
      step = 'adminCommissionType';
      adminCommissionType = json['adminCommissionType'];
      step = 'vendor';
      vendor =
      json['vendor'] != null ? VendorModel.fromJson(json['vendor']) : null;
      step = 'id';
      id = json['id'];
      step = 'adminCommission';
      adminCommission = json['adminCommission'];
      step = 'couponCode';
      couponCode = json['couponCode'];
      step = 'sectionId';
      sectionId = json['section_id'];
      step = 'specialDiscount';
      specialDiscount = json['specialDiscount'];
      step = 'deliveryCharge';
      deliveryCharge =
      json['deliveryCharge'].toString().isEmpty
          ? "0.0"
          : json['deliveryCharge'] ?? '0.0';
      step = 'scheduleTime';
      scheduleTime = json['scheduleTime'];
      step = 'tipAmount';
      tipAmount =
      json['tip_amount'].toString().isEmpty
          ? "0.0"
          : json['tip_amount'] ?? "0.0";
      step = 'notes';
      notes = json['notes'];
      step = 'author';
      author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
      step = 'driver';
      driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
      step = 'takeAway';
      takeAway = json['takeAway'];
      step = 'rejectedByDrivers';
      rejectedByDrivers = json['rejectedByDrivers'] ?? [];
      step = 'cashback';
      cashback =
      json['cashback'] != null
          ? CashbackModel.fromJson(json['cashback'])
          : null;
    } catch (e, st) {
      final raw = json[_resolveJsonKey(step)];
      developer.log(
        '❌ [OrderModel.fromJson] field="$step" '
        'value=$raw (${raw?.runtimeType}) error=$e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static String _resolveJsonKey(String step) {
    switch (step) {
      case 'paymentMethod':
        return 'payment_method';
      case 'sectionId':
        return 'section_id';
      case 'tipAmount':
        return 'tip_amount';
      case 'triggerDelivery':
        return 'triggerDelevery';
      default:
        return step;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (address != null) {
      data['address'] = address!.toJson();
    }
    data['status'] = status;
    data['couponId'] = couponId;
    data['vendorID'] = vendorID;
    data['driverID'] = driverID;
    data['discount'] = discount;
    data['authorID'] = authorID;
    data['estimatedTimeToPrepare'] = estimatedTimeToPrepare;
    data['createdAt'] = createdAt;
    // fromJson typo'li 'triggerDelevery' kalitini o'qiydi — yozishda ikkala
    // kalitni ham qoldiramiz (back/forward compat).
    data['triggerDelevery'] = triggerDelivery;
    data['triggerDelivery'] = triggerDelivery;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    data['payment_method'] = paymentMethod;
    if (products != null) {
      data['products'] = products!.map((v) => v.toJson()).toList();
    }
    data['adminCommissionType'] = adminCommissionType;
    if (vendor != null) {
      data['vendor'] = vendor!.toJson();
    }
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['section_id'] = sectionId;
    data['specialDiscount'] = specialDiscount;
    data['deliveryCharge'] = deliveryCharge;
    data['scheduleTime'] = scheduleTime;
    data['tip_amount'] = tipAmount;
    data['courierCompanyName'] = courierCompanyName;
    data['courierTrackingId'] = courierTrackingId;
    data['notes'] = notes;
    if (author != null) {
      data['author'] = author!.toJson();
    }
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }
    data['takeAway'] = takeAway;
    data['rejectedByDrivers'] = rejectedByDrivers;
    data['cashback'] = cashback?.toJson();
    return data;
  }
}
