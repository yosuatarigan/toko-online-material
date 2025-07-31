import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _fadeController.forward();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                _showSuccessSnackBar('Berhasil keluar dari akun');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
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

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur $feature akan segera hadir!'),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileHeader(),
                _buildQuickActions(),
                _buildMenuSection(),
                // _buildCustomerServiceSection(),
                _buildStoreInfoSection(),
                _buildFooter(),
                const SizedBox(height: 100), // Space for bottom nav
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF2E7D32),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
                Color(0xFF1B5E20),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Profile Saya',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Toko Barokah',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      // const Spacer(),
                      // Container(
                      //   decoration: BoxDecoration(
                      //     color: Colors.white.withOpacity(0.2),
                      //     borderRadius: BorderRadius.circular(12),
                      //   ),
                      //   child: IconButton(
                      //     icon: const Icon(Icons.settings, color: Colors.white),
                      //     onPressed: () => _showComingSoonSnackBar('Pengaturan'),
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2E7D32),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _userData?['profileImage']?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: _userData!['profileImage'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.green.shade50,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.green.shade400,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.green.shade50,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.green.shade400,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.green.shade50,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.green.shade400,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    onPressed: () => _showComingSoonSnackBar('Edit Foto Profile'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userData?['name'] ?? user?.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userData?['email'] ?? user?.email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (_userData?['phone']?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              _userData!['phone'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Pelanggan Setia',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Pesanan',
              subtitle: 'Riwayat',
              color: Colors.blue.shade600,
              onTap: () => _showComingSoonSnackBar('Riwayat Pesanan'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.favorite_outline,
              title: 'Wishlist',
              subtitle: 'Favorit',
              color: Colors.red.shade600,
              onTap: () => _showComingSoonSnackBar('Wishlist'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.location_on_outlined,
              title: 'Alamat',
              subtitle: 'Pengiriman',
              color: Colors.orange.shade600,
              onTap: () => _showComingSoonSnackBar('Alamat Pengiriman'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Ubah data pribadi Anda',
            onTap: () => _showComingSoonSnackBar('Edit Profile'),
          ),
          _buildMenuDivider(),
          // _buildMenuItem(
          //   icon: Icons.payment_outlined,
          //   title: 'Metode Pembayaran',
          //   subtitle: 'Kelola metode pembayaran',
          //   onTap: () => _showComingSoonSnackBar('Metode Pembayaran'),
          // ),
          // _buildMenuDivider(),
          // _buildMenuItem(
          //   icon: Icons.notifications_outlined,
          //   title: 'Notifikasi',
          //   subtitle: 'Pengaturan notifikasi',
          //   onTap: () => _showComingSoonSnackBar('Pengaturan Notifikasi'),
          // ),
          // _buildMenuDivider(),
          // _buildMenuItem(
          //   icon: Icons.security_outlined,
          //   title: 'Keamanan',
          //   subtitle: 'Password & keamanan akun',
          //   onTap: () => _showComingSoonSnackBar('Keamanan Akun'),
          // ),
          // _buildMenuDivider(),
          // _buildMenuItem(
          //   icon: Icons.language_outlined,
          //   title: 'Bahasa',
          //   subtitle: 'Pilih bahasa aplikasi',
          //   trailing: Text(
          //     'Indonesia',
          //     style: TextStyle(
          //       fontSize: 14,
          //       color: Colors.grey[600],
          //     ),
          //   ),
          //   onTap: () => _showComingSoonSnackBar('Pengaturan Bahasa'),
          // ),
        ],
      ),
    );
  }

  Widget _buildCustomerServiceSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bantuan & Dukungan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Pusat Bantuan',
            subtitle: 'FAQ dan panduan',
            onTap: () => _showComingSoonSnackBar('Pusat Bantuan'),
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            icon: Icons.chat_outlined,
            title: 'Live Chat',
            subtitle: 'Chat dengan customer service',
            onTap: () => _showComingSoonSnackBar('Live Chat'),
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            icon: Icons.phone_outlined,
            title: 'Hubungi Kami',
            subtitle: 'Kontak Toko Barokah',
            onTap: () => _showStoreContactDialog(),
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            icon: Icons.rate_review_outlined,
            title: 'Beri Rating',
            subtitle: 'Rating & review aplikasi',
            onTap: () => _showComingSoonSnackBar('Rating Aplikasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.home_work,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toko Barokah',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        'Material Berkualitas Sejak 2020',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStoreInfoItem(
              Icons.location_on,
              'Jl. Tanggul, Sawah, Centini, Kec. Laren\nKabupaten Lamongan, Jawa Timur 62262',
            ),
            const SizedBox(height: 12),
            _buildStoreInfoItem(
              Icons.access_time,
              'Senin - Sabtu: 07:00 - 17:00\nMinggu: 08:00 - 15:00',
            ),
            const SizedBox(height: 12),
            _buildStoreInfoItem(
              Icons.email,
              'toko.barokah.material@gmail.com',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          // Logout Button
          Container(
            width: double.infinity,
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _logout,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Keluar Akun',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // App Version
          Text(
            'Versi Aplikasi 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© 2025 Toko Barokah - All Rights Reserved',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.green.shade600,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    return Divider(
      height: 1,
      color: Colors.grey.shade200,
      indent: 58,
    );
  }

  void _showStoreContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.home_work,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Kontak Toko Barokah', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactItem(Icons.location_on, 'Alamat', 'Jl. Tanggul, Sawah, Centini\nKec. Laren, Lamongan, Jawa Timur'),
            const SizedBox(height: 16),
            _buildContactItem(Icons.access_time, 'Jam Buka', 'Senin-Sabtu: 07:00-17:00\nMinggu: 08:00-15:00'),
            const SizedBox(height: 16),
            _buildContactItem(Icons.email, 'Email', 'toko.barokah.material@gmail.com'),
          ],
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

  Widget _buildContactItem(IconData icon, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}