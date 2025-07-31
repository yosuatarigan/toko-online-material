import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String categoryId;
  final String categoryName;
  final String unit;
  final List<String> imageUrls;
  final bool isActive;
  final String sku;
  final double? weight;
  final bool hasVariants;
  final List<Map<String, dynamic>>? variants;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.categoryId,
    required this.categoryName,
    required this.unit,
    required this.imageUrls,
    required this.isActive,
    required this.sku,
    this.weight,
    this.hasVariants = false,
    this.variants,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties
  bool get isOutOfStock {
    if (hasVariants && variants != null) {
      return variants!.every((variant) => (variant['stock'] as int) == 0);
    }
    return stock == 0;
  }

  bool get isLowStock {
    if (hasVariants && variants != null) {
      final totalStock = variants!.fold<int>(0, (sum, variant) => sum + (variant['stock'] as int));
      return totalStock > 0 && totalStock <= 10;
    }
    return stock > 0 && stock <= 10;
  }

  int get totalStock {
    if (hasVariants && variants != null) {
      return variants!.fold<int>(0, (sum, variant) => sum + (variant['stock'] as int));
    }
    return stock;
  }

  String get stockStatus {
    if (isOutOfStock) {
      return 'Habis';
    } else if (isLowStock) {
      return 'Menipis';
    } else {
      return 'Tersedia';
    }
  }

  Color get stockStatusColor {
    if (isOutOfStock) {
      return const Color(0xFFDC2626); // Red
    } else if (isLowStock) {
      return const Color(0xFFF59E0B); // Orange
    } else {
      return const Color(0xFF059669); // Green
    }
  }

  String get stockInfo {
    if (hasVariants && variants != null) {
      final availableVariants = variants!.where((v) => (v['stock'] as int) > 0).length;
      final totalVariants = variants!.length;
      return '$availableVariants dari $totalVariants varian tersedia';
    }
    return '$totalStock $unit tersedia';
  }

  String get formattedPrice {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get priceRange {
    if (!hasVariants || variants == null || variants!.isEmpty) {
      return formattedPrice;
    }

    double minPrice = price;
    double maxPrice = price;

    for (var variant in variants!) {
      final variantPrice = price + (variant['priceAdjustment'] as double);
      if (variantPrice < minPrice) minPrice = variantPrice;
      if (variantPrice > maxPrice) maxPrice = variantPrice;
    }

    if (minPrice == maxPrice) {
      return 'Rp ${minPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}';
    }

    return 'Rp ${minPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )} - ${maxPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  List<ProductVariant> get productVariants {
    if (!hasVariants || variants == null) return [];
    
    return variants!.map((variantMap) => ProductVariant.fromMap(variantMap)).toList();
  }

  // Factory method to create Product from Firestore document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      stock: data['stock'] ?? 0,
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      unit: data['unit'] ?? 'pcs',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      isActive: data['isActive'] ?? true,
      sku: data['sku'] ?? '',
      weight: data['weight']?.toDouble(),
      hasVariants: data['hasVariants'] ?? false,
      variants: data['variants'] != null 
          ? List<Map<String, dynamic>>.from(data['variants'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert Product to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'unit': unit,
      'imageUrls': imageUrls,
      'isActive': isActive,
      'sku': sku,
      'weight': weight,
      'hasVariants': hasVariants,
      'variants': variants,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create a copy of Product with updated fields
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? categoryId,
    String? categoryName,
    String? unit,
    List<String>? imageUrls,
    bool? isActive,
    String? sku,
    double? weight,
    bool? hasVariants,
    List<Map<String, dynamic>>? variants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      imageUrls: imageUrls ?? this.imageUrls,
      isActive: isActive ?? this.isActive,
      sku: sku ?? this.sku,
      weight: weight ?? this.weight,
      hasVariants: hasVariants ?? this.hasVariants,
      variants: variants ?? this.variants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductVariant {
  final String id;
  final String name;
  final double priceAdjustment; // +/- dari harga dasar
  final int stock;
  final String? sku;
  final Map<String, dynamic>? attributes; // warna, ukuran, dll
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductVariant({
    required this.id,
    required this.name,
    this.priceAdjustment = 0,
    required this.stock,
    this.sku,
    this.attributes,
    this.createdAt,
    this.updatedAt,
  });

  // Computed properties
  bool get isOutOfStock => stock == 0;
  bool get isLowStock => stock > 0 && stock <= 5;

  String get formattedPriceAdjustment {
    if (priceAdjustment == 0) return '';
    
    final absAdjustment = priceAdjustment.abs();
    final formattedAmount = absAdjustment.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    
    return priceAdjustment > 0 ? '+Rp $formattedAmount' : '-Rp $formattedAmount';
  }

  double calculateFinalPrice(double basePrice) {
    return basePrice + priceAdjustment;
  }

  String getFormattedFinalPrice(double basePrice) {
    final finalPrice = calculateFinalPrice(basePrice);
    return 'Rp ${finalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  // Factory method to create ProductVariant from Map
  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      priceAdjustment: (map['priceAdjustment'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      sku: map['sku'],
      attributes: map['attributes'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convert ProductVariant to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'priceAdjustment': priceAdjustment,
      'stock': stock,
      'sku': sku,
      'attributes': attributes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create a copy of ProductVariant with updated fields
  ProductVariant copyWith({
    String? id,
    String? name,
    double? priceAdjustment,
    int? stock,
    String? sku,
    Map<String, dynamic>? attributes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      priceAdjustment: priceAdjustment ?? this.priceAdjustment,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      attributes: attributes ?? this.attributes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductVariant(id: $id, name: $name, priceAdjustment: $priceAdjustment, stock: $stock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ProductVariant &&
        other.id == id &&
        other.name == name &&
        other.priceAdjustment == priceAdjustment &&
        other.stock == stock &&
        other.sku == sku;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        priceAdjustment.hashCode ^
        stock.hashCode ^
        sku.hashCode;
  }
}

// Helper class untuk mengelola stok produk dengan varian
class ProductStockManager {
  static int getTotalStock(Product product) {
    if (product.hasVariants && product.variants != null) {
      return product.variants!.fold<int>(0, (sum, variant) => sum + (variant['stock'] as int));
    }
    return product.stock;
  }

  static bool isOutOfStock(Product product) {
    if (product.hasVariants && product.variants != null) {
      return product.variants!.every((variant) => (variant['stock'] as int) == 0);
    }
    return product.stock == 0;
  }

  static bool isLowStock(Product product, {int threshold = 10}) {
    final totalStock = getTotalStock(product);
    return totalStock > 0 && totalStock <= threshold;
  }

  static List<ProductVariant> getAvailableVariants(Product product) {
    if (!product.hasVariants || product.variants == null) return [];
    
    return product.variants!
        .map((variantMap) => ProductVariant.fromMap(variantMap))
        .where((variant) => variant.stock > 0)
        .toList();
  }

  static List<ProductVariant> getLowStockVariants(Product product, {int threshold = 5}) {
    if (!product.hasVariants || product.variants == null) return [];
    
    return product.variants!
        .map((variantMap) => ProductVariant.fromMap(variantMap))
        .where((variant) => variant.stock > 0 && variant.stock <= threshold)
        .toList();
  }

  static ProductVariant? getCheapestVariant(Product product) {
    if (!product.hasVariants || product.variants == null || product.variants!.isEmpty) {
      return null;
    }

    var cheapestVariant = ProductVariant.fromMap(product.variants!.first);
    double cheapestPrice = product.price + cheapestVariant.priceAdjustment;

    for (var variantMap in product.variants!) {
      final variant = ProductVariant.fromMap(variantMap);
      final variantPrice = product.price + variant.priceAdjustment;
      
      if (variantPrice < cheapestPrice) {
        cheapestPrice = variantPrice;
        cheapestVariant = variant;
      }
    }

    return cheapestVariant;
  }

  static ProductVariant? getMostExpensiveVariant(Product product) {
    if (!product.hasVariants || product.variants == null || product.variants!.isEmpty) {
      return null;
    }

    var expensiveVariant = ProductVariant.fromMap(product.variants!.first);
    double expensivePrice = product.price + expensiveVariant.priceAdjustment;

    for (var variantMap in product.variants!) {
      final variant = ProductVariant.fromMap(variantMap);
      final variantPrice = product.price + variant.priceAdjustment;
      
      if (variantPrice > expensivePrice) {
        expensivePrice = variantPrice;
        expensiveVariant = variant;
      }
    }

    return expensiveVariant;
  }
}