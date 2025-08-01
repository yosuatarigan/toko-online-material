import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';

class VariantSelector extends StatefulWidget {
  final Product product;
  final Function(ProductVariantCombination? combination) onVariantSelected;
  final ProductVariantCombination? initialVariant;

  const VariantSelector({
    super.key,
    required this.product,
    required this.onVariantSelected,
    this.initialVariant,
  });

  @override
  State<VariantSelector> createState() => _VariantSelectorState();
}

class _VariantSelectorState extends State<VariantSelector> {
  ProductVariantCombination? _selectedCombination;
  Map<String, String> _selectedAttributes = {}; // attributeId: optionValue

  @override
  void initState() {
    super.initState();
    _selectedCombination = widget.initialVariant;
    
    if (_selectedCombination != null) {
      _selectedAttributes = Map.from(_selectedCombination!.attributes);
    }
    
    // Auto-select first available combination if no initial variant and product has variants
    if (_selectedCombination == null && widget.product.hasVariants) {
      final combinations = widget.product.getVariantCombinations();
      if (combinations.isNotEmpty) {
        final availableCombinations = combinations.where((c) => c.stock > 0 && c.isActive).toList();
        if (availableCombinations.isNotEmpty) {
          _selectedCombination = availableCombinations.first;
          _selectedAttributes = Map.from(_selectedCombination!.attributes);
          widget.onVariantSelected(_selectedCombination);
        }
      }
    }
  }

  void _updateAttributeSelection(String attributeId, String optionValue) {
    setState(() {
      _selectedAttributes[attributeId] = optionValue;
      
      // Find matching combination
      final combinations = widget.product.getVariantCombinations();
      final matchingCombination = combinations.firstWhere(
        (combination) => _mapEquals(combination.attributes, _selectedAttributes),
        orElse: () => ProductVariantCombination(
          id: '',
          attributes: {},
          sku: '',
          stock: 0,
        ),
      );
      
      if (matchingCombination.id.isNotEmpty) {
        _selectedCombination = matchingCombination;
      } else {
        _selectedCombination = null;
      }
      
      widget.onVariantSelected(_selectedCombination);
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

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if product doesn't have variants
    if (!widget.product.hasVariants) {
      return const SizedBox.shrink();
    }

    final attributes = widget.product.getVariantAttributes();
    final combinations = widget.product.getVariantCombinations();

    if (attributes.isEmpty || combinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.tune,
                size: 20,
                color: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pilih Varian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: attribute.options.map((option) {
                    final isSelected = _selectedAttributes[attribute.id] == option;
                    
                    // Check if this option is available in any combination
                    final isAvailable = combinations.any((combination) =>
                        combination.attributes[attribute.id] == option &&
                        combination.stock > 0 &&
                        combination.isActive);
                    
                    return GestureDetector(
                      onTap: isAvailable ? () {
                        _updateAttributeSelection(attribute.id, option);
                      } : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF2E7D32).withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF2E7D32)
                                : isAvailable ? Colors.grey[300]! : Colors.red[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isAvailable 
                                ? (isSelected ? const Color(0xFF2E7D32) : const Color(0xFF2D3748))
                                : Colors.red,
                            decoration: isAvailable ? null : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
          
          // Selected combination info
          if (_selectedCombination != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Varian Terpilih:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getCombinationDisplayName(_selectedCombination!),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(widget.product.price + _selectedCombination!.priceAdjustment),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  
                  // Additional combination info
                  Text(
                    'SKU: ${_selectedCombination!.sku} | Stok: ${_selectedCombination!.stock}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (attributes.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Silakan pilih semua opsi varian',
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
}

// Modal untuk memilih varian (untuk dialog atau bottom sheet)
class VariantSelectorModal extends StatefulWidget {
  final Product product;
  final Function(ProductVariantCombination? combination) onVariantSelected;
  final ProductVariantCombination? initialVariant;

  const VariantSelectorModal({
    super.key,
    required this.product,
    required this.onVariantSelected,
    this.initialVariant,
  });

  @override
  State<VariantSelectorModal> createState() => _VariantSelectorModalState();
}

class _VariantSelectorModalState extends State<VariantSelectorModal> {
  ProductVariantCombination? _selectedCombination;
  Map<String, String> _selectedAttributes = {};

  @override
  void initState() {
    super.initState();
    _selectedCombination = widget.initialVariant;
    
    if (_selectedCombination != null) {
      _selectedAttributes = Map.from(_selectedCombination!.attributes);
    }
  }

  void _updateAttributeSelection(String attributeId, String optionValue) {
    setState(() {
      _selectedAttributes[attributeId] = optionValue;
      
      // Find matching combination
      final combinations = widget.product.getVariantCombinations();
      final matchingCombination = combinations.firstWhere(
        (combination) => _mapEquals(combination.attributes, _selectedAttributes),
        orElse: () => ProductVariantCombination(
          id: '',
          attributes: {},
          sku: '',
          stock: 0,
        ),
      );
      
      if (matchingCombination.id.isNotEmpty) {
        _selectedCombination = matchingCombination;
      } else {
        _selectedCombination = null;
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

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final attributes = widget.product.getVariantAttributes();
    final combinations = widget.product.getVariantCombinations();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
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
                  'Pilih Varian Produk',
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
          
          // Product info
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.product.imageUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: widget.product.imageUrls.first,
                            fit: BoxFit.cover,
                            // errorBuilder: (context, error, stackTrace) =>
                            //     Icon(Icons.image, color: Colors.grey.shade400),
                          ),
                        )
                      : Icon(Icons.image, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Harga dasar: ${_formatCurrency(widget.product.price)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Variant attributes
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...attributes.map((attribute) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            attribute.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attribute.options.map((option) {
                            final isSelected = _selectedAttributes[attribute.id] == option;
                            
                            // Check if this option is available in any combination
                            final isAvailable = combinations.any((combination) =>
                                combination.attributes[attribute.id] == option &&
                                combination.stock > 0 &&
                                combination.isActive);
                            
                            return GestureDetector(
                              onTap: isAvailable ? () {
                                _updateAttributeSelection(attribute.id, option);
                              } : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected 
                                        ? const Color(0xFF2E7D32)
                                        : isAvailable ? Colors.grey[300]! : Colors.red[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isAvailable 
                                            ? (isSelected ? const Color(0xFF2E7D32) : const Color(0xFF2D3748))
                                            : Colors.red,
                                        decoration: isAvailable ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF2E7D32),
                                        size: 16,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                  
                  // Selected combination preview
                  if (_selectedCombination != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Kombinasi Terpilih:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getCombinationDisplayName(_selectedCombination!),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SKU: ${_selectedCombination!.sku}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                              Text(
                                'Stok: ${_selectedCombination!.stock}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCurrency(widget.product.price + _selectedCombination!.priceAdjustment),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedCombination == null 
                        ? null 
                        : () {
                            widget.onVariantSelected(_selectedCombination);
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Pilih'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Function to show variant selector modal
void showVariantSelectorModal({
  required BuildContext context,
  required Product product,
  required Function(ProductVariantCombination? combination) onVariantSelected,
  ProductVariantCombination? initialVariant,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: VariantSelectorModal(
        product: product,
        onVariantSelected: onVariantSelected,
        initialVariant: initialVariant,
      ),
    ),
  );
}