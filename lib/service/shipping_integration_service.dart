// lib/service/shipping_integration_service.dart
import 'package:flutter/material.dart';
import 'package:toko_online_material/models/address_model.dart';
import 'package:toko_online_material/service/rajaongkir_service.dart';
import 'package:toko_online_material/service/distance_service.dart';
import 'package:toko_online_material/service/store_delevery_store.dart';

/// Service untuk mengintegrasikan berbagai metode pengiriman
class ShippingIntegrationService {
  /// Mendapatkan semua opsi pengiriman yang tersedia
  static Future<ShippingOptionsResult> getAllShippingOptions({
    required Address deliveryAddress,
    required double totalWeight,
    required double totalAmount,
    required List<String> selectedItemIds,
  }) async {
    final List<ShippingOptionItem> allOptions = [];
    final List<String> errors = [];

    try {
      // 1. Cek ketersediaan pengiriman toko
      final storeAvailability = await StoreDeliveryService.checkAvailability(
        address: deliveryAddress,
        totalWeight: totalWeight,
        totalAmount: totalAmount,
      );

      if (storeAvailability.isAvailable && storeAvailability.option != null) {
        allOptions.add(
          ShippingOptionItem(
            id: 'store_delivery',
            type: ShippingType.store,
            name: storeAvailability.option!.name,
            description: storeAvailability.option!.description,
            cost: storeAvailability.option!.cost,
            estimatedTime: storeAvailability.option!.estimatedTime,
            provider: 'Toko Barokah',
            isRecommended: true,
            additionalInfo: {
              'distance': storeAvailability.option!.distance.distanceText,
              'isEstimate': storeAvailability.option!.distance.isEstimate,
            },
          ),
        );
      }

      // 2. Dapatkan opsi kurir dari RajaOngkir
      if (deliveryAddress.subdistrictId.isNotEmpty) {
        try {
          final courierOptions = await RajaOngkirService.calculateCostWithIds(
            originId: '69943', // ID toko
            destinationId: deliveryAddress.subdistrictId,
            weight: totalWeight.toInt(),
          );

          for (final option in courierOptions) {
            if (option.cost > 0) {
              allOptions.add(
                ShippingOptionItem(
                  id: '${option.code}_${option.service}',
                  type: ShippingType.courier,
                  name: '${option.courierDisplayName} ${option.service}',
                  description: option.description,
                  cost: option.cost,
                  estimatedTime: option.etd,
                  provider: option.courierDisplayName,
                  isRecommended: false,
                ),
              );
            }
          }
        } catch (e) {
          errors.add('Gagal memuat opsi kurir: $e');
        }
      } else {
        errors.add('Alamat tidak memiliki informasi kecamatan yang valid');
      }

      // 3. Sort opsi berdasarkan rekomendasi dan harga
      allOptions.sort((a, b) {
        if (a.isRecommended && !b.isRecommended) return -1;
        if (!a.isRecommended && b.isRecommended) return 1;
        return a.cost.compareTo(b.cost);
      });

      return ShippingOptionsResult(
        options: allOptions,
        errors: errors,
        hasStoreDelivery: allOptions.any((o) => o.type == ShippingType.store),
        hasCourierOptions: allOptions.any((o) => o.type == ShippingType.courier),
      );

    } catch (e) {
      errors.add('Terjadi kesalahan saat memuat opsi pengiriman: $e');
      return ShippingOptionsResult(
        options: allOptions,
        errors: errors,
        hasStoreDelivery: false,
        hasCourierOptions: false,
      );
    }
  }

  /// Memilih opsi pengiriman terbaik berdasarkan preferensi
  static ShippingOptionItem? getBestShippingOption(
    List<ShippingOptionItem> options, {
    ShippingPreference preference = ShippingPreference.balanced,
  }) {
    if (options.isEmpty) return null;

    switch (preference) {
      case ShippingPreference.cheapest:
        // Pilih yang termurah
        options.sort((a, b) => a.cost.compareTo(b.cost));
        return options.first;

      case ShippingPreference.fastest:
        // Prioritaskan pengiriman toko karena lebih cepat
        final storeOptions = options.where((o) => o.type == ShippingType.store).toList();
        if (storeOptions.isNotEmpty) {
          return storeOptions.first;
        }
        // Jika tidak ada store delivery, pilih courier tercepat
        final courierOptions = options.where((o) => o.type == ShippingType.courier).toList();
        courierOptions.sort((a, b) => _compareEstimatedTime(a.estimatedTime, b.estimatedTime));
        return courierOptions.isNotEmpty ? courierOptions.first : null;

      case ShippingPreference.recommended:
        // Pilih yang recommended dulu
        final recommended = options.where((o) => o.isRecommended).toList();
        if (recommended.isNotEmpty) {
          recommended.sort((a, b) => a.cost.compareTo(b.cost));
          return recommended.first;
        }
        return options.first;

      case ShippingPreference.balanced:
      default:
        // Balance antara harga dan kecepatan, prioritaskan store delivery
        final storeOptions = options.where((o) => o.type == ShippingType.store).toList();
        if (storeOptions.isNotEmpty) {
          return storeOptions.first;
        }
        
        // Jika tidak ada store, pilih courier dengan harga sedang
        final courierOptions = options.where((o) => o.type == ShippingType.courier).toList();
        if (courierOptions.length <= 2) {
          return courierOptions.first;
        }
        
        courierOptions.sort((a, b) => a.cost.compareTo(b.cost));
        final midIndex = (courierOptions.length / 2).floor();
        return courierOptions[midIndex];
    }
  }

  /// Mendapatkan estimasi waktu pengiriman dalam format standar
  static DeliveryEstimate getDeliveryEstimate(ShippingOptionItem option) {
    if (option.type == ShippingType.store) {
      return DeliveryEstimate(
        minDays: 0,
        maxDays: 1,
        description: option.estimatedTime,
        isToday: option.estimatedTime.toLowerCase().contains('hari ini'),
      );
    }

    // Parse estimasi waktu dari courier
    final etd = option.estimatedTime.toLowerCase();
    if (etd.contains('1-2')) {
      return DeliveryEstimate(
        minDays: 1,
        maxDays: 2,
        description: option.estimatedTime,
        isToday: false,
      );
    } else if (etd.contains('2-3')) {
      return DeliveryEstimate(
        minDays: 2,
        maxDays: 3,
        description: option.estimatedTime,
        isToday: false,
      );
    } else if (etd.contains('3-4')) {
      return DeliveryEstimate(
        minDays: 3,
        maxDays: 4,
        description: option.estimatedTime,
        isToday: false,
      );
    }

    return DeliveryEstimate(
      minDays: 1,
      maxDays: 3,
      description: option.estimatedTime,
      isToday: false,
    );
  }

  /// Menghitung total biaya pengiriman termasuk asuransi dan biaya tambahan
  static ShippingCostBreakdown calculateTotalShippingCost(
    ShippingOptionItem option, {
    double? insuranceValue,
    bool addPackingCost = false,
  }) {
    int baseCost = option.cost;
    int insuranceCost = 0;
    int packingCost = 0;
    int adminCost = 0;

    // Hitung asuransi (1% dari nilai barang, min 5000, max 50000)
    if (insuranceValue != null && insuranceValue > 0) {
      insuranceCost = (insuranceValue * 0.01).round();
      if (insuranceCost < 5000) insuranceCost = 5000;
      if (insuranceCost > 50000) insuranceCost = 50000;
    }

    // Biaya packing untuk courier
    if (addPackingCost && option.type == ShippingType.courier) {
      packingCost = 2000; // Biaya packing standar
    }

    // Biaya admin untuk beberapa courier
    if (option.type == ShippingType.courier) {
      if (option.provider.toLowerCase().contains('jne') || 
          option.provider.toLowerCase().contains('tiki')) {
        adminCost = 1000;
      }
    }

    return ShippingCostBreakdown(
      baseCost: baseCost,
      insuranceCost: insuranceCost,
      packingCost: packingCost,
      adminCost: adminCost,
      totalCost: baseCost + insuranceCost + packingCost + adminCost,
    );
  }

  /// Validasi apakah pengiriman tersedia untuk alamat tertentu
  static Future<ShippingValidationResult> validateShippingToAddress(
    Address address,
    double totalWeight,
    double totalAmount,
  ) async {
    final List<String> errors = [];
    final List<String> warnings = [];

    // Validasi dasar alamat
    if (address.provinceName.isEmpty) {
      errors.add('Provinsi tidak boleh kosong');
    }
    
    if (address.cityName.isEmpty) {
      errors.add('Kota tidak boleh kosong');
    }

    if (address.detailAddress.isEmpty) {
      errors.add('Alamat detail tidak boleh kosong');
    }

    // Validasi berat
    if (totalWeight <= 0) {
      errors.add('Berat total tidak valid');
    } else if (totalWeight > 100000) { // 100kg
      errors.add('Berat total melebihi batas maksimal (100kg)');
    } else if (totalWeight > 50000) { // 50kg
      warnings.add('Berat total cukup besar, pastikan alamat mudah diakses');
    }

    // Validasi nilai pesanan
    if (totalAmount <= 0) {
      errors.add('Nilai pesanan tidak valid');
    } else if (totalAmount > 10000000) { // 10 juta
      warnings.add('Nilai pesanan tinggi, disarankan menggunakan asuransi');
    }

    // Validasi khusus untuk pengiriman toko
    bool storeDeliveryPossible = false;
    if (errors.isEmpty) {
      try {
        final storeAvailability = await StoreDeliveryService.checkAvailability(
          address: address,
          totalWeight: totalWeight,
          totalAmount: totalAmount,
        );
        storeDeliveryPossible = storeAvailability.isAvailable;
        
        if (!storeAvailability.isAvailable && storeAvailability.reason != null) {
          warnings.add('Pengiriman toko: ${storeAvailability.reason}');
        }
      } catch (e) {
        warnings.add('Tidak dapat mengecek ketersediaan pengiriman toko');
      }
    }

    // Validasi courier shipping
    bool courierShippingPossible = address.subdistrictId.isNotEmpty;
    if (!courierShippingPossible) {
      warnings.add('Data kecamatan tidak lengkap, opsi kurir mungkin terbatas');
    }

    return ShippingValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      hasStoreDelivery: storeDeliveryPossible,
      hasCourierShipping: courierShippingPossible,
    );
  }

  /// Mendapatkan rekomendasi pengiriman berdasarkan kondisi tertentu
  static List<ShippingRecommendation> getShippingRecommendations(
    List<ShippingOptionItem> options,
    double orderValue,
    bool isUrgent,
  ) {
    final recommendations = <ShippingRecommendation>[];

    // Rekomendasi berdasarkan nilai pesanan
    if (orderValue < 100000) {
      // Pesanan kecil - rekomendasikan yang murah
      final cheapest = getBestShippingOption(options, preference: ShippingPreference.cheapest);
      if (cheapest != null) {
        recommendations.add(ShippingRecommendation(
          option: cheapest,
          reason: 'Hemat biaya untuk pesanan dengan nilai rendah',
          priority: RecommendationPriority.high,
          savings: _calculateSavings(cheapest, options),
        ));
      }
    } else {
      // Pesanan besar - rekomendasikan asuransi
      final fastest = getBestShippingOption(options, preference: ShippingPreference.fastest);
      if (fastest != null) {
        recommendations.add(ShippingRecommendation(
          option: fastest,
          reason: 'Pengiriman cepat dan aman untuk nilai pesanan tinggi',
          priority: RecommendationPriority.high,
          addInsurance: true,
        ));
      }
    }

    // Rekomendasi berdasarkan urgensi
    if (isUrgent) {
      final storeDelivery = options.where((o) => o.type == ShippingType.store).firstOrNull;
      if (storeDelivery != null) {
        recommendations.add(ShippingRecommendation(
          option: storeDelivery,
          reason: 'Pengiriman tercepat untuk kebutuhan mendesak',
          priority: RecommendationPriority.urgent,
        ));
      }
    }

    // Rekomendasi pengiriman toko jika tersedia
    final storeOptions = options.where((o) => o.type == ShippingType.store && o.isRecommended).toList();
    for (final option in storeOptions) {
      if (!recommendations.any((r) => r.option.id == option.id)) {
        recommendations.add(ShippingRecommendation(
          option: option,
          reason: 'Pengiriman langsung dari toko dengan biaya terjangkau',
          priority: RecommendationPriority.medium,
        ));
      }
    }

    // Sort berdasarkan prioritas
    recommendations.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    return recommendations.take(3).toList(); // Maksimal 3 rekomendasi
  }

  /// Helper methods
  static int _compareEstimatedTime(String time1, String time2) {
    // Simplified comparison - prioritize "hari ini" over others
    if (time1.toLowerCase().contains('hari ini') && !time2.toLowerCase().contains('hari ini')) {
      return -1;
    }
    if (!time1.toLowerCase().contains('hari ini') && time2.toLowerCase().contains('hari ini')) {
      return 1;
    }
    return 0;
  }

  static double? _calculateSavings(ShippingOptionItem option, List<ShippingOptionItem> allOptions) {
    if (allOptions.length <= 1) return null;
    
    final costs = allOptions.map((o) => o.cost).toList()..sort();
    final maxCost = costs.last;
    final savings = maxCost - option.cost;
    
    return savings > 0 ? savings.toDouble() : null;
  }

  /// Mendapatkan informasi tambahan untuk opsi pengiriman
  static ShippingAdditionalInfo getAdditionalInfo(ShippingOptionItem option) {
    final features = <String>[];
    final restrictions = <String>[];

    if (option.type == ShippingType.store) {
      features.addAll([
        'Pengiriman langsung dari toko',
        'Dapat menghubungi toko langsung',
        'Biaya pengiriman terjangkau',
        'Tracking real-time',
      ]);
      
      restrictions.addAll([
        'Hanya untuk radius maksimal 10km',
        'Tergantung jam operasional toko',
      ]);
    } else {
      features.addAll([
        'Jangkauan pengiriman luas',
        'Tracking online tersedia',
        'Asuransi tersedia',
      ]);
      
      restrictions.addAll([
        'Waktu pengiriman lebih lama',
        'Biaya tambahan untuk asuransi',
      ]);

      // Tambahan berdasarkan provider
      if (option.provider.toLowerCase().contains('jne')) {
        features.add('Jaringan cabang luas');
      } else if (option.provider.toLowerCase().contains('jnt')) {
        features.add('Harga kompetitif');
      } else if (option.provider.toLowerCase().contains('sicepat')) {
        features.add('Pengiriman cepat');
      }
    }

    return ShippingAdditionalInfo(
      features: features,
      restrictions: restrictions,
      maxWeight: option.type == ShippingType.store ? 100 : 30, // kg
      maxValue: option.type == ShippingType.store ? 10000000 : 20000000, // rupiah
    );
  }
}

// Enums dan Models

enum ShippingType {
  store,
  courier,
}

enum ShippingPreference {
  cheapest,
  fastest,
  recommended,
  balanced,
}

enum RecommendationPriority {
  low,
  medium,
  high,
  urgent,
}

/// Model untuk opsi pengiriman yang sudah diintegrasikan
class ShippingOptionItem {
  final String id;
  final ShippingType type;
  final String name;
  final String description;
  final int cost;
  final String estimatedTime;
  final String provider;
  final bool isRecommended;
  final Map<String, dynamic> additionalInfo;

  ShippingOptionItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.cost,
    required this.estimatedTime,
    required this.provider,
    this.isRecommended = false,
    this.additionalInfo = const {},
  });

  String get formattedCost => 'Rp ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  
  String get typeLabel => type == ShippingType.store ? 'Pengiriman Toko' : 'Kurir Ekspedisi';
  
  bool get isStoreDelivery => type == ShippingType.store;
  
  Color get typeColor => type == ShippingType.store ? const Color(0xFF2E7D32) : Colors.blue;
  
  IconData get typeIcon => type == ShippingType.store ? Icons.store : Icons.local_shipping;
}

/// Model untuk hasil pencarian opsi pengiriman
class ShippingOptionsResult {
  final List<ShippingOptionItem> options;
  final List<String> errors;
  final bool hasStoreDelivery;
  final bool hasCourierOptions;

  ShippingOptionsResult({
    required this.options,
    required this.errors,
    required this.hasStoreDelivery,
    required this.hasCourierOptions,
  });

  bool get hasAnyOptions => options.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
  
  ShippingOptionItem? get recommendedOption => 
      options.where((o) => o.isRecommended).firstOrNull ?? options.firstOrNull;
  
  ShippingOptionItem? get cheapestOption {
    if (options.isEmpty) return null;
    return options.reduce((a, b) => a.cost < b.cost ? a : b);
  }
  
  List<ShippingOptionItem> get storeOptions => 
      options.where((o) => o.type == ShippingType.store).toList();
  
  List<ShippingOptionItem> get courierOptions => 
      options.where((o) => o.type == ShippingType.courier).toList();
}

/// Model untuk estimasi pengiriman
class DeliveryEstimate {
  final int minDays;
  final int maxDays;
  final String description;
  final bool isToday;

  DeliveryEstimate({
    required this.minDays,
    required this.maxDays,
    required this.description,
    required this.isToday,
  });

  String get daysRange {
    if (minDays == maxDays) {
      return '${minDays} hari';
    }
    return '$minDays-$maxDays hari';
  }
  
  String get displayText {
    if (isToday) return 'Hari ini';
    if (minDays == 0 && maxDays == 1) return 'Hari ini - Besok';
    return daysRange;
  }
}

/// Model untuk breakdown biaya pengiriman
class ShippingCostBreakdown {
  final int baseCost;
  final int insuranceCost;
  final int packingCost;
  final int adminCost;
  final int totalCost;

  ShippingCostBreakdown({
    required this.baseCost,
    required this.insuranceCost,
    required this.packingCost,
    required this.adminCost,
    required this.totalCost,
  });

  String get formattedBaseCost => _formatCurrency(baseCost);
  String get formattedInsuranceCost => _formatCurrency(insuranceCost);
  String get formattedPackingCost => _formatCurrency(packingCost);
  String get formattedAdminCost => _formatCurrency(adminCost);
  String get formattedTotalCost => _formatCurrency(totalCost);
  
  bool get hasAdditionalCosts => insuranceCost > 0 || packingCost > 0 || adminCost > 0;
  
  static String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}

/// Model untuk hasil validasi pengiriman
class ShippingValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final bool hasStoreDelivery;
  final bool hasCourierShipping;

  ShippingValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.hasStoreDelivery,
    required this.hasCourierShipping,
  });

  bool get hasAnyShipping => hasStoreDelivery || hasCourierShipping;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Model untuk rekomendasi pengiriman
class ShippingRecommendation {
  final ShippingOptionItem option;
  final String reason;
  final RecommendationPriority priority;
  final double? savings;
  final bool addInsurance;

  ShippingRecommendation({
    required this.option,
    required this.reason,
    required this.priority,
    this.savings,
    this.addInsurance = false,
  });

  String get priorityLabel {
    switch (priority) {
      case RecommendationPriority.urgent:
        return 'MENDESAK';
      case RecommendationPriority.high:
        return 'DIREKOMENDASIKAN';
      case RecommendationPriority.medium:
        return 'PILIHAN BAIK';
      case RecommendationPriority.low:
        return 'ALTERNATIF';
    }
  }
  
  Color get priorityColor {
    switch (priority) {
      case RecommendationPriority.urgent:
        return Colors.red;
      case RecommendationPriority.high:
        return Colors.green;
      case RecommendationPriority.medium:
        return Colors.orange;
      case RecommendationPriority.low:
        return Colors.grey;
    }
  }
  
  String? get savingsText => savings != null ? 'Hemat Rp ${savings!.toInt()}' : null;
}

/// Model untuk informasi tambahan pengiriman
class ShippingAdditionalInfo {
  final List<String> features;
  final List<String> restrictions;
  final double maxWeight;
  final double maxValue;

  ShippingAdditionalInfo({
    required this.features,
    required this.restrictions,
    required this.maxWeight,
    required this.maxValue,
  });
}

// Extension methods untuk kemudahan
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}