import 'dart:ui';

import '../models/product.dart';

class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final double productPrice;
  final int quantity;
  final String categoryId;
  final String categoryName;
  final String productUnit;
  final int maxStock;
  final DateTime addedAt;
  
  // Enhanced variant properties for new system
  final String? variantId; // Now contains ProductVariantCombination.id
  final String? variantName; // Display name for the combination (e.g., "Merah - L")
  final double variantPriceAdjustment;
  final String? variantSku; // SKU from the combination
  final Map<String, dynamic>? variantAttributes; // Attributes map from combination

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.quantity,
    required this.categoryId,
    required this.categoryName,
    required this.productUnit,
    required this.maxStock,
    required this.addedAt,
    this.variantId,
    this.variantName,
    this.variantPriceAdjustment = 0,
    this.variantSku,
    this.variantAttributes,
  });

  // Get effective price (base price + variant adjustment)
  double get effectivePrice => productPrice + variantPriceAdjustment;
  
  // Get total price for this item
  double get totalPrice => effectivePrice * quantity;
  
  // Get formatted price
  String get formattedPrice => 'Rp ${effectivePrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  
  // Get formatted total price
  String get formattedTotalPrice => 'Rp ${totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  
  // Check if item has variant
  bool get hasVariant => variantId != null && variantName != null;
  
  // Get display name (product name + variant if any)
  String get displayName {
    if (hasVariant) {
      return '$productName - $variantName';
    }
    return productName;
  }

  // Enhanced method to create CartItem from Product with new variant system
  factory CartItem.fromProduct(
    Product product, {
    int quantity = 1,
    String? variantId, // ProductVariantCombination.id
    String? variantName, // Auto-generated display name
    double variantPriceAdjustment = 0,
    String? variantSku, // From combination.sku
    Map<String, dynamic>? variantAttributes, // From combination.attributes
    int? variantStock, // From combination.stock
  }) {
    final now = DateTime.now();
    final itemId = '${product.id}_${variantId ?? 'default'}_${now.millisecondsSinceEpoch}';
    
    return CartItem(
      id: itemId,
      productId: product.id,
      productName: product.name,
      productImage: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      productPrice: product.price,
      quantity: quantity,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      productUnit: product.unit,
      maxStock: variantStock ?? product.totalStock,
      addedAt: now,
      variantId: variantId,
      variantName: variantName,
      variantPriceAdjustment: variantPriceAdjustment,
      variantSku: variantSku,
      variantAttributes: variantAttributes,
    );
  }

  // Create CartItem from ProductVariantCombination directly
  factory CartItem.fromProductWithCombination(
    Product product,
    ProductVariantCombination combination, {
    int quantity = 1,
  }) {
    // Generate combination display name
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
    final displayName = parts.join(' - ');

    final now = DateTime.now();
    final itemId = '${product.id}_${combination.id}_${now.millisecondsSinceEpoch}';
    
    return CartItem(
      id: itemId,
      productId: product.id,
      productName: product.name,
      productImage: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      productPrice: product.price,
      quantity: quantity,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      productUnit: product.unit,
      maxStock: combination.stock,
      addedAt: now,
      variantId: combination.id,
      variantName: displayName,
      variantPriceAdjustment: combination.priceAdjustment,
      variantSku: combination.sku,
      variantAttributes: combination.attributes,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'productPrice': productPrice,
      'quantity': quantity,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'productUnit': productUnit,
      'maxStock': maxStock,
      'addedAt': addedAt.toIso8601String(),
      'variantId': variantId,
      'variantName': variantName,
      'variantPriceAdjustment': variantPriceAdjustment,
      'variantSku': variantSku,
      'variantAttributes': variantAttributes,
    };
  }

  // Create CartItem from Map
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      productPrice: (map['productPrice'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      productUnit: map['productUnit'] ?? 'pcs',
      maxStock: map['maxStock'] ?? 0,
      addedAt: DateTime.parse(map['addedAt'] ?? DateTime.now().toIso8601String()),
      variantId: map['variantId'],
      variantName: map['variantName'],
      variantPriceAdjustment: (map['variantPriceAdjustment'] ?? 0).toDouble(),
      variantSku: map['variantSku'],
      variantAttributes: map['variantAttributes'] != null 
          ? Map<String, dynamic>.from(map['variantAttributes'])
          : null,
    );
  }

  // Copy with method for updates
  CartItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
    int? quantity,
    String? categoryId,
    String? categoryName,
    String? productUnit,
    int? maxStock,
    DateTime? addedAt,
    String? variantId,
    String? variantName,
    double? variantPriceAdjustment,
    String? variantSku,
    Map<String, dynamic>? variantAttributes,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      quantity: quantity ?? this.quantity,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      productUnit: productUnit ?? this.productUnit,
      maxStock: maxStock ?? this.maxStock,
      addedAt: addedAt ?? this.addedAt,
      variantId: variantId ?? this.variantId,
      variantName: variantName ?? this.variantName,
      variantPriceAdjustment: variantPriceAdjustment ?? this.variantPriceAdjustment,
      variantSku: variantSku ?? this.variantSku,
      variantAttributes: variantAttributes ?? this.variantAttributes,
    );
  }

  // Enhanced variant info display
  String get variantDisplayInfo {
    if (!hasVariant) return '';
    
    List<String> info = [];
    if (variantName != null) info.add(variantName!);
    if (variantSku != null) info.add('SKU: $variantSku');
    
    return info.join(' • ');
  }

  // Get formatted price adjustment for display
  String get formattedPriceAdjustment {
    if (variantPriceAdjustment == 0) return '';
    
    final absAdjustment = variantPriceAdjustment.abs();
    final formattedAmount = absAdjustment.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    
    return variantPriceAdjustment > 0 ? '+Rp $formattedAmount' : '-Rp $formattedAmount';
  }

  // Check if this cart item matches a specific product and variant combination
  bool matchesProductVariant(String productId, {String? variantId}) {
    return this.productId == productId && this.variantId == variantId;
  }

  // Get stock status for this item
  String get stockStatus {
    if (maxStock <= 0) return 'Habis';
    if (maxStock <= 10) return 'Menipis';
    return 'Tersedia';
  }

  // Get stock status color
  Color get stockStatusColor {
    if (maxStock <= 0) return const Color(0xFFDC2626); // Red
    if (maxStock <= 10) return const Color(0xFFF59E0B); // Orange
    return const Color(0xFF059669); // Green
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.productId == productId &&
        other.variantId == variantId;
  }

  @override
  int get hashCode => productId.hashCode ^ (variantId?.hashCode ?? 0);

  @override
  String toString() {
    return 'CartItem(id: $id, productName: $productName, variantName: $variantName, quantity: $quantity, price: $effectivePrice)';
  }
}

// Enhanced Cart Summary class
class CartSummary {
  final int itemCount;
  final int totalQuantity;
  final double subtotal;
  final double shipping;
  final double tax;
  final double discount;
  final double total;

  CartSummary({
    required this.itemCount,
    required this.totalQuantity,
    required this.subtotal,
    this.shipping = 0,
    this.tax = 0,
    this.discount = 0,
  }) : total = subtotal + shipping + tax - discount;

  factory CartSummary.fromItems(
    List<CartItem> items, {
    double shipping = 0,
    double tax = 0,
    double discount = 0,
  }) {
    final itemCount = items.length;
    final totalQuantity = items.fold(0, (sum, item) => sum + item.quantity);
    final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);

    return CartSummary(
      itemCount: itemCount,
      totalQuantity: totalQuantity,
      subtotal: subtotal,
      shipping: shipping,
      tax: tax,
      discount: discount,
    );
  }

  // Formatted currency methods
  String get formattedSubtotal => _formatCurrency(subtotal);
  String get formattedShipping => _formatCurrency(shipping);
  String get formattedTax => _formatCurrency(tax);
  String get formattedDiscount => _formatCurrency(discount);
  String get formattedTotal => _formatCurrency(total);

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  // Get item breakdown by category
  Map<String, List<CartItem>> getItemsByCategory(List<CartItem> items) {
    final Map<String, List<CartItem>> grouped = {};
    
    for (final item in items) {
      if (!grouped.containsKey(item.categoryName)) {
        grouped[item.categoryName] = [];
      }
      grouped[item.categoryName]!.add(item);
    }
    
    return grouped;
  }

  // Get items with variants vs without variants
  Map<String, List<CartItem>> getItemsByVariantStatus(List<CartItem> items) {
    final Map<String, List<CartItem>> grouped = {
      'withVariants': [],
      'withoutVariants': [],
    };
    
    for (final item in items) {
      if (item.hasVariant) {
        grouped['withVariants']!.add(item);
      } else {
        grouped['withoutVariants']!.add(item);
      }
    }
    
    return grouped;
  }

  // Calculate savings from variants (if any items have negative price adjustments)
  double calculateVariantSavings(List<CartItem> items) {
    double savings = 0;
    
    for (final item in items) {
      if (item.hasVariant && item.variantPriceAdjustment < 0) {
        savings += (item.variantPriceAdjustment.abs() * item.quantity);
      }
    }
    
    return savings;
  }

  String get formattedVariantSavings => _formatCurrency(calculateVariantSavings([]));

  // Get summary string for display
  String getSummaryText() {
    return '$itemCount item${itemCount > 1 ? 's' : ''} • $totalQuantity qty • $formattedTotal';
  }
}