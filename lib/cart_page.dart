// lib/pages/cart_page.dart (Modified to always show store delivery)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toko_online_material/cart_item_tile.dart';
import 'package:toko_online_material/checkout_page.dart';
import 'package:toko_online_material/models/cartitem.dart';
import 'package:toko_online_material/models/product.dart';
import 'package:toko_online_material/models/address_model.dart';
import 'package:toko_online_material/service/cart_service.dart';
import 'package:toko_online_material/service/rajaongkir_service.dart';
import 'package:toko_online_material/service/distance_service.dart';

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

  // Store delivery state - UPDATED
  DistanceResult? _distanceResult;
  StoreDeliveryOption? _storeDeliveryOption;
  bool _isCalculatingDistance = false;

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
      final snapshot =
          await FirebaseFirestore.instance
              .collection('addresses')
              .where('userId', isEqualTo: user!.uid)
              .orderBy('isDefault', descending: true)
              .get();

      final addresses =
          snapshot.docs.map((doc) => Address.fromFirestore(doc)).toList();

      setState(() {
        _userAddresses = addresses;
        _isLoadingAddresses = false;

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

  // FUNGSI DIUPDATE - Selalu buat opsi pengiriman toko
  Future<void> _calculateDistanceAndStoreDelivery() async {
    setState(() {
      _isCalculatingDistance = true;
    });

    try {
      if (_selectedAddress != null) {
        final distance = await DistanceService.calculateDistanceToAddress(
          _selectedAddress!.fullAddress,
          _selectedAddress!.cityName,
        );

        setState(() {
          _distanceResult = distance;
          // Selalu buat opsi pengiriman toko, biarkan StoreDeliveryOption menentukan availability
          _storeDeliveryOption = StoreDeliveryOption.createAlways(
            distance,
            _selectedAddress!.cityName,
          );
          _isCalculatingDistance = false;
        });

        print('Distance calculated: ${distance?.toString()}');
        print('Store delivery available: ${_storeDeliveryOption?.isAvailable}');
      } else {
        // Jika tidak ada alamat, buat opsi default untuk menunjukkan fitur
        setState(() {
          _distanceResult = null;
          _storeDeliveryOption = StoreDeliveryOption.createDefault();
          _isCalculatingDistance = false;
        });
      }
    } catch (e) {
      setState(() {
        _distanceResult = null;
        _storeDeliveryOption = StoreDeliveryOption.createDefault();
        _isCalculatingDistance = false;
      });
      print('Error calculating distance: $e');
    }
  }

  Future<void> _calculateShippingCosts() async {
    if (_selectedAddress == null || _selectedItems.isEmpty) {
      setState(() {
        _availableShipping = [];
        _selectedShipping = null;
        _shippingError = null;
      });
      // Tetap hitung jarak untuk opsi toko
      await _calculateDistanceAndStoreDelivery();
      return;
    }

    // Hitung jarak dan opsi toko terlebih dahulu
    await _calculateDistanceAndStoreDelivery();

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
          double itemWeight = 1000; // Default 1kg

          if (item.hasVariant) {
            final product = await _getProductById(item.productId);
            if (product != null && product.hasVariants) {
              final combinations = product.getVariantCombinations();
              final matchingCombination = combinations.firstWhere(
                (c) => c.id == item.variantId,
                orElse:
                    () => ProductVariantCombination(
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
            final product = await _getProductById(item.productId);
            if (product?.weight != null) {
              itemWeight = product!.weight! * 1000;
            }
          }

          totalWeight += (itemWeight * item.quantity);
        }
      }

      if (totalWeight <= 0) {
        setState(() {
          _shippingError = 'Tidak dapat menghitung berat paket';
          _isCalculatingShipping = false;
        });
        return;
      }

      // Calculate shipping costs
      final shippingCosts = await RajaOngkirService.calculateCostWithIds(
        originId: _storeOriginId,
        destinationId: _selectedAddress!.subdistrictId,
        weight: totalWeight.toInt(),
      );

      final validShippingCosts =
          shippingCosts.where((cost) => cost.cost != 0).toList();

      if (validShippingCosts.isEmpty) {
        setState(() {
          _shippingError =
              'Tidak ada layanan pengiriman yang tersedia untuk alamat ini.';
          _isCalculatingShipping = false;
        });
        return;
      }

      // Sort by price (cheapest first)
      validShippingCosts.sort((a, b) => a.cost.compareTo(b.cost));

      setState(() {
        _availableShipping = validShippingCosts;

        // Auto select store delivery jika tersedia dan lebih murah
        if (_storeDeliveryOption?.isAvailable == true) {
          final cheapestRegular = validShippingCosts.first.cost;
          if (_storeDeliveryOption!.cost <= cheapestRegular) {
            _selectedShipping = _convertStoreDeliveryToShippingCost(
              _storeDeliveryOption!,
            );
          } else {
            _selectedShipping = validShippingCosts.first;
          }
        } else {
          _selectedShipping = validShippingCosts.first;
        }

        _isCalculatingShipping = false;
      });
    } catch (e) {
      setState(() {
        _shippingError = 'Gagal menghitung ongkos kirim: $e';
        _isCalculatingShipping = false;
        _availableShipping = [];
        _selectedShipping = null;
      });
    }
  }

  // Convert store delivery ke ShippingCost format
  ShippingCost _convertStoreDeliveryToShippingCost(
    StoreDeliveryOption storeOption,
  ) {
    return ShippingCost(
      name: 'Toko Barokah',
      code: 'STORE',
      service: storeOption.name,
      description: storeOption.fullDescription,
      cost: storeOption.cost,
      etd: storeOption.estimatedTime,
    );
  }

  Future<Product?> _getProductById(String productId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
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
      builder:
          (context) => AlertDialog(
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

  // DIUPDATE - Selalu tampilkan opsi pengiriman toko
  void _showShippingModal() {
    List<Widget> shippingOptions = [];

    // Selalu tambahkan opsi pengiriman toko (bahkan jika tidak tersedia/disabled)
    if (_storeDeliveryOption != null) {
      shippingOptions.add(_buildStoreDeliveryOption(_storeDeliveryOption!));
    }

    // Tambahkan divider jika ada opsi toko dan ekspedisi
    if (_storeDeliveryOption != null && _availableShipping.isNotEmpty) {
      shippingOptions.add(const Divider(height: 1));
    }

    // Tambahkan opsi pengiriman reguler
    if (_availableShipping.isNotEmpty) {
      shippingOptions.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Pengiriman Ekspedisi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
      );

      for (final shipping in _availableShipping) {
        shippingOptions.add(_buildShippingOption(shipping));
      }
    }

    // Jika tidak ada opsi sama sekali, tampilkan pesan
    if (shippingOptions.isEmpty) {
      _showErrorSnackBar(
        'Pilih alamat terlebih dahulu untuk melihat opsi pengiriman',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
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
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Pilih Metode Pengiriman',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: ListView(shrinkWrap: true, children: shippingOptions),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // WIDGET DIUPDATE - Handle disabled state untuk store delivery
  Widget _buildStoreDeliveryOption(StoreDeliveryOption option) {
    final isSelected = _selectedShipping?.code == 'STORE' && option.isAvailable;
    final isDisabled = !option.isAvailable;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDisabled
                  ? [Colors.grey.shade100, Colors.grey.shade200]
                  : isSelected
                  ? [
                    const Color(0xFF2E7D32).withOpacity(0.1),
                    Colors.green.shade50,
                  ]
                  : [Colors.white, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color:
              isDisabled
                  ? Colors.grey.shade300
                  : isSelected
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        enabled: !isDisabled,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  isDisabled
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : [const Color(0xFF2E7D32), Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.store, color: Colors.white, size: 24),
        ),
        title: Row(
          children: [
            Text(
              option.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDisabled ? Colors.grey.shade600 : null,
              ),
            ),
            const SizedBox(width: 8),
            if (!isDisabled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'REKOMENDASI',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TIDAK TERSEDIA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              option.description,
              style: TextStyle(
                fontSize: 12,
                color: isDisabled ? Colors.grey.shade500 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            if (option.distance != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: isDisabled ? Colors.grey.shade400 : Colors.blue[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    option.distance!.distanceText,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDisabled ? Colors.grey.shade400 : Colors.blue[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color:
                        isDisabled ? Colors.grey.shade400 : Colors.orange[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    option.estimatedTime,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDisabled
                              ? Colors.grey.shade400
                              : Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            if (isDisabled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  option.unavailableReason,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (option.distance?.isEstimate == true) ...[
              Text(
                'Estimasi berdasarkan lokasi kota',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              option.formattedCost,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color:
                    isDisabled ? Colors.grey.shade500 : const Color(0xFF2E7D32),
              ),
            ),
            if (isSelected && !isDisabled) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2E7D32),
                size: 20,
              ),
            ],
          ],
        ),
        onTap:
            isDisabled
                ? null
                : () {
                  setState(() {
                    _selectedShipping = _convertStoreDeliveryToShippingCost(
                      option,
                    );
                  });
                  Navigator.pop(context);
                },
      ),
    );
  }

  // Widget untuk shipping section - UPDATED
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
                            color:
                                _selectedAddress != null
                                    ? const Color(0xFF2D3748)
                                    : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Store delivery info banner - UPDATED
          if (_isCalculatingDistance) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mengecek ketersediaan pengiriman toko...',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (_storeDeliveryOption?.isAvailable == true) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        color: Colors.green.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pengiriman Toko Tersedia!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_distanceResult != null)
                    Text(
                      'Jarak ${_distanceResult!.distanceText} • ${_storeDeliveryOption!.formattedCost}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (_storeDeliveryOption != null &&
              !_storeDeliveryOption!.isAvailable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pengiriman Toko Tidak Tersedia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _storeDeliveryOption!.unavailableReason,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

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
                    _selectedShipping?.code == 'STORE'
                        ? Icons.store
                        : Icons.local_shipping_outlined,
                    color:
                        _selectedShipping?.code == 'STORE'
                            ? Colors.green[600]
                            : Colors.grey[600],
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue[600]!,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Menghitung ongkos kirim...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
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
                          Row(
                            children: [
                              if (_selectedShipping!.code == 'STORE') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'TOKO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  '${_selectedShipping!.courierDisplayName} - ${_selectedShipping!.service}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ),
                            ],
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
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shipping option builder (existing)
  Widget _buildShippingOption(ShippingCost shipping) {
    final isSelected =
        _selectedShipping?.code == shipping.code &&
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
          shipping.courierDisplayName,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2E7D32),
                size: 16,
              ),
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

  // Rest of the methods remain the same...
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
        ],
      ),
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
              color:
                  color ??
                  (isTotal ? const Color(0xFF2E7D32) : const Color(0xFF2D3748)),
            ),
          ),
        ],
      ),
    );
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
                      const SizedBox(height: 100),
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

  // Rest of widget builders remain the same...
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
                _calculateShippingCosts();
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
            child: CartItemTile(
              item: item,
              isSelected: isSelected,
              onSelectionChanged: () => _toggleItemSelection(item.id),
              onQuantityChanged: (newQuantity) {
                cartService.updateQuantity(item.id, newQuantity);
                _calculateShippingCosts();
              },
              onRemove: () {
                cartService.removeItem(item.id);
                setState(() {
                  _selectedItems.remove(item.id);
                });
                _calculateShippingCosts();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomCheckoutBar(CartService cartService) {
    final selectedTotal = _calculateSelectedTotal(cartService);
    final shippingCost = _selectedShipping?.cost.toDouble() ?? 0;
    final discount = _selectedVoucher.isNotEmpty ? 10000 : 0;
    final total = selectedTotal + shippingCost - discount;

    final canCheckout =
        _selectedItems.isNotEmpty &&
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isValidating || _isCalculatingShipping
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Checkout (${_getSelectedItemsCount()})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  canCheckout
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

  // Address Modal (same as before)
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
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Pilih Alamat Pengiriman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
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
                child:
                    _userAddresses.isEmpty
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
                            final isSelected =
                                _selectedAddress?.id == address.id;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? const Color(0xFF2E7D32)
                                          : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Text(
                                      address.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (address.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                trailing:
                                    isSelected
                                        ? const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF2E7D32),
                                        )
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

    setState(() {
      _isValidating = true;
    });

    try {
      final issues = await cartService.validateCart();
      final selectedItemIssues =
          issues.where((issue) {
            return _selectedItems.any((itemId) {
              final item = cartService.items.firstWhere(
                (i) => i.id == itemId,
                orElse:
                    () => CartItem.fromProduct(
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
      final shippingCost = _selectedShipping!.cost.toDouble();
      final total =
          selectedTotal +
          shippingCost -
          (_selectedVoucher.isNotEmpty ? 10000 : 0);

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
      builder:
          (context) => AlertDialog(
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
                const Expanded(
                  child: Text(
                    'Konfirmasi Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                          _buildSummaryRow(
                            'Total Item',
                            '${_getSelectedItemsCount()} produk',
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Subtotal',
                            _formatCurrency(subtotal),
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Ongkos Kirim',
                            _formatCurrency(shipping),
                          ),
                          if (_selectedVoucher.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Diskon',
                              '-Rp 10.000',
                              color: Colors.green,
                            ),
                          ],
                          const Divider(height: 20),
                          _buildSummaryRow(
                            'Total Pembayaran',
                            _formatCurrency(total),
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shipping info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _selectedShipping!.code == 'STORE'
                                ? Colors.green.shade50
                                : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _selectedShipping!.code == 'STORE'
                                  ? Colors.green.shade200
                                  : Colors.blue.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedShipping!.code == 'STORE'
                                    ? Icons.store
                                    : Icons.local_shipping,
                                color:
                                    _selectedShipping!.code == 'STORE'
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedShipping!.code == 'STORE'
                                    ? 'Pengiriman Toko'
                                    : 'Pengiriman Ekspedisi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _selectedShipping!.code == 'STORE'
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_selectedShipping!.courierDisplayName} - ${_selectedShipping!.service}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Ke: ${_selectedAddress!.cityName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Estimasi: ${_selectedShipping!.etd}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
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
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedShipping!.code == 'STORE'
                                  ? 'Pesanan akan dikirim langsung oleh Toko Barokah'
                                  : 'Pesanan akan diproses dari Toko Barokah, Laren - Lamongan',
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

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
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
            color:
                color ??
                (isTotal ? const Color(0xFF2E7D32) : const Color(0xFF2D3748)),
          ),
        ),
      ],
    );
  }

  Future<void> _processCheckout() async {
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

    // Navigate to checkout page
    final cartService = Provider.of<CartService>(context, listen: false);
    final selectedCartItems =
        cartService.items
            .where((item) => _selectedItems.contains(item.id))
            .toList();

    final selectedTotal = _calculateSelectedTotal(cartService);
    final shippingCost = _selectedShipping!.cost.toDouble();
    final total =
        selectedTotal +
        shippingCost -
        (_selectedVoucher.isNotEmpty ? 10000 : 0);

    // Navigate ke checkout page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CheckoutPage(
              selectedItems: selectedCartItems,
              address: _selectedAddress!,
              shipping: _selectedShipping!,
              subtotal: selectedTotal,
              shippingCost: shippingCost,
              total: total,
            ),
      ),
    );
  }
}
