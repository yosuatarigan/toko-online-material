// lib/service/distance_service.dart (Updated to always show store delivery option)
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class DistanceService {
  // Koordinat toko (Laren, Lamongan)
  static const double _storeLatitude = -7.1617;
  static const double _storeLongitude = 112.3089;
  static const String _storeAddress = "Laren, Lamongan, Jawa Timur";
  
  // Google Maps API Key (ganti dengan API key Anda)
  static const String _googleApiKey = 'AIzaSyCRNOb3ZhhFSWFB6_bN_Ogz6EI3DP8Bfqw';

  /// Menghitung jarak menggunakan Haversine formula (jarak lurus)
  static double calculateHaversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371; // Radius bumi dalam km

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Mendapatkan koordinat dari alamat menggunakan Google Geocoding API
  static Future<Map<String, double>?> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleApiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'latitude': location['lat'].toDouble(),
            'longitude': location['lng'].toDouble(),
          };
        }
      }
    } catch (e) {
      print('Error getting coordinates: $e');
    }
    return null;
  }

  /// Menghitung jarak rute menggunakan Google Distance Matrix API
  static Future<DistanceResult?> calculateRouteDistance(
    String destinationAddress,
  ) async {
    try {
      final encodedDestination = Uri.encodeComponent(destinationAddress);
      final encodedOrigin = Uri.encodeComponent(_storeAddress);
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$encodedOrigin&destinations=$encodedDestination&units=metric&key=$_googleApiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && 
            data['rows'].isNotEmpty && 
            data['rows'][0]['elements'].isNotEmpty) {
          
          final element = data['rows'][0]['elements'][0];
          
          if (element['status'] == 'OK') {
            return DistanceResult(
              distanceKm: element['distance']['value'] / 1000.0,
              distanceText: element['distance']['text'],
              durationText: element['duration']['text'],
              durationMinutes: element['duration']['value'] / 60.0,
            );
          }
        }
      }
    } catch (e) {
      print('Error calculating route distance: $e');
    }
    return null;
  }

  /// Menggunakan estimasi berdasarkan nama kota untuk fallback
  static DistanceResult? estimateDistanceByCity(String cityName) {
    final Map<String, DistanceResult> cityDistances = {
      'LAMONGAN': DistanceResult(
        distanceKm: 5.0,
        distanceText: '5 km',
        durationText: '15 menit',
        durationMinutes: 15,
      ),
      'GRESIK': DistanceResult(
        distanceKm: 35.0,
        distanceText: '35 km',
        durationText: '45 menit',
        durationMinutes: 45,
      ),
      'TUBAN': DistanceResult(
        distanceKm: 45.0,
        distanceText: '45 km',
        durationText: '1 jam',
        durationMinutes: 60,
      ),
      'BOJONEGORO': DistanceResult(
        distanceKm: 55.0,
        distanceText: '55 km',
        durationText: '1 jam 15 menit',
        durationMinutes: 75,
      ),
      'SURABAYA': DistanceResult(
        distanceKm: 65.0,
        distanceText: '65 km',
        durationText: '1 jam 30 menit',
        durationMinutes: 90,
      ),
    };

    final upperCityName = cityName.toUpperCase();
    for (final city in cityDistances.keys) {
      if (upperCityName.contains(city)) {
        return cityDistances[city];
      }
    }

    // Default untuk wilayah Jawa Timur lainnya
    if (upperCityName.contains('JAWA TIMUR') || 
        upperCityName.contains('JATIM')) {
      return DistanceResult(
        distanceKm: 80.0,
        distanceText: '~80 km',
        durationText: '~2 jam',
        durationMinutes: 120,
      );
    }

    return null;
  }

  /// Method utama untuk menghitung jarak ke alamat tujuan
  static Future<DistanceResult?> calculateDistanceToAddress(
    String fullAddress,
    String cityName,
  ) async {
    try {
      // Coba menggunakan Google Distance Matrix API dulu
      final routeResult = await calculateRouteDistance(fullAddress);
      if (routeResult != null) {
        return routeResult;
      }

      // Fallback ke estimasi berdasarkan kota
      final estimateResult = estimateDistanceByCity(cityName);
      if (estimateResult != null) {
        return estimateResult.copyWith(isEstimate: true);
      }

      return null;
    } catch (e) {
      print('Error calculating distance: $e');
      return null;
    }
  }

  /// Mengecek apakah alamat memenuhi syarat pengiriman toko
  static bool isEligibleForStoreDelivery(DistanceResult? distance) {
    if (distance == null) return false;
    return distance.distanceKm <= 10.0;
  }

  /// Menghitung biaya pengiriman toko berdasarkan jarak
  static int calculateStoreDeliveryFee(DistanceResult distance) {
    if (distance.distanceKm <= 3.0) {
      return 5000; // Gratis untuk 3 km pertama, tapi minimal fee 5000
    } else if (distance.distanceKm <= 5.0) {
      return 10000;
    } else if (distance.distanceKm <= 8.0) {
      return 15000;
    } else {
      return 20000; // Maksimal untuk 10 km
    }
  }

  /// Mendapatkan estimasi waktu pengiriman toko
  static String getStoreDeliveryEstimate(DistanceResult distance) {
    if (distance.distanceKm <= 3.0) {
      return 'Hari ini (2-4 jam)';
    } else if (distance.distanceKm <= 6.0) {
      return 'Hari ini (3-6 jam)';
    } else {
      return 'Besok (1-2 hari)';
    }
  }

  /// BARU - Mendapatkan alasan mengapa pengiriman toko tidak tersedia
  static String getUnavailableReason(DistanceResult? distance, String? cityName) {
    if (distance == null) {
      return 'Lokasi terlalu jauh atau di luar jangkauan';
    }
    
    if (distance.distanceKm > 10.0) {
      return 'Jarak ${distance.distanceText} melebihi batas maksimal 10 km';
    }

    // Fallback jika ada kondisi khusus lainnya
    return 'Layanan sementara tidak tersedia untuk wilayah ini';
  }
}

/// Model untuk hasil perhitungan jarak
class DistanceResult {
  final double distanceKm;
  final String distanceText;
  final String durationText;
  final double durationMinutes;
  final bool isEstimate;

  DistanceResult({
    required this.distanceKm,
    required this.distanceText,
    required this.durationText,
    required this.durationMinutes,
    this.isEstimate = false,
  });

  DistanceResult copyWith({
    double? distanceKm,
    String? distanceText,
    String? durationText,
    double? durationMinutes,
    bool? isEstimate,
  }) {
    return DistanceResult(
      distanceKm: distanceKm ?? this.distanceKm,
      distanceText: distanceText ?? this.distanceText,
      durationText: durationText ?? this.durationText,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isEstimate: isEstimate ?? this.isEstimate,
    );
  }

  @override
  String toString() {
    return 'Distance: $distanceText, Duration: $durationText${isEstimate ? ' (estimasi)' : ''}';
  }
}

/// Model untuk opsi pengiriman toko - DIUPDATE
class StoreDeliveryOption {
  final String id;
  final String name;
  final String description;
  final int cost;
  final String estimatedTime;
  final DistanceResult? distance;
  final bool isAvailable;
  final String unavailableReason;

  StoreDeliveryOption({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.estimatedTime,
    this.distance,
    this.isAvailable = true,
    this.unavailableReason = '',
  });

  String get formattedCost => 'Rp ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  
  String get fullDescription {
    if (distance != null) {
      return '$description • ${distance!.distanceText} • $estimatedTime';
    }
    return description;
  }

  /// Factory method original - buat berdasarkan jarak yang sudah ada
  factory StoreDeliveryOption.create(DistanceResult distance) {
    final cost = DistanceService.calculateStoreDeliveryFee(distance);
    final estimate = DistanceService.getStoreDeliveryEstimate(distance);
    
    return StoreDeliveryOption(
      id: 'store_delivery',
      name: 'Pengiriman Toko',
      description: 'Dikirim langsung oleh Toko Barokah',
      cost: cost,
      estimatedTime: estimate,
      distance: distance,
      isAvailable: DistanceService.isEligibleForStoreDelivery(distance),
      unavailableReason: DistanceService.isEligibleForStoreDelivery(distance) 
        ? '' 
        : DistanceService.getUnavailableReason(distance, null),
    );
  }

  /// FACTORY METHOD BARU - Selalu buat opsi pengiriman toko (available atau disabled)
  factory StoreDeliveryOption.createAlways(DistanceResult? distance, String? cityName) {
    if (distance != null) {
      // Jika ada data jarak, buat berdasarkan jarak
      final isEligible = DistanceService.isEligibleForStoreDelivery(distance);
      final cost = isEligible ? DistanceService.calculateStoreDeliveryFee(distance) : 0;
      final estimate = isEligible ? DistanceService.getStoreDeliveryEstimate(distance) : 'Tidak tersedia';
      final reason = isEligible ? '' : DistanceService.getUnavailableReason(distance, cityName);
      
      return StoreDeliveryOption(
        id: 'store_delivery',
        name: 'Pengiriman Toko',
        description: 'Dikirim langsung oleh Toko Barokah',
        cost: cost,
        estimatedTime: estimate,
        distance: distance,
        isAvailable: isEligible,
        unavailableReason: reason,
      );
    } else {
      // Jika tidak ada data jarak, buat opsi disabled dengan pesan umum
      return StoreDeliveryOption(
        id: 'store_delivery',
        name: 'Pengiriman Toko',
        description: 'Dikirim langsung oleh Toko Barokah',
        cost: 0,
        estimatedTime: 'Tidak tersedia',
        distance: null,
        isAvailable: false,
        unavailableReason: DistanceService.getUnavailableReason(null, cityName),
      );
    }
  }

  /// FACTORY METHOD BARU - Buat opsi default ketika tidak ada alamat
  factory StoreDeliveryOption.createDefault() {
    return StoreDeliveryOption(
      id: 'store_delivery',
      name: 'Pengiriman Toko',
      description: 'Dikirim langsung oleh Toko Barokah',
      cost: 0,
      estimatedTime: 'Maksimal 10 km',
      distance: null,
      isAvailable: false,
      unavailableReason: 'Pilih alamat terlebih dahulu untuk mengecek ketersediaan',
    );
  }

  /// Method untuk membuat copy dengan perubahan tertentu
  StoreDeliveryOption copyWith({
    String? id,
    String? name,
    String? description,
    int? cost,
    String? estimatedTime,
    DistanceResult? distance,
    bool? isAvailable,
    String? unavailableReason,
  }) {
    return StoreDeliveryOption(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      cost: cost ?? this.cost,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      distance: distance ?? this.distance,
      isAvailable: isAvailable ?? this.isAvailable,
      unavailableReason: unavailableReason ?? this.unavailableReason,
    );
  }

  @override
  String toString() {
    return 'StoreDeliveryOption{name: $name, cost: $formattedCost, available: $isAvailable, distance: ${distance?.distanceText ?? 'unknown'}}';
  }
}