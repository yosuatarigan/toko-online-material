// lib/pages/admin/store_delivery_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreDeliverySettingsPage extends StatefulWidget {
  const StoreDeliverySettingsPage({super.key});

  @override
  State<StoreDeliverySettingsPage> createState() => _StoreDeliverySettingsPageState();
}

class _StoreDeliverySettingsPageState extends State<StoreDeliverySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _maxRadiusController = TextEditingController();
  final _baseFeeController = TextEditingController();
  final _feePerKmController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxWeightController = TextEditingController();

  // Settings
  StoreDeliverySettings _settings = StoreDeliverySettings.defaultSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _maxRadiusController.dispose();
    _baseFeeController.dispose();
    _feePerKmController.dispose();
    _minOrderController.dispose();
    _maxWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('store_delivery')
          .get();

      if (doc.exists) {
        _settings = StoreDeliverySettings.fromFirestore(doc.data()!);
      }

      _updateControllers();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Gagal memuat pengaturan: $e');
    }
  }

  void _updateControllers() {
    _maxRadiusController.text = _settings.maxDeliveryRadius.toString();
    _baseFeeController.text = _settings.baseFee.toString();
    _feePerKmController.text = _settings.feePerKm.toString();
    _minOrderController.text = _settings.minOrderAmount.toString();
    _maxWeightController.text = _settings.maxWeight.toString();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedSettings = _settings.copyWith(
        maxDeliveryRadius: double.parse(_maxRadiusController.text),
        baseFee: int.parse(_baseFeeController.text),
        feePerKm: int.parse(_feePerKmController.text),
        minOrderAmount: int.parse(_minOrderController.text),
        maxWeight: double.parse(_maxWeightController.text),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('settings')
          .doc('store_delivery')
          .set(updatedSettings.toFirestore());

      setState(() {
        _settings = updatedSettings;
        _isSaving = false;
      });

      _showSuccessSnackBar('Pengaturan berhasil disimpan');
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showErrorSnackBar('Gagal menyimpan pengaturan: $e');
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
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
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
      title: const Text(
        'Pengaturan Pengiriman Toko',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (!_isLoading)
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Simpan',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF2E7D32),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildBasicSettings(),
            const SizedBox(height: 16),
            _buildPricingSettings(),
            const SizedBox(height: 16),
            _buildLimitationSettings(),
            const SizedBox(height: 16),
            _buildOperationalSettings(),
            const SizedBox(height: 16),
            _buildPreviewCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _settings.isEnabled
                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: _settings.isEnabled
                      ? const Color(0xFF2E7D32)
                      : Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Pengiriman Toko',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _settings.isEnabled
                          ? 'Aktif - Tersedia untuk pelanggan'
                          : 'Nonaktif - Tidak tersedia',
                      style: TextStyle(
                        fontSize: 14,
                        color: _settings.isEnabled
                            ? const Color(0xFF2E7D32)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _settings.isEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(isEnabled: value);
                  });
                },
                activeColor: const Color(0xFF2E7D32),
              ),
            ],
          ),
          if (_settings.isEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pengiriman toko akan muncul sebagai opsi untuk pelanggan dalam radius ${_settings.maxDeliveryRadius} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
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

  Widget _buildBasicSettings() {
    return _buildSettingsCard(
      title: 'Pengaturan Dasar',
      icon: Icons.settings,
      children: [
        _buildNumberField(
          controller: _maxRadiusController,
          label: 'Radius Maksimal (km)',
          hint: 'Masukkan radius pengiriman maksimal',
          suffix: 'km',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Radius wajib diisi';
            final radius = double.tryParse(value!);
            if (radius == null || radius <= 0) return 'Radius harus lebih dari 0';
            if (radius > 50) return 'Radius maksimal 50 km';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _minOrderController,
          label: 'Minimal Pembelian (Rp)',
          hint: 'Masukkan minimal pembelian',
          prefix: 'Rp ',
          isInteger: true,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Minimal pembelian wajib diisi';
            final amount = int.tryParse(value!);
            if (amount == null || amount < 0) return 'Jumlah tidak valid';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPricingSettings() {
    return _buildSettingsCard(
      title: 'Pengaturan Harga',
      icon: Icons.attach_money,
      children: [
        _buildNumberField(
          controller: _baseFeeController,
          label: 'Biaya Dasar (Rp)',
          hint: 'Biaya pengiriman dasar',
          prefix: 'Rp ',
          isInteger: true,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Biaya dasar wajib diisi';
            final fee = int.tryParse(value!);
            if (fee == null || fee < 0) return 'Biaya tidak valid';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _feePerKmController,
          label: 'Biaya per KM (Rp)',
          hint: 'Biaya tambahan per kilometer',
          prefix: 'Rp ',
          suffix: '/km',
          isInteger: true,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Biaya per km wajib diisi';
            final fee = int.tryParse(value!);
            if (fee == null || fee < 0) return 'Biaya tidak valid';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Simulasi Perhitungan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• 3 km: Rp ${_calculateDeliveryFee(3.0).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '• 5 km: Rp ${_calculateDeliveryFee(5.0).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '• 8 km: Rp ${_calculateDeliveryFee(8.0).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLimitationSettings() {
    return _buildSettingsCard(
      title: 'Batasan Pengiriman',
      icon: Icons.policy,
      children: [
        _buildNumberField(
          controller: _maxWeightController,
          label: 'Berat Maksimal (kg)',
          hint: 'Berat maksimal per pengiriman',
          suffix: 'kg',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Berat maksimal wajib diisi';
            final weight = double.tryParse(value!);
            if (weight == null || weight <= 0) return 'Berat harus lebih dari 0';
            if (weight > 1000) return 'Berat maksimal 1000 kg';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _settings.enableWeightValidation,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(
                    enableWeightValidation: value ?? false,
                  );
                });
              },
              activeColor: const Color(0xFF2E7D32),
            ),
            const Expanded(
              child: Text(
                'Validasi berat produk saat checkout',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _settings.allowWeekendDelivery,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(
                    allowWeekendDelivery: value ?? false,
                  );
                });
              },
              activeColor: const Color(0xFF2E7D32),
            ),
            const Expanded(
              child: Text(
                'Izinkan pengiriman akhir pekan',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOperationalSettings() {
    return _buildSettingsCard(
      title: 'Pengaturan Operasional',
      icon: Icons.schedule,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jam Operasional',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '${_settings.operatingHours.start} - ${_settings.operatingHours.end}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Estimasi Pengiriman',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        _buildEstimationTile('0-3 km', 'Hari ini (2-4 jam)'),
        _buildEstimationTile('3-6 km', 'Hari ini (3-6 jam)'),
        _buildEstimationTile('6-10 km', 'Besok (1-2 hari)'),
      ],
    );
  }

  Widget _buildEstimationTile(String distance, String estimation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              distance,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              estimation,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.preview, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Preview untuk Pelanggan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF2E7D32), Colors.green.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.store, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengiriman Toko',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Dikirim langsung oleh Toko Barokah',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rp ${_calculateDeliveryFee(5.0).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const Text(
                          'Hari ini (3-6 jam)',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    const Text(
                      '5 km',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.info_outline, size: 14, color: Colors.orange[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Min. pembelian Rp ${int.parse(_minOrderController.text.isEmpty ? "0" : _minOrderController.text).toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    String? suffix,
    bool isInteger = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
          inputFormatters: [
            if (isInteger) FilteringTextInputFormatter.digitsOnly
            else FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            suffixText: suffix,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  double _calculateDeliveryFee(double distance) {
    final baseFee = int.tryParse(_baseFeeController.text) ?? 0;
    final feePerKm = int.tryParse(_feePerKmController.text) ?? 0;
    return baseFee + (distance * feePerKm);
  }
}

// Model untuk pengaturan pengiriman toko
class StoreDeliverySettings {
  final bool isEnabled;
  final double maxDeliveryRadius;
  final int baseFee;
  final int feePerKm;
  final int minOrderAmount;
  final double maxWeight;
  final bool enableWeightValidation;
  final bool allowWeekendDelivery;
  final OperatingHours operatingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoreDeliverySettings({
    required this.isEnabled,
    required this.maxDeliveryRadius,
    required this.baseFee,
    required this.feePerKm,
    required this.minOrderAmount,
    required this.maxWeight,
    required this.enableWeightValidation,
    required this.allowWeekendDelivery,
    required this.operatingHours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreDeliverySettings.defaultSettings() {
    return StoreDeliverySettings(
      isEnabled: true,
      maxDeliveryRadius: 10.0,
      baseFee: 5000,
      feePerKm: 2000,
      minOrderAmount: 50000,
      maxWeight: 100.0,
      enableWeightValidation: true,
      allowWeekendDelivery: false,
      operatingHours: OperatingHours(start: '07:00', end: '17:00'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory StoreDeliverySettings.fromFirestore(Map<String, dynamic> data) {
    return StoreDeliverySettings(
      isEnabled: data['isEnabled'] ?? true,
      maxDeliveryRadius: (data['maxDeliveryRadius'] ?? 10.0).toDouble(),
      baseFee: data['baseFee'] ?? 5000,
      feePerKm: data['feePerKm'] ?? 2000,
      minOrderAmount: data['minOrderAmount'] ?? 50000,
      maxWeight: (data['maxWeight'] ?? 100.0).toDouble(),
      enableWeightValidation: data['enableWeightValidation'] ?? true,
      allowWeekendDelivery: data['allowWeekendDelivery'] ?? false,
      operatingHours: OperatingHours.fromMap(data['operatingHours'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isEnabled': isEnabled,
      'maxDeliveryRadius': maxDeliveryRadius,
      'baseFee': baseFee,
      'feePerKm': feePerKm,
      'minOrderAmount': minOrderAmount,
      'maxWeight': maxWeight,
      'enableWeightValidation': enableWeightValidation,
      'allowWeekendDelivery': allowWeekendDelivery,
      'operatingHours': operatingHours.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  StoreDeliverySettings copyWith({
    bool? isEnabled,
    double? maxDeliveryRadius,
    int? baseFee,
    int? feePerKm,
    int? minOrderAmount,
    double? maxWeight,
    bool? enableWeightValidation,
    bool? allowWeekendDelivery,
    OperatingHours? operatingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreDeliverySettings(
      isEnabled: isEnabled ?? this.isEnabled,
      maxDeliveryRadius: maxDeliveryRadius ?? this.maxDeliveryRadius,
      baseFee: baseFee ?? this.baseFee,
      feePerKm: feePerKm ?? this.feePerKm,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxWeight: maxWeight ?? this.maxWeight,
      enableWeightValidation: enableWeightValidation ?? this.enableWeightValidation,
      allowWeekendDelivery: allowWeekendDelivery ?? this.allowWeekendDelivery,
      operatingHours: operatingHours ?? this.operatingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class OperatingHours {
  final String start;
  final String end;

  OperatingHours({required this.start, required this.end});

  factory OperatingHours.fromMap(Map<String, dynamic> data) {
    return OperatingHours(
      start: data['start'] ?? '07:00',
      end: data['end'] ?? '17:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
    };
  }
}