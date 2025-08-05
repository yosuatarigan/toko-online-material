import 'package:flutter/material.dart';
import '../models/address.dart';
import '../service/shipping_service.dart';
import '../address_list_page.dart';

class ShippingCostWidget extends StatefulWidget {
  final UserAddress? selectedAddress;
  final int totalWeight; // in grams
  final Function(UserAddress) onAddressChanged;
  final Function(ShippingCostDetail?) onShippingCostChanged;

  const ShippingCostWidget({
    super.key,
    required this.selectedAddress,
    required this.totalWeight,
    required this.onAddressChanged,
    required this.onShippingCostChanged,
  });

  @override
  State<ShippingCostWidget> createState() => _ShippingCostWidgetState();
}

class _ShippingCostWidgetState extends State<ShippingCostWidget> {
  final ShippingService _shippingService = ShippingService();
  
  Map<String, List<CourierOption>> _shippingOptions = {};
  ShippingCostDetail? _selectedShipping;
  bool _isLoadingShipping = false;
  String? _shippingError;
  bool _isInitialized = false;
  
  // Prevent rapid rebuild cycles
  String? _lastAddressId;
  int _lastWeight = 0;

  @override
  void initState() {
    super.initState();
    // Defer initialization to prevent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWidget();
    });
  }

  void _initializeWidget() {
    if (!mounted) return;
    
    // Initialize tracking values
    _lastAddressId = widget.selectedAddress?.id;
    _lastWeight = widget.totalWeight;
    
    setState(() {
      _isInitialized = true;
    });
    
    // Load shipping costs if address is available
    if (widget.selectedAddress != null) {
      _loadShippingCosts();
    }
  }

  @override
  void didUpdateWidget(ShippingCostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (!_isInitialized) return;
    
    // Only reload if there's a significant change
    final addressChanged = oldWidget.selectedAddress?.id != widget.selectedAddress?.id;
    final weightChanged = (oldWidget.totalWeight - widget.totalWeight).abs() > 100; // 100g threshold
    
    if (addressChanged || weightChanged) {
      _resetState();
      
      if (widget.selectedAddress != null) {
        // Add small delay to prevent rapid successive calls
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && 
              (widget.selectedAddress?.id != _lastAddressId || 
               (widget.totalWeight - _lastWeight).abs() > 100)) {
            _loadShippingCosts();
          }
        });
      }
    }
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _selectedShipping = null;
        _shippingOptions = {};
        _shippingError = null;
        _isLoadingShipping = false;
      });
      
      // Notify parent about reset
      widget.onShippingCostChanged(null);
    }
  }

  Future<void> _loadShippingCosts() async {
    if (widget.selectedAddress == null || !mounted) return;

    // Update tracking values
    _lastAddressId = widget.selectedAddress!.id;
    _lastWeight = widget.totalWeight;

    setState(() {
      _isLoadingShipping = true;
      _shippingError = null;
    });

    try {
      final options = await _shippingService.getAllShippingOptions(
        destinationCityId: widget.selectedAddress!.cityId,
        weight: widget.totalWeight,
      );

      if (mounted) {
        setState(() {
          _shippingOptions = options;
          _isLoadingShipping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingShipping = false;
          _shippingError = e.toString();
        });
      }
    }
  }

  void _selectAddress() async {
    try {
      final result = await Navigator.push<UserAddress>(
        context,
        MaterialPageRoute(
          builder: (context) => AddressListPage(
            isSelectionMode: true,
            selectedAddress: widget.selectedAddress,
            onAddressSelected: (address) {
              widget.onAddressChanged(address);
            },
          ),
        ),
      );

      if (result != null && mounted) {
        widget.onAddressChanged(result);
      }
    } catch (e) {
      debugPrint('Error navigating to address list: $e');
    }
  }

  void _selectShippingOption(ShippingCostDetail shipping) {
    if (mounted) {
      setState(() {
        _selectedShipping = shipping;
      });
      widget.onShippingCostChanged(shipping);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader(),
          _buildAddressSelector(),
          if (widget.selectedAddress != null) ...[
            _buildWeightInfo(),
            _buildShippingOptions(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Color(0xFF2E7D32),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Pengiriman',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _selectAddress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.selectedAddress != null
                ? _buildSelectedAddress()
                : _buildSelectAddressPrompt(),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAddress() {
    final address = widget.selectedAddress!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                address.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Ubah',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade600,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.blue.shade600,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          address.recipientName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          address.recipientPhone,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          address.fullDisplayAddress,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSelectAddressPrompt() {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          color: Colors.grey[400],
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Alamat Pengiriman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              Text(
                'Untuk menghitung ongkos kirim',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
      ],
    );
  }

  Widget _buildWeightInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.scale, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            'Total berat: ${_shippingService.formatWeight(widget.totalWeight)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingOptions() {
    if (_isLoadingShipping) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text(
                'Menghitung ongkos kirim...',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_shippingError != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal menghitung ongkos kirim',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Coba lagi atau pilih alamat lain',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadShippingCosts,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_shippingOptions.isEmpty || 
        _shippingOptions.values.every((options) => options.isEmpty)) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Tidak ada opsi pengiriman tersedia',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Pilih Layanan Pengiriman',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        ..._buildShippingOptionsList(),
        const SizedBox(height: 12),
      ],
    );
  }

  List<Widget> _buildShippingOptionsList() {
    final List<Widget> widgets = [];
    int optionIndex = 0; // Add index for unique keys

    _shippingOptions.forEach((courierCode, courierOptions) {
      if (courierOptions.isNotEmpty) {
        for (final courier in courierOptions) {
          for (final service in courier.costs) {
            for (final cost in service.cost) {
              widgets.add(_buildShippingOptionCard(
                key: ValueKey('shipping_option_${courierCode}_${service.service}_${cost.value}_$optionIndex'),
                courierName: courier.name,
                service: service,
                cost: cost,
              ));
              optionIndex++;
            }
          }
        }
      }
    });

    return widgets;
  }

  Widget _buildShippingOptionCard({
    Key? key,
    required String courierName,
    required ShippingCost service,
    required ShippingCostDetail cost,
  }) {
    final isSelected = _selectedShipping == cost;

    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF2E7D32) 
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectShippingOption(cost),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
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
                    Icons.local_shipping,
                    color: Color(0xFF2E7D32),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$courierName - ${service.service}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estimasi: ${cost.estimatedDelivery}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cost.formattedCost,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF2E7D32),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}