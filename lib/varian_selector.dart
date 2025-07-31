import 'package:flutter/material.dart';
import '../models/product.dart';

class VariantSelector extends StatefulWidget {
  final Product product;
  final Function(Map<String, dynamic>? variant) onVariantSelected;
  final Map<String, dynamic>? initialVariant;

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
  Map<String, dynamic>? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.initialVariant;
    
    // Auto-select first variant if no initial variant and product has variants
    if (_selectedVariant == null && 
        widget.product.hasVariants && 
        widget.product.variants != null && 
        widget.product.variants!.isNotEmpty) {
      _selectedVariant = widget.product.variants!.first;
      widget.onVariantSelected(_selectedVariant);
    }
  }

  void _selectVariant(Map<String, dynamic> variant) {
    setState(() {
      _selectedVariant = variant;
    });
    widget.onVariantSelected(variant);
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  double _getVariantPrice(Map<String, dynamic> variant) {
    final priceAdjustment = (variant['priceAdjustment'] ?? 0).toDouble();
    return widget.product.price + priceAdjustment;
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if product doesn't have variants
    if (!widget.product.hasVariants || 
        widget.product.variants == null || 
        widget.product.variants!.isEmpty) {
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
          
          const SizedBox(height: 12),
          
          // Variants Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: widget.product.variants!.length,
            itemBuilder: (context, index) {
              final variant = widget.product.variants![index];
              final isSelected = _selectedVariant != null && 
                  _selectedVariant!['id'] == variant['id'];
              final isOutOfStock = (variant['stock'] ?? 0) <= 0;
              
              return GestureDetector(
                onTap: isOutOfStock ? null : () => _selectVariant(variant),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOutOfStock 
                        ? Colors.grey.shade100 
                        : isSelected 
                            ? const Color(0xFF2E7D32).withOpacity(0.1)
                            : Colors.white,
                    border: Border.all(
                      color: isOutOfStock
                          ? Colors.grey.shade300
                          : isSelected 
                              ? const Color(0xFF2E7D32) 
                              : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Variant name
                      Text(
                        variant['name'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock 
                              ? Colors.grey.shade500
                              : isSelected 
                                  ? const Color(0xFF2E7D32) 
                                  : const Color(0xFF2D3748),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Price and stock info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _formatCurrency(_getVariantPrice(variant)),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isOutOfStock 
                                    ? Colors.grey.shade500
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                          
                          // Stock or selected indicator
                          if (isOutOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Habis',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else if (isSelected)
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: const Color(0xFF2E7D32),
                            )
                          else
                            Text(
                              'Stok: ${variant['stock']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Selected variant info
          if (_selectedVariant != null) ...[
            const SizedBox(height: 12),
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
                          _selectedVariant!['name'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(_getVariantPrice(_selectedVariant!)),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  
                  // Additional variant info
                  if (_selectedVariant!['sku'] != null)
                    Text(
                      'SKU: ${_selectedVariant!['sku']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
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
  final Function(Map<String, dynamic>? variant) onVariantSelected;
  final Map<String, dynamic>? initialVariant;

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
  Map<String, dynamic>? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.initialVariant;
  }

  void _selectVariant(Map<String, dynamic> variant) {
    setState(() {
      _selectedVariant = variant;
    });
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  double _getVariantPrice(Map<String, dynamic> variant) {
    final priceAdjustment = (variant['priceAdjustment'] ?? 0).toDouble();
    return widget.product.price + priceAdjustment;
  }

  @override
  Widget build(BuildContext context) {
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
                          child: Image.network(
                            widget.product.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.construction, color: Colors.grey.shade400),
                          ),
                        )
                      : Icon(Icons.construction, color: Colors.grey.shade400),
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
          
          // Variants list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.product.variants?.length ?? 0,
              itemBuilder: (context, index) {
                final variant = widget.product.variants![index];
                final isSelected = _selectedVariant != null && 
                    _selectedVariant!['id'] == variant['id'];
                final isOutOfStock = (variant['stock'] ?? 0) <= 0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isOutOfStock
                          ? Colors.grey.shade300
                          : isSelected 
                              ? const Color(0xFF2E7D32) 
                              : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    enabled: !isOutOfStock,
                    onTap: isOutOfStock ? null : () => _selectVariant(variant),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOutOfStock 
                            ? Colors.grey.shade100
                            : isSelected
                                ? const Color(0xFF2E7D32).withOpacity(0.1)
                                : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune,
                        color: isOutOfStock 
                            ? Colors.grey.shade400
                            : isSelected 
                                ? const Color(0xFF2E7D32) 
                                : Colors.grey.shade600,
                      ),
                    ),
                    title: Text(
                      variant['name'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock 
                            ? Colors.grey.shade500 
                            : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCurrency(_getVariantPrice(variant)),
                          style: TextStyle(
                            color: isOutOfStock 
                                ? Colors.grey.shade500
                                : const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (variant['sku'] != null)
                          Text(
                            'SKU: ${variant['sku']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isOutOfStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Stok Habis',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2E7D32),
                          )
                        else
                          Text(
                            'Stok: ${variant['stock']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
                    onPressed: _selectedVariant == null 
                        ? null 
                        : () {
                            widget.onVariantSelected(_selectedVariant);
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
  required Function(Map<String, dynamic>? variant) onVariantSelected,
  Map<String, dynamic>? initialVariant,
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