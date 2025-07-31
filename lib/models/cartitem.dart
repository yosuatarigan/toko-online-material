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
  
  // Variant properties
  final String? variantId;
  final String? variantName;
  final double variantPriceAdjustment;
  final String? variantSku;
  final Map<String, dynamic>? variantAttributes;

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

  // Create CartItem from Product
  factory CartItem.fromProduct(
    Product product, {
    int quantity = 1,
    String? variantId,
    String? variantName,
    double variantPriceAdjustment = 0,
    String? variantSku,
    Map<String, dynamic>? variantAttributes,
    int? variantStock,
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
      maxStock: variantStock ?? product.stock,
      addedAt: now,
      variantId: variantId,
      variantName: variantName,
      variantPriceAdjustment: variantPriceAdjustment,
      variantSku: variantSku,
      variantAttributes: variantAttributes,
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
      variantAttributes: map['variantAttributes'],
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.productId == productId &&
        other.variantId == variantId;
  }

  @override
  int get hashCode => productId.hashCode ^ (variantId?.hashCode ?? 0);
}

// Cart Summary class
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

  String get formattedSubtotal => 'Rp ${subtotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  String get formattedShipping => 'Rp ${shipping.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  String get formattedTax => 'Rp ${tax.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  String get formattedDiscount => 'Rp ${discount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  String get formattedTotal => 'Rp ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
}