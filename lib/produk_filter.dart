import '../models/product.dart';

class ProductFilterUtils {
  // Filter products based on search query
  static List<Product> filterBySearch(List<Product> products, String query) {
    if (query.isEmpty) return products;
    
    final lowercaseQuery = query.toLowerCase();
    return products.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
             product.description.toLowerCase().contains(lowercaseQuery) ||
             product.sku.toLowerCase().contains(lowercaseQuery) ||
             product.categoryName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Filter products by category
  static List<Product> filterByCategory(List<Product> products, String categoryId) {
    if (categoryId.isEmpty) return products;
    return products.where((product) => product.categoryId == categoryId).toList();
  }

  // Filter products by status
  static List<Product> filterByStatus(List<Product> products, ProductStatus status) {
    switch (status) {
      case ProductStatus.all:
        return products;
      case ProductStatus.active:
        return products.where((product) => product.isActive).toList();
      case ProductStatus.inactive:
        return products.where((product) => !product.isActive).toList();
      case ProductStatus.lowStock:
        return products.where((product) => product.isLowStock && !product.isOutOfStock).toList();
      case ProductStatus.outOfStock:
        return products.where((product) => product.isOutOfStock).toList();
      case ProductStatus.hasVariants:
        return products.where((product) => product.hasVariants).toList();
      case ProductStatus.noVariants:
        return products.where((product) => !product.hasVariants).toList();
    }
  }

  // Filter products by multiple criteria
  static List<Product> filterProducts({
    required List<Product> products,
    String? searchQuery,
    String? categoryId,
    ProductStatus? status,
    double? minPrice,
    double? maxPrice,
    bool? hasImages,
  }) {
    var filtered = products;

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filtered = filterBySearch(filtered, searchQuery);
    }

    // Apply category filter
    if (categoryId != null && categoryId.isNotEmpty) {
      filtered = filterByCategory(filtered, categoryId);
    }

    // Apply status filter
    if (status != null) {
      filtered = filterByStatus(filtered, status);
    }

    // Apply price range filter
    if (minPrice != null) {
      filtered = filtered.where((product) => product.price >= minPrice).toList();
    }
    if (maxPrice != null) {
      filtered = filtered.where((product) => product.price <= maxPrice).toList();
    }

    // Apply image filter
    if (hasImages != null) {
      if (hasImages) {
        filtered = filtered.where((product) => product.imageUrls.isNotEmpty).toList();
      } else {
        filtered = filtered.where((product) => product.imageUrls.isEmpty).toList();
      }
    }

    return filtered;
  }

  // Sort products
  static List<Product> sortProducts(List<Product> products, ProductSortBy sortBy, {bool ascending = true}) {
    final sorted = List<Product>.from(products);

    switch (sortBy) {
      case ProductSortBy.name:
        sorted.sort((a, b) => ascending 
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name));
        break;
      case ProductSortBy.price:
        sorted.sort((a, b) => ascending 
            ? a.price.compareTo(b.price)
            : b.price.compareTo(a.price));
        break;
      case ProductSortBy.stock:
        sorted.sort((a, b) => ascending 
            ? a.totalStock.compareTo(b.totalStock)
            : b.totalStock.compareTo(a.totalStock));
        break;
      case ProductSortBy.createdAt:
        sorted.sort((a, b) => ascending 
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt));
        break;
      case ProductSortBy.updatedAt:
        sorted.sort((a, b) => ascending 
            ? a.updatedAt.compareTo(b.updatedAt)
            : b.updatedAt.compareTo(a.updatedAt));
        break;
      case ProductSortBy.category:
        sorted.sort((a, b) => ascending 
            ? a.categoryName.compareTo(b.categoryName)
            : b.categoryName.compareTo(a.categoryName));
        break;
      case ProductSortBy.sku:
        sorted.sort((a, b) => ascending 
            ? a.sku.compareTo(b.sku)
            : b.sku.compareTo(a.sku));
        break;
    }

    return sorted;
  }

  // Get products statistics
  static ProductStatistics getStatistics(List<Product> products) {
    final activeProducts = products.where((p) => p.isActive).length;
    final inactiveProducts = products.length - activeProducts;
    final outOfStockProducts = products.where((p) => p.isOutOfStock).length;
    final lowStockProducts = products.where((p) => p.isLowStock && !p.isOutOfStock).length;
    final productsWithVariants = products.where((p) => p.hasVariants).length;
    final productsWithImages = products.where((p) => p.imageUrls.isNotEmpty).length;
    
    final totalValue = products.fold<double>(0, (sum, product) => sum + (product.price * product.totalStock));
    final totalStock = products.fold<int>(0, (sum, product) => sum + product.totalStock);

    return ProductStatistics(
      totalProducts: products.length,
      activeProducts: activeProducts,
      inactiveProducts: inactiveProducts,
      outOfStockProducts: outOfStockProducts,
      lowStockProducts: lowStockProducts,
      productsWithVariants: productsWithVariants,
      productsWithImages: productsWithImages,
      totalInventoryValue: totalValue,
      totalStock: totalStock,
    );
  }

  // Get category distribution
  static Map<String, int> getCategoryDistribution(List<Product> products) {
    final distribution = <String, int>{};
    
    for (final product in products) {
      distribution[product.categoryName] = (distribution[product.categoryName] ?? 0) + 1;
    }
    
    return distribution;
  }

  // Get stock status distribution
  static Map<String, int> getStockStatusDistribution(List<Product> products) {
    final distribution = <String, int>{
      'Tersedia': 0,
      'Menipis': 0,
      'Habis': 0,
    };
    
    for (final product in products) {
      distribution[product.stockStatus] = (distribution[product.stockStatus] ?? 0) + 1;
    }
    
    return distribution;
  }
}

// Enums for filtering and sorting
enum ProductStatus {
  all,
  active,
  inactive,
  lowStock,
  outOfStock,
  hasVariants,
  noVariants,
}

enum ProductSortBy {
  name,
  price,
  stock,
  createdAt,
  updatedAt,
  category,
  sku,
}

// Statistics class
class ProductStatistics {
  final int totalProducts;
  final int activeProducts;
  final int inactiveProducts;
  final int outOfStockProducts;
  final int lowStockProducts;
  final int productsWithVariants;
  final int productsWithImages;
  final double totalInventoryValue;
  final int totalStock;

  ProductStatistics({
    required this.totalProducts,
    required this.activeProducts,
    required this.inactiveProducts,
    required this.outOfStockProducts,
    required this.lowStockProducts,
    required this.productsWithVariants,
    required this.productsWithImages,
    required this.totalInventoryValue,
    required this.totalStock,
  });

  double get activeProductsPercentage => totalProducts > 0 ? (activeProducts / totalProducts) * 100 : 0;
  double get outOfStockPercentage => totalProducts > 0 ? (outOfStockProducts / totalProducts) * 100 : 0;
  double get lowStockPercentage => totalProducts > 0 ? (lowStockProducts / totalProducts) * 100 : 0;
  double get variantsPercentage => totalProducts > 0 ? (productsWithVariants / totalProducts) * 100 : 0;

  String get formattedInventoryValue {
    return 'Rp ${totalInventoryValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }
}

// Filter options model
class ProductFilterOptions {
  final String? searchQuery;
  final String? categoryId;
  final ProductStatus status;
  final double? minPrice;
  final double? maxPrice;
  final bool? hasImages;
  final ProductSortBy sortBy;
  final bool ascending;

  ProductFilterOptions({
    this.searchQuery,
    this.categoryId,
    this.status = ProductStatus.all,
    this.minPrice,
    this.maxPrice,
    this.hasImages,
    this.sortBy = ProductSortBy.updatedAt,
    this.ascending = false,
  });

  ProductFilterOptions copyWith({
    String? searchQuery,
    String? categoryId,
    ProductStatus? status,
    double? minPrice,
    double? maxPrice,
    bool? hasImages,
    ProductSortBy? sortBy,
    bool? ascending,
  }) {
    return ProductFilterOptions(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      hasImages: hasImages ?? this.hasImages,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }

  bool get hasActiveFilters {
    return (searchQuery != null && searchQuery!.isNotEmpty) ||
           (categoryId != null && categoryId!.isNotEmpty) ||
           status != ProductStatus.all ||
           minPrice != null ||
           maxPrice != null ||
           hasImages != null;
  }
}