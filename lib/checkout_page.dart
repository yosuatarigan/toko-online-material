// lib/checkout_page.dart (Updated)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:toko_online_material/models/cartitem.dart';
import 'package:toko_online_material/models/address_model.dart';
import 'package:toko_online_material/models/order_model.dart' as order_model;
import 'package:toko_online_material/models/product.dart';
import 'package:toko_online_material/service/rajaongkir_service.dart';
import 'package:toko_online_material/service/distance_service.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> selectedItems;
  final double subtotal;

  const CheckoutPage({
    super.key,
    required this.selectedItems,
    required this.subtotal,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  File? _paymentProof;
  String? _orderId;

  // Address & Shipping state
  List<Address> _userAddresses = [];
  Address? _selectedAddress;
  List<ShippingCost> _availableShipping = [];
  ShippingCost? _selectedShipping;
  bool _isLoadingAddresses = true;
  bool _isCalculatingShipping = false;
  String? _shippingError;

  // Store delivery state
  DistanceResult? _distanceResult;
  StoreDeliveryOption? _storeDeliveryOption;
  bool _isCalculatingDistance = false;

  // Fixed origin ID untuk toko
  static const String _storeOriginId = '69943';

  @override
  void initState() {
    super.initState();
    _loadUserAddresses();
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

        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => addresses.first,
          );
          _calculateShippingCosts();
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingAddresses = false;
      });
      _showErrorSnackBar('Gagal memuat alamat: $e');
    }
  }

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
          _storeDeliveryOption = StoreDeliveryOption.createAlways(
            distance,
            _selectedAddress!.cityName,
          );
          _isCalculatingDistance = false;
        });
      } else {
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
    if (_selectedAddress == null) {
      setState(() {
        _availableShipping = [];
        _selectedShipping = null;
        _shippingError = null;
      });
      await _calculateDistanceAndStoreDelivery();
      return;
    }

    await _calculateDistanceAndStoreDelivery();

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
      // Calculate total weight
      double totalWeight = 0;
      for (final item in widget.selectedItems) {
        double itemWeight = 1000; // Default 1kg
        
        if (item.hasVariant) {
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
          final product = await _getProductById(item.productId);
          if (product?.weight != null) {
            itemWeight = product!.weight! * 1000;
          }
        }

        totalWeight += (itemWeight * item.quantity);
      }

      if (totalWeight <= 0) {
        setState(() {
          _shippingError = 'Tidak dapat menghitung berat paket';
          _isCalculatingShipping = false;
        });
        return;
      }

      final shippingCosts = await RajaOngkirService.calculateCostWithIds(
        originId: _storeOriginId,
        destinationId: _selectedAddress!.subdistrictId,
        weight: totalWeight.toInt(),
      );

      final validShippingCosts = shippingCosts.where((cost) => cost.cost != 0).toList();

      if (validShippingCosts.isEmpty) {
        setState(() {
          _shippingError = 'Tidak ada layanan pengiriman yang tersedia untuk alamat ini.';
          _isCalculatingShipping = false;
        });
        return;
      }

      validShippingCosts.sort((a, b) => a.cost.compareTo(b.cost));

      setState(() {
        _availableShipping = validShippingCosts;

        // Auto select store delivery if available and cheaper
        if (_storeDeliveryOption?.isAvailable == true) {
          final cheapestRegular = validShippingCosts.first.cost;
          if (_storeDeliveryOption!.cost <= cheapestRegular) {
            _selectedShipping = _convertStoreDeliveryToShippingCost(_storeDeliveryOption!);
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

  ShippingCost _convertStoreDeliveryToShippingCost(StoreDeliveryOption storeOption) {
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

  double get _shippingCost => _selectedShipping?.cost.toDouble() ?? 0;
  double get _total => widget.subtotal + _shippingCost;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildOrderSummary(),
                  _buildAddressSection(),
                  _buildShippingSection(),
                  _buildPaymentSummary(),
                  if (_orderId == null) _buildQRISPayment(),
                  if (_orderId != null) _buildUploadPaymentProof(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
               Text(
                'Pesanan (${widget.selectedItems.length} item)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.selectedItems.map((item) => _buildOrderItem(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported),
                    ),
                  )
                : const Icon(Icons.inventory),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} ${item.productUnit} × ${_formatCurrency(item.productPrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(item.totalPrice),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Alamat Pengiriman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingAddresses) ...[
            const Center(child: CircularProgressIndicator()),
          ] else if (_selectedAddress != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.green.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedAddress!.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedAddress!.isDefault) ...[
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
                  const SizedBox(height: 4),
                  Text(
                    _selectedAddress!.recipientName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _selectedAddress!.recipientPhone,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedAddress!.fullAddress,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showAddressModal,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Ganti Alamat'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: _showAddressModal,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_location, color: Colors.grey.shade600, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih Alamat Pengiriman',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShippingSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Metode Pengiriman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Store delivery info banner
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
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
                      Icon(Icons.local_offer, color: Colors.green.shade700, size: 16),
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
          ],

          // Shipping method selection
          if (_isCalculatingShipping) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  const Text('Menghitung ongkos kirim...'),
                ],
              ),
            ),
          ] else if (_shippingError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _shippingError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ] else if (_selectedShipping != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.green.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedShipping!.code == 'STORE' ? Icons.store : Icons.local_shipping,
                        color: _selectedShipping!.code == 'STORE' ? Colors.green : Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedShipping!.courierDisplayName} - ${_selectedShipping!.service}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _selectedShipping!.formattedCost,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimasi: ${_selectedShipping!.etd}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showShippingModal,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Ganti Metode Pengiriman'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
              ),
            ),
          ] else if (_selectedAddress != null) ...[
            GestureDetector(
              onTap: _showShippingModal,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.grey.shade600, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih Metode Pengiriman',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Pilih alamat terlebih dahulu untuk melihat opsi pengiriman',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Ringkasan Pembayaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal Produk', _formatCurrency(widget.subtotal)),
          _buildSummaryRow('Biaya Pengiriman', _formatCurrency(_shippingCost)),
          const Divider(height: 24),
          _buildSummaryRow('Total Pembayaran', _formatCurrency(_total), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
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
              fontWeight: FontWeight.bold,
              color: isTotal ? const Color(0xFF2E7D32) : const Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRISPayment() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Pembayaran QRIS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              children: [
                const Text(
                  'Scan QR Code untuk melakukan pembayaran',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // QR Code Image with Zoom functionality
                GestureDetector(
                  onTap: () => _showQRZoom(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/qris.jpg',
                          height: 200,
                          width: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            width: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('QR Code', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        // Zoom indicator overlay
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Download and Zoom buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _downloadQRImage,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple.shade600,
                          side: BorderSide(color: Colors.purple.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showQRZoom,
                        icon: const Icon(Icons.zoom_in, size: 18),
                        label: const Text('Perbesar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple.shade600,
                          side: BorderSide(color: Colors.purple.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total yang harus dibayar: ${_formatCurrency(_total)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tap gambar QR untuk memperbesar atau download',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPaymentProof() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Upload Bukti Pembayaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_paymentProof != null) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_paymentProof!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.edit),
                    label: const Text('Ganti Foto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _uploadPaymentProof,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isLoading ? 'Mengirim...' : 'Kirim Bukti'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'Tap untuk upload bukti pembayaran',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format: JPG, PNG (Max 5MB)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final canCreateOrder = _selectedAddress != null && _selectedShipping != null && _orderId == null;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatCurrency(_total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canCreateOrder ? (_isLoading ? null : _createOrder) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Membuat Pesanan...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _orderId != null
                              ? 'Pesanan Dibuat'
                              : canCreateOrder
                              ? 'Buat Pesanan'
                              : 'Lengkapi Data Pengiriman',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: canCreateOrder ? Colors.white : Colors.grey.shade600,
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

  // Modal implementations and other methods...
  void _showAddressModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                                  color: isSelected
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
                                      style: const TextStyle(fontWeight: FontWeight.w600),
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
      ),
    );
  }

  void _showShippingModal() {
    List<Widget> shippingOptions = [];

    // Add store delivery option if available
    if (_storeDeliveryOption != null) {
      shippingOptions.add(_buildStoreDeliveryOption(_storeDeliveryOption!));
    }

    // Add divider if both options exist
    if (_storeDeliveryOption != null && _availableShipping.isNotEmpty) {
      shippingOptions.add(const Divider(height: 1));
    }

    // Add regular shipping options
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

    if (shippingOptions.isEmpty) {
      _showErrorSnackBar('Tidak ada opsi pengiriman tersedia');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                  const Text(
                    'Pilih Metode Pengiriman',
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

  Widget _buildStoreDeliveryOption(StoreDeliveryOption option) {
    final isSelected = _selectedShipping?.code == 'STORE' && option.isAvailable;
    final isDisabled = !option.isAvailable;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDisabled
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
          color: isDisabled
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
              colors: isDisabled
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : [const Color(0xFF2E7D32), Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.store, color: Colors.white, size: 24),
        ),
        title: Text(
          option.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDisabled ? Colors.grey.shade600 : null,
          ),
        ),
        subtitle: Text(
          option.description,
          style: TextStyle(
            fontSize: 12,
            color: isDisabled ? Colors.grey.shade500 : Colors.grey[600],
          ),
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
                color: isDisabled ? Colors.grey.shade500 : const Color(0xFF2E7D32),
              ),
            ),
            if (isSelected && !isDisabled) ...[
              const SizedBox(height: 4),
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
            ],
          ],
        ),
        onTap: isDisabled
            ? null
            : () {
                setState(() {
                  _selectedShipping = _convertStoreDeliveryToShippingCost(option);
                });
                Navigator.pop(context);
              },
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
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
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

  // Other methods remain the same...
  Future<void> _createOrder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not logged in';

      final orderItems = widget.selectedItems
          .map(
            (item) => order_model.OrderItem(
              productId: item.productId,
              productName: item.productName,
              variantId: item.variantId,
              variantName: item.variantName,
              price: item.productPrice,
              quantity: item.quantity,
              unit: item.productUnit,
              imageUrl: item.productImage,
            ),
          )
          .toList();

      final order = order_model.Order(
        id: '',
        userId: user.uid,
        userEmail: user.email ?? '',
        items: orderItems,
        address: order_model.OrderAddress(
          label: _selectedAddress!.label,
          recipientName: _selectedAddress!.recipientName,
          phone: _selectedAddress!.recipientPhone,
          fullAddress: _selectedAddress!.fullAddress,
          cityName: _selectedAddress!.cityName,
        ),
        shipping: order_model.OrderShipping(
          courierName: _selectedShipping!.courierDisplayName,
          serviceName: _selectedShipping!.service,
          description: _selectedShipping!.description,
          cost: _shippingCost,
          etd: _selectedShipping!.etd,
        ),
        summary: order_model.OrderSummary(
          subtotal: widget.subtotal,
          shippingCost: _shippingCost,
          discount: 0,
          total: _total,
        ),
        status: order_model.OrderStatus.waitingPayment,
        paymentStatus: order_model.PaymentStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await FirebaseFirestore.instance.collection('orders').add(order.toMap());

      setState(() {
        _orderId = docRef.id;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibuat! Silakan upload bukti pembayaran.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat pesanan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _paymentProof = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadPaymentProof() async {
    if (_paymentProof == null || _orderId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final fileName = 'payment_proofs/${_orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_paymentProof!);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('orders').doc(_orderId!).update({
        'paymentProofUrl': downloadUrl,
        'paymentStatus': order_model.PaymentStatus.waitingConfirmation.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bukti pembayaran berhasil dikirim! Menunggu konfirmasi admin.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim bukti pembayaran: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  // QR Code Zoom and Download functions
  void _showQRZoom() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Zoomable QR Code
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40,
                  maxHeight: MediaQuery.of(context).size.height - 100,
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code, color: Colors.purple, size: 24),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'QR Code Pembayaran',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Image.asset(
                          'assets/qris.jpg',
                          width: 300,
                          height: 300,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code, size: 60, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'QR Code',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Total Pembayaran',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(_total),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _downloadQRImage();
                                },
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Download'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.purple.shade600,
                                  side: BorderSide(color: Colors.purple.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pinch untuk zoom, drag untuk geser',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadQRImage() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Mengunduh QR Code...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      // Check if Gal is supported
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final hasPermission = await Gal.requestAccess();
        if (!hasPermission) {
          _showErrorSnackBar('Izin akses galeri diperlukan untuk menyimpan gambar');
          return;
        }
      }

      // Load image from assets
      final ByteData bytes = await rootBundle.load('assets/qris.jpg');
      final Uint8List imageBytes = bytes.buffer.asUint8List();

      // Get temporary directory to save file temporarily
      final tempDir = await getTemporaryDirectory();
      final fileName = 'qris_toko_barokah_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      
      // Write image to temporary file
      await file.writeAsBytes(imageBytes);

      // Save to gallery using Gal
      await Gal.putImage(file.path, album: 'Toko Barokah');

      // Clean up temporary file
      if (await file.exists()) {
        await file.delete();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('QR Code berhasil disimpan ke galeri!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error downloading QR: $e');
      _showErrorSnackBar('Gagal mengunduh QR Code: ${e.toString()}');
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}