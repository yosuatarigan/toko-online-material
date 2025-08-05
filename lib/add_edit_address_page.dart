import 'package:flutter/material.dart';
import '../models/address.dart';
import '../service/shipping_service.dart';

class AddEditAddressPage extends StatefulWidget {
  final UserAddress? address;

  const AddEditAddressPage({super.key, this.address});

  @override
  State<AddEditAddressPage> createState() => _AddEditAddressPageState();
}

class _AddEditAddressPageState extends State<AddEditAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final ShippingService _shippingService = ShippingService();

  // Form controllers
  final _labelController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _districtController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _notesController = TextEditingController();

  // Dropdown data
  List<Province> _provinces = [];
  List<City> _cities = [];
  Province? _selectedProvince;
  City? _selectedCity;
  bool _isDefault = false;

  // Loading states
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;
  bool _isSaving = false;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    if (_isEditing) {
      _populateFormFields();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _fullAddressController.dispose();
    _districtController.dispose();
    _postalCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateFormFields() {
    final address = widget.address!;
    _labelController.text = address.label;
    _recipientNameController.text = address.recipientName;
    _recipientPhoneController.text = address.recipientPhone;
    _fullAddressController.text = address.fullAddress;
    _districtController.text = address.district;
    _postalCodeController.text = address.postalCode;
    _notesController.text = address.notes ?? '';
    _isDefault = address.isDefault;
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _isLoadingProvinces = true;
    });

    try {
      final provinces = await _shippingService.getProvinces();
      setState(() {
        _provinces = provinces;
        _isLoadingProvinces = false;
      });

      // If editing, find and set the province
      if (_isEditing) {
        final address = widget.address!;
        final province = provinces.firstWhere(
          (p) => p.provinceId == address.provinceId,
          orElse: () => Province(provinceId: '', province: ''),
        );
        if (province.provinceId.isNotEmpty) {
          setState(() {
            _selectedProvince = province;
          });
          await _loadCities(province.provinceId);
          
          // Find and set the city
          final city = _cities.firstWhere(
            (c) => c.cityId == address.cityId,
            orElse: () => City(
              cityId: '',
              provinceId: '',
              province: '',
              type: '',
              cityName: '',
              postalCode: '',
            ),
          );
          if (city.cityId.isNotEmpty) {
            setState(() {
              _selectedCity = city;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingProvinces = false;
      });
      _showErrorSnackBar('Gagal memuat data provinsi: $e');
    }
  }

  Future<void> _loadCities(String provinceId) async {
    setState(() {
      _isLoadingCities = true;
      _selectedCity = null;
      _cities = [];
    });

    try {
      final cities = await _shippingService.getCities(provinceId);
      setState(() {
        _cities = cities;
        _isLoadingCities = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCities = false;
      });
      _showErrorSnackBar('Gagal memuat data kota: $e');
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedCity == null) {
      _showErrorSnackBar('Pilih provinsi dan kota terlebih dahulu');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final address = UserAddress(
        id: _isEditing ? widget.address!.id : '',
        userId: _isEditing ? widget.address!.userId : '',
        label: _labelController.text.trim(),
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        fullAddress: _fullAddressController.text.trim(),
        province: _selectedProvince!.province,
        provinceId: _selectedProvince!.provinceId,
        city: _selectedCity!.fullName,
        cityId: _selectedCity!.cityId,
        district: _districtController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        isDefault: _isDefault,
        createdAt: _isEditing ? widget.address!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await _shippingService.updateAddress(address.id, address);
        _showSuccessSnackBar('Alamat berhasil diperbarui');
      } else {
        await _shippingService.addAddress(address);
        _showSuccessSnackBar('Alamat berhasil ditambahkan');
      }

      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Gagal menyimpan alamat: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _buildForm(),
      bottomNavigationBar: _buildBottomBar(),
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
      title: Text(
        _isEditing ? 'Edit Alamat' : 'Tambah Alamat',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFormSection(
            title: 'Label Alamat',
            icon: Icons.label_outline,
            child: TextFormField(
              controller: _labelController,
              decoration: _inputDecoration('Contoh: Rumah, Kantor, Kos'),
              validator: (value) => value?.trim().isEmpty == true 
                  ? 'Label alamat harus diisi' 
                  : null,
            ),
          ),

          const SizedBox(height: 20),

          _buildFormSection(
            title: 'Data Penerima',
            icon: Icons.person_outline,
            child: Column(
              children: [
                TextFormField(
                  controller: _recipientNameController,
                  decoration: _inputDecoration('Nama lengkap penerima'),
                  validator: (value) => value?.trim().isEmpty == true 
                      ? 'Nama penerima harus diisi' 
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _recipientPhoneController,
                  decoration: _inputDecoration('Nomor HP penerima'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) {
                      return 'Nomor HP harus diisi';
                    }
                    if (value!.length < 10) {
                      return 'Nomor HP minimal 10 digit';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildFormSection(
            title: 'Alamat Lengkap',
            icon: Icons.location_on_outlined,
            child: Column(
              children: [
                // Province Dropdown
                DropdownButtonFormField<Province>(
                  value: _selectedProvince,
                  decoration: _inputDecoration('Pilih Provinsi'),
                  isExpanded: true,
                  items: _provinces.map((province) {
                    return DropdownMenuItem(
                      value: province,
                      child: Text(province.province),
                    );
                  }).toList(),
                  onChanged: _isLoadingProvinces ? null : (Province? value) {
                    setState(() {
                      _selectedProvince = value;
                      _selectedCity = null;
                    });
                    if (value != null) {
                      _loadCities(value.provinceId);
                    }
                  },
                  validator: (value) => value == null ? 'Pilih provinsi' : null,
                ),

                const SizedBox(height: 16),

                // City Dropdown
                DropdownButtonFormField<City>(
                  value: _selectedCity,
                  decoration: _inputDecoration('Pilih Kota/Kabupaten'),
                  isExpanded: true,
                  items: _cities.map((city) {
                    return DropdownMenuItem(
                      value: city,
                      child: Text(city.fullName),
                    );
                  }).toList(),
                  onChanged: _isLoadingCities ? null : (City? value) {
                    setState(() {
                      _selectedCity = value;
                    });
                  },
                  validator: (value) => value == null ? 'Pilih kota/kabupaten' : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _districtController,
                  decoration: _inputDecoration('Kecamatan'),
                  validator: (value) => value?.trim().isEmpty == true 
                      ? 'Kecamatan harus diisi' 
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _fullAddressController,
                  decoration: _inputDecoration('Alamat lengkap (jalan, RT/RW, dll)'),
                  maxLines: 3,
                  validator: (value) => value?.trim().isEmpty == true 
                      ? 'Alamat lengkap harus diisi' 
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _postalCodeController,
                  decoration: _inputDecoration('Kode pos'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) {
                      return 'Kode pos harus diisi';
                    }
                    if (value!.length != 5) {
                      return 'Kode pos harus 5 digit';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildFormSection(
            title: 'Catatan Tambahan',
            icon: Icons.note_outlined,
            child: TextFormField(
              controller: _notesController,
              decoration: _inputDecoration('Patokan atau catatan khusus (opsional)'),
              maxLines: 2,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isDefault,
                  onChanged: (value) {
                    setState(() {
                      _isDefault = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jadikan alamat utama',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        'Alamat ini akan dipilih secara otomatis saat checkout',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
              Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveAddress,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isEditing ? 'Perbarui Alamat' : 'Simpan Alamat',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}