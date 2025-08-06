import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toko_online_material/service/image_upload_service.dart';
import '../models/product.dart';
import '../models/category.dart';
import 'dart:io';

class AddEditProductPage extends StatefulWidget {
  final Product? product;

  const AddEditProductPage({super.key, this.product});

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();

  // Variables
  String _selectedCategoryId = '';
  String _selectedCategoryName = '';
  String _selectedUnit = 'pcs';
  bool _isActive = true;
  bool _isLoading = false;
  List<Category> _categories = [];

  // Images
  List<String> _existingImageUrls = [];
  List<XFile> _newImages = [];
  List<String> _imagesToDelete = [];
  bool _isUploadingImages = false;
  double _uploadProgress = 0.0;

  // Enhanced Variants
  List<VariantAttribute> _variantAttributes = [];
  List<ProductVariantCombination> _variantCombinations = [];
  bool _hasVariants = false;

  final List<String> _availableUnits = [
    'pcs', 'kg', 'gram', 'meter', 'cm', 'liter', 'ml', 
    'pack', 'box', 'roll', 'sheet', 'sak', 'batang',
  ];

  bool get isEditMode => widget.product != null;
  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCategories();
    if (isEditMode) {
      _fillFormWithProductData();
    } else {
      _generateSKU();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // Load Categories
  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();
      setState(() {
        _categories = snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat kategori: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Fill Form Data
  void _fillFormWithProductData() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price.toString();
    _stockController.text = product.stock.toString();
    _skuController.text = product.sku;
    _weightController.text = product.weight?.toString() ?? '1000';
    _selectedCategoryId = product.categoryId;
    _selectedCategoryName = product.categoryName;
    _selectedUnit = product.unit;
    _isActive = product.isActive;
    _existingImageUrls = List.from(product.imageUrls);
    _hasVariants = product.hasVariants;

    if (_hasVariants && product.variantAttributes != null && product.variantCombinations != null) {
      _variantAttributes = product.variantAttributes!
          .map((attr) => VariantAttribute.fromMap(attr))
          .toList();
      _variantCombinations = product.variantCombinations!
          .map((comb) => ProductVariantCombination.fromMap(comb))
          .toList();
    }
  }

  void _generateSKU() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _skuController.text = 'PRD$timestamp';
  }

  // Enhanced Variant Management
  void _showAddVariantAttributeDialog() {
    final nameController = TextEditingController();
    final optionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Atribut Varian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Atribut',
                hintText: 'Contoh: Ukuran, Warna, Model',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: optionsController,
              decoration: const InputDecoration(
                labelText: 'Opsi (pisahkan dengan koma)',
                hintText: 'Contoh: S, M, L atau Merah, Biru, Hijau',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final optionsText = optionsController.text.trim();
              
              if (name.isNotEmpty && optionsText.isNotEmpty) {
                final options = optionsText
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                
                if (options.isNotEmpty) {
                  _addVariantAttribute(name, options);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _addVariantAttribute(String name, List<String> options) {
    final attribute = VariantAttribute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      options: options,
    );
    setState(() {
      _variantAttributes.add(attribute);
    });
    _generateVariantCombinations();
  }

  void _editVariantAttribute(int index) {
    final attribute = _variantAttributes[index];
    final nameController = TextEditingController(text: attribute.name);
    final optionsController = TextEditingController(text: attribute.options.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Atribut Varian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Atribut'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: optionsController,
              decoration: const InputDecoration(
                labelText: 'Opsi (pisahkan dengan koma)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final optionsText = optionsController.text.trim();
              
              if (name.isNotEmpty && optionsText.isNotEmpty) {
                final options = optionsText
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                
                if (options.isNotEmpty) {
                  setState(() {
                    _variantAttributes[index] = VariantAttribute(
                      id: attribute.id,
                      name: name,
                      options: options,
                    );
                  });
                  _generateVariantCombinations();
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _generateVariantCombinations() {
    if (_variantAttributes.isEmpty) {
      setState(() {
        _variantCombinations.clear();
      });
      return;
    }

    List<List<String>> allOptions = _variantAttributes.map((attr) => attr.options).toList();
    List<List<String>> combinations = _generateCombinations(allOptions);
    List<ProductVariantCombination> newCombinations = [];

    // Get default weight from base product or use 1000g
    final defaultWeight = double.tryParse(_weightController.text) ?? 1000;

    for (var combo in combinations) {
      Map<String, String> attributes = {};
      for (int i = 0; i < combo.length; i++) {
        attributes[_variantAttributes[i].id] = combo[i];
      }

      // Check if combination already exists
      final existing = _variantCombinations.firstWhere(
        (existing) => _mapEquals(existing.attributes, attributes),
        orElse: () => ProductVariantCombination(
          id: '',
          attributes: {},
          sku: '',
          stock: 0,
          weight: defaultWeight, // Set default weight
        ),
      );

      if (existing.id.isNotEmpty) {
        newCombinations.add(existing);
      } else {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final baseSku = _skuController.text.isNotEmpty ? _skuController.text : 'PRD';

        newCombinations.add(
          ProductVariantCombination(
            id: timestamp + newCombinations.length.toString(),
            attributes: attributes,
            sku: '$baseSku-${newCombinations.length + 1}',
            stock: 0,
            weight: defaultWeight, // Set default weight 1000g
          ),
        );
      }
    }

    setState(() {
      _variantCombinations = newCombinations;
    });
  }

  List<List<String>> _generateCombinations(List<List<String>> lists) {
    if (lists.isEmpty) return [];
    if (lists.length == 1) return lists[0].map((item) => [item]).toList();

    List<List<String>> result = [];
    List<List<String>> subCombinations = _generateCombinations(lists.sublist(1));

    for (String item in lists[0]) {
      for (List<String> subCombination in subCombinations) {
        result.add([item, ...subCombination]);
      }
    }
    return result;
  }

  bool _mapEquals(Map<String, String> map1, Map<String, String> map2) {
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  String _getCombinationDisplayName(ProductVariantCombination combination) {
    List<String> parts = [];
    for (String attributeId in combination.attributes.keys) {
      final attribute = _variantAttributes.firstWhere(
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

  // Image Management
  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await ImageUploadService.pickMultipleImages();
      if (images != null && images.isNotEmpty) {
        if (_totalImageCount + images.length > 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maksimal 10 gambar per produk'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        setState(() {
          _newImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeNewImage(int index) => setState(() {
    _newImages.removeAt(index);
  });

  void _removeExistingImage(int index) => setState(() {
    _imagesToDelete.add(_existingImageUrls[index]);
    _existingImageUrls.removeAt(index);
  });

  // Category Picker
  void _showCategoryPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Kategori'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return ListTile(
                title: Text(category.name),
                subtitle: Text(category.description),
                onTap: () {
                  setState(() {
                    _selectedCategoryId = category.id;
                    _selectedCategoryName = category.name;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Save Product
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih kategori'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete old images
      if (_imagesToDelete.isNotEmpty) {
        await ImageUploadService.deleteMultipleImages(_imagesToDelete);
      }

      // Upload new images
      List<String> newImageUrls = [];
      if (_newImages.isNotEmpty) {
        newImageUrls = await ImageUploadService.uploadMultipleImages(
          imageFiles: _newImages,
          folder: 'products',
          onProgress: (completed, total) => setState(() {
            _uploadProgress = completed / total;
          }),
        );
      }

      final allImageUrls = [..._existingImageUrls, ...newImageUrls];
      final now = DateTime.now();
      final totalStock = _hasVariants
          ? _variantCombinations.fold(0, (sum, c) => sum + c.stock)
          : int.parse(_stockController.text);

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'stock': totalStock,
        'categoryId': _selectedCategoryId,
        'categoryName': _selectedCategoryName,
        'unit': _selectedUnit,
        'imageUrls': allImageUrls,
        'isActive': _isActive,
        'sku': _skuController.text.trim(),
        'weight': _weightController.text.isNotEmpty ? double.parse(_weightController.text) : null,
        'hasVariants': _hasVariants,
        'variantAttributes': _hasVariants ? _variantAttributes.map((attr) => attr.toMap()).toList() : null,
        'variantCombinations': _hasVariants ? _variantCombinations.map((comb) => comb.toMap()).toList() : null,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (isEditMode) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update(productData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk berhasil diperbarui'), backgroundColor: Colors.green),
        );
      } else {
        productData['createdAt'] = Timestamp.fromDate(now);
        await FirebaseFirestore.instance.collection('products').add(productData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk berhasil ditambahkan'), backgroundColor: Colors.green),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan produk: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Produk' : 'Tambah Produk'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Info Dasar'),
            Tab(text: 'Gambar'),
            Tab(text: 'Varian'),
            Tab(text: 'Detail'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildImagesTab(),
                  _buildVariantsTab(),
                  _buildDetailTab(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditMode ? 'Perbarui Produk' : 'Simpan Produk',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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

  // Basic Info Tab
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Produk',
              prefixIcon: const Icon(Icons.shopping_bag_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => value?.trim().isEmpty == true ? 'Nama produk harus diisi' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Deskripsi',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => value?.trim().isEmpty == true ? 'Deskripsi harus diisi' : null,
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _showCategoryPicker,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCategoryName.isEmpty ? 'Pilih kategori' : _selectedCategoryName,
                      style: TextStyle(
                        color: _selectedCategoryName.isEmpty ? Colors.grey[500] : Colors.black,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Harga Dasar',
                    prefixIcon: const Icon(Icons.attach_money),
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Harga harus diisi';
                    if (double.tryParse(value!) == null || double.parse(value) < 0) {
                      return 'Harga tidak valid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: InputDecoration(
                    labelText: 'Satuan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _availableUnits
                      .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedUnit = value!;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!_hasVariants)
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stok',
                prefixIcon: const Icon(Icons.inventory_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (!_hasVariants && value?.isEmpty == true) return 'Stok harus diisi';
                if (!_hasVariants && (int.tryParse(value!) == null || int.parse(value) < 0)) {
                  return 'Stok tidak valid';
                }
                return null;
              },
            ),
          if (!_hasVariants) const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Status Aktif'),
            subtitle: Text(_isActive ? 'Produk aktif dan dapat dibeli' : 'Produk nonaktif'),
            value: _isActive,
            onChanged: (value) => setState(() {
              _isActive = value;
            }),
            activeColor: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  // Images Tab
  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_totalImageCount > 0)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _totalImageCount + (_totalImageCount < 10 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _totalImageCount) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: _totalImageCount < 10 ? _pickImages : null,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: Color(0xFF2E7D32)),
                          SizedBox(height: 8),
                          Text('Tambah Gambar', style: TextStyle(color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ),
                  );
                }

                final isExisting = index < _existingImageUrls.length;
                final imageIndex = isExisting ? index : index - _existingImageUrls.length;

                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isExisting
                          ? CachedNetworkImage(
                              imageUrl: _existingImageUrls[imageIndex],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            )
                          : Image.file(
                              File(_newImages[imageIndex].path),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (index == 0)
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Chip(
                          label: Text('UTAMA', style: TextStyle(fontSize: 10)),
                          backgroundColor: Color(0xFF2E7D32),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => isExisting
                            ? _removeExistingImage(imageIndex)
                            : _removeNewImage(imageIndex),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: _pickImages,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Upload Gambar Produk', style: TextStyle(fontSize: 18)),
                    Text('Tap untuk memilih gambar (Max 10)', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Enhanced Variants Tab dengan Weight Support
  Widget _buildVariantsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Varian Produk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Aktifkan Varian'),
            subtitle: Text(_hasVariants ? 'Produk memiliki beberapa varian' : 'Produk tanpa varian'),
            value: _hasVariants,
            onChanged: (value) {
              setState(() {
                _hasVariants = value;
                if (!value) {
                  _variantAttributes.clear();
                  _variantCombinations.clear();
                }
              });
            },
            activeColor: const Color(0xFF2E7D32),
          ),

          if (_hasVariants) ...[
            const SizedBox(height: 20),
            
            // Add Attribute Button
            Row(
              children: [
                const Text('Atribut Varian:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showAddVariantAttributeDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Atribut'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Setup Buttons (Optional)
            if (_variantAttributes.isEmpty) ...[
              const Text('Quick Setup:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickSetupButton('Ukuran', ['S', 'M', 'L']),
                  _buildQuickSetupButton('Warna', ['Merah', 'Biru']),
                  _buildQuickSetupButton('Model', ['Tipe A', 'Tipe B']),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Attributes List
            if (_variantAttributes.isNotEmpty) ...[
              ..._variantAttributes.asMap().entries.map((entry) {
                final index = entry.key;
                final attr = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(attr.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${attr.options.length} opsi: ${attr.options.join(', ')}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editVariantAttribute(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _variantAttributes.removeAt(index);
                            });
                            _generateVariantCombinations();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],

            // Combinations dengan Weight Input
            if (_variantCombinations.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Kombinasi Varian (${_variantCombinations.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _generateVariantCombinations,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._variantCombinations.asMap().entries.map((entry) {
                final index = entry.key;
                final combo = entry.value;
                final displayName = _getCombinationDisplayName(combo);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('SKU: ${combo.sku} | Stok: ${combo.stock} | Berat: ${combo.formattedWeight}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              initialValue: combo.sku,
                              decoration: const InputDecoration(
                                labelText: 'SKU',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => combo.sku = value,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: combo.priceAdjustment.toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Penyesuaian Harga (Rp)',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => combo.priceAdjustment = double.tryParse(value) ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: combo.stock.toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Stok',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => combo.stock = int.tryParse(value) ?? 0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: combo.weight.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Berat (gram)',
                                border: OutlineInputBorder(),
                                suffixText: 'g',
                                helperText: 'Default: 1000g (1kg)',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => combo.weight = double.tryParse(value) ?? 1000,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSetupButton(String name, List<String> options) {
    return ElevatedButton(
      onPressed: () => _addVariantAttribute(name, options),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black87,
      ),
      child: Text('+ $name'),
    );
  }

  // Detail Tab
  Widget _buildDetailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextFormField(
            controller: _skuController,
            decoration: InputDecoration(
              labelText: 'SKU',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _generateSKU,
              ),
            ),
            validator: (value) => value?.trim().isEmpty == true ? 'SKU harus diisi' : null,
          ),
          const SizedBox(height: 20),
          if (!_hasVariants)
            TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Berat (gram)',
                prefixIcon: const Icon(Icons.scale_outlined),
                suffixText: 'g',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                helperText: 'Default: 1000g (1kg)',
              ),
              validator: (value) {
                if (value?.isNotEmpty == true &&
                    (double.tryParse(value!) == null || double.parse(value) < 0)) {
                  return 'Berat tidak valid';
                }
                return null;
              },
            ),
        ],
      ),
    );
  }
}