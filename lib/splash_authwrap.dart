import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:toko_online_material/service/cart_service.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'admin_home_page.dart';

class SplashAuthWrapper extends StatefulWidget {
  const SplashAuthWrapper({super.key});

  @override
  State<SplashAuthWrapper> createState() => _SplashAuthWrapperState();
}

class _SplashAuthWrapperState extends State<SplashAuthWrapper> {
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash delay

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _getUserRole(user.uid);
      
      // Sync cart after login
      if (mounted) {
        final cartService = Provider.of<CartService>(context, listen: false);
        await cartService.mergeLocalWithFirebase();
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _userRole = doc.data()?['role'] ?? 'user';
        });
      }
    } catch (e) {
      setState(() {
        _userRole = 'user'; // Default role
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          // User is logged in, sync cart and check role
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final cartService = Provider.of<CartService>(context, listen: false);
            await cartService.mergeLocalWithFirebase();
          });

          if (_userRole == 'admin') {
            return const AdminHomePage();
          } else {
            return const HomePage();
          }
        } else {
          // User not logged in, clear cart sync
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final cartService = Provider.of<CartService>(context, listen: false);
            await cartService.onUserLogout();
          });
          
          return const LoginPage();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.store,
                size: 60,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'MaterialStore',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Toko Online Bahan Material',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}