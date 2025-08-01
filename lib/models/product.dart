import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Variant Attribute Model
class VariantAttribute {
  String id;
  String name;
  List<String> options;

  VariantAttribute({
    required this.id,
    required this.name,
    required this.options,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'options': options,
  };

  factory VariantAttribute.fromMap(Map<String, dynamic> map) => VariantAttribute(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    options: List<String>.from(map['options'] ?? []),
  );
}

// Product Variant Combination Model
class ProductVariantCombination {
  String id;
  Map<String, String> attributes; // attributeId: optionValue
  String sku;
  double priceAdjustment;
  int stock;
  bool isActive;
  String? imageUrl;

  ProductVariantCombination({
    required this.id,
    required this.attributes,
    required this.sku,
    this.priceAdjustment = 0,
    required this.stock,
    this.isActive = true,
    this.imageUrl,
  });

  String get displayName => attributes.values.join(' - ');

  double calculateFinalPrice(double basePrice) => basePrice + priceAdjustment;

  String getFormattedPrice(double basePrice) {
    final finalPrice = calculateFinalPrice(basePrice);
    return 'Rp ${finalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'attributes': attributes,
    'sku': sku,
    'priceAdjustment': priceAdjustment,
    'stock': stock,
    'isActive': isActive,
    'imageUrl': imageUrl,
  };

  factory ProductVariantCombination.fromMap(Map<String, dynamic> map) => ProductVariantCombination(
    id: map['id'] ?? '',
    attributes: Map<String, String>.from(map['attributes'] ?? {}),
    sku: map['sku'] ?? '',
    priceAdjustment: (map['priceAdjustment'] ?? 0).toDouble(),
    stock: map['stock'] ?? 0,
    isActive: map['isActive'] ?? true,
    imageUrl: map['imageUrl'],
  );
}

// Enhanced Product Model
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
  final List<Map<String, dynamic>>? variantAttributes;
  final List<Map<String, dynamic>>? variantCombinations;
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
    this.variantAttributes,
    this.variantCombinations,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties
  bool get isOutOfStock {
    if (hasVariants) {
      final combinations = getVariantCombinations();
      return combinations.every((combination) => combination.stock == 0);
    }
    return stock == 0;
  }

  bool get isLowStock => totalStock > 0 && totalStock <= 10;

  int get totalStock {
    if (hasVariants) {
      final combinations = getVariantCombinations();
      return combinations.fold<int>(0, (sum, combination) => sum + combination.stock);
    }
    return stock;
  }

  String get stockStatus {
    if (isOutOfStock) return 'Habis';
    if (isLowStock) return 'Menipis';
    return 'Tersedia';
  }

  Color get stockStatusColor {
    if (isOutOfStock) return const Color(0xFFDC2626);
    if (isLowStock) return const Color(0xFFF59E0B);
    return const Color(0xFF059669);
  }

  String get formattedPrice {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get priceRange {
    if (!hasVariants) return formattedPrice;

    double minPrice = price;
    double maxPrice = price;

    final combinations = getVariantCombinations();
    for (var combination in combinations) {
      final variantPrice = price + combination.priceAdjustment;
      if (variantPrice < minPrice) minPrice = variantPrice;
      if (variantPrice > maxPrice) maxPrice = variantPrice;
    }

    if (minPrice == maxPrice) {
      return 'Rp ${minPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}';
    }

    final minFormatted = minPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    final maxFormatted = maxPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return 'Rp $minFormatted - $maxFormatted';
  }

  // Helper methods
  List<VariantAttribute> getVariantAttributes() {
    if (variantAttributes == null) return [];
    return variantAttributes!
        .map((attrMap) => VariantAttribute.fromMap(attrMap))
        .toList();
  }

  List<ProductVariantCombination> getVariantCombinations() {
    if (variantCombinations == null) return [];
    return variantCombinations!
        .map((combMap) => ProductVariantCombination.fromMap(combMap))
        .toList();
  }

  List<ProductVariantCombination> getAvailableVariantCombinations() {
    return getVariantCombinations()
        .where((combination) => combination.stock > 0 && combination.isActive)
        .toList();
  }

  // Factory method from Firestore
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
      variantAttributes: data['variantAttributes'] != null
          ? List<Map<String, dynamic>>.from(data['variantAttributes'])
          : null,
      variantCombinations: data['variantCombinations'] != null
          ? List<Map<String, dynamic>>.from(data['variantCombinations'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Firestore
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
      'variantAttributes': variantAttributes,
      'variantCombinations': variantCombinations,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

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
    List<Map<String, dynamic>>? variantAttributes,
    List<Map<String, dynamic>>? variantCombinations,
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
      variantAttributes: variantAttributes ?? this.variantAttributes,
      variantCombinations: variantCombinations ?? this.variantCombinations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}