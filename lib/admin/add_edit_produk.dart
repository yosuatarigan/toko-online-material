import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toko_online_material/service/image_upload_service.dart';
import '../models/product.dart';
import '../models/category.dart';
class AddEditProductPage extends StatefulWidget {
  final Product? product; // null untuk add, ada value untuk edit

  const AddEditProductPage({super.key, this.product});

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();

  // Form variables
  String _selectedCategoryId = '';
  String _selectedCategoryName = '';
  String _selectedUnit = 'pcs';
  bool _isActive = true;
  bool _isLoading = false;
  List<Category> _categories = [];

  // Image variables
  List<String> _existingImageUrls = [];
  List<XFile> _newImages = [];
  List<String> _imagesToDelete = [];
  bool _isUploadingImages = false;
  double _uploadProgress = 0.0;

  // Available units
  final List<String> _availableUnits = [
    'pcs', 'kg', 'gram', 'meter', 'cm', 'liter', 'ml', 
    'pack', 'box', 'roll', 'sheet', 'sak', 'batang'
  ];

  bool get isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();
      
      setState(() {
        _categories = snapshot.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat kategori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _fillFormWithProductData() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price.toString();
    _stockController.text = product.stock.toString();
    _skuController.text = product.sku;
    _weightController.text = product.weight?.toString() ?? '';
    _selectedCategoryId = product.categoryId;
    _selectedCategoryName = product.categoryName;
    _selectedUnit = product.unit;
    _isActive = product.isActive;
    _existingImageUrls = List.from(product.imageUrls);
  }

  void _generateSKU() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _skuController.text = 'PRD$timestamp';
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kategori'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploadingImages = true;
      _uploadProgress = 0.0;
    });

    try {
      // Delete removed images from storage
      if (_imagesToDelete.isNotEmpty) {
        await ImageUploadService.deleteMultipleImages(_imagesToDelete);
      }

      // Upload new images
      List<String> newImageUrls = [];
      if (_newImages.isNotEmpty) {
        newImageUrls = await ImageUploadService.uploadMultipleImages(
          imageFiles: _newImages,
          folder: 'products',
          onProgress: (completed, total) {
            setState(() {
              _uploadProgress = completed / total;
            });
          },
        );
      }

      // Combine existing and new image URLs
      final List<String> allImageUrls = [
        ..._existingImageUrls,
        ...newImageUrls,
      ];

      setState(() {
        _isUploadingImages = false;
      });

      final now = DateTime.now();
      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'categoryId': _selectedCategoryId,
        'categoryName': _selectedCategoryName,
        'unit': _selectedUnit,
        'imageUrls': allImageUrls,
        'isActive': _isActive,
        'sku': _skuController.text.trim(),
        'weight': _weightController.text.isNotEmpty 
            ? double.parse(_weightController.text) 
            : null,
        'specifications': null, // TODO: Implement specifications
        'updatedAt': Timestamp.fromDate(now),
      };

      if (isEditMode) {
        // Update existing product
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update(productData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new product
        productData['createdAt'] = Timestamp.fromDate(now);
        
        await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImages = false;
        });
      }
    }
  }

  // Image management methods
  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await ImageUploadService.pickMultipleImages();
      
      if (images != null && images.isNotEmpty) {
        // Check file sizes
        for (XFile image in images) {
          final double sizeInMB = await ImageUploadService.getImageSize(image);
          if (sizeInMB > 10) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gambar ${image.name} terlalu besar (${sizeInMB.toStringAsFixed(1)}MB). Maksimal 10MB.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        setState(() {
          _newImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickSingleImage() async {
    try {
      final ImageSource? source = await ImageUploadService.showImageSourceDialog(context);
      if (source == null) return;

      final XFile? image = await ImageUploadService.pickImage(source: source);
      
      if (image != null) {
        // Check file size
        final double sizeInMB = await ImageUploadService.getImageSize(image);
        if (sizeInMB > 10) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gambar terlalu besar (${sizeInMB.toStringAsFixed(1)}MB). Maksimal 10MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _newImages.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      final String imageUrl = _existingImageUrls[index];
      _existingImageUrls.removeAt(index);
      _imagesToDelete.add(imageUrl);
    });
  }

  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  void _showCategoryPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Kategori'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _categories.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category.id == _selectedCategoryId;
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse(category.color)).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIconData(category.iconName),
                          color: Color(int.parse(category.color)),
                          size: 20,
                        ),
                      ),
                      title: Text(category.name),
                      subtitle: Text(category.description),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
                          : null,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'foundation':
        return Icons.foundation;
      case 'build':
        return Icons.build;
      case 'grid_4x4':
        return Icons.grid_4x4;
      case 'palette':
        return Icons.palette;
      case 'hardware':
        return Icons.hardware;
      case 'construction':
        return Icons.construction;
      default:
        return Icons.category;
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
                  _buildDetailTab(),
                ],
              ),
            ),
            
            // Save Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Produk',
              hintText: 'Masukkan nama produk',
              prefixIcon: const Icon(Icons.shopping_bag_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama produk harus diisi';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 20),
          
          // Description
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Deskripsi',
              hintText: 'Masukkan deskripsi produk',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Deskripsi harus diisi';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 20),
          
          // Category Selector
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kategori',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF718096),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedCategoryName.isEmpty 
                              ? 'Pilih kategori' 
                              : _selectedCategoryName,
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedCategoryName.isEmpty 
                                ? Colors.grey[500] 
                                : const Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Price and Unit
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Harga',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.attach_money),
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Harga harus diisi';
                    }
                    if (double.tryParse(value) == null || double.parse(value) < 0) {
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _availableUnits.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUnit = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Stock
          TextFormField(
            controller: _stockController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Stok',
              hintText: '0',
              prefixIcon: const Icon(Icons.inventory_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Stok harus diisi';
              }
              if (int.tryParse(value) == null || int.parse(value) < 0) {
                return 'Stok tidak valid';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 20),
          
          // Status Switch
          SwitchListTile(
            title: const Text('Status Aktif'),
            subtitle: Text(_isActive ? 'Produk aktif dan dapat dibeli' : 'Produk nonaktif'),
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            activeColor: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SKU
          TextFormField(
            controller: _skuController,
            decoration: InputDecoration(
              labelText: 'SKU (Stock Keeping Unit)',
              hintText: 'Kode unik produk',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _generateSKU,
                tooltip: 'Generate SKU baru',
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'SKU harus diisi';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 20),
          
          // Weight
          TextFormField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
            ],
            decoration: InputDecoration(
              labelText: 'Berat (kg)',
              hintText: 'Opsional',
              prefixIcon: const Icon(Icons.scale_outlined),
              suffixText: 'kg',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (double.tryParse(value) == null || double.parse(value) < 0) {
                  return 'Berat tidak valid';
                }
              }
              return null;
            },
          ),
          
          const SizedBox(height: 20),
          
          // Image Upload Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.image_outlined),
                  const SizedBox(width: 8),
                  const Text(
                    'Gambar Produk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_totalImageCount}/5',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Upload Progress Indicator
              if (_isUploadingImages)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mengupload gambar... ${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              
              // Image Grid
              if (_totalImageCount > 0)
                Container(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _totalImageCount + (_totalImageCount < 5 ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Add image button
                      if (index >= _totalImageCount) {
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: InkWell(
                            onTap: _totalImageCount < 5 ? _pickSingleImage : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 32,
                                  color: _totalImageCount < 5 ? Colors.grey[600] : Colors.grey[400],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tambah',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _totalImageCount < 5 ? Colors.grey[600] : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Existing images
                      if (index < _existingImageUrls.length) {
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: _existingImageUrls[index],
                                  width: 100,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.error),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeExistingImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      // New images
                      final newImageIndex = index - _existingImageUrls.length;
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _newImages[newImageIndex].path,
                                width: 100,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // For mobile, show file path preview
                                  return Container(
                                    width: 100,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.image, size: 32),
                                        const SizedBox(height: 4),
                                        Text(
                                          _newImages[newImageIndex].name.length > 10
                                              ? '${_newImages[newImageIndex].name.substring(0, 10)}...'
                                              : _newImages[newImageIndex].name,
                                          style: const TextStyle(fontSize: 10),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeNewImage(newImageIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                // Empty state - no images
                InkWell(
                  onTap: _pickImages,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload Gambar Produk',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap untuk memilih gambar (Max 5)',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Image upload tips
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Tips Upload Gambar:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Maksimal 5 gambar per produk\n• Ukuran maksimal 10MB per gambar\n• Format: JPG, PNG, GIF, WebP\n• Gambar pertama akan jadi gambar utama',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Specifications Placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings_outlined),
                    const SizedBox(width: 8),
                    const Text(
                      'Spesifikasi Teknis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Fitur untuk menambahkan spesifikasi detail produk seperti dimensi, material, warna, dll.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fitur akan segera hadir',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
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