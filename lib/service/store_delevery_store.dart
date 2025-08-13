// lib/service/store_delivery_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toko_online_material/models/address_model.dart';
import 'package:toko_online_material/service/distance_service.dart';

class StoreDeliveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mengecek apakah pengiriman toko tersedia untuk alamat tertentu
  static Future<StoreDeliveryAvailability> checkAvailability({
    required Address address,
    required double totalWeight,
    required double totalAmount,
  }) async {
    try {
      // Ambil pengaturan pengiriman toko
      final settings = await _getStoreDeliverySettings();
      
      if (!settings.isEnabled) {
        return StoreDeliveryAvailability(
          isAvailable: false,
          reason: 'Pengiriman toko sedang tidak aktif',
        );
      }

      // Cek minimal pembelian
      if (totalAmount < settings.minOrderAmount) {
        return StoreDeliveryAvailability(
          isAvailable: false,
          reason: 'Minimal pembelian Rp ${_formatCurrency(settings.minOrderAmount.toDouble())}',
        );
      }

      // Cek berat maksimal
      if (settings.enableWeightValidation && totalWeight > settings.maxWeight) {
        return StoreDeliveryAvailability(
          isAvailable: false,
          reason: 'Berat melebihi maksimal ${settings.maxWeight} kg',
        );
      }

      // Hitung jarak ke alamat
      final distance = await DistanceService.calculateDistanceToAddress(
        address.fullAddress,
        address.cityName,
      );

      if (distance == null) {
        return StoreDeliveryAvailability(
          isAvailable: false,
          reason: 'Tidak dapat menghitung jarak ke alamat Anda',
        );
      }

      // Cek apakah dalam radius
      if (distance.distanceKm > settings.maxDeliveryRadius) {
        return StoreDeliveryAvailability(
          isAvailable: false,
          reason: 'Alamat di luar radius pengiriman (max ${settings.maxDeliveryRadius} km)',
        );
      }

      // Cek jam operasional jika hari ini
      final now = DateTime.now();
      if (!settings.allowWeekendDelivery && _isWeekend(now)) {
        return StoreDeliveryAvailability(
          isAvailable: false,
          reason: 'Pengiriman toko tidak tersedia di akhir pekan',
        );
      }

      // Hitung biaya dan estimasi
      final deliveryFee = _calculateDeliveryFee(distance.distanceKm, settings);
      final estimatedTime = _getDeliveryEstimation(distance.distanceKm, now);

      final option = StoreDeliveryOption(
        id: 'store_delivery_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Pengiriman Toko',
        description: 'Dikirim langsung oleh Toko Barokah',
        cost: deliveryFee,
        estimatedTime: estimatedTime,
        distance: distance,
        isAvailable: true,
      );

      return StoreDeliveryAvailability(
        isAvailable: true,
        option: option,
        settings: settings,
      );

    } catch (e) {
      print('Error checking store delivery availability: $e');
      return StoreDeliveryAvailability(
        isAvailable: false,
        reason: 'Terjadi kesalahan saat mengecek ketersediaan',
      );
    }
  }

  /// Membuat pesanan dengan pengiriman toko
  static Future<String> createStoreDeliveryOrder({
    required List<String> cartItemIds,
    required Address deliveryAddress,
    required StoreDeliveryOption deliveryOption,
    required double subtotal,
    String? notes,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');

      final orderData = {
        'orderId': _generateOrderId(),
        'userId': user.uid,
        'userEmail': user.email,
        'cartItemIds': cartItemIds,
        'deliveryType': 'store_delivery',
        'deliveryAddress': deliveryAddress.toFirestore(),
        'deliveryOption': deliveryOption.toMap(),
        'subtotal': subtotal,
        'deliveryFee': deliveryOption.cost,
        'total': subtotal + deliveryOption.cost,
        'notes': notes ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'estimatedDelivery': _calculateEstimatedDeliveryTime(deliveryOption),
      };

      final docRef = await _firestore.collection('orders').add(orderData);
      
      // Log aktivitas
      await _logDeliveryActivity(
        orderId: orderData['orderId'] as String,
        activity: 'Order dibuat dengan pengiriman toko',
        status: 'pending',
      );

      return docRef.id;

    } catch (e) {
      print('Error creating store delivery order: $e');
      throw Exception('Gagal membuat pesanan: $e');
    }
  }

  /// Update status pengiriman toko
  static Future<void> updateDeliveryStatus({
    required String orderId,
    required String status,
    String? notes,
    Map<String, dynamic>? trackingData,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (notes != null) updateData['statusNotes'] = notes;
      if (trackingData != null) updateData['trackingData'] = trackingData;

      // Update status pesanan
      await _firestore
          .collection('orders')
          .where('orderId', isEqualTo: orderId)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update(updateData);
        }
      });

      // Log aktivitas
      await _logDeliveryActivity(
        orderId: orderId,
        activity: _getActivityMessage(status, notes),
        status: status,
        additionalData: trackingData,
      );

    } catch (e) {
      print('Error updating delivery status: $e');
      throw Exception('Gagal mengupdate status pengiriman');
    }
  }

  /// Mendapatkan riwayat pengiriman
  static Future<List<DeliveryActivity>> getDeliveryHistory(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('delivery_activities')
          .where('orderId', isEqualTo: orderId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => DeliveryActivity.fromFirestore(doc.data()))
          .toList();

    } catch (e) {
      print('Error getting delivery history: $e');
      return [];
    }
  }

  /// Mendapatkan statistik pengiriman toko
  static Future<StoreDeliveryStats> getDeliveryStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      Query query = _firestore
          .collection('orders')
          .where('deliveryType', isEqualTo: 'store_delivery');

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }
      
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      
      int totalOrders = snapshot.docs.length;
      int deliveredOrders = 0;
      int pendingOrders = 0;
      int cancelledOrders = 0;
      double totalRevenue = 0;
      double totalDistance = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String;
        final total = (data['total'] ?? 0).toDouble();
        final distance = data['deliveryOption']?['distance']?['distanceKm']?.toDouble() ?? 0;

        switch (status) {
          case 'delivered':
            deliveredOrders++;
            totalRevenue += total;
            break;
          case 'pending':
          case 'confirmed':
          case 'preparing':
          case 'on_delivery':
            pendingOrders++;
            break;
          case 'cancelled':
            cancelledOrders++;
            break;
        }

        totalDistance += distance;
      }

      return StoreDeliveryStats(
        totalOrders: totalOrders,
        deliveredOrders: deliveredOrders,
        pendingOrders: pendingOrders,
        cancelledOrders: cancelledOrders,
        totalRevenue: totalRevenue,
        averageDistance: totalOrders > 0 ? totalDistance / totalOrders : 0,
        successRate: totalOrders > 0 ? (deliveredOrders / totalOrders) * 100 : 0,
      );

    } catch (e) {
      print('Error getting delivery stats: $e');
      return StoreDeliveryStats.empty();
    }
  }

  // Helper methods

  static Future<StoreDeliverySettings> _getStoreDeliverySettings() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('store_delivery')
          .get();

      if (doc.exists) {
        return StoreDeliverySettings.fromFirestore(doc.data()!);
      } else {
        return StoreDeliverySettings.defaultSettings();
      }
    } catch (e) {
      return StoreDeliverySettings.defaultSettings();
    }
  }

  static int _calculateDeliveryFee(double distance, StoreDeliverySettings settings) {
    return settings.baseFee + (distance * settings.feePerKm).round();
  }

  static String _getDeliveryEstimation(double distance, DateTime orderTime) {
    final hour = orderTime.hour;
    
    if (distance <= 3.0) {
      if (hour >= 7 && hour <= 12) {
        return 'Hari ini (2-4 jam)';
      } else {
        return 'Besok (pagi)';
      }
    } else if (distance <= 6.0) {
      if (hour >= 7 && hour <= 10) {
        return 'Hari ini (3-6 jam)';
      } else {
        return 'Besok (siang)';
      }
    } else {
      return 'Besok (1-2 hari)';
    }
  }

  static bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  static String _generateOrderId() {
    final now = DateTime.now();
    return 'TB${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.millisecondsSinceEpoch.toString().substring(8)}';
  }

  static DateTime _calculateEstimatedDeliveryTime(StoreDeliveryOption option) {
    final now = DateTime.now();
    
    if (option.distance.distanceKm <= 3.0) {
      return now.add(const Duration(hours: 3));
    } else if (option.distance.distanceKm <= 6.0) {
      return now.add(const Duration(hours: 5));
    } else {
      return now.add(const Duration(days: 1));
    }
  }

  static Future<void> _logDeliveryActivity({
    required String orderId,
    required String activity,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore.collection('delivery_activities').add({
        'orderId': orderId,
        'activity': activity,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      });
    } catch (e) {
      print('Error logging delivery activity: $e');
    }
  }

  static String _getActivityMessage(String status, String? notes) {
    switch (status) {
      case 'confirmed':
        return 'Pesanan dikonfirmasi dan sedang disiapkan';
      case 'preparing':
        return 'Pesanan sedang disiapkan untuk pengiriman';
      case 'on_delivery':
        return 'Pesanan dalam perjalanan ke alamat tujuan';
      case 'delivered':
        return 'Pesanan berhasil diterima pelanggan';
      case 'cancelled':
        return 'Pesanan dibatalkan${notes != null ? ': $notes' : ''}';
      default:
        return 'Status pesanan diupdate ke $status';
    }
  }

  static String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.',
    );
  }
}

// Models untuk Store Delivery

class StoreDeliveryAvailability {
  final bool isAvailable;
  final String? reason;
  final StoreDeliveryOption? option;
  final StoreDeliverySettings? settings;

  StoreDeliveryAvailability({
    required this.isAvailable,
    this.reason,
    this.option,
    this.settings,
  });
}

class StoreDeliveryOption {
  final String id;
  final String name;
  final String description;
  final int cost;
  final String estimatedTime;
  final DistanceResult distance;
  final bool isAvailable;

  StoreDeliveryOption({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.estimatedTime,
    required this.distance,
    this.isAvailable = true,
  });

  String get formattedCost => 'Rp ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  
  String get fullDescription => '$description • ${distance.distanceText} • $estimatedTime';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cost': cost,
      'estimatedTime': estimatedTime,
      'distance': {
        'distanceKm': distance.distanceKm,
        'distanceText': distance.distanceText,
        'durationText': distance.durationText,
        'durationMinutes': distance.durationMinutes,
        'isEstimate': distance.isEstimate,
      },
      'isAvailable': isAvailable,
    };
  }

  factory StoreDeliveryOption.fromMap(Map<String, dynamic> map) {
    return StoreDeliveryOption(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      cost: map['cost'] ?? 0,
      estimatedTime: map['estimatedTime'] ?? '',
      distance: DistanceResult(
        distanceKm: (map['distance']?['distanceKm'] ?? 0).toDouble(),
        distanceText: map['distance']?['distanceText'] ?? '',
        durationText: map['distance']?['durationText'] ?? '',
        durationMinutes: (map['distance']?['durationMinutes'] ?? 0).toDouble(),
        isEstimate: map['distance']?['isEstimate'] ?? false,
      ),
      isAvailable: map['isAvailable'] ?? true,
    );
  }
}

class DeliveryActivity {
  final String orderId;
  final String activity;
  final String status;
  final DateTime timestamp;
  final Map<String, dynamic> additionalData;

  DeliveryActivity({
    required this.orderId,
    required this.activity,
    required this.status,
    required this.timestamp,
    this.additionalData = const {},
  });

  factory DeliveryActivity.fromFirestore(Map<String, dynamic> data) {
    return DeliveryActivity(
      orderId: data['orderId'] ?? '',
      activity: data['activity'] ?? '',
      status: data['status'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      additionalData: data['additionalData'] ?? {},
    );
  }
}

class StoreDeliveryStats {
  final int totalOrders;
  final int deliveredOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final double totalRevenue;
  final double averageDistance;
  final double successRate;

  StoreDeliveryStats({
    required this.totalOrders,
    required this.deliveredOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.totalRevenue,
    required this.averageDistance,
    required this.successRate,
  });

  factory StoreDeliveryStats.empty() {
    return StoreDeliveryStats(
      totalOrders: 0,
      deliveredOrders: 0,
      pendingOrders: 0,
      cancelledOrders: 0,
      totalRevenue: 0,
      averageDistance: 0,
      successRate: 0,
    );
  }
}

class StoreDeliverySettings {
  final bool isEnabled;
  final double maxDeliveryRadius;
  final int baseFee;
  final int feePerKm;
  final int minOrderAmount;
  final double maxWeight;
  final bool enableWeightValidation;
  final bool allowWeekendDelivery;
  final OperatingHours operatingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoreDeliverySettings({
    required this.isEnabled,
    required this.maxDeliveryRadius,
    required this.baseFee,
    required this.feePerKm,
    required this.minOrderAmount,
    required this.maxWeight,
    required this.enableWeightValidation,
    required this.allowWeekendDelivery,
    required this.operatingHours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreDeliverySettings.defaultSettings() {
    return StoreDeliverySettings(
      isEnabled: true,
      maxDeliveryRadius: 10.0,
      baseFee: 5000,
      feePerKm: 2000,
      minOrderAmount: 50000,
      maxWeight: 100.0,
      enableWeightValidation: true,
      allowWeekendDelivery: false,
      operatingHours: OperatingHours(start: '07:00', end: '17:00'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory StoreDeliverySettings.fromFirestore(Map<String, dynamic> data) {
    return StoreDeliverySettings(
      isEnabled: data['isEnabled'] ?? true,
      maxDeliveryRadius: (data['maxDeliveryRadius'] ?? 10.0).toDouble(),
      baseFee: data['baseFee'] ?? 5000,
      feePerKm: data['feePerKm'] ?? 2000,
      minOrderAmount: data['minOrderAmount'] ?? 50000,
      maxWeight: (data['maxWeight'] ?? 100.0).toDouble(),
      enableWeightValidation: data['enableWeightValidation'] ?? true,
      allowWeekendDelivery: data['allowWeekendDelivery'] ?? false,
      operatingHours: OperatingHours.fromMap(data['operatingHours'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  StoreDeliverySettings copyWith({
    bool? isEnabled,
    double? maxDeliveryRadius,
    int? baseFee,
    int? feePerKm,
    int? minOrderAmount,
    double? maxWeight,
    bool? enableWeightValidation,
    bool? allowWeekendDelivery,
    OperatingHours? operatingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreDeliverySettings(
      isEnabled: isEnabled ?? this.isEnabled,
      maxDeliveryRadius: maxDeliveryRadius ?? this.maxDeliveryRadius,
      baseFee: baseFee ?? this.baseFee,
      feePerKm: feePerKm ?? this.feePerKm,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxWeight: maxWeight ?? this.maxWeight,
      enableWeightValidation: enableWeightValidation ?? this.enableWeightValidation,
      allowWeekendDelivery: allowWeekendDelivery ?? this.allowWeekendDelivery,
      operatingHours: operatingHours ?? this.operatingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class OperatingHours {
  final String start;
  final String end;

  OperatingHours({required this.start, required this.end});

  factory OperatingHours.fromMap(Map<String, dynamic> data) {
    return OperatingHours(
      start: data['start'] ?? '07:00',
      end: data['end'] ?? '17:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
    };
  }
}