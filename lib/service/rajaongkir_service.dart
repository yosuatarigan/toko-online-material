// lib/service/rajaongkir_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:toko_online_material/models/address_model.dart';

class RajaOngkirService {
  static const String _baseUrl = 'https://rajaongkir.komerce.id/api/v1';
  static const String _apiKey = 'fcehIjgBbdd10044e905d7aedEqf4ZFw';
  
  static const Map<String, String> _headers = {
    'key': _apiKey,
    'Content-Type': 'application/json',
  };

  // New method: Calculate shipping cost directly with IDs
  static Future<List<ShippingCost>> calculateCostWithIds({
    required String originId,
    required String destinationId,
    required int weight,
    String? courier,
  }) async {
    try {
      // Prepare form-data request using MultipartRequest
      final uri = Uri.parse('${_baseUrl}/calculate/domestic-cost');
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers
      request.headers['key'] = _apiKey;
      
      // Add form fields
      request.fields['origin'] = originId;
      request.fields['destination'] = destinationId;
      request.fields['weight'] = weight.toString();
      
      // Add courier filter if specified, otherwise use multiple couriers
      if (courier != null && courier.isNotEmpty) {
        request.fields['courier'] = courier;
      } else {
        // Use multiple couriers for better options (sesuai dengan Postman)
        request.fields['courier'] = 'jne:tiki:pos:jnt:sicepat:ninja:anteraja';
      }

      print('Sending form-data request to: $uri');
      print('Request fields: ${request.fields}');
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          return results.map((json) => ShippingCost.fromApiResponse(json)).toList();
        } else {
          throw Exception(data['meta']['message'] ?? 'Failed to calculate shipping cost');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to calculate shipping cost');
      }
    } catch (e) {
      print('Error calculating shipping cost: $e');
      throw Exception('Error calculating shipping cost: $e');
    }
  }

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

  // Search destinations by province name (new approach)
  static Future<List<City>> getCitiesByProvinceName(String provinceName) async {
    try {
      final uri = Uri.parse('$_baseUrl/destination/domestic-destination').replace(
        queryParameters: {
          'search': provinceName,
          'limit': '200', // Get more results
          'offset': '0',
        },
      );

      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          
          // Group by city to avoid duplicates
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
          'limit': '500', // Get more results for subdistricts
          'offset': '0',
        },
      );

      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          
          // Filter and group by subdistrict to avoid duplicates
          Map<String, Subdistrict> uniqueSubdistricts = {};
          
          for (var item in results) {
            // Only include exact city matches
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
      return []; // Return empty list if fails, subdistrict is optional
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

  // Legacy method: Calculate shipping cost (for backward compatibility)
  static Future<List<ShippingCostLegacy>> calculateCost({
    required String originId,
    required String destinationId,
    required int weight,
    String? courier,
  }) async {
    try {
      final body = {
        'origin': originId,
        'destination': destinationId,
        'weight': weight,
        if (courier != null) 'courier': courier,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/cost/domestic'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['meta']['status'] == 'success') {
          final List<dynamic> results = data['data'];
          return results.map((json) => ShippingCostLegacy.fromJsonV2(json)).toList();
        } else {
          throw Exception(data['meta']['message']);
        }
      } else {
        throw Exception('Failed to calculate cost: ${response.statusCode}');
      }
    } catch (e) {
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

// Updated Shipping Cost Model (matches API response structure)
class ShippingCost {
  final String name;
  final String code;
  final String service;
  final String description;
  final int cost;
  final String etd;

  ShippingCost({
    required this.name,
    required this.code,
    required this.service,
    required this.description,
    required this.cost,
    required this.etd,
  });

  // Factory method for new API response structure
  factory ShippingCost.fromApiResponse(Map<String, dynamic> json) {
    return ShippingCost(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      service: json['service'] ?? '',
      description: json['description'] ?? '',
      cost: (json['cost'] is int) ? json['cost'] : int.tryParse(json['cost'].toString()) ?? 0,
      etd: json['etd'] ?? '',
    );
  }

  String get formattedCost => 'Rp ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  String get displayName => '$service${etd.isNotEmpty ? ' ($etd)' : ''}';
  String get courierDisplayName => name;

  @override
  String toString() => '$name - $service: $formattedCost';
}

// Legacy Shipping Cost Model (for backward compatibility)
class ShippingCostLegacy {
  final String courier;
  final String service;
  final String description;
  final int cost;
  final String etd;

  ShippingCostLegacy({
    required this.courier,
    required this.service,
    required this.description,
    required this.cost,
    required this.etd,
  });

  factory ShippingCostLegacy.fromJsonV2(Map<String, dynamic> json) {
    return ShippingCostLegacy(
      courier: json['courier'] ?? '',
      service: json['service'] ?? '',
      description: json['description'] ?? '',
      cost: json['cost'] ?? 0,
      etd: json['etd'] ?? '',
    );
  }

  String get formattedCost => 'Rp ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
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