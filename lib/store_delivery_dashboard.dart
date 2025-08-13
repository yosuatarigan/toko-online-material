// // lib/pages/admin/store_delivery_dashboard.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:toko_online_material/service/store_delevery_store.dart';

// class StoreDeliveryDashboard extends StatefulWidget {
//   const StoreDeliveryDashboard({super.key});

//   @override
//   State<StoreDeliveryDashboard> createState() => _StoreDeliveryDashboardState();
// }

// class _StoreDeliveryDashboardState extends State<StoreDeliveryDashboard>
//     with TickerProviderStateMixin {
//   late TabController _tabController;
  
//   StoreDeliveryStats? _stats;
//   List<StoreDeliveryOrder> _pendingOrders = [];
//   List<StoreDeliveryOrder> _todayOrders = [];
//   bool _isLoading = true;
  
//   DateTime _selectedDate = DateTime.now();

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _loadData();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadData() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final stats = await StoreDeliveryService.getDeliveryStats(
//         startDate: _selectedDate.subtract(const Duration(days: 30)),
//         endDate: _selectedDate,
//       );

//       final pendingOrders = await _loadPendingOrders();
//       final todayOrders = await _loadTodayOrders();

//       setState(() {
//         _stats = stats;
//         _pendingOrders = pendingOrders;
//         _todayOrders = todayOrders;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showErrorSnackBar('Gagal memuat data: $e');
//     }
//   }

//   Future<List<StoreDeliveryOrder>> _loadPendingOrders() async {
//     // Mock data - replace with actual service call
//     return [
//       StoreDeliveryOrder(
//         orderId: 'TB2025010101',
//         customerName: 'Ahmad Sudi',
//         customerPhone: '081234567890',
//         address: 'Jl. Raya Lamongan No. 123',
//         distance: 5.2,
//         totalAmount: 150000,
//         status: 'confirmed',
//         createdAt: DateTime.now().subtract(const Duration(hours: 2)),
//         estimatedDelivery: DateTime.now().add(const Duration(hours: 3)),
//       ),
//       StoreDeliveryOrder(
//         orderId: 'TB2025010102',
//         customerName: 'Siti Aminah',
//         customerPhone: '081234567891',
//         address: 'Desa Centini, Laren',
//         distance: 2.8,
//         totalAmount: 85000,
//         status: 'preparing',
//         createdAt: DateTime.now().subtract(const Duration(hours: 1)),
//         estimatedDelivery: DateTime.now().add(const Duration(hours: 2)),
//       ),
//     ];
//   }

//   Future<List<StoreDeliveryOrder>> _loadTodayOrders() async {
//     // Mock data - replace with actual service call
//     return [
//       StoreDeliveryOrder(
//         orderId: 'TB2025010103',
//         customerName: 'Budi Hartono',
//         customerPhone: '081234567892',
//         address: 'Jl. Veteran Lamongan',
//         distance: 7.1,
//         totalAmount: 230000,
//         status: 'on_delivery',
//         createdAt: DateTime.now().subtract(const Duration(hours: 3)),
//         estimatedDelivery: DateTime.now().add(const Duration(hours: 1)),
//       ),
//       StoreDeliveryOrder(
//         orderId: 'TB2025010104',
//         customerName: 'Dewi Sartika',
//         customerPhone: '081234567893',
//         address: 'Perumahan Griya Lamongan',
//         distance: 4.5,
//         totalAmount: 95000,
//         status: 'delivered',
//         createdAt: DateTime.now().subtract(const Duration(hours: 6)),
//         estimatedDelivery: DateTime.now().subtract(const Duration(hours: 2)),
//       ),
//     ];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: _buildAppBar(),
//       body: _isLoading ? _buildLoadingState() : _buildContent(),
//       floatingActionButton: _buildFloatingActionButton(),
//     );
//   }

//   PreferredSizeWidget _buildAppBar() {
//     return AppBar(
//       backgroundColor: Colors.white,
//       elevation: 1,
//       shadowColor: Colors.black.withOpacity(0.1),
//       leading: IconButton(
//         icon: const Icon(Icons.arrow_back, color: Colors.black87),
//         onPressed: () => Navigator.pop(context),
//       ),
//       title: const Text(
//         'Dashboard Pengiriman Toko',
//         style: TextStyle(
//           color: Colors.black87,
//           fontSize: 18,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//       actions: [
//         IconButton(
//           icon: const Icon(Icons.settings, color: Colors.grey),
//           onPressed: () {
//             // Navigate to settings
//           },
//         ),
//         IconButton(
//           icon: const Icon(Icons.refresh, color: Colors.grey),
//           onPressed: _loadData,
//         ),
//       ],
//       bottom: TabBar(
//         controller: _tabController,
//         labelColor: const Color(0xFF2E7D32),
//         unselectedLabelColor: Colors.grey[600],
//         indicatorColor: const Color(0xFF2E7D32),
//         tabs: const [
//           Tab(text: 'Overview'),
//           Tab(text: 'Pesanan'),
//           Tab(text: 'Statistik'),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingState() {
//     return const Center(
//       child: CircularProgressIndicator(
//         color: Color(0xFF2E7D32),
//       ),
//     );
//   }

//   Widget _buildContent() {
//     return TabBarView(
//       controller: _tabController,
//       children: [
//         _buildOverviewTab(),
//         _buildOrdersTab(),
//         _buildStatsTab(),
//       ],
//     );
//   }

//   Widget _buildOverviewTab() {
//     return RefreshIndicator(
//       onRefresh: _loadData,
//       color: const Color(0xFF2E7D32),
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         physics: const AlwaysScrollableScrollPhysics(),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildQuickStats(),
//             const SizedBox(height: 20),
//             _buildPendingOrdersSection(),
//             const SizedBox(height: 20),
//             _buildTodayOrdersSection(),
//             const SizedBox(height: 20),
//             _buildQuickActions(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildQuickStats() {
//     if (_stats == null) return const SizedBox.shrink();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Ringkasan Hari Ini',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: Color(0xFF2D3748),
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             Expanded(
//               child: _buildStatCard(
//                 title: 'Pesanan Pending',
//                 value: '${_pendingOrders.length}',
//                 icon: Icons.schedule,
//                 color: Colors.orange,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _buildStatCard(
//                 title: 'Sedang Dikirim',
//                 value: '${_todayOrders.where((o) => o.status == 'on_delivery').length}',
//                 icon: Icons.local_shipping,
//                 color: Colors.blue,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: _buildStatCard(
//                 title: 'Selesai Hari Ini',
//                 value: '${_todayOrders.where((o) => o.status == 'delivered').length}',
//                 icon: Icons.check_circle,
//                 color: Colors.green,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _buildStatCard(
//                 title: 'Total Pendapatan',
//                 value: 'Rp ${_formatCurrency(_todayOrders.where((o) => o.status == 'delivered').fold(0.0, (sum, order) => sum + order.totalAmount))}',
//                 icon: Icons.attach_money,
//                 color: const Color(0xFF2E7D32),
//                 isAmount: true,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildStatCard({
//     required String title,
//     required String value,
//     required IconData icon,
//     required Color color,
//     bool isAmount = false,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.2)),
//         boxShadow: [
//           BoxShadow(
//             color: color.withOpacity(0.1),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(icon, color: color, size: 20),
//               ),
//               const Spacer(),
//               Icon(Icons.trending_up, color: color, size: 16),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: isAmount ? 14 : 20,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey[600],
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPendingOrdersSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Text(
//               'Pesanan Menunggu',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF2D3748),
//               ),
//             ),
//             const Spacer(),
//             if (_pendingOrders.isNotEmpty)
//               TextButton(
//                 onPressed: () {
//                   // Navigate to full pending orders list
//                 },
//                 child: const Text('Lihat Semua'),
//               ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         if (_pendingOrders.isEmpty) ...[
//           _buildEmptyState(
//             'Tidak ada pesanan menunggu',
//             'Semua pesanan sudah diproses',
//             Icons.check_circle_outline,
//           ),
//         ] else ...[
//           ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: _pendingOrders.take(3).length,
//             itemBuilder: (context, index) {
//               return _buildOrderCard(_pendingOrders[index]);
//             },
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildTodayOrdersSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Text(
//               'Pesanan Hari Ini',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF2D3748),
//               ),
//             ),
//             const Spacer(),
//             TextButton(
//               onPressed: () {
//                 // Navigate to today's orders
//               },
//               child: const Text('Lihat Semua'),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         if (_todayOrders.isEmpty) ...[
//           _buildEmptyState(
//             'Belum ada pesanan hari ini',
//             'Pesanan akan muncul di sini',
//             Icons.local_shipping_outlined,
//           ),
//         ] else ...[
//           ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: _todayOrders.take(3).length,
//             itemBuilder: (context, index) {
//               return _buildOrderCard(_todayOrders[index]);
//             },
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildOrderCard(StoreDeliveryOrder order) {
//     final statusInfo = _getOrderStatusInfo(order.status);

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: statusInfo.color.withOpacity(0.2)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: statusInfo.color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   statusInfo.label,
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.bold,
//                     color: statusInfo.color,
//                   ),
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 order.orderId,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF2D3748),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       order.customerName,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.bold,
//                         color: Color(0xFF2D3748),
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Row(
//                       children: [
//                         Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
//                         const SizedBox(width: 4),
//                         Expanded(
//                           child: Text(
//                             order.address,
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[600],
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 2),
//                     Row(
//                       children: [
//                         Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
//                         const SizedBox(width: 4),
//                         Text(
//                           '${order.distance.toStringAsFixed(1)} km',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     'Rp ${_formatCurrency(order.totalAmount)}',
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF2E7D32),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     _formatTime(order.estimatedDelivery),
//                     style: TextStyle(
//                       fontSize: 11,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: () => _viewOrderDetails(order),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: const Color(0xFF2E7D32),
//                     side: const BorderSide(color: Color(0xFF2E7D32)),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: const Text('Detail'),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: () => _updateOrderStatus(order),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: statusInfo.color,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: Text(_getNextStatusAction(order.status)),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildQuickActions() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Aksi Cepat',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: Color(0xFF2D3748),
//           ),
//         ),
//         const SizedBox(height: 16),
//         GridView.count(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           crossAxisCount: 2,
//           crossAxisSpacing: 12,
//           mainAxisSpacing: 12,
//           childAspectRatio: 1.8,
//           children: [
//             _buildQuickActionCard(
//               'Pengaturan Pengiriman',
//               Icons.settings,
//               Colors.blue,
//               () {
//                 // Navigate to settings
//               },
//             ),
//             _buildQuickActionCard(
//               'Laporan Harian',
//               Icons.assessment,
//               Colors.purple,
//               () {
//                 // Generate daily report
//               },
//             ),
//             _buildQuickActionCard(
//               'Rute Pengiriman',
//               Icons.map,
//               Colors.orange,
//               () {
//                 // Show delivery routes
//               },
//             ),
//             _buildQuickActionCard(
//               'Notifikasi',
//               Icons.notifications,
//               Colors.red,
//               () {
//                 // Show notifications
//               },
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildQuickActionCard(
//     String title,
//     IconData icon,
//     Color color,
//     VoidCallback onTap,
//   ) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(0.2)),
//           boxShadow: [
//             BoxShadow(
//               color: color.withOpacity(0.1),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Icon(icon, color: color, size: 24),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               title,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF2D3748),
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildOrdersTab() {
//     return RefreshIndicator(
//       onRefresh: _loadData,
//       color: const Color(0xFF2E7D32),
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         physics: const AlwaysScrollableScrollPhysics(),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildOrderFilters(),
//             const SizedBox(height: 20),
//             ..._getAllOrders().map((order) => _buildOrderCard(order)).toList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildOrderFilters() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Filter Pesanan',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF2D3748),
//             ),
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: _buildFilterChip('Semua', true, () {}),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _buildFilterChip('Pending', false, () {}),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _buildFilterChip('Dikirim', false, () {}),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _buildFilterChip('Selesai', false, () {}),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//         decoration: BoxDecoration(
//           color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade100,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w500,
//             color: isSelected ? Colors.white : Colors.grey[700],
//           ),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }

//   Widget _buildStatsTab() {
//     return RefreshIndicator(
//       onRefresh: _loadData,
//       color: const Color(0xFF2E7D32),
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         physics: const AlwaysScrollableScrollPhysics(),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildStatsOverview(),
//             const SizedBox(height: 20),
//             _buildPerformanceMetrics(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatsOverview() {
//     if (_stats == null) return const SizedBox.shrink();

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Statistik 30 Hari Terakhir',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF2D3748),
//             ),
//           ),
//           const SizedBox(height: 20),
//           _buildStatsGrid(),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatsGrid() {
//     if (_stats == null) return const SizedBox.shrink();

//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: _buildStatItem(
//                 'Total Pesanan',
//                 '${_stats!.totalOrders}',
//                 Icons.shopping_cart,
//                 Colors.blue,
//               ),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: _buildStatItem(
//                 'Terkirim',
//                 '${_stats!.deliveredOrders}',
//                 Icons.check_circle,
//                 Colors.green,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             Expanded(
//               child: _buildStatItem(
//                 'Tingkat Sukses',
//                 '${_stats!.successRate.toStringAsFixed(1)}%',
//                 Icons.trending_up,
//                 Colors.purple,
//               ),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: _buildStatItem(
//                 'Jarak Rata-rata',
//                 '${_stats!.averageDistance.toStringAsFixed(1)} km',
//                 Icons.straighten,
//                 Colors.orange,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         _buildStatItem(
//           'Total Pendapatan',
//           'Rp ${_formatCurrency(_stats!.totalRevenue)}',
//           Icons.attach_money,
//           const Color(0xFF2E7D32),
//           isFullWidth: true,
//         ),
//       ],
//     );
//   }

//   Widget _buildStatItem(
//     String label,
//     String value,
//     IconData icon,
//     Color color, {
//     bool isFullWidth = false,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: color, size: 20),
//               const Spacer(),
//               if (!isFullWidth)
//                 Icon(Icons.arrow_upward, color: color, size: 16),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: isFullWidth ? 18 : 16,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey[600],
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPerformanceMetrics() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Metrik Performa',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF2D3748),
//             ),
//           ),
//           const SizedBox(height: 20),
//           _buildMetricItem('Waktu Rata-rata Pengiriman', '2.5 jam', Colors.blue),
//           _buildMetricItem('Kepuasan Pelanggan', '4.8/5.0', Colors.green),
//           _buildMetricItem('Efisiensi Rute', '87%', Colors.purple),
//           _buildMetricItem('Biaya per Pengiriman', 'Rp 12,500', Colors.orange),
//         ],
//       ),
//     );
//   }

//   Widget _buildMetricItem(String label, String value, Color color) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Row(
//         children: [
//           Container(
//             width: 8,
//             height: 40,
//             decoration: BoxDecoration(
//               color: color,
//               borderRadius: BorderRadius.circular(4),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     color: Color(0xFF2D3748),
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: color,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState(String title, String subtitle, IconData icon) {
//     return Container(
//       padding: const EdgeInsets.all(32),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Icon(
//             icon,
//             size: 48,
//             color: Colors.grey.shade400,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//               color: Color(0xFF2D3748),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             subtitle,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey[600],
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFloatingActionButton() {
//     return FloatingActionButton.extended(
//       onPressed: () {
//         // Create manual delivery order
//       },
//       backgroundColor: const Color(0xFF2E7D32),
//       icon: const Icon(Icons.add, color: Colors.white),
//       label: const Text(
//         'Buat Pengiriman',
//         style: TextStyle(color: Colors.white),
//       ),
//     );
//   }

//   // Helper methods
//   List<StoreDeliveryOrder> _getAllOrders() {
//     return [..._pendingOrders, ..._todayOrders];
//   }

//   OrderStatusInfo _getOrderStatusInfo(String status) {
//     switch (status) {
//       case 'pending':
//         return OrderStatusInfo('Menunggu', Colors.orange);
//       case 'confirmed':
//         return OrderStatusInfo('Dikonfirmasi', Colors.blue);
//       case 'preparing':
//         return OrderStatusInfo('Disiapkan', Colors.purple);
//       case 'on_delivery':
//         return OrderStatusInfo('Dikirim', Colors.blue);
//       case 'delivered':
//         return OrderStatusInfo('Terkirim', Colors.green);
//       case 'cancelled':
//         return OrderStatusInfo('Dibatalkan', Colors.red);
//       default:
//         return OrderStatusInfo('Unknown', Colors.grey);
//     }
//   }

//   String _getNextStatusAction(String status) {
//     switch (status) {
//       case 'pending':
//         return 'Konfirmasi';
//       case 'confirmed':
//         return 'Siapkan';
//       case 'preparing':
//         return 'Kirim';
//       case 'on_delivery':
//         return 'Selesai';
//       default:
//         return 'Update';
//     }
//   }

//   void _viewOrderDetails(StoreDeliveryOrder order) {
//     // Navigate to order details page
//   }

//   void _updateOrderStatus(StoreDeliveryOrder order) {
//     // Show status update dialog
//   }

//   String _formatCurrency(double amount) {
//     return amount.toStringAsFixed(0).replaceAllMapped(
//       RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
//       (Match m) => '${m[1]}.',
//     );
//   }

//   String _formatTime(DateTime dateTime) {
//     return DateFormat('HH:mm').format(dateTime);
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }

// // Models
// class StoreDeliveryOrder {
//   final String orderId;
//   final String customerName;
//   final String customerPhone;
//   final String address;
//   final double distance;
//   final double totalAmount;
//   final String status;
//   final DateTime createdAt;
//   final DateTime estimatedDelivery;

//   StoreDeliveryOrder({
//     required this.orderId,
//     required this.customerName,
//     required this.customerPhone,
//     required this.address,
//     required this.distance,
//     required this.totalAmount,
//     required this.status,
//     required this.createdAt,
//     required this.estimatedDelivery,
//   });
// }

// class OrderStatusInfo {
//   final String label;
//   final Color color;

//   OrderStatusInfo(this.label, this.color);
// }