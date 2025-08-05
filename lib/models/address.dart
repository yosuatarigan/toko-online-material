import 'package:cloud_firestore/cloud_firestore.dart';

class UserAddress {
  final String id;
  final String userId;
  final String label; // "Rumah", "Kantor", "Kos", dll
  final String recipientName;
  final String recipientPhone;
  final String fullAddress;
  final String province;
  final String provinceId;
  final String city;
  final String cityId;
  final String district;
  final String postalCode;
  final String? notes; // Catatan tambahan (patokan, dll)
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.fullAddress,
    required this.province,
    required this.provinceId,
    required this.city,
    required this.cityId,
    required this.district,
    required this.postalCode,
    this.notes,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAddress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAddress(
      id: doc.id,
      userId: data['userId'] ?? '',
      label: data['label'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientPhone: data['recipientPhone'] ?? '',
      fullAddress: data['fullAddress'] ?? '',
      province: data['province'] ?? '',
      provinceId: data['provinceId'] ?? '',
      city: data['city'] ?? '',
      cityId: data['cityId'] ?? '',
      district: data['district'] ?? '',
      postalCode: data['postalCode'] ?? '',
      notes: data['notes'],
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'label': label,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'fullAddress': fullAddress,
      'province': province,
      'provinceId': provinceId,
      'city': city,
      'cityId': cityId,
      'district': district,
      'postalCode': postalCode,
      'notes': notes,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get fullDisplayAddress {
    return '$fullAddress, $district, $city, $province $postalCode';
  }

  UserAddress copyWith({
    String? id,
    String? userId,
    String? label,
    String? recipientName,
    String? recipientPhone,
    String? fullAddress,
    String? province,
    String? provinceId,
    String? city,
    String? cityId,
    String? district,
    String? postalCode,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAddress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      fullAddress: fullAddress ?? this.fullAddress,
      province: province ?? this.province,
      provinceId: provinceId ?? this.provinceId,
      city: city ?? this.city,
      cityId: cityId ?? this.cityId,
      district: district ?? this.district,
      postalCode: postalCode ?? this.postalCode,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Model untuk API Raja Ongkir
class Province {
  final String provinceId;
  final String province;

  Province({
    required this.provinceId,
    required this.province,
  });

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      provinceId: json['province_id']?.toString() ?? '',
      province: json['province'] ?? '',
    );
  }
}

class City {
  final String cityId;
  final String provinceId;
  final String province;
  final String type;
  final String cityName;
  final String postalCode;

  City({
    required this.cityId,
    required this.provinceId,
    required this.province,
    required this.type,
    required this.cityName,
    required this.postalCode,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      cityId: json['city_id']?.toString() ?? '',
      provinceId: json['province_id']?.toString() ?? '',
      province: json['province'] ?? '',
      type: json['type'] ?? '',
      cityName: json['city_name'] ?? '',
      postalCode: json['postal_code'] ?? '',
    );
  }

  String get fullName => '$type $cityName';
}

class ShippingCost {
  final String service;
  final String description;
  final List<ShippingCostDetail> cost;

  ShippingCost({
    required this.service,
    required this.description,
    required this.cost,
  });

  factory ShippingCost.fromJson(Map<String, dynamic> json) {
    return ShippingCost(
      service: json['service'] ?? '',
      description: json['description'] ?? '',
      cost: (json['cost'] as List<dynamic>?)
          ?.map((item) => ShippingCostDetail.fromJson(item))
          .toList() ?? [],
    );
  }
}

class ShippingCostDetail {
  final int value;
  final String etd;
  final String note;

  ShippingCostDetail({
    required this.value,
    required this.etd,
    required this.note,
  });

  factory ShippingCostDetail.fromJson(Map<String, dynamic> json) {
    return ShippingCostDetail(
      value: json['value'] ?? 0,
      etd: json['etd'] ?? '',
      note: json['note'] ?? '',
    );
  }

  String get formattedCost {
    return 'Rp ${value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get estimatedDelivery {
    if (etd.isEmpty) return 'Estimasi tidak tersedia';
    
    if (etd.contains('-')) {
      final parts = etd.split('-');
      if (parts.length == 2) {
        return '${parts[0]}-${parts[1]} hari';
      }
    }
    
    return '$etd hari';
  }
}

class CourierOption {
  final String code;
  final String name;
  final List<ShippingCost> costs;

  CourierOption({
    required this.code,
    required this.name,
    required this.costs,
  });

  factory CourierOption.fromJson(Map<String, dynamic> json) {
    return CourierOption(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      costs: (json['costs'] as List<dynamic>?)
          ?.map((item) => ShippingCost.fromJson(item))
          .toList() ?? [],
    );
  }
}