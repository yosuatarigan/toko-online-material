// lib/models/order.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  waitingPayment,
  processing,
  shipping,
  delivered,
  cancelled
}

enum PaymentStatus {
  pending,
  waitingConfirmation,
  confirmed,
  failed
}

class Order {
  final String id;
  final String userId;
  final String userEmail;
  final List<OrderItem> items;
  final OrderAddress address;
  final OrderShipping shipping;
  final OrderSummary summary;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentProofUrl;
  final String? adminNotes;
  final String? trackingNumber;
  final String? shipmentProofUrl;
  final String? shippingNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.items,
    required this.address,
    required this.shipping,
    required this.summary,
    required this.status,
    required this.paymentStatus,
    this.paymentProofUrl,
    this.adminNotes,
    this.trackingNumber,
    this.shipmentProofUrl,
    this.shippingNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Order(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      items: (data['items'] as List<dynamic>)
          .map((item) => OrderItem.fromMap(item))
          .toList(),
      address: OrderAddress.fromMap(data['address']),
      shipping: OrderShipping.fromMap(data['shipping']),
      summary: OrderSummary.fromMap(data['summary']),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == data['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentProofUrl: data['paymentProofUrl'],
      adminNotes: data['adminNotes'],
      trackingNumber: data['trackingNumber'],
      shipmentProofUrl: data['shipmentProofUrl'],
      shippingNotes: data['shippingNotes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'address': address.toMap(),
      'shipping': shipping.toMap(),
      'summary': summary.toMap(),
      'status': status.name,
      'paymentStatus': paymentStatus.name,
      'paymentProofUrl': paymentProofUrl,
      'adminNotes': adminNotes,
      'trackingNumber': trackingNumber,
      'shipmentProofUrl': shipmentProofUrl,
      'shippingNotes': shippingNotes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'Menunggu';
      case OrderStatus.waitingPayment:
        return 'Menunggu Pembayaran';
      case OrderStatus.processing:
        return 'Diproses';
      case OrderStatus.shipping:
        return 'Dikirim';
      case OrderStatus.delivered:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  String get paymentStatusText {
    switch (paymentStatus) {
      case PaymentStatus.pending:
        return 'Belum Dibayar';
      case PaymentStatus.waitingConfirmation:
        return 'Menunggu Konfirmasi';
      case PaymentStatus.confirmed:
        return 'Terkonfirmasi';
      case PaymentStatus.failed:
        return 'Gagal';
    }
  }

  String get orderNumber => 'TB${createdAt.millisecondsSinceEpoch.toString().substring(7)}';

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  // Shipping type detection
  bool get isStoreDelivery => shipping.courierName.toLowerCase().contains('toko barokah');
  bool get isExpedisiDelivery => !isStoreDelivery;

  // Tracking URL generation
  String? get trackingUrl {
    if (trackingNumber == null || isStoreDelivery) return null;
    
    // Import ShippingUtils and use it for more accurate URL generation
    return _generateTrackingUrl(shipping.courierName, trackingNumber!);
  }

  String? _generateTrackingUrl(String courierName, String trackingNumber) {
    final courier = courierName.toLowerCase();
    if (courier.contains('jne')) {
      return 'https://www.jne.co.id/id/tracking/trace';
    } else if (courier.contains('tiki')) {
      return 'https://www.tiki.id/tracking';
    } else if (courier.contains('pos')) {
      return 'https://www.posindonesia.co.id/id/tracking';
    } else if (courier.contains('j&t') || courier.contains('jnt')) {
      return 'https://www.jet.co.id/track';
    }
    return null;
  }

  // Shipping status text
  String get shippingStatusText {
    if (isStoreDelivery) {
      if (shipmentProofUrl != null) {
        return 'Sedang Dikirim Toko';
      }
      return 'Sedang Disiapkan';
    } else {
      if (trackingNumber != null) {
        return 'Diserahkan ke Kurir';
      }
      return 'Sedang Disiapkan';
    }
  }

  // Check if shipping info is complete
  bool get hasShippingInfo {
    if (isStoreDelivery) {
      return shipmentProofUrl != null;
    } else {
      return trackingNumber != null;
    }
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final double price;
  final int quantity;
  final String unit;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    required this.price,
    required this.quantity,
    required this.unit,
    this.imageUrl,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      variantId: map['variantId'],
      variantName: map['variantName'],
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'variantId': variantId,
      'variantName': variantName,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'imageUrl': imageUrl,
    };
  }

  double get totalPrice => price * quantity;
  String get displayName => variantName != null ? '$productName ($variantName)' : productName;
}

class OrderAddress {
  final String label;
  final String recipientName;
  final String phone;
  final String fullAddress;
  final String cityName;

  OrderAddress({
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    required this.cityName,
  });

  factory OrderAddress.fromMap(Map<String, dynamic> map) {
    return OrderAddress(
      label: map['label'] ?? '',
      recipientName: map['recipientName'] ?? '',
      phone: map['phone'] ?? '',
      fullAddress: map['fullAddress'] ?? '',
      cityName: map['cityName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'recipientName': recipientName,
      'phone': phone,
      'fullAddress': fullAddress,
      'cityName': cityName,
    };
  }
}

class OrderShipping {
  final String courierName;
  final String serviceName;
  final String description;
  final double cost;
  final String etd;

  OrderShipping({
    required this.courierName,
    required this.serviceName,
    required this.description,
    required this.cost,
    required this.etd,
  });

  factory OrderShipping.fromMap(Map<String, dynamic> map) {
    return OrderShipping(
      courierName: map['courierName'] ?? '',
      serviceName: map['serviceName'] ?? '',
      description: map['description'] ?? '',
      cost: (map['cost'] ?? 0).toDouble(),
      etd: map['etd'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courierName': courierName,
      'serviceName': serviceName,
      'description': description,
      'cost': cost,
      'etd': etd,
    };
  }
}

class OrderSummary {
  final double subtotal;
  final double shippingCost;
  final double discount;
  final double total;

  OrderSummary({
    required this.subtotal,
    required this.shippingCost,
    required this.discount,
    required this.total,
  });

  factory OrderSummary.fromMap(Map<String, dynamic> map) {
    return OrderSummary(
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      shippingCost: (map['shippingCost'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subtotal': subtotal,
      'shippingCost': shippingCost,
      'discount': discount,
      'total': total,
    };
  }
}