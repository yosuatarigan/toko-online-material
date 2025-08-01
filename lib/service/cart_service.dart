import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toko_online_material/models/cartitem.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _lastError;

  // Getters
  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  
  // Cart summary
  CartSummary get summary => CartSummary.fromItems(_items);
  
  // Quick access properties
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  // Storage keys
  static const String _localCartKey = 'local_cart_items';
  static const String _cartCollection = 'user_carts';

  // Initialize cart service
  Future<void> initialize() async {
    await _loadCartFromLocal();
    
    // Sync with Firebase if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _syncWithFirebase();
    }
  }

  // Enhanced add item method with new variant system support
  Future<bool> addItem(
    Product product, {
    int quantity = 1,
    String? variantId, // Now this is the combination ID
    String? variantName, // Display name for the combination
    double variantPriceAdjustment = 0,
    String? variantSku,
    Map<String, dynamic>? variantAttributes,
    int? variantStock,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Validate product
      if (!product.isActive || (product.totalStock <= 0)) {
        _setError('Produk tidak tersedia');
        return false;
      }

      // For products with variants, validate variant combination
      if (product.hasVariants && variantId == null) {
        _setError('Silakan pilih varian produk');
        return false;
      }

      // Get variant combination details if product has variants
      ProductVariantCombination? variantCombination;
      if (product.hasVariants && variantId != null) {
        final combinations = product.getVariantCombinations();
        try {
          variantCombination = combinations.firstWhere((c) => c.id == variantId);
        } catch (e) {
          _setError('Varian tidak ditemukan');
          return false;
        }

        if (!variantCombination.isActive || variantCombination.stock <= 0) {
          _setError('Varian tidak tersedia');
          return false;
        }
      }

      // Determine available stock and other details
      final availableStock = variantCombination?.stock ?? product.stock;
      final finalVariantName = variantCombination != null 
          ? _getCombinationDisplayName(product, variantCombination)
          : variantName;
      final finalVariantSku = variantCombination?.sku ?? variantSku;
      final finalPriceAdjustment = variantCombination?.priceAdjustment ?? variantPriceAdjustment;

      if (availableStock <= 0) {
        _setError('Stok tidak tersedia');
        return false;
      }

      // Create unique identifier for the item (product + variant combination)
      final itemKey = _getItemKey(product.id, variantId);
      
      // Check if item already exists in cart
      final existingIndex = _items.indexWhere((item) => 
          _getItemKey(item.productId, item.variantId) == itemKey);
      
      if (existingIndex != -1) {
        // Update existing item quantity
        final existingItem = _items[existingIndex];
        final newQuantity = existingItem.quantity + quantity;
        
        // Check stock limit
        if (newQuantity > availableStock) {
          _setError('Stok tidak mencukupi. Maksimal $availableStock ${product.unit}');
          return false;
        }
        
        _items[existingIndex] = existingItem.copyWith(quantity: newQuantity);
      } else {
        // Add new item
        if (quantity > availableStock) {
          _setError('Stok tidak mencukupi. Maksimal $availableStock ${product.unit}');
          return false;
        }
        
        final cartItem = CartItem.fromProduct(
          product,
          quantity: quantity,
          variantId: variantId,
          variantName: finalVariantName,
          variantPriceAdjustment: finalPriceAdjustment,
          variantSku: finalVariantSku,
          variantAttributes: variantCombination?.attributes,
          variantStock: availableStock,
        );
        _items.add(cartItem);
      }

      await _saveCartToLocal();
      await _syncWithFirebase();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Gagal menambahkan item ke keranjang: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Helper method to get combination display name
  String _getCombinationDisplayName(Product product, ProductVariantCombination combination) {
    final attributes = product.getVariantAttributes();
    List<String> parts = [];
    
    for (String attributeId in combination.attributes.keys) {
      final attribute = attributes.firstWhere(
        (attr) => attr.id == attributeId,
        orElse: () => VariantAttribute(id: '', name: '', options: []),
      );
      if (attribute.id.isNotEmpty) {
        final optionValue = combination.attributes[attributeId]!;
        parts.add(optionValue);
      }
    }
    return parts.join(' - ');
  }

  // Generate unique key for item (product + variant)
  String _getItemKey(String productId, String? variantId) {
    return '${productId}_${variantId ?? 'default'}';
  }

  // Remove item from cart
  Future<bool> removeItem(String itemId) async {
    try {
      _setLoading(true);
      _clearError();

      _items.removeWhere((item) => item.id == itemId);
      
      await _saveCartToLocal();
      await _syncWithFirebase();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Gagal menghapus item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update item quantity
  Future<bool> updateQuantity(String itemId, int newQuantity) async {
    try {
      _setLoading(true);
      _clearError();

      if (newQuantity <= 0) {
        return await removeItem(itemId);
      }

      final itemIndex = _items.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) {
        _setError('Item tidak ditemukan');
        return false;
      }

      final item = _items[itemIndex];
      
      // Check stock limit
      if (newQuantity > item.maxStock) {
        _setError('Stok tidak mencukupi. Maksimal ${item.maxStock} ${item.productUnit}');
        return false;
      }

      _items[itemIndex] = item.copyWith(quantity: newQuantity);
      
      await _saveCartToLocal();
      await _syncWithFirebase();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Gagal mengupdate jumlah: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Clear cart
  Future<bool> clearCart() async {
    try {
      _setLoading(true);
      _clearError();

      _items.clear();
      
      await _saveCartToLocal();
      await _syncWithFirebase();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Gagal mengosongkan keranjang: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get item by product ID and variant ID
  CartItem? getItem(String productId, {String? variantId}) {
    try {
      return _items.firstWhere((item) => 
          item.productId == productId && 
          item.variantId == variantId);
    } catch (e) {
      return null;
    }
  }

  // Check if product/variant combination is in cart
  bool isInCart(String productId, {String? variantId}) {
    return _items.any((item) => 
        item.productId == productId && 
        item.variantId == variantId);
  }

  // Get quantity of product/variant in cart
  int getQuantity(String productId, {String? variantId}) {
    final item = getItem(productId, variantId: variantId);
    return item?.quantity ?? 0;
  }

  // Get all variants of a product in cart
  List<CartItem> getProductVariants(String productId) {
    return _items.where((item) => item.productId == productId).toList();
  }

  // Enhanced validate cart items with new variant system
  Future<List<String>> validateCart() async {
    final issues = <String>[];
    
    for (final item in _items) {
      try {
        // Get latest product data from Firestore
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(item.productId)
            .get();
        
        if (!productDoc.exists) {
          issues.add('${item.displayName} tidak lagi tersedia');
          continue;
        }
        
        final product = Product.fromFirestore(productDoc);
        
        if (!product.isActive) {
          issues.add('${item.displayName} sedang tidak aktif');
          continue;
        }

        // Check variant-specific stock if applicable (new system)
        if (item.hasVariant && product.hasVariants) {
          final combinations = product.getVariantCombinations();
          
          try {
            final combination = combinations.firstWhere((c) => c.id == item.variantId);
            
            if (!combination.isActive) {
              issues.add('Varian ${item.variantName} dari ${item.productName} tidak lagi tersedia');
              continue;
            }

            if (combination.stock <= 0) {
              issues.add('${item.displayName} stok habis');
            } else if (item.quantity > combination.stock) {
              issues.add('${item.displayName} stok hanya tersisa ${combination.stock} ${product.unit}');
            }
          } catch (e) {
            issues.add('Varian ${item.variantName} dari ${item.productName} tidak lagi tersedia');
            continue;
          }
        } else {
          // Check regular product stock
          if (product.isOutOfStock) {
            issues.add('${item.displayName} stok habis');
          } else if (item.quantity > product.totalStock) {
            issues.add('${item.displayName} stok hanya tersisa ${product.totalStock} ${product.unit}');
          }
        }
      } catch (e) {
        issues.add('Gagal memeriksa ${item.displayName}');
      }
    }
    
    return issues;
  }

  // Load cart from local storage
  Future<void> _loadCartFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_localCartKey);
      
      if (cartJson != null) {
        final cartData = jsonDecode(cartJson) as List;
        _items = cartData.map((item) => CartItem.fromMap(item)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cart from local: $e');
      }
    }
  }

  // Save cart to local storage
  Future<void> _saveCartToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _items.map((item) => item.toMap()).toList();
      await prefs.setString(_localCartKey, jsonEncode(cartData));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving cart to local: $e');
      }
    }
  }

  // Sync cart with Firebase
  Future<void> _syncWithFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final cartData = _items.map((item) => item.toMap()).toList();
      
      await FirebaseFirestore.instance
          .collection(_cartCollection)
          .doc(user.uid)
          .set({
        'items': cartData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing cart with Firebase: $e');
      }
    }
  }

  // Load cart from Firebase
  Future<void> loadCartFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _setLoading(true);

      final cartDoc = await FirebaseFirestore.instance
          .collection(_cartCollection)
          .doc(user.uid)
          .get();

      if (cartDoc.exists) {
        final data = cartDoc.data();
        if (data != null && data['items'] != null) {
          final itemsData = data['items'] as List;
          _items = itemsData.map((item) => CartItem.fromMap(item)).toList();
          
          await _saveCartToLocal();
          notifyListeners();
        }
      }
    } catch (e) {
      _setError('Gagal memuat keranjang dari server: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Merge local cart with Firebase cart (after login)
  Future<void> mergeLocalWithFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _setLoading(true);

      final cartDoc = await FirebaseFirestore.instance
          .collection(_cartCollection)
          .doc(user.uid)
          .get();

      if (cartDoc.exists) {
        final data = cartDoc.data();
        if (data != null && data['items'] != null) {
          final firebaseItems = (data['items'] as List)
              .map((item) => CartItem.fromMap(item))
              .toList();

          // Merge with local items
          for (final localItem in _items) {
            final existingIndex = firebaseItems.indexWhere(
              (item) => _getItemKey(item.productId, item.variantId) == 
                       _getItemKey(localItem.productId, localItem.variantId),
            );

            if (existingIndex != -1) {
              // Update quantity if item exists
              final existingItem = firebaseItems[existingIndex];
              final newQuantity = existingItem.quantity + localItem.quantity;
              firebaseItems[existingIndex] = existingItem.copyWith(
                quantity: newQuantity.clamp(1, existingItem.maxStock),
              );
            } else {
              // Add new item
              firebaseItems.add(localItem);
            }
          }

          _items = firebaseItems;
          await _saveCartToLocal();
          await _syncWithFirebase();
          notifyListeners();
        }
      } else {
        // No Firebase cart exists, sync local cart
        await _syncWithFirebase();
      }
    } catch (e) {
      _setError('Gagal menggabungkan keranjang: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Clear cart on logout
  Future<void> onUserLogout() async {
    await clearCart();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
  }

  // Get cart items grouped by category
  Map<String, List<CartItem>> get itemsByCategory {
    final Map<String, List<CartItem>> grouped = {};
    
    for (final item in _items) {
      if (!grouped.containsKey(item.categoryName)) {
        grouped[item.categoryName] = [];
      }
      grouped[item.categoryName]!.add(item);
    }
    
    return grouped;
  }

  // Calculate shipping cost (placeholder logic)
  double calculateShipping() {
    if (isEmpty) return 0.0;
    if (subtotal >= 500000) return 0.0; // Free shipping over 500k
    return 25000.0; // Flat rate 25k
  }

  // Calculate tax (placeholder logic)
  double calculateTax() {
    return subtotal * 0.1; // 10% tax
  }

  // Get cart summary with shipping and tax
  CartSummary get detailedSummary {
    final shipping = calculateShipping();
    final tax = calculateTax();
    
    return CartSummary.fromItems(
      _items,
      shipping: shipping,
      tax: tax,
    );
  }
}