import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

class AddEditCategoryPage extends StatefulWidget {
  final Category? category; // null untuk add, ada value untuk edit

  const AddEditCategoryPage({super.key, this.category});

  @override
  State<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends State<AddEditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedIcon = 'category';
  String _selectedColor = '0xFF2196F3';
  bool _isLoading = false;

  // Available icons
  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'category', 'icon': Icons.category, 'label': 'Kategori'},
    {'name': 'foundation', 'icon': Icons.foundation, 'label': 'Semen & Beton'},
    {'name': 'build', 'icon': Icons.build, 'label': 'Baja & Metal'},
    {'name': 'grid_4x4', 'icon': Icons.grid_4x4, 'label': 'Keramik & Ubin'},
    {'name': 'palette', 'icon': Icons.palette, 'label': 'Cat & Finishing'},
    {'name': 'hardware', 'icon': Icons.hardware, 'label': 'Hardware'},
    {'name': 'construction', 'icon': Icons.construction, 'label': 'Konstruksi'},
    {'name': 'home_repair_service', 'icon': Icons.home_repair_service, 'label': 'Alat'},
    {'name': 'electrical_services', 'icon': Icons.electrical_services, 'label': 'Elektrik'},
    {'name': 'plumbing', 'icon': Icons.plumbing, 'label': 'Pipa & Sanitasi'},
  ];

  // Available colors
  final List<Map<String, dynamic>> _availableColors = [
    {'name': 'Biru', 'value': '0xFF2196F3', 'color': const Color(0xFF2196F3)},
    {'name': 'Hijau', 'value': '0xFF4CAF50', 'color': const Color(0xFF4CAF50)},
    {'name': 'Orange', 'value': '0xFFFF9800', 'color': const Color(0xFFFF9800)},
    {'name': 'Ungu', 'value': '0xFF9C27B0', 'color': const Color(0xFF9C27B0)},
    {'name': 'Merah', 'value': '0xFFF44336', 'color': const Color(0xFFF44336)},
    {'name': 'Teal', 'value': '0xFF009688', 'color': const Color(0xFF009688)},
    {'name': 'Indigo', 'value': '0xFF3F51B5', 'color': const Color(0xFF3F51B5)},
    {'name': 'Abu-abu', 'value': '0xFF607D8B', 'color': const Color(0xFF607D8B)},
  ];

  bool get isEditMode => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description;
      _selectedIcon = widget.category!.iconName;
      _selectedColor = widget.category!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final categoryData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'iconName': _selectedIcon,
        'color': _selectedColor,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (isEditMode) {
        // Update existing category
        await FirebaseFirestore.instance
            .collection('categories')
            .doc(widget.category!.id)
            .update(categoryData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kategori berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new category
        categoryData['createdAt'] = Timestamp.fromDate(now);
        
        await FirebaseFirestore.instance
            .collection('categories')
            .add(categoryData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kategori berhasil ditambahkan'),
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
            content: Text('Gagal menyimpan kategori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Icon'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _availableIcons.length,
            itemBuilder: (context, index) {
              final iconData = _availableIcons[index];
              final isSelected = iconData['name'] == _selectedIcon;
              
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIcon = iconData['name'];
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2E7D32) : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? const Color(0xFF2E7D32).withOpacity(0.1) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconData['icon'],
                        size: 32,
                        color: isSelected ? const Color(0xFF2E7D32) : Colors.grey[600],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        iconData['label'],
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? const Color(0xFF2E7D32) : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Warna'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableColors.map((colorData) {
              final isSelected = colorData['value'] == _selectedColor;
              
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedColor = colorData['value'];
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorData['color'],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey[300]!,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
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

  @override
  Widget build(BuildContext context) {
    final selectedIconData = _availableIcons.firstWhere(
      (icon) => icon['name'] == _selectedIcon,
      orElse: () => _availableIcons[0],
    );
    
    final selectedColorData = _availableColors.firstWhere(
      (color) => color['value'] == _selectedColor,
      orElse: () => _availableColors[0],
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Kategori' : 'Tambah Kategori'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Preview Kategori',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: selectedColorData['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          selectedIconData['icon'],
                          size: 40,
                          color: selectedColorData['color'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _nameController.text.isEmpty ? 'Nama Kategori' : _nameController.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _descriptionController.text.isEmpty 
                            ? 'Deskripsi kategori' 
                            : _descriptionController.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF718096),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Form Fields
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Kategori',
                    hintText: 'Masukkan nama kategori',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama kategori harus diisi';
                    }
                    if (value.trim().length < 2) {
                      return 'Nama kategori minimal 2 karakter';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() {}),
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi',
                    hintText: 'Masukkan deskripsi kategori',
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
                  onChanged: (value) => setState(() {}),
                ),
                
                const SizedBox(height: 20),
                
                // Icon Selector
                InkWell(
                  onTap: _showIconPicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apps),
                        const SizedBox(width: 12),
                        const Text('Icon'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedColorData['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            selectedIconData['icon'],
                            color: selectedColorData['color'],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Color Selector
                InkWell(
                  onTap: _showColorPicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.palette),
                        const SizedBox(width: 12),
                        const Text('Warna'),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selectedColorData['color'],
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(selectedColorData['name']),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isEditMode ? 'Perbarui Kategori' : 'Simpan Kategori',
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
          ),
        ),
      ),
    );
  }
}