// lib/service/order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:toko_online_material/models/order_model.dart';

class OrderService extends ChangeNotifier {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create new order
  Future<String?> createOrder(Order order) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final docRef = await _firestore.collection('orders').add(order.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating order: $e');
      }
      rethrow;
    }
  }

  // Upload payment proof
  Future<String> uploadPaymentProof(String orderId, File imageFile) async {
    try {
      final fileName = 'payment_proofs/${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading payment proof: $e');
      }
      rethrow;
    }
  }

  // Update order with payment proof
  Future<void> updateOrderPaymentProof(String orderId, String paymentProofUrl) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentProofUrl': paymentProofUrl,
        'paymentStatus': PaymentStatus.waitingConfirmation.name,
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating payment proof: $e');
      }
      rethrow;
    }
  }

  // Get user orders stream
  Stream<List<Order>> getUserOrdersStream({OrderStatus? status}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    firestore.Query query = _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    });
  }

  // Get all orders stream (for admin)
  Stream<List<Order>> getAllOrdersStream({
    OrderStatus? status,
    PaymentStatus? paymentStatus,
  }) {
    firestore.Query query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (paymentStatus != null) {
      query = query.where('paymentStatus', isEqualTo: paymentStatus.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    });
  }

  // Get orders waiting for payment confirmation count
  Stream<int> getWaitingConfirmationCount() {
    return _firestore
        .collection('orders')
        .where('paymentStatus', isEqualTo: PaymentStatus.waitingConfirmation.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Admin: Confirm payment
  Future<void> confirmPayment(String orderId, bool approved, {String? notes}) async {
    try {
      final updateData = <String, dynamic>{
        'paymentStatus': approved ? PaymentStatus.confirmed.name : PaymentStatus.failed.name,
        'status': approved ? OrderStatus.processing.name : OrderStatus.cancelled.name,
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      };

      if (notes != null && notes.isNotEmpty) {
        updateData['adminNotes'] = notes;
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);
    } catch (e) {
      if (kDebugMode) {
        print('Error confirming payment: $e');
      }
      rethrow;
    }
  }

  // Admin: Update order status
  Future<void> updateOrderStatus(
    String orderId, 
    OrderStatus status, {
    String? adminNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      };

      if (adminNotes != null) {
        updateData['adminNotes'] = adminNotes;
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating order status: $e');
      }
      rethrow;
    }
  }

  // Get order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return Order.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting order: $e');
      }
      return null;
    }
  }

  // Get order statistics for admin dashboard
  Future<Map<String, int>> getOrderStatistics() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Today's orders count
      final todayOrders = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: firestore.Timestamp.fromDate(startOfDay))
          .get();

      // Waiting confirmation count
      final waitingConfirmation = await _firestore
          .collection('orders')
          .where('paymentStatus', isEqualTo: PaymentStatus.waitingConfirmation.name)
          .get();

      // Processing orders count
      final processing = await _firestore
          .collection('orders')
          .where('status', isEqualTo: OrderStatus.processing.name)
          .get();

      // Shipping orders count
      final shipping = await _firestore
          .collection('orders')
          .where('status', isEqualTo: OrderStatus.shipping.name)
          .get();

      return {
        'todayOrders': todayOrders.docs.length,
        'waitingConfirmation': waitingConfirmation.docs.length,
        'processing': processing.docs.length,
        'shipping': shipping.docs.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting order statistics: $e');
      }
      return {
        'todayOrders': 0,
        'waitingConfirmation': 0,
        'processing': 0,
        'shipping': 0,
      };
    }
  }

  // Calculate today's revenue
  Future<double> getTodayRevenue() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final todayOrders = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: firestore.Timestamp.fromDate(startOfDay))
          .where('paymentStatus', isEqualTo: PaymentStatus.confirmed.name)
          .get();

      double totalRevenue = 0;
      for (final doc in todayOrders.docs) {
        final data = doc.data();
        final summary = data['summary'] as Map<String, dynamic>;
        totalRevenue += (summary['total'] ?? 0).toDouble();
      }

      return totalRevenue;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating revenue: $e');
      }
      return 0;
    }
  }

  // Delete order (if needed)
  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting order: $e');
      }
      rethrow;
    }
  }

  // Admin: Update shipping information
  Future<void> updateShippingInfo(
    String orderId,
    String? trackingNumber,
    String? shipmentProofUrl,
    String? shippingNotes,
  ) async {
    try {
      final updateData = <String, dynamic>{
        'status': OrderStatus.shipping.name,
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      };

      if (trackingNumber != null && trackingNumber.isNotEmpty) {
        updateData['trackingNumber'] = trackingNumber.trim();
      }

      if (shipmentProofUrl != null) {
        updateData['shipmentProofUrl'] = shipmentProofUrl;
      }

      if (shippingNotes != null && shippingNotes.isNotEmpty) {
        updateData['shippingNotes'] = shippingNotes.trim();
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating shipping info: $e');
      }
      rethrow;
    }
  }

  // Upload shipment proof image
  Future<String> uploadShipmentProof(String orderId, File imageFile) async {
    try {
      final fileName = 'shipment_proofs/${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading shipment proof: $e');
      }
      rethrow;
    }
  }

  // Get orders that need shipping action (for admin)
  Stream<List<Order>> getOrdersNeedingShipping() {
    return _firestore
        .collection('orders')
        .where('paymentStatus', isEqualTo: PaymentStatus.confirmed.name)
        .where('status', isEqualTo: OrderStatus.processing.name)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    });
  }

  // Get shipped orders count for admin dashboard
  Future<int> getShippedOrdersCount() async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: OrderStatus.shipping.name)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting shipped orders count: $e');
      }
      return 0;
    }
  }

  // Cancel order (user action)
  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.cancelled.name,
        'adminNotes': 'Dibatalkan oleh pelanggan. Alasan: $reason',
        'updatedAt': firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling order: $e');
      }
      rethrow;
    }
  }
}