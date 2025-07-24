import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final double productPrice;
  final String productUnit;
  final String categoryName;
  final String sku;
  final int maxStock;
  int quantity;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.productUnit,
    required this.categoryName,
    required this.sku,
    required this.maxStock,
    required this.quantity,
    required this.addedAt,
  });

  // Create CartItem from Product
  factory CartItem.fromProduct(Product product, {int quantity = 1}) {
    return CartItem(
      id: '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      productName: product.name,
      productImage: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      productPrice: product.price,
      productUnit: product.unit,
      categoryName: product.categoryName,
      sku: product.sku,
      maxStock: product.stock,
      quantity: quantity,
      addedAt: DateTime.now(),
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
      'productUnit': productUnit,
      'categoryName': categoryName,
      'sku': sku,
      'maxStock': maxStock,
      'quantity': quantity,
      'addedAt': addedAt.millisecondsSinceEpoch,
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
      productUnit: map['productUnit'] ?? 'pcs',
      categoryName: map['categoryName'] ?? '',
      sku: map['sku'] ?? '',
      maxStock: map['maxStock'] ?? 0,
      quantity: map['quantity'] ?? 1,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] ?? 0),
    );
  }

  // Convert to JSON string
  String toJson() {
    return '${toMap()}';
  }

  // Create CartItem from JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem.fromMap(json);
  }

  // Calculate total price for this item
  double get totalPrice => productPrice * quantity;

  // Formatted price
  String get formattedPrice {
    return 'Rp ${productPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  // Formatted total price
  String get formattedTotalPrice {
    return 'Rp ${totalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  // Check if quantity is valid
  bool get isValidQuantity => quantity > 0 && quantity <= maxStock;

  // Check if item is available (has stock)
  bool get isAvailable => maxStock > 0;

  // Copy with method
  CartItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
    String? productUnit,
    String? categoryName,
    String? sku,
    int? maxStock,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      productUnit: productUnit ?? this.productUnit,
      categoryName: categoryName ?? this.categoryName,
      sku: sku ?? this.sku,
      maxStock: maxStock ?? this.maxStock,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  String toString() {
    return 'CartItem(id: $id, productName: $productName, quantity: $quantity, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Cart summary model
class CartSummary {
  final List<CartItem> items;
  final int totalItems;
  final int totalQuantity;
  final double subtotal;
  final double tax;
  final double shipping;
  final double discount;
  final double total;

  CartSummary({
    required this.items,
    required this.totalItems,
    required this.totalQuantity,
    required this.subtotal,
    this.tax = 0.0,
    this.shipping = 0.0,
    this.discount = 0.0,
  }) : total = subtotal + tax + shipping - discount;

  // Create empty cart summary
  factory CartSummary.empty() {
    return CartSummary(
      items: [],
      totalItems: 0,
      totalQuantity: 0,
      subtotal: 0.0,
    );
  }

  // Create cart summary from items
  factory CartSummary.fromItems(List<CartItem> items, {
    double tax = 0.0,
    double shipping = 0.0,
    double discount = 0.0,
  }) {
    final totalQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    
    return CartSummary(
      items: List.unmodifiable(items),
      totalItems: items.length,
      totalQuantity: totalQuantity,
      subtotal: subtotal,
      tax: tax,
      shipping: shipping,
      discount: discount,
    );
  }

  // Formatted prices
  String get formattedSubtotal {
    return 'Rp ${subtotal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get formattedTotal {
    return 'Rp ${total.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get formattedTax {
    return 'Rp ${tax.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get formattedShipping {
    return 'Rp ${shipping.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get formattedDiscount {
    return 'Rp ${discount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  // Check if cart is empty
  bool get isEmpty => items.isEmpty;

  // Check if cart has items
  bool get isNotEmpty => items.isNotEmpty;
}