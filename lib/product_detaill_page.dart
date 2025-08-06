// lib/pages/product_detail_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:toko_online_material/cart_page.dart';
import 'package:toko_online_material/chat_detail_page.dart';
import 'package:toko_online_material/image_viewer.dart';
import 'package:toko_online_material/product_card.dart';
import 'package:toko_online_material/service/cart_service.dart';
import 'package:toko_online_material/service/chat_service.dart';
import '../models/product.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ChatService _chatService = ChatService();

  PageController _imageController = PageController();
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _isFavorite = false;
  List<Product> _relatedProducts = [];
  bool _isLoading = true;

  // Enhanced Variant state with weight support
  ProductVariantCombination? _selectedVariantCombination;
  Map<String, String> _selectedAttributes = {}; // attributeId: optionValue
  double _currentPrice = 0;
  int _availableStock = 0;
  double _currentWeight = 1000; // Default weight in grams

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _initializeProductData();
    _loadRelatedProducts();
    _startAnimations();
  }

  void _initializeProductData() {
    // Initialize price, stock, and weight based on variants
    if (widget.product.hasVariants) {
      final combinations = widget.product.getVariantCombinations();
      if (combinations.isNotEmpty) {
        // Select first available combination or first combination
        final availableCombinations =
            combinations.where((c) => c.stock > 0 && c.isActive).toList();
        if (availableCombinations.isNotEmpty) {
          _selectedVariantCombination = availableCombinations.first;
        } else {
          _selectedVariantCombination = combinations.first;
        }
        _selectedAttributes = Map.from(_selectedVariantCombination!.attributes);
        _updatePriceStockAndWeight();
      } else {
        _currentPrice = widget.product.price;
        _availableStock = widget.product.stock;
        _currentWeight = widget.product.weight ?? 1000;
      }
    } else {
      _currentPrice = widget.product.price;
      _availableStock = widget.product.stock;
      _currentWeight = widget.product.weight ?? 1000;
    }
  }

  void _updatePriceStockAndWeight() {
    if (_selectedVariantCombination != null) {
      _currentPrice =
          widget.product.price + _selectedVariantCombination!.priceAdjustment;
      _availableStock = _selectedVariantCombination!.stock;
      _currentWeight = _selectedVariantCombination!.weight;
    } else {
      _currentPrice = widget.product.price;
      _availableStock = widget.product.totalStock;
      _currentWeight = widget.product.weight ?? 1000;
    }

    // Reset quantity if it exceeds available stock
    if (_quantity > _availableStock) {
      _quantity = _availableStock > 0 ? 1 : 0;
    }
  }

  void _selectVariantCombination(ProductVariantCombination combination) {
    setState(() {
      _selectedVariantCombination = combination;
      _selectedAttributes = Map.from(combination.attributes);
      _updatePriceStockAndWeight();
    });
  }

  void _updateAttributeSelection(String attributeId, String optionValue) {
    setState(() {
      _selectedAttributes[attributeId] = optionValue;

      // Find matching combination
      final combinations = widget.product.getVariantCombinations();
      final matchingCombination = combinations.firstWhere(
        (combination) =>
            _mapEquals(combination.attributes, _selectedAttributes),
        orElse:
            () => ProductVariantCombination(
              id: '',
              attributes: {},
              sku: '',
              stock: 0,
              weight: 1000, // Default weight
            ),
      );

      if (matchingCombination.id.isNotEmpty) {
        _selectedVariantCombination = matchingCombination;
        _updatePriceStockAndWeight();
      } else {
        _selectedVariantCombination = null;
        _currentPrice = widget.product.price;
        _availableStock = 0;
        _currentWeight = widget.product.weight ?? 1000;
      }
    });
  }

  bool _mapEquals(Map<String, String> map1, Map<String, String> map2) {
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  String _getCombinationDisplayName(ProductVariantCombination combination) {
    final attributes = widget.product.getVariantAttributes();
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

  String _formatWeight(double weightInGrams) {
    if (weightInGrams >= 1000) {
      final kg = weightInGrams / 1000;
      if (kg == kg.toInt()) {
        return '${kg.toInt()} kg';
      } else {
        return '${kg.toStringAsFixed(1)} kg';
      }
    } else {
      return '${weightInGrams.toInt()} g';
    }
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _imageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadRelatedProducts() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .where('categoryId', isEqualTo: widget.product.categoryId)
              .where('isActive', isEqualTo: true)
              .limit(6)
              .get();

      final products =
          snapshot.docs
              .map((doc) => Product.fromFirestore(doc))
              .where((product) => product.id != widget.product.id)
              .take(4)
              .toList();

      setState(() {
        _relatedProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToCart() async {
    final cartService = Provider.of<CartService>(context, listen: false);

    // Create variant info if applicable
    String? variantId;
    if (_selectedVariantCombination != null) {
      variantId = _selectedVariantCombination!.id;
    }

    final success = await cartService.addItem(
      widget.product,
      quantity: _quantity,
      variantId: variantId,
    );

    if (success && mounted) {
      final variantText =
          _selectedVariantCombination != null
              ? ' (${_getCombinationDisplayName(_selectedVariantCombination!)})'
              : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.product.name}$variantText ($_quantity x) ditambahkan ke keranjang',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Lihat Keranjang',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartPage()),
              );
            },
          ),
        ),
      );
    } else if (cartService.lastError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(cartService.lastError!)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _buyNow() async {
    final cartService = Provider.of<CartService>(context, listen: false);

    String? variantId;
    if (_selectedVariantCombination != null) {
      variantId = _selectedVariantCombination!.id;
    }

    final success = await cartService.addItem(
      widget.product,
      quantity: _quantity,
      variantId: variantId,
    );

    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CartPage()),
      );
    } else if (cartService.lastError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(cartService.lastError!)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _shareProduct() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Fitur share akan segera hadir'),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getFormattedPrice(double price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  bool get _isOutOfStock {
    if (widget.product.hasVariants) {
      return _availableStock == 0;
    }
    return widget.product.isOutOfStock;
  }

  bool get _canAddToCart {
    return widget.product.isActive &&
        !_isOutOfStock &&
        (!widget.product.hasVariants || _selectedVariantCombination != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildSliverAppBar()];
        },
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductInfo(),
                  if (widget.product.hasVariants) _buildVariantSelector(),
                  if (widget.product.isActive && !_isOutOfStock)
                    _buildQuantitySelector(),
                  _buildTabsSection(),
                  if (_relatedProducts.isNotEmpty) _buildRelatedProducts(),
                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.black,
            ),
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isFavorite
                        ? 'Ditambahkan ke favorit'
                        : 'Dihapus dari favorit',
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(0, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _shareProduct,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(background: _buildImageGallery()),
    );
  }

  Widget _buildImageGallery() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child:
            widget.product.imageUrls.isNotEmpty
                ? Stack(
                  children: [
                    PageView.builder(
                      controller: _imageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemCount: widget.product.imageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            showImageViewer(
                              context,
                              imageUrls: widget.product.imageUrls,
                              initialIndex: index,
                              productName: widget.product.name,
                            );
                          },
                          child: Container(
                            color: Colors.grey[50],
                            child: CachedNetworkImage(
                              imageUrl: widget.product.imageUrls[index],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              placeholder:
                                  (context, url) => Container(
                                    color: Colors.grey[100],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).primaryColor,
                                            ),
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey[100],
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_outlined,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Gambar tidak dapat dimuat',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Image indicators
                    if (widget.product.imageUrls.length > 1)
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.product.imageUrls.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: index == _currentImageIndex ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color:
                                    index == _currentImageIndex
                                        ? Theme.of(context).primaryColor
                                        : Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Zoom hint
                    Positioned(
                      top: 100,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Tap to zoom',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                : Container(
                  color: Colors.grey[100],
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Tidak ada gambar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.product.categoryName,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Product name
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          // SKU
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SKU: ${_selectedVariantCombination?.sku ?? widget.product.sku}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Price and stock row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show price range if has variants but no variant selected, or current price
                    Text(
                      widget.product.hasVariants &&
                              _selectedVariantCombination == null
                          ? widget.product.priceRange
                          : _getFormattedPrice(_currentPrice),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    Text(
                      'per ${widget.product.unit}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    // Show price adjustment if variant selected
                    if (_selectedVariantCombination != null &&
                        _selectedVariantCombination!.priceAdjustment != 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _selectedVariantCombination!.priceAdjustment > 0
                            ? '+${_getFormattedPrice(_selectedVariantCombination!.priceAdjustment)}'
                            : '${_getFormattedPrice(_selectedVariantCombination!.priceAdjustment)}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _selectedVariantCombination!.priceAdjustment > 0
                                  ? Colors.red
                                  : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.product.stockStatusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.product.stockStatusColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 16,
                          color: widget.product.stockStatusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_availableStock tersedia',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.product.stockStatusColor,
                          ),
                        ),
                      ],
                    ),
                    if (widget.product.hasVariants) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${widget.product.totalStock}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Weight info - updated to show variant-specific weight
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.scale_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Berat: ${_formatWeight(_currentWeight)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              if (widget.product.hasVariants && _selectedVariantCombination != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'varian',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSelector() {
    if (!widget.product.hasVariants) return const SizedBox.shrink();

    final attributes = widget.product.getVariantAttributes();
    final combinations = widget.product.getVariantCombinations();

    if (attributes.isEmpty || combinations.isEmpty)
      return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 20, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text(
                'Pilih Varian',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Display attributes and their options
          ...attributes.map((attribute) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attribute.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      attribute.options.map((option) {
                        final isSelected =
                            _selectedAttributes[attribute.id] == option;

                        // Check if this option is available in any combination
                        final isAvailable = combinations.any(
                          (combination) =>
                              combination.attributes[attribute.id] == option &&
                              combination.stock > 0 &&
                              combination.isActive,
                        );

                        return GestureDetector(
                          onTap:
                              isAvailable
                                  ? () {
                                    _updateAttributeSelection(
                                      attribute.id,
                                      option,
                                    );
                                  }
                                  : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                                      : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? const Color(0xFF2E7D32)
                                        : isAvailable
                                        ? Colors.grey[300]!
                                        : Colors.red[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    isAvailable
                                        ? (isSelected
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFF2D3748))
                                        : Colors.red,
                                decoration:
                                    isAvailable
                                        ? null
                                        : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),

          // Selected combination info with weight
          if (_selectedVariantCombination != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Varian Terpilih:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getCombinationDisplayName(
                            _selectedVariantCombination!,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                      ),
                      Text(
                        _getFormattedPrice(_currentPrice),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'SKU: ${_selectedVariantCombination!.sku}',
                        style: TextStyle(fontSize: 11, color: Colors.green[600]),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.scale_outlined, size: 12, color: Colors.green[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatWeight(_currentWeight),
                            style: TextStyle(fontSize: 11, color: Colors.green[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (widget.product.hasVariants) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Silakan pilih semua opsi varian terlebih dahulu',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    // Don't show if variant required but not selected
    if (widget.product.hasVariants && _selectedVariantCombination == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Jumlah',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuantityButton(
                      Icons.remove,
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Container(
                      width: 60,
                      height: 48,
                      alignment: Alignment.center,
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildQuantityButton(
                      Icons.add,
                      _quantity < _availableStock
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total Harga',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getFormattedPrice(_currentPrice * _quantity),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  // Show total weight
                  const SizedBox(height: 2),
                  Text(
                    'Berat: ${_formatWeight(_currentWeight * _quantity)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color:
            onPressed != null
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color:
              onPressed != null ? Theme.of(context).primaryColor : Colors.grey,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildTabsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Deskripsi'),
                Tab(text: 'Spesifikasi'),
                Tab(text: 'Ulasan'),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDescriptionTab(),
                _buildSpecificationTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deskripsi Produk',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                widget.product.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF4A5568),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spesifikasi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Basic specs
                  _buildSpecRow('Kategori', widget.product.categoryName),
                  _buildSpecRow('SKU', widget.product.sku),
                  _buildSpecRow('Satuan', widget.product.unit),
                  
                  // Weight info - enhanced for variants
                  if (widget.product.hasVariants) ...[
                    if (_selectedVariantCombination != null)
                      _buildSpecRow('Berat Varian', _formatWeight(_currentWeight))
                    else
                      _buildSpecRow('Rentang Berat', _getWeightRange()),
                  ] else if (widget.product.weight != null)
                    _buildSpecRow('Berat', _formatWeight(widget.product.weight!)),
                    
                  if (widget.product.hasVariants) ...[
                    _buildSpecRow(
                      'Jumlah Varian',
                      '${widget.product.getVariantCombinations().length} kombinasi',
                    ),
                    _buildSpecRow(
                      'Atribut Varian',
                      widget.product
                          .getVariantAttributes()
                          .map((attr) => attr.name)
                          .join(', '),
                    ),
                  ],

                  // Additional specifications would go here
                  const SizedBox(height: 16),
                  _buildEmptyState(
                    Icons.description_outlined,
                    'Spesifikasi detail akan segera ditambahkan',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getWeightRange() {
    if (!widget.product.hasVariants) {
      return _formatWeight(widget.product.weight ?? 1000);
    }
    
    final combinations = widget.product.getVariantCombinations();
    if (combinations.isEmpty) {
      return _formatWeight(widget.product.weight ?? 1000);
    }
    
    final weights = combinations.map((c) => c.weight).toList()..sort();
    final minWeight = weights.first;
    final maxWeight = weights.last;
    
    if (minWeight == maxWeight) {
      return _formatWeight(minWeight);
    } else {
      return '${_formatWeight(minWeight)} - ${_formatWeight(maxWeight)}';
    }
  }

  Widget _buildSpecRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF4A5568)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Ulasan Pelanggan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _buildEmptyState(
              Icons.rate_review_outlined,
              'Fitur ulasan akan segera hadir',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
          child: Row(
            children: [
              const Text(
                'Produk Terkait',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _relatedProducts.length,
            itemBuilder: (context, index) {
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 12),
                child: ProductCard(
                  product: _relatedProducts[index],
                  showCategory: false,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (!_canAddToCart) {
      String buttonText = 'Produk Tidak Tersedia';
      if (!widget.product.isActive) {
        buttonText = 'Produk Tidak Aktif';
      } else if (_isOutOfStock) {
        buttonText = 'Stok Habis';
      } else if (widget.product.hasVariants &&
          _selectedVariantCombination == null) {
        buttonText = 'Pilih Varian Terlebih Dahulu';
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Chat button - always available
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _startChatWithAdmin,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Chat'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  foregroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Disabled product button
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  buttonText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Chat button
          OutlinedButton.icon(
            onPressed: _startChatWithAdmin,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Chat'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1565C0)),
              foregroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: const Size(80, 48),
            ),
          ),
          const SizedBox(width: 12),
          // Add to cart button
          Expanded(
            child: OutlinedButton(
              onPressed: _addToCart,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Tambah ke Keranjang',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Buy now button
          Expanded(
            child: ElevatedButton(
              onPressed: _buyNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
              child: const Text(
                'Beli Sekarang',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startChatWithAdmin() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final chatId = await _chatService.createOrGetChat(
        product: widget.product,
      );

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (chatId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatDetailPage(
                  chatId: chatId,
                  chatTitle: 'Chat tentang ${widget.product.name}',
                  productId: widget.product.id,
                  productName: widget.product.name,
                  productImageUrl:
                      widget.product.imageUrls.isNotEmpty
                          ? widget.product.imageUrls.first
                          : null,
                ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Gagal memulai chat. Pastikan Anda sudah login.'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      // Hide loading if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}