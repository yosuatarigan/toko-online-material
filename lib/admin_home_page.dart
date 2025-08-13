// lib/admin/admin_home_page.dart (Enhanced)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toko_online_material/admin/add_edit_kateogory.dart';
import 'package:toko_online_material/admin/add_edit_produk.dart';
import 'package:toko_online_material/admin/admin_chat_list_page.dart';
import 'package:toko_online_material/admin/store_delevery_setting.dart';
import 'package:toko_online_material/service/chat_service.dart';
import 'package:toko_online_material/service/store_delevery_store.dart';
import 'package:toko_online_material/store_delivery_dashboard.dart';
import '../models/category.dart';
import '../models/product.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _DashboardTab(),
      _ProductsTab(),
      _CategoriesTab(),
      const AdminChatListPage(),
      _OrdersTab(), // Enhanced dengan store delivery
      _ReportsTab(),
    ]);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Store Delivery Quick Access
          // if (_currentIndex == 0 || _currentIndex == 4)
          //   IconButton(
          //     icon: const Icon(Icons.local_shipping, color: Colors.white),
          //     onPressed: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder: (context) => const StoreDeliveryDashboard(),
          //         ),
          //       );
          //     },
          //     tooltip: 'Dashboard Pengiriman Toko',
          //   ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur notifikasi admin akan segera hadir'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'store_delivery_settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StoreDeliverySettingsPage(),
                  ),
                );
              } else {
                _showComingSoon(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 12),
                    Text('Profile Admin'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'store_delivery_settings',
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_outlined),
                    SizedBox(width: 12),
                    Text('Pengaturan Pengiriman'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 12),
                    Text('Pengaturan Lainnya'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Keluar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        elevation: 8,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Produk',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Kategori',
          ),
          // Chat tab dengan badge
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                StreamBuilder<int>(
                  stream: ChatService().getAdminUnreadCountStream(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    if (unreadCount > 0) {
                      return Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            activeIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble),
                StreamBuilder<int>(
                  stream: ChatService().getAdminUnreadCountStream(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    if (unreadCount > 0) {
                      return Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Kelola Produk';
      case 2:
        return 'Kelola Kategori';
      case 3:
        return 'Chat Pelanggan';
      case 4:
        return 'Kelola Pesanan';
      case 5:
        return 'Laporan & Analitik';
      default:
        return 'Admin Dashboard';
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur $feature akan segera hadir!'),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Enhanced Dashboard Tab dengan Store Delivery Stats
class _DashboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card (tetap sama)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43A047).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selamat datang, Admin!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            user?.email ?? 'admin@tokobarokah.com',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selamat datang di Dashboard Admin Toko Barokah. Kelola seluruh operasional toko material dengan mudah.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions untuk Store Delivery
          // Row(
          //   children: [
          //     const Text(
          //       'Aksi Cepat',
          //       style: TextStyle(
          //         fontSize: 20,
          //         fontWeight: FontWeight.bold,
          //         color: Color(0xFF2D3748),
          //       ),
          //     ),
          //     const Spacer(),
          //     TextButton.icon(
          //       onPressed: () {
          //         Navigator.push(
          //           context,
          //           MaterialPageRoute(
          //             builder: (context) => const StoreDeliveryDashboard(),
          //           ),
          //         );
          //       },
          //       icon: const Icon(Icons.local_shipping, size: 16),
          //       label: const Text('Lihat Semua'),
          //       style: TextButton.styleFrom(
          //         foregroundColor: const Color(0xFF2E7D32),
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 16),

          // Store Delivery Quick Actions
          // Row(
          //   children: [
          //     Expanded(
          //       child: _buildQuickActionCard(
          //         'Dashboard Pengiriman',
          //         Icons.local_shipping,
          //         const Color(0xFF2E7D32),
          //         () {
          //           Navigator.push(
          //             context,
          //             MaterialPageRoute(
          //               builder: (context) => const StoreDeliveryDashboard(),
          //             ),
          //           );
          //         },
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: _buildQuickActionCard(
          //         'Pengaturan Pengiriman',
          //         Icons.settings,
          //         Colors.blue,
          //         () {
          //           Navigator.push(
          //             context,
          //             MaterialPageRoute(
          //               builder: (context) => const StoreDeliverySettingsPage(),
          //             ),
          //           );
          //         },
          //       ),
          //     ),
          //   ],
          // ),

          const SizedBox(height: 24),

          // Enhanced Stats dengan Store Delivery
          const Text(
            'Statistik Cepat',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, productSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                builder: (context, categorySnapshot) {
                  final productCount = productSnapshot.hasData ? productSnapshot.data!.docs.length : 0;
                  final categoryCount = categorySnapshot.hasData ? categorySnapshot.data!.docs.length : 0;

                  return Column(
                    children: [
                      // First Row - Basic Stats
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Produk',
                              '$productCount',
                              Icons.inventory,
                              const Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Total Kategori',
                              '$categoryCount',
                              Icons.category,
                              const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Second Row - Order Stats
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Pesanan Hari Ini',
                              '0',
                              Icons.shopping_bag,
                              const Color(0xFFFF9800),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Pengiriman Toko',
                              '0',
                              Icons.local_shipping,
                              const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Third Row - Revenue
                      _buildStatCard(
                        'Pendapatan Hari Ini',
                        'Rp 0',
                        Icons.attach_money,
                        const Color(0xFF9C27B0),
                        isFullWidth: true,
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Store Delivery Stats Preview
          // FutureBuilder<StoreDeliveryStats>(
          //   future: StoreDeliveryService.getDeliveryStats(),
          //   builder: (context, snapshot) {
          //     if (snapshot.connectionState == ConnectionState.waiting) {
          //       return const Center(child: CircularProgressIndicator());
          //     }

          //     final stats = snapshot.data ?? StoreDeliveryStats.empty();
          //     return _buildStoreDeliveryPreview(context, stats);
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildStoreDeliveryPreview(BuildContext context, StoreDeliveryStats stats) {
  //   return Container(
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [Colors.green.shade50, Colors.white],
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //       ),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: Colors.green.shade200),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(8),
  //               decoration: BoxDecoration(
  //                 color: const Color(0xFF2E7D32),
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //               child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
  //             ),
  //             const SizedBox(width: 12),
  //             const Text(
  //               'Pengiriman Toko - 30 Hari Terakhir',
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //                 color: Color(0xFF2D3748),
  //               ),
  //             ),
  //             const Spacer(),
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.push(
  //                   context,
  //                   MaterialPageRoute(
  //                     builder: (context) => const StoreDeliveryDashboard(),
  //                   ),
  //                 );
  //               },
  //               child: const Text('Detail'),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //         Row(
  //           children: [
  //             Expanded(
  //               child: _buildMiniStatCard(
  //                 'Total Pesanan',
  //                 '${stats.totalOrders}',
  //                 Icons.shopping_cart,
  //                 Colors.blue,
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: _buildMiniStatCard(
  //                 'Terkirim',
  //                 '${stats.deliveredOrders}',
  //                 Icons.check_circle,
  //                 Colors.green,
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: _buildMiniStatCard(
  //                 'Sukses Rate',
  //                 '${stats.successRate.toStringAsFixed(0)}%',
  //                 Icons.trending_up,
  //                 Colors.purple,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isFullWidth = false,
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
          ),
        ],
      ),
    );
  }
}

// Enhanced Orders Tab dengan Store Delivery Integration
class _OrdersTab extends StatefulWidget {
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2E7D32),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF2E7D32),
            tabs: const [
              Tab(text: 'Semua Pesanan'),
              Tab(text: 'Pengiriman Toko'),
              Tab(text: 'Kurir Ekspedisi'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllOrdersView(),
              _buildStoreDeliveryView(),
              _buildCourierOrdersView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllOrdersView() {
    return _buildComingSoonContent('Semua Pesanan', 
      'Kelola semua pesanan dari berbagai metode pengiriman');
  }

  Widget _buildStoreDeliveryView() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header dengan tombol aksi
          // Row(
          //   children: [
          //     const Text(
          //       'Pengiriman Toko',
          //       style: TextStyle(
          //         fontSize: 20,
          //         fontWeight: FontWeight.bold,
          //         color: Color(0xFF2D3748),
          //       ),
          //     ),
          //     const Spacer(),
          //     ElevatedButton.icon(
          //       onPressed: () {
          //         Navigator.push(
          //           context,
          //           MaterialPageRoute(
          //             builder: (context) => const StoreDeliveryDashboard(),
          //           ),
          //         );
          //       },
          //       icon: const Icon(Icons.dashboard, size: 18),
          //       label: const Text('Dashboard'),
          //       style: ElevatedButton.styleFrom(
          //         backgroundColor: const Color(0xFF2E7D32),
          //         foregroundColor: Colors.white,
          //         shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(12),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
          const SizedBox(height: 24),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStatsCard(
                  'Menunggu Konfirmasi',
                  '0',
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStatsCard(
                  'Sedang Dikirim',
                  '0',
                  Icons.local_shipping,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStatsCard(
                  'Selesai',
                  '0',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Info Card
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      size: 40,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Kelola Pengiriman Toko',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fitur lengkap untuk mengelola pesanan dengan pengiriman toko.\nAkses dashboard untuk melihat detail dan mengatur pengiriman.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF718096),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     OutlinedButton.icon(
                  //       onPressed: () {
                  //         Navigator.push(
                  //           context,
                  //           MaterialPageRoute(
                  //             builder: (context) => const StoreDeliverySettingsPage(),
                  //           ),
                  //         );
                  //       },
                  //       icon: const Icon(Icons.settings, size: 18),
                  //       label: const Text('Pengaturan'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: const Color(0xFF2E7D32),
                  //         side: const BorderSide(color: Color(0xFF2E7D32)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 16),
                  //     ElevatedButton.icon(
                  //       onPressed: () {
                  //         Navigator.push(
                  //           context,
                  //           MaterialPageRoute(
                  //             builder: (context) => const StoreDeliveryDashboard(),
                  //           ),
                  //         );
                  //       },
                  //       icon: const Icon(Icons.dashboard, size: 18),
                  //       label: const Text('Buka Dashboard'),
                  //       style: ElevatedButton.styleFrom(
                  //         backgroundColor: const Color(0xFF2E7D32),
                  //         foregroundColor: Colors.white,
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierOrdersView() {
    return _buildComingSoonContent('Pesanan Kurir Ekspedisi', 
      'Kelola pesanan yang dikirim melalui kurir ekspedisi (JNE, TIKI, dll)');
  }

  Widget _buildQuickStatsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Products Tab (tetap sama seperti aslinya)
class _ProductsTab extends StatefulWidget {
  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _productsStream {
    return FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;

    return products.where((product) {
      return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk "${product.name}" berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text(
          'Apakah Anda yakin ingin menghapus produk "${product.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar & Add Button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditProductPage(),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF2E7D32),
                mini: true,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),

        // Products List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada produk',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap tombol + untuk menambah produk',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              final products = snapshot.data!.docs
                  .map((doc) => Product.fromFirestore(doc))
                  .toList();

              final filteredProducts = _filterProducts(products);

              if (filteredProducts.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Produk tidak ditemukan',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredProducts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return _ProductCard(
                    product: product,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEditProductPage(product: product),
                        ),
                      );
                    },
                    onDelete: () => _showDeleteConfirmation(product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Categories Tab (tetap sama seperti aslinya)
class _CategoriesTab extends StatefulWidget {
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _categoriesStream {
    return FirebaseFirestore.instance
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<Category> _filterCategories(List<Category> categories) {
    if (_searchQuery.isEmpty) return categories;

    return categories.where((category) {
      return category.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          category.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _deleteCategory(Category category) async {
    // Check if category is being used by products
    final productsQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('categoryId', isEqualTo: category.id)
        .limit(1)
        .get();

    if (productsQuery.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kategori tidak dapat dihapus karena masih digunakan oleh produk',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(category.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategori "${category.name}" berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus kategori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "${category.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(category);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar & Add Button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari kategori...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditCategoryPage(),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF2E7D32),
                mini: true,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),

        // Categories List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _categoriesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada kategori',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap tombol + untuk menambah kategori',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              final categories = snapshot.data!.docs
                  .map((doc) => Category.fromFirestore(doc))
                  .toList();

              final filteredCategories = _filterCategories(categories);

              if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Kategori tidak ditemukan',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredCategories.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final category = filteredCategories[index];
                  return _CategoryCard(
                    category: category,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddEditCategoryPage(category: category),
                        ),
                      );
                    },
                    onDelete: () => _showDeleteConfirmation(category),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// Reports Tab (tetap sama)
class _ReportsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _buildComingSoonContent('Laporan & Analitik',
      'Lihat laporan penjualan, analitik pengiriman, dan performa toko');
  }
}

Widget _buildComingSoonContent(String feature, [String? description]) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    margin: const EdgeInsets.all(24),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.construction,
            size: 40,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Fitur $feature',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description ?? 'Sedang dalam pengembangan\nakan segera hadir!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Color(0xFF718096), height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Text(
            '🚀 Coming Soon',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    ),
  );
}

// Product Card Component (tetap sama seperti aslinya)
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.imageUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported);
                          },
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        size: 30,
                        color: Colors.grey,
                      ),
              ),

              const SizedBox(width: 16),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF718096),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Price and Weight Row
                    Row(
                      children: [
                        Text(
                          product.hasVariants ? product.priceRange : product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 12,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.scale_outlined,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.weightRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Status and Variants Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: product.isActive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.isActive ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: product.isActive ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (product.hasVariants)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${product.getVariantCombinations().length} Varian',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: product.stockStatusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_outlined,
                                size: 12,
                                color: product.stockStatusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${product.totalStock}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: product.stockStatusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Category Card Component (tetap sama seperti aslinya)
class _CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

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

  Color _getColor(String colorString) {
    try {
      return Color(int.parse(colorString));
    } catch (e) {
      return const Color(0xFF2196F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(category.color);
    final icon = _getIconData(category.iconName);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),

              const SizedBox(width: 16),

              // Category Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF718096),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dibuat: ${category.createdAt.day}/${category.createdAt.month}/${category.createdAt.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}