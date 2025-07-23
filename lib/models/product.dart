import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String categoryId;
  final String categoryName;
  final String unit; // kg, meter, pcs, dll
  final List<String> imageUrls;
  final bool isActive;
  final String sku; // Stock Keeping Unit
  final double? weight; // berat dalam kg
  final Map<String, dynamic>? specifications; // spesifikasi tambahan
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
    this.specifications,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert Product to Map for Firestore
  Map<String, dynamic> toMap() {
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
      'specifications': specifications,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create Product from Firestore DocumentSnapshot
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
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
      specifications: data['specifications'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create Product from Map
  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      unit: map['unit'] ?? 'pcs',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      isActive: map['isActive'] ?? true,
      sku: map['sku'] ?? '',
      weight: map['weight']?.toDouble(),
      specifications: map['specifications'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with method untuk update
  Product copyWith({
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
    Map<String, dynamic>? specifications,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id,
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
      specifications: specifications ?? this.specifications,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Helper methods
  String get formattedPrice {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get stockStatus {
    if (stock <= 0) return 'Habis';
    if (stock <= 10) return 'Stok Menipis';
    return 'Stok Tersedia';
  }

  bool get isLowStock => stock <= 10;
  bool get isOutOfStock => stock <= 0;

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, stock: $stock)';
  }
}