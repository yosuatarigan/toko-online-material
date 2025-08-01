import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:toko_online_material/service/cart_service.dart';
import 'package:toko_online_material/splash_authwrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  await CartService().initialize();
  
  // Set system UI untuk tampilan modern dengan tema hijau
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const TokoBarokahApp());
}

class TokoBarokahApp extends StatelessWidget {
  const TokoBarokahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CartService(),
      child: MaterialApp(
        title: 'Toko Barokah',
        debugShowCheckedModeBanner: false,
        theme: _buildBarokahTheme(),
        home: const SplashAuthWrapper(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
      ),
    );
  }

  ThemeData _buildBarokahTheme() {
    // Palet warna hijau untuk Toko Barokah
    const primaryGreen = Color(0xFF2E7D32); // Hijau utama
    const darkGreen = Color(0xFF1B5E20);    // Hijau gelap
    const mediumGreen = Color(0xFF388E3C);  // Hijau medium
    const lightGreen = Color(0xFF4CAF50);   // Hijau terang
    const accentGreen = Color(0xFF66BB6A);  // Hijau aksen
    
    const lightBackground = Color(0xFFF1F8E9); // Background hijau sangat muda
    const darkGrey = Color(0xFF2D3748);
    const mediumGrey = Color(0xFF4A5568);
    const lightTextGrey = Color(0xFF718096);

    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      
      // Color Scheme dengan tema hijau barokah
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.light,
        primary: primaryGreen,
        onPrimary: Colors.white,
        secondary: mediumGreen,
        tertiary: accentGreen,
        surface: Colors.white,
        onSurface: darkGrey,
        background: lightBackground,
        onBackground: darkGrey,
        surfaceVariant: const Color(0xFFE8F5E8),
        onSurfaceVariant: mediumGrey,
      ),
      
      scaffoldBackgroundColor: lightBackground,
      
      // Typography - Tetap menggunakan font system yang clean
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkGrey),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGrey),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkGrey),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: darkGrey),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkGrey),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkGrey),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkGrey),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: darkGrey),
        bodyLarge: TextStyle(fontSize: 16, color: mediumGrey),
        bodyMedium: TextStyle(fontSize: 14, color: mediumGrey),
        bodySmall: TextStyle(fontSize: 12, color: lightTextGrey),
      ),
      
      // AppBar Theme dengan gradien hijau
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 4,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      
      // Card Theme dengan shadow hijau subtle
      cardTheme: CardTheme(
        elevation: 3,
        shadowColor: primaryGreen.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        surfaceTintColor: const Color(0xFFE8F5E8),
      ),
      
      // Button Themes dengan warna hijau barokah
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryGreen.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) {
                return darkGreen;
              }
              if (states.contains(MaterialState.hovered)) {
                return mediumGreen;
              }
              return primaryGreen;
            },
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Input Theme dengan aksen hijau
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: const TextStyle(color: lightTextGrey),
        labelStyle: const TextStyle(color: mediumGrey),
        prefixIconColor: primaryGreen,
        suffixIconColor: primaryGreen,
      ),
      
      // Bottom Navigation Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: lightTextGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      
      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkGrey,
        ),
        contentTextStyle: const TextStyle(fontSize: 16, color: mediumGrey),
      ),
      
      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        modalBackgroundColor: Colors.white,
        modalElevation: 16,
      ),
      
      // Snackbar Theme dengan warna hijau
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryGreen,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: lightGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),
      
      // Chip Theme dengan warna hijau
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE8F5E8),
        selectedColor: primaryGreen.withOpacity(0.15),
        disabledColor: Colors.grey.shade300,
        labelStyle: const TextStyle(color: darkGrey),
        secondaryLabelStyle: const TextStyle(color: primaryGreen),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        checkmarkColor: primaryGreen,
        deleteIconColor: primaryGreen,
      ),
      
      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: darkGrey),
        subtitleTextStyle: TextStyle(fontSize: 14, color: lightTextGrey),
        iconColor: primaryGreen,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 16,
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
        linearTrackColor: Colors.transparent,
        circularTrackColor: Colors.transparent,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(color: primaryGreen, size: 24),
      
      // Tab Bar Theme
      tabBarTheme: const TabBarTheme(
        labelColor: primaryGreen,
        unselectedLabelColor: lightTextGrey,
        indicatorColor: primaryGreen,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
      ),
      
      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return primaryGreen;
            }
            return Colors.grey.shade400;
          },
        ),
        trackColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return primaryGreen.withOpacity(0.5);
            }
            return Colors.grey.shade300;
          },
        ),
      ),
      
      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return primaryGreen;
            }
            return Colors.transparent;
          },
        ),
        checkColor: MaterialStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      
      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return primaryGreen;
            }
            return Colors.grey.shade400;
          },
        ),
      ),
    );
  }
}