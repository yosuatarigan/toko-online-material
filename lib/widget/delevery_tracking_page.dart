// lib/pages/delivery_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:toko_online_material/service/store_delevery_store.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String orderId;
  final String orderType; // 'store_delivery' or 'courier'

  const DeliveryTrackingPage({
    super.key,
    required this.orderId,
    required this.orderType,
  });

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage>
    with TickerProviderStateMixin {
  List<DeliveryActivity> _activities = [];
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTrackingData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
  }

  Future<void> _loadTrackingData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (widget.orderType == 'store_delivery') {
        final activities = await StoreDeliveryService.getDeliveryHistory(widget.orderId);
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      } else {
        // Load courier tracking data
        setState(() {
          _activities = _getMockCourierActivities();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data tracking: $e';
        _isLoading = false;
      });
    }
  }

  List<DeliveryActivity> _getMockCourierActivities() {
    // Mock data untuk courier tracking
    return [
      DeliveryActivity(
        orderId: widget.orderId,
        activity: 'Paket telah diterima oleh kurir',
        status: 'on_delivery',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      DeliveryActivity(
        orderId: widget.orderId,
        activity: 'Paket dalam perjalanan ke alamat tujuan',
        status: 'shipping',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      DeliveryActivity(
        orderId: widget.orderId,
        activity: 'Paket telah diserahkan ke kurir JNE',
        status: 'shipped',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _buildBody(),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lacak Pengiriman',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Order ${widget.orderId}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.orderType == 'store_delivery')
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF2E7D32)),
            onPressed: _callStore,
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.grey),
          onPressed: _loadTrackingData,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadTrackingData,
        color: const Color(0xFF2E7D32),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderStatusCard(),
              const SizedBox(height: 20),
              _buildDeliveryInfoCard(),
              const SizedBox(height: 20),
              _buildTrackingTimeline(),
              const SizedBox(height: 20),
              if (widget.orderType == 'store_delivery') _buildStoreContactCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF2E7D32),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Memuat informasi pengiriman...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadTrackingData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusCard() {
    final latestActivity = _activities.isNotEmpty ? _activities.first : null;
    final status = latestActivity?.status ?? 'pending';
    final statusInfo = _getStatusInfo(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusInfo.color.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: statusInfo.color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: statusInfo.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: statusInfo.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(statusInfo.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusInfo.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusInfo.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusInfo.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (latestActivity != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Update terakhir: ${_formatDateTime(latestActivity.timestamp)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
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
                child: Icon(
                  widget.orderType == 'store_delivery' ? Icons.store : Icons.local_shipping,
                  color: const Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informasi Pengiriman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.location_on,
            'Jenis Pengiriman',
            widget.orderType == 'store_delivery' ? 'Pengiriman Toko' : 'Kurir Ekspedisi',
          ),
          _buildInfoRow(
            Icons.confirmation_number,
            'Nomor Pesanan',
            widget.orderId,
          ),
          if (widget.orderType == 'store_delivery') ...[
            _buildInfoRow(
              Icons.access_time,
              'Estimasi Tiba',
              'Hari ini - Besok',
            ),
            _buildInfoRow(
              Icons.store,
              'Dikirim dari',
              'Toko Barokah, Laren - Lamongan',
            ),
          ] else ...[
            _buildInfoRow(
              Icons.local_shipping,
              'Kurir',
              'JNE Regular',
            ),
            _buildInfoRow(
              Icons.confirmation_number,
              'Resi',
              'JNE123456789',
              isClickable: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isClickable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: isClickable ? () => _openCourierTracking(value) : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: isClickable ? const Color(0xFF2E7D32) : const Color(0xFF2D3748),
                  fontWeight: FontWeight.w500,
                  decoration: isClickable ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline() {
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
                child: const Icon(
                  Icons.timeline,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Riwayat Pengiriman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_activities.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada aktivitas pengiriman',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];
                final isLast = index == _activities.length - 1;
                return _buildTimelineItem(activity, isLast);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem(DeliveryActivity activity, bool isLast) {
    final statusInfo = _getStatusInfo(activity.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: statusInfo.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusInfo.color.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                statusInfo.icon,
                color: Colors.white,
                size: 14,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activity,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(activity.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (activity.additionalData.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activity.additionalData.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreContactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
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
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Hubungi Toko',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Ada pertanyaan tentang pengiriman ini? Hubungi langsung Toko Barokah.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _callStore,
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Telepon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openWhatsApp,
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return StatusInfo(
          title: 'Menunggu Konfirmasi',
          description: 'Pesanan sedang diproses',
          icon: Icons.schedule,
          color: Colors.orange,
        );
      case 'confirmed':
        return StatusInfo(
          title: 'Dikonfirmasi',
          description: 'Pesanan telah dikonfirmasi',
          icon: Icons.check_circle,
          color: Colors.blue,
        );
      case 'preparing':
        return StatusInfo(
          title: 'Sedang Disiapkan',
          description: 'Pesanan sedang disiapkan',
          icon: Icons.inventory,
          color: Colors.purple,
        );
      case 'on_delivery':
        return StatusInfo(
          title: 'Dalam Perjalanan',
          description: 'Sedang dikirim ke alamat tujuan',
          icon: Icons.local_shipping,
          color: Colors.blue,
        );
      case 'delivered':
        return StatusInfo(
          title: 'Terkirim',
          description: 'Pesanan telah diterima',
          icon: Icons.check_circle,
          color: Colors.green,
        );
      case 'cancelled':
        return StatusInfo(
          title: 'Dibatalkan',
          description: 'Pesanan telah dibatalkan',
          icon: Icons.cancel,
          color: Colors.red,
        );
      default:
        return StatusInfo(
          title: 'Status Tidak Diketahui',
          description: 'Status pesanan tidak jelas',
          icon: Icons.help_outline,
          color: Colors.grey,
        );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dateTime);
  }

  void _callStore() async {
    const phoneNumber = 'tel:+6281234567890';
    final uri = Uri.parse(phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp() async {
    const phoneNumber = '+6281234567890';
    final message = 'Halo, saya ingin menanyakan tentang pengiriman order ${widget.orderId}';
    final uri = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openCourierTracking(String resi) async {
    // Implementasi untuk membuka tracking kurir
    final uri = Uri.parse('https://www.jne.co.id/id/tracking/trace/$resi');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class StatusInfo {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  StatusInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}