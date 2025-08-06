// lib/models/address_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String id;
  final String userId;
  final String label; // Home, Office, etc.
  final String recipientName;
  final String recipientPhone;
  final String provinceName;
  final String provinceId;
  final String cityName;
  final String cityId;
  final String subdistrictName;
  final String subdistrictId;
  final String districtName; // Added for V2 API
  final String detailAddress;
  final String postalCode;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.provinceName,
    required this.provinceId,
    required this.cityName,
    required this.cityId,
    required this.subdistrictName,
    required this.subdistrictId,
    this.districtName = '',
    required this.detailAddress,
    required this.postalCode,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress {
    var parts = <String>[];
    if (detailAddress.isNotEmpty) parts.add(detailAddress);
    if (subdistrictName.isNotEmpty) parts.add(subdistrictName);
    if (districtName.isNotEmpty && districtName != subdistrictName) parts.add(districtName);
    if (cityName.isNotEmpty) parts.add(cityName);
    if (provinceName.isNotEmpty) parts.add(provinceName);
    if (postalCode.isNotEmpty) parts.add(postalCode);
    
    return parts.join(', ');
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'label': label,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'provinceName': provinceName,
      'provinceId': provinceId,
      'cityName': cityName,
      'cityId': cityId,
      'subdistrictName': subdistrictName,
      'subdistrictId': subdistrictId,
      'districtName': districtName,
      'detailAddress': detailAddress,
      'postalCode': postalCode,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Address.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Address(
      id: doc.id,
      userId: data['userId'] ?? '',
      label: data['label'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientPhone: data['recipientPhone'] ?? '',
      provinceName: data['provinceName'] ?? '',
      provinceId: data['provinceId'] ?? '',
      cityName: data['cityName'] ?? '',
      cityId: data['cityId'] ?? '',
      subdistrictName: data['subdistrictName'] ?? '',
      subdistrictId: data['subdistrictId'] ?? '',
      districtName: data['districtName'] ?? '',
      detailAddress: data['detailAddress'] ?? '',
      postalCode: data['postalCode'] ?? '',
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Address copyWith({
    String? id,
    String? userId,
    String? label,
    String? recipientName,
    String? recipientPhone,
    String? provinceName,
    String? provinceId,
    String? cityName,
    String? cityId,
    String? subdistrictName,
    String? subdistrictId,
    String? districtName,
    String? detailAddress,
    String? postalCode,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      provinceName: provinceName ?? this.provinceName,
      provinceId: provinceId ?? this.provinceId,
      cityName: cityName ?? this.cityName,
      cityId: cityId ?? this.cityId,
      subdistrictName: subdistrictName ?? this.subdistrictName,
      subdistrictId: subdistrictId ?? this.subdistrictId,
      districtName: districtName ?? this.districtName,
      detailAddress: detailAddress ?? this.detailAddress,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Province Model for API V2
class Province {
  final String id;
  final String name;

  Province({required this.id, required this.name});

  // Factory for V2 API response
  factory Province.fromJsonV2(Map<String, dynamic> json) {
    return Province(
      id: json['id'].toString(),
      name: json['name'] ?? '',
    );
  }

  // Factory for V1 API response (fallback)
  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: json['province_id']?.toString() ?? '',
      name: json['province'] ?? '',
    );
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Province && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// City Model for API V2
class City {
  final String id;
  final String name;
  final String type;
  final String provinceId;
  final String provinceName;
  final String? postalCode;

  City({
    required this.id,
    required this.name,
    required this.type,
    required this.provinceId,
    required this.provinceName,
    this.postalCode,
  });

  // Factory for V2 API response (from search results)
  factory City.fromJsonV2(Map<String, dynamic> json) {
    return City(
      id: json['id'].toString(),
      name: json['city_name'] ?? '',
      type: _determineCityType(json['city_name'] ?? ''),
      provinceId: '', // Not available in V2 search response
      provinceName: json['province_name'] ?? '',
      postalCode: json['zip_code'],
    );
  }

  // Factory for V1 API response (fallback)
  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['city_id']?.toString() ?? '',
      name: json['city_name'] ?? '',
      type: json['type'] ?? '',
      provinceId: json['province_id']?.toString() ?? '',
      provinceName: json['province'] ?? '',
      postalCode: json['postal_code'],
    );
  }

  static String _determineCityType(String cityName) {
    final upperName = cityName.toUpperCase();
    if (upperName.contains('KOTA') || 
        upperName.contains('JAKARTA') || 
        upperName.contains('SURABAYA') ||
        upperName.contains('BANDUNG') ||
        upperName.contains('MEDAN') ||
        upperName.contains('SEMARANG') ||
        upperName.contains('PALEMBANG') ||
        upperName.contains('MAKASSAR') ||
        upperName.contains('TANGERANG') ||
        upperName.contains('BEKASI') ||
        upperName.contains('DEPOK') ||
        upperName.contains('BOGOR')) {
      return 'Kota';
    }
    return 'Kabupaten';
  }

  String get displayName => name.contains(type) ? name : '$type $name';
  String get fullName => '$displayName, $provinceName';

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is City && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Subdistrict Model for API V2
class Subdistrict {
  final String id;
  final String name;
  final String cityId;
  final String cityName;
  final String provinceName;
  final String districtName;
  final String? postalCode;

  Subdistrict({
    required this.id,
    required this.name,
    required this.cityId,
    required this.cityName,
    required this.provinceName,
    this.districtName = '',
    this.postalCode,
  });

  // Factory for V2 API response (from search results)
  factory Subdistrict.fromJsonV2(Map<String, dynamic> json) {
    return Subdistrict(
      id: json['id'].toString(),
      name: json['subdistrict_name'] ?? '',
      cityId: '', // Not available in V2 search response
      cityName: json['city_name'] ?? '',
      provinceName: json['province_name'] ?? '',
      districtName: json['district_name'] ?? '',
      postalCode: json['zip_code'],
    );
  }

  // Factory for V1 API response (fallback)
  factory Subdistrict.fromJson(Map<String, dynamic> json) {
    return Subdistrict(
      id: json['subdistrict_id']?.toString() ?? '',
      name: json['subdistrict_name'] ?? '',
      cityId: json['city_id']?.toString() ?? '',
      cityName: json['city'] ?? '',
      provinceName: json['province'] ?? '',
      districtName: json['district_name'] ?? '',
    );
  }

  // Factory for alternative API
  factory Subdistrict.fromAlternativeApi(Map<String, dynamic> json) {
    return Subdistrict(
      id: json['id']?.toString() ?? '',
      name: json['text'] ?? '',
      cityId: '',
      cityName: '',
      provinceName: '',
    );
  }

  String get fullName {
    var parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (districtName.isNotEmpty && districtName != name) parts.add(districtName);
    if (cityName.isNotEmpty) parts.add(cityName);
    if (provinceName.isNotEmpty) parts.add(provinceName);
    
    return parts.join(', ');
  }

  String get displayName {
    if (districtName.isNotEmpty && districtName != name) {
      return '$name ($districtName)';
    }
    return name;
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subdistrict && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}