import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/models/tax_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';

class CabOrderModel {
  String? status;
  List<dynamic>? rejectedByDrivers;
  String? couponId;
  Timestamp? scheduleDateTime;
  String? duration;
  bool? roundTrip;
  bool? paymentStatus;
  String? discount;
  String? destinationLocationName;
  String? authorID;
  Timestamp? createdAt;
  DestinationLocation? destinationLocation;
  String? adminCommissionType;
  String? sourceLocationName;
  String? rideType;
  List<TaxModel>? taxSetting;
  Timestamp? triggerDelevery;
  String? id;
  String? adminCommission;
  String? couponCode;
  Timestamp? scheduleReturnDateTime;
  String? sectionId;
  String? tipAmount;
  String? distance;
  String? vehicleId;
  String? paymentMethod;
  VehicleType? vehicleType;
  String? otpCode;
  DestinationLocation? sourceLocation;
  UserModel? author;
  UserModel? driver;
  String? driverId;
  String? subTotal;

  // Cab booking trip tracking (yo'riqnoma)
  Timestamp? startTime;
  Timestamp? endTime;
  DestinationLocation? startLocation;
  double? accumulatedDistance;
  bool? isTracking;
  DestinationLocation? lastLocation;
  Timestamp? lastUpdateTime;
  double? finalDistance;
  double? finalFare;
  double? extraKm;
  double? extraCharge;
  // Package: bepul km va qo'shimcha km narxi (vehicleType dan yoki order da saqlanadi)
  double? cabIncludedKm;
  double? cabExtraKmFare;

  CabOrderModel({
    this.status,
    this.rejectedByDrivers,
    this.couponId,
    this.scheduleDateTime,
    this.duration,
    this.roundTrip,
    this.paymentStatus,
    this.discount,
    this.destinationLocationName,
    this.authorID,
    this.createdAt,
    this.destinationLocation,
    this.adminCommissionType,
    this.sourceLocationName,
    this.rideType,
    this.taxSetting,
    this.triggerDelevery,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.scheduleReturnDateTime,
    this.sectionId,
    this.tipAmount,
    this.distance,
    this.vehicleId,
    this.paymentMethod,
    this.vehicleType,
    this.otpCode,
    this.sourceLocation,
    this.author,
    this.subTotal,
    this.driver,
    this.driverId,
    this.startTime,
    this.endTime,
    this.startLocation,
    this.accumulatedDistance,
    this.isTracking,
    this.lastLocation,
    this.lastUpdateTime,
    this.finalDistance,
    this.finalFare,
    this.extraKm,
    this.extraCharge,
    this.cabIncludedKm,
    this.cabExtraKmFare,
  });

  CabOrderModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    rejectedByDrivers = json['rejectedByDrivers'] ?? [];
    couponId = json['couponId'];
    scheduleDateTime = json['scheduleDateTime'];
    duration = json['duration'];
    roundTrip = json['roundTrip'];
    paymentStatus = json['paymentStatus'];
    discount = json['discount'];
    destinationLocationName = json['destinationLocationName'];
    authorID = json['authorID'];
    createdAt = json['createdAt'];
    destinationLocation = json['destinationLocation'] != null ? DestinationLocation.fromJson(json['destinationLocation']) : null;
    adminCommissionType = json['adminCommissionType'];
    sourceLocationName = json['sourceLocationName'];
    rideType = json['rideType'];
    if (json['taxSetting'] != null) {
      taxSetting = <TaxModel>[];
      json['taxSetting'].forEach((v) {
        taxSetting!.add(TaxModel.fromJson(v));
      });
    }
    triggerDelevery = json['trigger_delevery'];
    id = json['id'];
    adminCommission = json['adminCommission'];
    couponCode = json['couponCode'];
    scheduleReturnDateTime = json['scheduleReturnDateTime'];
    sectionId = json['sectionId'];
    tipAmount = json['tip_amount'];
    distance = json['distance'];
    vehicleId = json['vehicleId'];
    paymentMethod = json['paymentMethod'];
    vehicleType = json['vehicleType'] != null ? VehicleType.fromJson(json['vehicleType']) : null;
    otpCode = json['otpCode'];
    sourceLocation = json['sourceLocation'] != null ? DestinationLocation.fromJson(json['sourceLocation']) : null;
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    subTotal = json['subTotal'];
    driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
    driverId = json['driverId'];
    startTime = json['startTime'];
    endTime = json['endTime'];
    startLocation = json['startLocation'] != null ? DestinationLocation.fromJson(json['startLocation']) : null;
    accumulatedDistance = (json['accumulatedDistance'] is num) ? (json['accumulatedDistance'] as num).toDouble() : null;
    isTracking = json['isTracking'];
    lastLocation = json['lastLocation'] != null ? DestinationLocation.fromJson(json['lastLocation']) : null;
    lastUpdateTime = json['lastUpdateTime'];
    finalDistance = (json['finalDistance'] is num) ? (json['finalDistance'] as num).toDouble() : null;
    finalFare = (json['finalFare'] is num) ? (json['finalFare'] as num).toDouble() : null;
    extraKm = (json['extraKm'] is num) ? (json['extraKm'] as num).toDouble() : null;
    extraCharge = (json['extraCharge'] is num) ? (json['extraCharge'] as num).toDouble() : null;
    cabIncludedKm = _safeDouble(json['cabIncludedKm']);
    cabExtraKmFare = _safeDouble(json['cabExtraKmFare']);
  }

  /// NaN yoki noto'g'ri qiymat bo'lsa null (keyin vehicleType dan olinadi)
  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final d = value.toDouble();
      return d.isNaN || d.isInfinite ? null : d;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    // if (rejectedByDrivers != null) {
    //   data['rejectedByDrivers'] = rejectedByDrivers!.map((v) => v.toJson()).toList();
    // }
    if (rejectedByDrivers != null) {
      data['rejectedByDrivers'] = rejectedByDrivers!;
    }
    data['couponId'] = couponId;
    data['scheduleDateTime'] = scheduleDateTime!;
    data['duration'] = duration;
    data['roundTrip'] = roundTrip;
    data['paymentStatus'] = paymentStatus;
    data['discount'] = discount;
    data['destinationLocationName'] = destinationLocationName;
    data['authorID'] = authorID;
    data['createdAt'] = createdAt;
    if (destinationLocation != null) {
      data['destinationLocation'] = destinationLocation!.toJson();
    }
    data['adminCommissionType'] = adminCommissionType;
    data['sourceLocationName'] = sourceLocationName;
    data['rideType'] = rideType;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    data['trigger_delevery'] = triggerDelevery!;
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['scheduleReturnDateTime'] = scheduleReturnDateTime;
    data['sectionId'] = sectionId;
    data['tip_amount'] = tipAmount;
    data['distance'] = distance;
    data['vehicleId'] = vehicleId;
    data['paymentMethod'] = paymentMethod;
    data['driverId'] = driverId;
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }

    if (vehicleType != null) {
      data['vehicleType'] = vehicleType!.toJson();
    }
    data['otpCode'] = otpCode;
    if (sourceLocation != null) {
      data['sourceLocation'] = sourceLocation!.toJson();
    }
    if (author != null) {
      data['author'] = author!.toJson();
    }
    data['subTotal'] = subTotal;
    if (startTime != null) data['startTime'] = startTime;
    if (endTime != null) data['endTime'] = endTime;
    if (startLocation != null) data['startLocation'] = startLocation!.toJson();
    if (accumulatedDistance != null) data['accumulatedDistance'] = accumulatedDistance;
    if (isTracking != null) data['isTracking'] = isTracking;
    if (lastLocation != null) data['lastLocation'] = lastLocation!.toJson();
    if (lastUpdateTime != null) data['lastUpdateTime'] = lastUpdateTime;
    if (finalDistance != null) data['finalDistance'] = finalDistance;
    if (finalFare != null) data['finalFare'] = finalFare;
    if (extraKm != null) data['extraKm'] = extraKm;
    if (extraCharge != null) data['extraCharge'] = extraCharge;
    if (cabIncludedKm != null) data['cabIncludedKm'] = cabIncludedKm;
    if (cabExtraKmFare != null) data['cabExtraKmFare'] = cabExtraKmFare;
    return data;
  }
}

class DestinationLocation {
  double? longitude;
  double? latitude;

  DestinationLocation({this.longitude, this.latitude});

  DestinationLocation.fromJson(Map<String, dynamic> json) {
    longitude = json['longitude'];
    latitude = json['latitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['longitude'] = longitude;
    data['latitude'] = latitude;
    return data;
  }
}
