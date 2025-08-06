// lib/service/rajaongkir_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:toko_online_material/models/address_model.dart';

class RajaOngkirService {
  static const String _baseUrl = 'https://rajaongkir.komerce.id/api/v1';
  static const String _apiKey = 'fcehljgBbdd10044e905d7aedEqf4ZFw'; // Ganti dengan API Key Anda
  
  static const Map<String, String> _headers = {
    'key': _apiKey,
    'Accept': 'application/json',
  };

  // Get list of provinces
  static Future<List<Province>> getProvinces() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/destination/province'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          return results.map((json) => Province.fromJsonV2(json)).toList();
        } else {
          throw Exception(data['meta']['message']);
        }
      } else {
        throw Exception('Failed to load provinces: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching provinces: $e');
    }
  }

  // Search destinations by province name
  static Future<List<City>> getCitiesByProvinceName(String provinceName) async {
    try {
      final uri = Uri.parse('$_baseUrl/destination/domestic-destination').replace(
        queryParameters: {
          'search': provinceName,
          'limit': '200',
          'offset': '0',
        },
      );

      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          
          Map<String, City> uniqueCities = {};
          
          for (var item in results) {
            final cityName = item['city_name'];
            if (!uniqueCities.containsKey(cityName)) {
              uniqueCities[cityName] = City.fromJsonV2(item);
            }
          }
          
          var cities = uniqueCities.values.toList();
          cities.sort((a, b) => a.name.compareTo(b.name));
          return cities;
        } else {
          throw Exception(data['meta']['message']);
        }
      } else {
        throw Exception('Failed to load cities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching cities: $e');
    }
  }

  // Search destinations by city name to get subdistricts
  static Future<List<Subdistrict>> getSubdistrictsByCityName(String cityName) async {
    try {
      final uri = Uri.parse('$_baseUrl/destination/domestic-destination').replace(
        queryParameters: {
          'search': cityName,
          'limit': '500',
          'offset': '0',
        },
      );

      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          
          Map<String, Subdistrict> uniqueSubdistricts = {};
          
          for (var item in results) {
            if (item['city_name'].toString().toLowerCase() == cityName.toLowerCase()) {
              final subdistrictName = item['subdistrict_name'];
              final districtName = item['district_name'];
              final key = '$subdistrictName-$districtName';
              
              if (!uniqueSubdistricts.containsKey(key)) {
                uniqueSubdistricts[key] = Subdistrict.fromJsonV2(item);
              }
            }
          }
          
          var subdistricts = uniqueSubdistricts.values.toList();
          subdistricts.sort((a, b) => a.name.compareTo(b.name));
          return subdistricts;
        } else {
          throw Exception(data['meta']['message']);
        }
      } else {
        throw Exception('Failed to load subdistricts: ${response.statusCode}');
      }
    } catch (e) {
      print('Subdistrict API failed: $e');
      return [];
    }
  }

  // Generic search for autocomplete
  static Future<List<Destination>> searchDestinations({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/destination/domestic-destination').replace(
        queryParameters: {
          'search': query,
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );

      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          return results.map((json) => Destination.fromJsonV2(json)).toList();
        } else {
          throw Exception(data['meta']['message']);
        }
      } else {
        throw Exception('Failed to search destinations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching destinations: $e');
    }
  }

  // FIXED: Calculate shipping cost dengan format yang benar
  static Future<List<ShippingCost>> calculateCost({
    required String originId,
    required String destinationId,
    required int weight,
    List<String>? couriers,
  }) async {
    try {
      print('Calculating cost with:');
      print('Origin: $originId');
      print('Destination: $destinationId');
      print('Weight: ${weight}g');
      
      // Default couriers jika tidak disediakan
      final courierList = couriers ?? ['jne', 'tiki', 'pos', 'jnt', 'sicepat', 'ninja', 'anteraja'];
      final courierString = courierList.join(':');
      
      print('Couriers: $courierString');

      // FIXED: Menggunakan form-data seperti yang berhasil di Postman
      final body = {
        'origin': originId,
        'destination': destinationId,
        'weight': weight.toString(),
        'courier': courierString,
      };

      // FIXED: Menggunakan endpoint yang benar dan content-type form-urlencoded
      final response = await http.post(
        Uri.parse('$_baseUrl/calculate/domestic-cost'),
        headers: {
          'key': _apiKey,
          'Accept': 'application/json',
          // PENTING: Tidak pakai Content-Type JSON, biarkan http package handle form data
        },
        body: body, // Kirim sebagai form data, bukan JSON
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'] ?? [];
          
          if (results.isEmpty) {
            throw Exception('Tidak ada layanan pengiriman tersedia');
          }
          
          return results.map((json) => ShippingCost.fromJsonV2(json)).toList();
        } else {
          throw Exception(data['meta']['message'] ?? 'Unknown error');
        }
      } else {
        throw Exception('Failed to calculate cost: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Calculate cost error: $e');
      throw Exception('Error calculating cost: $e');
    }
  }

  // Utility functions
  static bool isValidPostalCode(String postalCode) {
    final regex = RegExp(r'^\d{5}$');
    return regex.hasMatch(postalCode);
  }

  static String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('62')) {
      cleaned = '62$cleaned';
    }
    
    return cleaned;
  }

  // Get sample postal codes for common cities (fallback data)
  static String? getSamplePostalCode(String cityName) {
    final Map<String, String> cityPostalCodes = {
      'JAKARTA PUSAT': '10110',
      'JAKARTA UTARA': '14240',
      'JAKARTA BARAT': '11220',
      'JAKARTA SELATAN': '12560',
      'JAKARTA TIMUR': '13330',
      'SURABAYA': '60119',
      'BANDUNG': '40111',
      'BANDUNG BARAT': '40391',
      'MEDAN': '20111',
      'BEKASI': '17112',
      'TANGERANG': '15111',
      'TANGERANG SELATAN': '15412',
      'DEPOK': '16411',
      'SEMARANG': '50133',
      'PALEMBANG': '30111',
      'MAKASSAR': '90111',
      'YOGYAKARTA': '55161',
      'BOGOR': '16111',
      'MALANG': '65111',
      'SOLO': '57111',
      'LAMONGAN': '62200', // Added store location
    };

    final upperCityName = cityName.toUpperCase();
    for (String city in cityPostalCodes.keys) {
      if (upperCityName.contains(city) || city.contains(upperCityName)) {
        return cityPostalCodes[city];
      }
    }
    return null;
  }

  // Extract postal code from destination data
  static String? extractPostalCode(Destination destination) {
    return destination.zipCode;
  }
}

// Updated Models for V2 API
class Destination {
  final String id;
  final String label;
  final String provinceName;
  final String cityName;
  final String districtName;
  final String subdistrictName;
  final String zipCode;

  Destination({
    required this.id,
    required this.label,
    required this.provinceName,
    required this.cityName,
    required this.districtName,
    required this.subdistrictName,
    required this.zipCode,
  });

  factory Destination.fromJsonV2(Map<String, dynamic> json) {
    return Destination(
      id: json['id'].toString(),
      label: json['label'] ?? '',
      provinceName: json['province_name'] ?? '',
      cityName: json['city_name'] ?? '',
      districtName: json['district_name'] ?? '',
      subdistrictName: json['subdistrict_name'] ?? '',
      zipCode: json['zip_code'] ?? '',
    );
  }

  String get fullAddress => label;
  String get shortAddress => '$subdistrictName, $districtName, $cityName';
}

class ShippingCost {
  final String name; // Nama lengkap courier
  final String code; // Code courier
  final String service; // Jenis layanan
  final String description; // Deskripsi layanan
  final int cost; // Biaya dalam Rupiah
  final String etd; // Estimasi waktu pengiriman

  ShippingCost({
    required this.name,
    required this.code,
    required this.service,
    required this.description,
    required this.cost,
    required this.etd,
  });

  factory ShippingCost.fromJsonV2(Map<String, dynamic> json) {
    return ShippingCost(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      service: json['service'] ?? '',
      description: json['description'] ?? '',
      cost: (json['cost'] is int) ? json['cost'] : int.tryParse(json['cost'].toString()) ?? 0,
      etd: json['etd']?.toString() ?? '',
    );
  }

  // Getter untuk kompatibilitas dengan kode yang ada
  String get courier => code;
  
  String get formattedCost => 'Rp ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  
  String get displayName {
    if (etd.isNotEmpty && etd != '0') {
      return '$service ($etd hari)';
    }
    return service;
  }

  String get fullDisplayName => '${name.toUpperCase()} $service';
}