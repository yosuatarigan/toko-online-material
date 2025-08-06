// lib/pages/cart_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toko_online_material/models/cartitem.dart';
import 'package:toko_online_material/models/product.dart';
import 'package:toko_online_material/models/address_model.dart';
import 'package:toko_online_material/service/cart_service.dart';
import 'package:toko_online_material/service/rajaongkir_service.dart';



class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  
  bool _isValidating = false;
  bool _selectAll = true;
  Set<String> _selectedItems = {};
  String _selectedVoucher = '';

  // Shipping related state
  List<Address> _userAddresses = [];
  Address? _selectedAddress;
  List<ShippingCost> _availableShipping = [];
  ShippingCost? _selectedShipping;
  bool _isLoadingAddresses = true;
  bool _isCalculatingShipping = false;
  String? _shippingError;

  // Fixed origin ID untuk toko
  static const String _storeOriginId = '69943';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSelectedItems();
    _loadUserAddresses();
    _validateCartItems();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
  }

  void _initializeSelectedItems() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartService = Provider.of<CartService>(context, listen: false);
      setState(() {
        _selectedItems = cartService.items.map((item) => item.id).toSet();
      });
      // Auto calculate shipping jika ada alamat default
      _autoSelectDefaultAddressAndCalculateShipping();
    });
  }

  Future<void> _loadUserAddresses() async {
    if (user == null) {
      setState(() {
        _isLoadingAddresses = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('addresses')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('isDefault', descending: true)
          .get();

      final addresses = snapshot.docs.map((doc) => Address.fromFirestore(doc)).toList();
      
      setState(() {
        _userAddresses = addresses;
        _isLoadingAddresses = false;
        
        // Auto-select default address
        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => addresses.first,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingAddresses = false;
      });
      _showErrorSnackBar('Gagal memuat alamat: $e');
    }
  }

  void _autoSelectDefaultAddressAndCalculateShipping() {
    if (_selectedAddress != null && _selectedItems.isNotEmpty) {
      _calculateShippingCosts();
    }
  }

  Future<void> _calculateShippingCosts() async {
    if (_selectedAddress == null || _selectedItems.isEmpty) {
      setState(() {
        _availableShipping = [];
        _selectedShipping = null;
        _shippingError = null;
      });
      return;
    }

    // Validasi subdistrictId
    if (_selectedAddress!.subdistrictId.isEmpty) {
      setState(() {
        _shippingError = 'Alamat tidak memiliki kecamatan yang valid';
        _isCalculatingShipping = false;
        _availableShipping = [];
        _selectedShipping = null;
      });
      return;
    }

    setState(() {
      _isCalculatingShipping = true;
      _shippingError = null;
    });

    try {
      final cartService = Provider.of<CartService>(context, listen: false);
      
      // Calculate total weight dari selected items
      double totalWeight = 0;
      for (final item in cartService.items) {
        if (_selectedItems.contains(item.id)) {
          // Get weight berdasarkan variant atau default product weight
          double itemWeight = 1000; // Default 1kg
          
          if (item.hasVariant) {
            // Cari weight dari variant combination
            final product = await _getProductById(item.productId);
            if (product != null && product.hasVariants) {
              final combinations = product.getVariantCombinations();
              final matchingCombination = combinations.firstWhere(
                (c) => c.id == item.variantId,
                orElse: () => ProductVariantCombination(
                  id: '',
                  attributes: {},
                  sku: '',
                  stock: 0,
                  weight: 1000,
                ),
              );
              if (matchingCombination.id.isNotEmpty) {
                itemWeight = matchingCombination.weight;
              }
            }
          } else {
            // Use product weight atau default
            final product = await _getProductById(item.productId);
            if (product?.weight != null) {
              itemWeight = product!.weight! * 1000; // Convert kg to gram
            }
          }
          
          totalWeight += (itemWeight * item.quantity);
        }
      }

      print('Total weight: ${totalWeight}g');
      print('Origin ID: $_storeOriginId');
      print('Destination ID: ${_selectedAddress!.subdistrictId}');

      if (totalWeight <= 0) {
        setState(() {
          _shippingError = 'Tidak dapat menghitung berat paket';
          _isCalculatingShipping = false;
        });
        return;
      }

      // Calculate shipping costs langsung menggunakan ID
      final shippingCosts = await RajaOngkirService.calculateCostWithIds(
        originId: _storeOriginId,
        destinationId: _selectedAddress!.subdistrictId,
        weight: totalWeight.toInt(),
      );

      if (shippingCosts.isEmpty) {
        setState(() {
          _shippingError = 'Tidak ada layanan pengiriman tersedia';
          _isCalculatingShipping = false;
        });
        return;
      }

      // Sort by price (cheapest first)
      shippingCosts.sort((a, b) => a.cost.compareTo(b.cost));

      setState(() {
        _availableShipping = shippingCosts;
        _selectedShipping = shippingCosts.first; // Auto select cheapest
        _isCalculatingShipping = false;
      });

      print('Found ${shippingCosts.length} shipping options');

    } catch (e) {
      setState(() {
        _shippingError = 'Gagal menghitung ongkos kirim: $e';
        _isCalculatingShipping = false;
        _availableShipping = [];
        _selectedShipping = null;
      });
      print('Shipping calculation error: $e');
    }
  }

  Future<Product?> _getProductById(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      
      if (doc.exists) {
        return Product.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting product: $e');
    }
    return null;
  }

  // Validate cart items in background
  Future<void> _validateCartItems() async {
    final cartService = Provider.of<CartService>(context, listen: false);
    if (cartService.isEmpty) return;

    setState(() {
      _isValidating = true;
    });

    try {
      final issues = await cartService.validateCart();
      if (issues.isNotEmpty && mounted) {
        _showValidationDialog(issues);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal memvalidasi keranjang: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  void _showValidationDialog(List<String> issues) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
            const SizedBox(width: 8),
            const Text('Perhatian', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Beberapa item di keranjang Anda memiliki masalah:'),
            const SizedBox(height: 12),
            ...issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Colors.red[600])),
                  Expanded(
                    child: Text(
                      issue,
                      style: TextStyle(color: Colors.red[600], fontSize: 13),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool? value, CartService cartService) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedItems = cartService.items.map((item) => item.id).toSet();
      } else {
        _selectedItems.clear();
      }
    });
    // Recalculate shipping when selection changes
    _calculateShippingCosts();
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }

      final cartService = Provider.of<CartService>(context, listen: false);
      _selectAll = _selectedItems.length == cartService.items.length;
    });
    // Recalculate shipping when selection changes
    _calculateShippingCosts();
  }

  double _calculateSelectedTotal(CartService cartService) {
    double total = 0;
    for (final item in cartService.items) {
      if (_selectedItems.contains(item.id)) {
        total += item.totalPrice;
      }
    }
    return total;
  }

  int _getSelectedItemsCount() {
    return _selectedItems.length;
  }

  void _showAddressModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddressModal(),
    );
  }

  void _showShippingModal() {
    if (_availableShipping.isEmpty) {
      _showErrorSnackBar('Pilih alamat terlebih dahulu untuk melihat opsi pengiriman');
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildShippingModal(),
    );
  }

  void _showVoucherModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildVoucherModal(),
    );
  }

  Future<void> _checkout(CartService cartService) async {
    if (_selectedItems.isEmpty) {
      _showErrorSnackBar('Pilih minimal 1 produk untuk checkout');
      return;
    }

    if (_selectedAddress == null) {
      _showErrorSnackBar('Pilih alamat pengiriman terlebih dahulu');
      return;
    }

    if (_selectedShipping == null) {
      _showErrorSnackBar('Pilih metode pengiriman terlebih dahulu');
      return;
    }

    // Validate selected items before checkout
    setState(() {
      _isValidating = true;
    });

    try {
      final issues = await cartService.validateCart();
      final selectedItemIssues = issues.where((issue) {
        return _selectedItems.any((itemId) {
          final item = cartService.items.firstWhere((i) => i.id == itemId, 
              orElse: () => CartItem.fromProduct(Product(
                id: '', name: '', description: '', price: 0, stock: 0,
                categoryId: '', categoryName: '', unit: '', imageUrls: [],
                isActive: false, sku: '', createdAt: DateTime.now(), updatedAt: DateTime.now()
              )));
          return issue.contains(item.displayName);
        });
      }).toList();

      if (selectedItemIssues.isNotEmpty) {
        _showValidationDialog(selectedItemIssues);
        return;
      }

      final selectedTotal = _calculateSelectedTotal(cartService);
      final shippingCost = _selectedShipping!.cost.toDouble();
      final total = selectedTotal + shippingCost - (_selectedVoucher.isNotEmpty ? 10000 : 0);
      
      _showCheckoutDialog(selectedTotal, shippingCost, total);
    } catch (e) {
      _showErrorSnackBar('Gagal memvalidasi keranjang: $e');
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  void _showCheckoutDialog(double subtotal, double shipping, double total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payment, color: Color(0xFF2E7D32), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Konfirmasi Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Item', '${_getSelectedItemsCount()} produk'),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Subtotal', _formatCurrency(subtotal)),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Ongkos Kirim', _formatCurrency(shipping)),
                      if (_selectedVoucher.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('Diskon', '-Rp 10.000', color: Colors.green),
                      ],
                      const Divider(height: 20),
                      _buildSummaryRow('Total Pembayaran', _formatCurrency(total), isTotal: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Shipping info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Pengiriman',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_selectedShipping!.courierDisplayName} - ${_selectedShipping!.service}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Ke: ${_selectedAddress!.cityName}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Estimasi: ${_selectedShipping!.etd}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesanan akan diproses dari Toko Barokah, Laren - Lamongan',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processCheckout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Checkout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal ? const Color(0xFF2D3748) : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: color ?? (isTotal ? const Color(0xFF2E7D32) : const Color(0xFF2D3748)),
          ),
        ),
      ],
    );
  }

  Future<void> _processCheckout() async {
    _showSuccessSnackBar('Checkout berhasil! Pesanan Anda sedang diproses');
    
    // TODO: Implement real checkout process
    // - Save order to database
    // - Clear selected items from cart
    // - Navigate to order confirmation page
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          if (cartService.isEmpty) {
            return _buildEmptyCart();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildStoreHeader(),
                _buildSelectAllBar(cartService),
                if (_isValidating) _buildValidationBar(),
                Expanded(
                  child: ListView(
                    children: [
                      _buildCartItems(cartService),
                      _buildShippingSection(),
                      _buildOrderSummary(cartService),
                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Consumer<CartService>(
        builder: (context, cartService, child) {
          if (cartService.isEmpty) return const SizedBox.shrink();
          return _buildBottomCheckoutBar(cartService);
        },
      ),
    );
  }

  Widget _buildValidationBar() {
    return Container(
      color: Colors.orange[50],
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Memvalidasi ketersediaan produk...',
            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Keranjang',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Consumer<CartService>(
          builder: (context, cartService, child) {
            if (cartService.isNotEmpty) {
              return TextButton(
                onPressed: () => _showClearCartDialog(),
                child: Text(
                  'Hapus',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keranjang Kosong',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yuk mulai belanja material berkualitas\ndi Toko Barokah!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Mulai Belanja',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.store,
              color: Color(0xFF2E7D32),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toko Barokah',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Text(
                  'Material Berkualitas • Laren, Lamongan',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Terpercaya',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllBar(CartService cartService) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            onChanged: (value) => _toggleSelectAll(value, cartService),
            activeColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          const Text(
            'Pilih Semua',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D3748),
            ),
          ),
          const Spacer(),
          if (_selectedItems.isNotEmpty)
            TextButton(
              onPressed: () {
                final itemsToRemove = _selectedItems.toList();
                for (final itemId in itemsToRemove) {
                  cartService.removeItem(itemId);
                }
                setState(() {
                  _selectedItems.clear();
                  _selectAll = false;
                });
                _showSuccessSnackBar('${itemsToRemove.length} item dihapus');
                _calculateShippingCosts(); // Recalculate after removal
              },
              child: Text(
                'Hapus (${_selectedItems.length})',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItems(CartService cartService) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartService.items.length,
        itemBuilder: (context, index) {
          final item = cartService.items[index];
          final isSelected = _selectedItems.contains(item.id);

          return Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 1),
            child: _CartItemTile(
              item: item,
              isSelected: isSelected,
              onSelectionChanged: () => _toggleItemSelection(item.id),
              onQuantityChanged: (newQuantity) {
                cartService.updateQuantity(item.id, newQuantity);
                // Recalculate shipping when quantity changes
                _calculateShippingCosts();
              },
              onRemove: () {
                cartService.removeItem(item.id);
                setState(() {
                  _selectedItems.remove(item.id);
                });
                _showSuccessSnackBar('${item.displayName} dihapus dari keranjang');
                // Recalculate shipping after removal
                _calculateShippingCosts();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildShippingSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Pengiriman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Address selection
          GestureDetector(
            onTap: _showAddressModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alamat Pengiriman',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedAddress != null
                              ? '${_selectedAddress!.label} - ${_selectedAddress!.cityName}'
                              : _isLoadingAddresses
                                  ? 'Memuat alamat...'
                                  : 'Pilih alamat pengiriman',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _selectedAddress != null
                                ? const Color(0xFF2D3748)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Shipping method selection
          GestureDetector(
            onTap: _showShippingModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined, 
                    color: Colors.grey[600], 
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Metode Pengiriman',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_isCalculatingShipping) ...[
                          Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Menghitung ongkos kirim...',
                                style: TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ],
                          ),
                        ] else if (_shippingError != null) ...[
                          Text(
                            _shippingError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ] else if (_selectedShipping != null) ...[
                          Text(
                            '${_selectedShipping!.courierDisplayName} - ${_selectedShipping!.service}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          Text(
                            '${_selectedShipping!.formattedCost} • ${_selectedShipping!.etd}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ] else ...[
                          Text(
                            _selectedAddress != null
                                ? 'Pilih metode pengiriman'
                                : 'Pilih alamat terlebih dahulu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartService cartService) {
    final selectedTotal = _calculateSelectedTotal(cartService);
    final shippingCost = _selectedShipping?.cost.toDouble() ?? 0;
    final discount = _selectedVoucher.isNotEmpty ? 10000 : 0;
    final total = selectedTotal + shippingCost - discount;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Pesanan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryItem('Subtotal Produk', _formatCurrency(selectedTotal)),
          _buildSummaryItem(
            'Biaya Pengiriman', 
            _selectedShipping != null 
                ? _selectedShipping!.formattedCost
                : _isCalculatingShipping 
                    ? 'Menghitung...'
                    : _shippingError != null
                        ? 'Error'
                        : 'Pilih pengiriman',
          ),
          if (_selectedVoucher.isNotEmpty)
            _buildSummaryItem('Voucher Diskon', '-Rp 10.000', color: Colors.green),
          const Divider(height: 24),
          _buildSummaryItem(
            'Total Pembayaran',
            _formatCurrency(total),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? const Color(0xFF2D3748) : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isTotal ? const Color(0xFF2E7D32) : const Color(0xFF2D3748)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar(CartService cartService) {
    final selectedTotal = _calculateSelectedTotal(cartService);
    final shippingCost = _selectedShipping?.cost.toDouble() ?? 0;
    final discount = _selectedVoucher.isNotEmpty ? 10000 : 0;
    final total = selectedTotal + shippingCost - discount;

    final canCheckout = _selectedItems.isNotEmpty && 
                       _selectedAddress != null && 
                       _selectedShipping != null && 
                       !_isValidating &&
                       !_isCalculatingShipping;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total (${_getSelectedItemsCount()} item)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _formatCurrency(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: canCheckout ? () => _checkout(cartService) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isValidating || _isCalculatingShipping
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Checkout (${_getSelectedItemsCount()})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: canCheckout ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shipping Modal
  Widget _buildShippingModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Text('Pilih Metode Pengiriman', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          if (_availableShipping.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Tidak ada layanan pengiriman tersedia',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ] else ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableShipping.length,
                itemBuilder: (context, index) {
                  final shipping = _availableShipping[index];
                  return _buildShippingOption(shipping);
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShippingOption(ShippingCost shipping) {
    final isSelected = _selectedShipping?.code == shipping.code && 
                      _selectedShipping?.service == shipping.service;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
        ),
        title: Text(
          '${shipping.courierDisplayName}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${shipping.service} - ${shipping.description}',
              style: const TextStyle(fontSize: 12),
            ),
            if (shipping.etd.isNotEmpty)
              Text(
                'Estimasi: ${shipping.etd}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              shipping.formattedCost,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
          ],
        ),
        onTap: () {
          setState(() {
            _selectedShipping = shipping;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // Address Modal
  Widget _buildAddressModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Pilih Alamat Pengiriman',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _userAddresses.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada alamat tersimpan.\nTambahkan alamat di halaman profil.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _userAddresses.length,
                        itemBuilder: (context, index) {
                          final address = _userAddresses[index];
                          final isSelected = _selectedAddress?.id == address.id;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Text(
                                    address.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  if (address.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'UTAMA',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(address.recipientName),
                                  Text(
                                    address.fullAddress,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: isSelected 
                                  ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) 
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedAddress = address;
                                });
                                Navigator.pop(context);
                                _calculateShippingCosts();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoucherModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Pilih Voucher',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildVoucherItem('NEWUSER10', 'Diskon Rp 10.000', 'Min. belanja Rp 50.000', Colors.orange),
                    _buildVoucherItem('FREEONGKIR', 'Gratis Ongkir', 'Min. belanja Rp 100.000', Colors.blue),
                    _buildVoucherItem('MATERIAL15', 'Diskon 15%', 'Max. diskon Rp 25.000', Colors.green),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoucherItem(String code, String title, String description, Color color) {
    final isSelected = _selectedVoucher == code;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.local_offer, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$code • $description',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: isSelected 
            ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) 
            : null,
        onTap: () {
          setState(() {
            _selectedVoucher = isSelected ? '' : code;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Semua'),
        content: const Text('Yakin ingin menghapus semua item dari keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<CartService>(context, listen: false).clearCart();
              setState(() {
                _selectedItems.clear();
                _selectAll = false;
              });
              _showSuccessSnackBar('Keranjang berhasil dikosongkan');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Enhanced Cart Item Tile with new variant system support
class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool isSelected;
  final VoidCallback onSelectionChanged;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (_) => onSelectionChanged(),
            activeColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          _buildProductImage(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductInfo(),
                const SizedBox(height: 12),
                _buildQuantityAndPrice(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.productImage.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: item.productImage,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade100,
                  child: Icon(Icons.image, color: Colors.grey.shade400, size: 30),
                ),
              )
            : Icon(Icons.image, color: Colors.grey.shade400, size: 30),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.productName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Enhanced variant info display
        if (item.hasVariant) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune,
                  size: 12,
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    item.variantName!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.categoryName,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 8),

        // Enhanced price display with variant adjustment indicator
        Row(
          children: [
            Text(
              item.formattedPrice,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            if (item.hasVariant && item.variantPriceAdjustment != 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: item.variantPriceAdjustment > 0 
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.variantPriceAdjustment > 0 ? Icons.add : Icons.remove,
                      size: 10,
                      color: item.variantPriceAdjustment > 0 ? Colors.orange : Colors.green,
                    ),
                    Text(
                      'Rp ${item.variantPriceAdjustment.abs().toInt()}',
                      style: TextStyle(
                        fontSize: 9,
                        color: item.variantPriceAdjustment > 0 ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityAndPrice() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuantityButton(
                Icons.remove,
                item.quantity > 1 ? () => onQuantityChanged(item.quantity - 1) : null,
              ),
              Container(
                width: 40,
                height: 32,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              _buildQuantityButton(
                Icons.add,
                item.quantity < item.maxStock ? () => onQuantityChanged(item.quantity + 1) : null,
              ),
            ],
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.formattedTotalPrice,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.hasVariant && item.variantSku != null) ...[
                  Text(
                    'SKU: ${item.variantSku}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Hapus',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(
          icon,
          size: 16,
          color: onPressed != null ? const Color(0xFF2D3748) : Colors.grey,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}