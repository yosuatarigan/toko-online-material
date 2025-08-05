import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toko_online_material/models/address.dart';
import 'package:toko_online_material/models/cartitem.dart';
import 'package:toko_online_material/models/product.dart';
import 'package:toko_online_material/service/cart_service.dart';
import 'package:toko_online_material/service/shipping_service.dart';
import 'package:toko_online_material/widget/shipping_cost_widget.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with TickerProviderStateMixin {
  bool _isValidating = false;
  bool _selectAll = true;
  Set<String> _selectedItems = <String>{};
  String _selectedVoucher = '';
  final ShippingService _shippingService = ShippingService();
  UserAddress? _selectedAddress;
  ShippingCostDetail? _selectedShipping;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Add this to prevent setState during build
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Defer initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCart();
    });
  }

  Future<void> _initializeCart() async {
    if (!mounted) return;
    
    await _loadDefaultAddress();
    _initializeSelectedItems();
    await _validateCartItems();
    
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final defaultAddress = await _shippingService.getDefaultAddress();
      if (defaultAddress != null && mounted) {
        setState(() {
          _selectedAddress = defaultAddress;
        });
      }
    } catch (e) {
      debugPrint('Error loading default address: $e');
    }
  }

  void _onAddressChanged(UserAddress address) {
    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _selectedShipping = null;
      });
    }
  }

  void _onShippingCostChanged(ShippingCostDetail? shipping) {
    if (mounted) {
      setState(() {
        _selectedShipping = shipping;
      });
    }
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
    final cartService = Provider.of<CartService>(context, listen: false);
    if (mounted) {
      setState(() {
        _selectedItems = cartService.items.map((item) => item.id).toSet();
      });
    }
  }

  Future<void> _validateCartItems() async {
    if (!mounted) return;
    
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
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Perhatian',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Beberapa item di keranjang Anda memiliki masalah:'),
            const SizedBox(height: 12),
            ...issues
                .map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(color: Colors.red[600]),
                        ),
                        Expanded(
                          child: Text(
                            issue,
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
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
  }

  double _calculateSelectedTotal(CartService cartService) {
    double subtotal = 0;
    for (final item in cartService.items) {
      if (_selectedItems.contains(item.id)) {
        subtotal += item.totalPrice;
      }
    }
    return subtotal;
  }

  double _getShippingCost() {
    return _selectedShipping?.value.toDouble() ?? 0.0;
  }

  int _calculateTotalWeight(CartService cartService) {
    final selectedItems = cartService.items
        .where((item) => _selectedItems.contains(item.id))
        .toList();
    return _shippingService.calculateCartWeight(selectedItems);
  }

  int _getSelectedItemsCount() {
    return _selectedItems.length;
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
      _showErrorSnackBar('Pilih layanan pengiriman terlebih dahulu');
      return;
    }

    setState(() {
      _isValidating = true;
    });

    try {
      final issues = await cartService.validateCart();
      final selectedItemIssues = issues.where((issue) {
        return _selectedItems.any((itemId) {
          final item = cartService.items.firstWhere(
            (i) => i.id == itemId,
            orElse: () => CartItem.fromProduct(
              Product(
                id: '',
                name: '',
                description: '',
                price: 0,
                stock: 0,
                categoryId: '',
                categoryName: '',
                unit: '',
                imageUrls: [],
                isActive: false,
                sku: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
          );
          return issue.contains(item.displayName);
        });
      }).toList();

      if (selectedItemIssues.isNotEmpty) {
        _showValidationDialog(selectedItemIssues);
        return;
      }

      final selectedTotal = _calculateSelectedTotal(cartService);
      final shippingCost = _getShippingCost();
      final voucherDiscount = _selectedVoucher.isNotEmpty ? 10000.0 : 0.0;
      final total = selectedTotal + shippingCost - voucherDiscount;

      _showCheckoutDialog(total);
    } catch (e) {
      _showErrorSnackBar('Gagal memvalidasi keranjang: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  void _showCheckoutDialog(double total) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.payment,
                color: Color(0xFF2E7D32),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Konfirmasi Checkout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow(
                'Total Item',
                '${_getSelectedItemsCount()} produk',
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Subtotal',
                _formatCurrency(
                  _calculateSelectedTotal(
                    Provider.of<CartService>(context, listen: false),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedShipping != null)
                _buildSummaryRow(
                  'Ongkos Kirim',
                  _selectedShipping!.formattedCost,
                ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Total Pembayaran',
                _formatCurrency(total),
                isTotal: true,
              ),
              const SizedBox(height: 12),
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
                        Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pengiriman',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ke: ${_selectedAddress!.recipientName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    Text(
                      _selectedAddress!.fullDisplayAddress,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    if (_selectedShipping != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Estimasi: ${_selectedShipping!.estimatedDelivery}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text(
              'Checkout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
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
            color: isTotal ? const Color(0xFF2E7D32) : const Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  Future<void> _processCheckout() async {
    _showSuccessSnackBar('Checkout berhasil! Pesanan Anda sedang diproses');
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
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
    if (!mounted) return;
    
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

  String _getCheckoutButtonText() {
    if (_selectedItems.isEmpty) return 'Pilih Produk';
    if (_selectedAddress == null) return 'Pilih Alamat';
    if (_selectedShipping == null) return 'Pilih Ongkir';
    return 'Checkout';
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

          if (!_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildStoreHeader(),
                _buildSelectAllBar(cartService),
                if (_isValidating) _buildValidationBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCartItems(cartService),
                        _buildOrderSummary(cartService),
                        const SizedBox(height: 100), // Space for bottom bar
                      ],
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            child: const Icon(Icons.store, color: Color(0xFF2E7D32), size: 20),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
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
      child: Column(
        children: cartService.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = _selectedItems.contains(item.id);
          
          return Container(
            key: ValueKey('cart_item_${item.id}_$index'), // More unique key
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 1),
            child: _CartItemTile(
              item: item,
              isSelected: isSelected,
              onSelectionChanged: () => _toggleItemSelection(item.id),
              onQuantityChanged: (newQuantity) {
                cartService.updateQuantity(item.id, newQuantity);
              },
              onRemove: () {
                cartService.removeItem(item.id);
                setState(() {
                  _selectedItems.remove(item.id);
                });
                _showSuccessSnackBar(
                  '${item.displayName} dihapus dari keranjang',
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderSummary(CartService cartService) {
    final selectedTotal = _calculateSelectedTotal(cartService);
    final shippingCost = _getShippingCost();
    final voucherDiscount = _selectedVoucher.isNotEmpty ? 10000.0 : 0.0;
    final total = selectedTotal + shippingCost - voucherDiscount;

    return Column(
      children: [
        // Shipping Cost Widget with unique key
        ShippingCostWidget(
          key: ValueKey('shipping_widget_${_selectedAddress?.id ?? 'none'}'),
          selectedAddress: _selectedAddress,
          totalWeight: _calculateTotalWeight(cartService),
          onAddressChanged: _onAddressChanged,
          onShippingCostChanged: _onShippingCostChanged,
        ),

        const SizedBox(height: 8),

        // Order Summary
        Container(
          color: Colors.white,
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
              _buildSummaryItem(
                'Subtotal Produk',
                _formatCurrency(selectedTotal),
              ),

              if (_selectedShipping != null)
                _buildSummaryItem(
                  'Ongkos Kirim (${_selectedShipping!.estimatedDelivery})',
                  _selectedShipping!.formattedCost,
                ),

              if (_selectedVoucher.isNotEmpty)
                _buildSummaryItem(
                  'Voucher Diskon',
                  '-Rp 10.000',
                  color: Colors.green,
                ),

              const Divider(height: 24),
              _buildSummaryItem(
                'Total Pembayaran',
                _formatCurrency(total),
                isTotal: true,
              ),

              // Status info
              if (_selectedAddress != null && _selectedShipping == null) ...[
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
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pilih layanan pengiriman untuk melanjutkan checkout',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_selectedAddress == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pilih alamat pengiriman untuk melanjutkan checkout',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
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
              color: color ??
                  (isTotal ? const Color(0xFF2E7D32) : const Color(0xFF2D3748)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar(CartService cartService) {
    final selectedTotal = _calculateSelectedTotal(cartService);
    final shippingCost = _getShippingCost();
    final voucherDiscount = _selectedVoucher.isNotEmpty ? 10000.0 : 0.0;
    final total = selectedTotal + shippingCost - voucherDiscount;

    final canCheckout = _selectedItems.isNotEmpty &&
        !_isValidating &&
        _selectedAddress != null &&
        _selectedShipping != null;

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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isValidating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          canCheckout
                              ? 'Checkout (${_getSelectedItemsCount()})'
                              : _getCheckoutButtonText(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: canCheckout
                                ? Colors.white
                                : Colors.grey.shade600,
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

  void _showClearCartDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Hapus Semua'),
        content: const Text(
          'Yakin ingin menghapus semua item dari keranjang?',
        ),
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
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Cart Item Tile
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
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
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade100,
                  child: Icon(
                    Icons.image,
                    color: Colors.grey.shade400,
                    size: 30,
                  ),
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
                const Icon(Icons.tune, size: 12, color: Color(0xFF2E7D32)),
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

        // Enhanced price display
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
                      item.variantPriceAdjustment > 0
                          ? Icons.add
                          : Icons.remove,
                      size: 10,
                      color: item.variantPriceAdjustment > 0
                          ? Colors.orange
                          : Colors.green,
                    ),
                    Text(
                      'Rp ${item.variantPriceAdjustment.abs().toInt()}',
                      style: TextStyle(
                        fontSize: 9,
                        color: item.variantPriceAdjustment > 0
                            ? Colors.orange
                            : Colors.green,
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
                item.quantity > 1
                    ? () => onQuantityChanged(item.quantity - 1)
                    : null,
              ),
              Container(
                width: 40,
                height: 32,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildQuantityButton(
                Icons.add,
                item.quantity < item.maxStock
                    ? () => onQuantityChanged(item.quantity + 1)
                    : null,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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