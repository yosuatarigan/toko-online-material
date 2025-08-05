import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toko_online_material/models/cartitem.dart';
import '../models/address.dart';

class ShippingService {
  static const String _baseUrl = 'https://api.rajaongkir.com/starter';
  static const String _apiKey =
      'Tx8rT8Lzec5688c093359dc67ZEIc60e'; // Ganti dengan API key Anda

  // Origin city untuk Toko Barokah (Lamongan)
  static const String _originCityId = '272'; // City ID untuk Lamongan

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===== RAJA ONGKIR API METHODS =====

  Future<List<Province>> getProvinces() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/province'),
        headers: {'key': _apiKey, 'content-type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['rajaongkir']['status']['code'] == 200) {
          final provinces = data['rajaongkir']['results'] as List;
          return provinces.map((p) => Province.fromJson(p)).toList();
        }
      }
      throw Exception('Failed to load provinces');
    } catch (e) {
      throw Exception('Error fetching provinces: $e');
    }
  }

  Future<List<City>> getCities(String provinceId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/city?province=$provinceId'),
        headers: {'key': _apiKey, 'content-type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['rajaongkir']['status']['code'] == 200) {
          final cities = data['rajaongkir']['results'] as List;
          return cities.map((c) => City.fromJson(c)).toList();
        }
      }
      throw Exception('Failed to load cities');
    } catch (e) {
      throw Exception('Error fetching cities: $e');
    }
  }

  Future<List<CourierOption>> getShippingCost({
    required String destinationCityId,
    required int weight, // dalam gram
    required String courier, // jne, pos, tiki
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cost'),
        headers: {
          'key': _apiKey,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: {
          'origin': _originCityId,
          'destination': destinationCityId,
          'weight': weight.toString(),
          'courier': courier,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['rajaongkir']['status']['code'] == 200) {
          final results = data['rajaongkir']['results'] as List;
          return results.map((r) => CourierOption.fromJson(r)).toList();
        }
      }
      throw Exception('Failed to get shipping cost');
    } catch (e) {
      throw Exception('Error getting shipping cost: $e');
    }
  }

  Future<Map<String, List<CourierOption>>> getAllShippingOptions({
    required String destinationCityId,
    required int weight,
  }) async {
    final couriers = ['jne', 'pos', 'tiki'];
    final Map<String, List<CourierOption>> results = {};

    for (String courier in couriers) {
      try {
        final options = await getShippingCost(
          destinationCityId: destinationCityId,
          weight: weight,
          courier: courier,
        );
        results[courier] = options;
      } catch (e) {
        print('Error getting $courier shipping cost: $e');
        results[courier] = [];
      }
    }

    return results;
  }

  // ===== ADDRESS MANAGEMENT METHODS =====

  Stream<List<UserAddress>> getUserAddresses() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('user_addresses')
        .where('userId', isEqualTo: user.uid)
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => UserAddress.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<UserAddress?> getDefaultAddress() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final query =
          await _firestore
              .collection('user_addresses')
              .where('userId', isEqualTo: user.uid)
              .where('isDefault', isEqualTo: true)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        return UserAddress.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting default address: $e');
      return null;
    }
  }

  Future<String> addAddress(UserAddress address) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // If this is the first address or marked as default, make it default
      final existingAddresses =
          await _firestore
              .collection('user_addresses')
              .where('userId', isEqualTo: user.uid)
              .get();

      bool shouldBeDefault =
          address.isDefault || existingAddresses.docs.isEmpty;

      // If setting as default, unset other default addresses
      if (shouldBeDefault) {
        await _unsetOtherDefaults(user.uid);
      }

      final addressToAdd = address.copyWith(
        userId: user.uid,
        isDefault: shouldBeDefault,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('user_addresses')
          .add(addressToAdd.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add address: $e');
    }
  }

  Future<void> updateAddress(String addressId, UserAddress address) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // If setting as default, unset other default addresses
      if (address.isDefault) {
        await _unsetOtherDefaults(user.uid, excludeId: addressId);
      }

      final updatedAddress = address.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection('user_addresses')
          .doc(addressId)
          .update(updatedAddress.toFirestore());
    } catch (e) {
      throw Exception('Failed to update address: $e');
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      await _firestore.collection('user_addresses').doc(addressId).delete();
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Unset all other default addresses
      await _unsetOtherDefaults(user.uid, excludeId: addressId);

      // Set this address as default
      await _firestore.collection('user_addresses').doc(addressId).update({
        'isDefault': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to set default address: $e');
    }
  }

  Future<void> _unsetOtherDefaults(String userId, {String? excludeId}) async {
    final query = _firestore
        .collection('user_addresses')
        .where('userId', isEqualTo: userId)
        .where('isDefault', isEqualTo: true);

    final docs = await query.get();

    final batch = _firestore.batch();
    for (final doc in docs.docs) {
      if (excludeId == null || doc.id != excludeId) {
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // ===== UTILITY METHODS =====

  int calculateTotalWeight(List<dynamic> cartItems) {
    double totalKg = 0;

    for (final item in cartItems) {
      // Gunakan totalWeight dari CartItem yang sudah include quantity
      if (item is CartItem) {
        totalKg += item.totalWeight;
      } else {
        // Fallback untuk dynamic items (jika ada)
        final weight = item.weight ?? 1.0;
        final quantity = item.quantity ?? 1;
        totalKg += (weight * quantity);
      }
    }

    // Convert to grams (minimum 1000g for Raja Ongkir)
    int totalGrams = (totalKg * 1000).round();
    return totalGrams < 1000 ? 1000 : totalGrams;
  }

  int calculateCartWeight(List<CartItem> cartItems) {
    double totalKg = cartItems.fold(0.0, (sum, item) => sum + item.totalWeight);

    // Convert to grams (minimum 1000g for Raja Ongkir)
    int totalGrams = (totalKg * 1000).round();
    return totalGrams < 1000 ? 1000 : totalGrams;
  }

  String formatWeight(int weightInGrams) {
    if (weightInGrams < 1000) {
      return '${weightInGrams}g';
    } else {
      double kg = weightInGrams / 1000;
      return '${kg.toStringAsFixed(1)}kg';
    }
  }

  // Check if address is complete for shipping calculation
  bool isAddressComplete(UserAddress address) {
    return address.cityId.isNotEmpty &&
        address.recipientName.isNotEmpty &&
        address.recipientPhone.isNotEmpty &&
        address.fullAddress.isNotEmpty;
  }

  // Get available courier names
  List<String> getAvailableCouriers() {
    return ['JNE', 'POS Indonesia', 'TIKI'];
  }

  Map<String, String> getCourierCodes() {
    return {'JNE': 'jne', 'POS Indonesia': 'pos', 'TIKI': 'tiki'};
  }
}
