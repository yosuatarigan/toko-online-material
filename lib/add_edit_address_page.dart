// lib/pages/add_edit_address_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toko_online_material/models/address_model.dart';
import 'package:toko_online_material/service/rajaongkir_service.dart';

class AddEditAddressPage extends StatefulWidget {
  final Address? address;

  const AddEditAddressPage({super.key, this.address});

  @override
  State<AddEditAddressPage> createState() => _AddEditAddressPageState();
}

class _AddEditAddressPageState extends State<AddEditAddressPage> 
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;

  // Controllers
  final _labelController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Loading states
  bool _isLoading = false;
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;
  bool _isLoadingSubdistricts = false;

  // Form data
  bool _isDefault = false;

  // Location data
  List<Province> _provinces = [];
  List<City> _cities = [];
  List<Subdistrict> _subdistricts = [];

  // Selected values
  Province? _selectedProvince;
  City? _selectedCity;
  Subdistrict? _selectedSubdistrict;

  // Predefined labels
  final List<String> _predefinedLabels = [
    'Rumah', 'Kantor', 'Apartemen', 'Kos', 'Lainnya'
  ];

  bool get isEditMode => widget.address != null;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadProvinces();
    if (isEditMode) {
      _fillFormWithAddressData();
    }
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  void _fillFormWithAddressData() {
    final address = widget.address!;
    _labelController.text = address.label;
    _recipientNameController.text = address.recipientName;
    _recipientPhoneController.text = address.recipientPhone;
    _detailAddressController.text = address.detailAddress;
    _postalCodeController.text = address.postalCode;
    _isDefault = address.isDefault;

    // Set selected province after provinces are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSelectedProvinceFromAddress(address);
    });
  }

  void _setSelectedProvinceFromAddress(Address address) {
    final province = _provinces.firstWhere(
      (p) => p.name == address.provinceName || p.id == address.provinceId,
      orElse: () => Province(id: '', name: ''),
    );

    if (province.id.isNotEmpty) {
      setState(() {
        _selectedProvince = province;
      });
      _loadCitiesByProvince(province.name).then((_) {
        _setSelectedCityFromAddress(address);
      });
    }
  }

  void _setSelectedCityFromAddress(Address address) {
    final city = _cities.firstWhere(
      (c) => c.name == address.cityName,
      orElse: () => City(id: '', name: '', type: '', provinceId: '', provinceName: ''),
    );

    if (city.id.isNotEmpty) {
      setState(() {
        _selectedCity = city;
      });
      _loadSubdistrictsByCity(city.name).then((_) {
        _setSelectedSubdistrictFromAddress(address);
      });
    }
  }

  void _setSelectedSubdistrictFromAddress(Address address) {
    if (_subdistricts.isNotEmpty) {
      final subdistrict = _subdistricts.firstWhere(
        (s) => s.name == address.subdistrictName,
        orElse: () => Subdistrict(id: '', name: '', cityId: '', cityName: '', provinceName: ''),
      );

      if (subdistrict.id.isNotEmpty) {
        setState(() {
          _selectedSubdistrict = subdistrict;
        });
        // Auto-fill postal code if available
        if (subdistrict.postalCode != null && subdistrict.postalCode!.isNotEmpty) {
          _postalCodeController.text = subdistrict.postalCode!;
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _labelController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _detailAddressController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _isLoadingProvinces = true;
    });

    try {
      final provinces = await RajaOngkirService.getProvinces();
      setState(() {
        _provinces = provinces;
        _isLoadingProvinces = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingProvinces = false;
      });
      _showErrorSnackBar('Gagal memuat daftar provinsi: $e');
    }
  }

  Future<void> _loadCitiesByProvince(String provinceName) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _subdistricts = [];
      _selectedCity = null;
      _selectedSubdistrict = null;
    });

    try {
      final cities = await RajaOngkirService.getCitiesByProvinceName(provinceName);
      setState(() {
        _cities = cities;
        _isLoadingCities = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCities = false;
      });
      _showErrorSnackBar('Gagal memuat daftar kota: $e');
    }
  }

  Future<void> _loadSubdistrictsByCity(String cityName) async {
    setState(() {
      _isLoadingSubdistricts = true;
      _subdistricts = [];
      _selectedSubdistrict = null;
    });

    try {
      final subdistricts = await RajaOngkirService.getSubdistrictsByCityName(cityName);
      setState(() {
        _subdistricts = subdistricts;
        _isLoadingSubdistricts = false;
      });

      // Auto-fill postal code if city has sample postal code
      if (_postalCodeController.text.isEmpty) {
        final sampleCode = RajaOngkirService.getSamplePostalCode(cityName);
        if (sampleCode != null) {
          _postalCodeController.text = sampleCode;
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingSubdistricts = false;
      });
      print('Failed to load subdistricts: $e');
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null) {
      _showErrorSnackBar('Silakan pilih provinsi');
      return;
    }
    if (_selectedCity == null) {
      _showErrorSnackBar('Silakan pilih kota/kabupaten');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      
      // If setting as default, first remove default from other addresses
      if (_isDefault) {
        await _removeDefaultFromOtherAddresses();
      }

      final addressData = {
        'userId': user!.uid,
        'label': _labelController.text.trim(),
        'recipientName': _recipientNameController.text.trim(),
        'recipientPhone': RajaOngkirService.formatPhoneNumber(_recipientPhoneController.text.trim()),
        'provinceName': _selectedProvince!.name,
        'provinceId': _selectedProvince!.id,
        'cityName': _selectedCity!.name,
        'cityId': _selectedCity!.id,
        'subdistrictName': _selectedSubdistrict?.name ?? '',
        'subdistrictId': _selectedSubdistrict?.id ?? '',
        'districtName': _selectedSubdistrict?.districtName ?? '',
        'detailAddress': _detailAddressController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'isDefault': _isDefault,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (isEditMode) {
        await FirebaseFirestore.instance
            .collection('addresses')
            .doc(widget.address!.id)
            .update(addressData);
        _showSuccessSnackBar('Alamat berhasil diperbarui');
      } else {
        addressData['createdAt'] = Timestamp.fromDate(now);
        await FirebaseFirestore.instance
            .collection('addresses')
            .add(addressData);
        _showSuccessSnackBar('Alamat berhasil ditambahkan');
      }

      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('Gagal menyimpan alamat: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeDefaultFromOtherAddresses() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('addresses')
        .where('userId', isEqualTo: user!.uid)
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      if (!isEditMode || doc.id != widget.address!.id) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }
    await batch.commit();
  }

  void _showLabelPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pilih Label Alamat'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _predefinedLabels.length,
            itemBuilder: (context, index) {
              final label = _predefinedLabels[index];
              return ListTile(
                leading: Icon(
                  _getLabelIcon(label),
                  color: const Color(0xFF2E7D32),
                ),
                title: Text(label),
                onTap: () {
                  _labelController.text = label;
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    switch (label) {
      case 'Rumah':
        return Icons.home;
      case 'Kantor':
        return Icons.business;
      case 'Apartemen':
        return Icons.apartment;
      case 'Kos':
        return Icons.bed;
      default:
        return Icons.location_on;
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditMode ? 'Edit Alamat' : 'Tambah Alamat',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionCard(
                        title: 'Informasi Penerima',
                        icon: Icons.person,
                        children: [
                          _buildTextFormField(
                            controller: _recipientNameController,
                            label: 'Nama Penerima',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Nama penerima harus diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            controller: _recipientPhoneController,
                            label: 'Nomor Telepon',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Nomor telepon harus diisi';
                              }
                              if (value!.trim().length < 10) {
                                return 'Nomor telepon tidak valid';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: 'Label Alamat',
                        icon: Icons.label,
                        children: [
                          _buildTextFormField(
                            controller: _labelController,
                            label: 'Label Alamat',
                            icon: Icons.label_outline,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              onPressed: _showLabelPicker,
                            ),
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Label alamat harus diisi';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: 'Lokasi',
                        icon: Icons.location_on,
                        children: [
                          // Province Dropdown
                          _buildLocationDropdown<Province>(
                            label: 'Provinsi',
                            icon: Icons.map_outlined,
                            value: _selectedProvince,
                            items: _provinces,
                            isLoading: _isLoadingProvinces,
                            onChanged: (Province? province) {
                              setState(() {
                                _selectedProvince = province;
                                _selectedCity = null;
                                _selectedSubdistrict = null;
                              });
                              if (province != null) {
                                _loadCitiesByProvince(province.name);
                              }
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Silakan pilih provinsi';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // City Dropdown
                          _buildLocationDropdown<City>(
                            label: 'Kota/Kabupaten',
                            icon: Icons.location_city_outlined,
                            value: _selectedCity,
                            items: _cities,
                            isLoading: _isLoadingCities,
                            enabled: _selectedProvince != null,
                            onChanged: (City? city) {
                              setState(() {
                                _selectedCity = city;
                                _selectedSubdistrict = null;
                              });
                              if (city != null) {
                                _loadSubdistrictsByCity(city.name);
                              }
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Silakan pilih kota/kabupaten';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Subdistrict Dropdown (Optional)
                          _buildLocationDropdown<Subdistrict>(
                            label: 'Kecamatan (Opsional)',
                            icon: Icons.location_on_outlined,
                            value: _selectedSubdistrict,
                            items: _subdistricts,
                            isLoading: _isLoadingSubdistricts,
                            enabled: _selectedCity != null,
                            onChanged: (Subdistrict? subdistrict) {
                              setState(() {
                                _selectedSubdistrict = subdistrict;
                              });
                              // Auto-fill postal code if available
                              if (subdistrict?.postalCode != null && 
                                  subdistrict!.postalCode!.isNotEmpty) {
                                _postalCodeController.text = subdistrict.postalCode!;
                              }
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: 'Detail Alamat',
                        icon: Icons.home,
                        children: [
                          _buildTextFormField(
                            controller: _detailAddressController,
                            label: 'Alamat Lengkap',
                            icon: Icons.home_outlined,
                            maxLines: 3,
                            hintText: 'Nama jalan, nomor rumah, RT/RW, landmark, dll',
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Alamat lengkap harus diisi';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            controller: _postalCodeController,
                            label: 'Kode Pos',
                            icon: Icons.local_post_office_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Kode pos harus diisi';
                              }
                              if (!RajaOngkirService.isValidPostalCode(value!.trim())) {
                                return 'Kode pos harus 5 digit';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _buildDefaultAddressSwitch(),
                      const SizedBox(height: 100), // Space for floating button
                    ],
                  ),
                ),
              ),
              
              // Save Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isEditMode ? 'Perbarui Alamat' : 'Simpan Alamat',
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
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildLocationDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?>? onChanged,
    bool isLoading = false,
    bool enabled = true,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: enabled && !isLoading
          ? items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList()
          : [],
      onChanged: enabled && !isLoading ? onChanged : null,
      validator: validator,
      hint: Text(
        enabled
            ? isLoading
                ? 'Memuat...'
                : 'Pilih $label'
            : 'Pilih ${label.split(' ')[0].toLowerCase()} terlebih dahulu',
        style: TextStyle(
          color: enabled ? null : Colors.grey,
        ),
      ),
      isExpanded: true,
    );
  }

  Widget _buildDefaultAddressSwitch() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.star_outline,
              color: Colors.orange.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jadikan Alamat Utama',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Alamat ini akan diprioritaskan saat checkout',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isDefault,
            onChanged: (value) {
              setState(() {
                _isDefault = value;
              });
            },
            activeColor: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }
}