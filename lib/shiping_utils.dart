// lib/utils/shipping_utils.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ShippingUtils {
  
  // Copy text to clipboard
  static Future<void> copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nomor resi $text berhasil disalin'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyalin nomor resi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Launch URL
  static Future<void> launchCourierUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get courier website URL with tracking number
  static String? getCourierTrackingUrl(String courierName, String trackingNumber) {
    final courier = courierName.toLowerCase();
    
    if (courier.contains('jne')) {
      return 'https://www.jne.co.id/id/tracking/trace?tracking_no=$trackingNumber';
    } else if (courier.contains('tiki')) {
      return 'https://www.tiki.id/tracking?tracking_no=$trackingNumber';
    } else if (courier.contains('pos')) {
      return 'https://www.posindonesia.co.id/id/tracking?tracking_no=$trackingNumber';
    } else if (courier.contains('j&t') || courier.contains('jnt')) {
      return 'https://www.jet.co.id/track?tracking_no=$trackingNumber';
    } else if (courier.contains('sicepat')) {
      return 'https://www.sicepat.com/checkAwb?tracking_no=$trackingNumber';
    } else if (courier.contains('ninja')) {
      return 'https://www.ninjaxpress.co/en-id/tracking?tracking_no=$trackingNumber';
    } else if (courier.contains('anteraja')) {
      return 'https://www.anteraja.id/tracking?tracking_no=$trackingNumber';
    }
    
    return null;
  }

  // Get courier icon
  static IconData getCourierIcon(String courierName) {
    final courier = courierName.toLowerCase();
    
    if (courier.contains('toko') || courier.contains('store')) {
      return Icons.store;
    } else {
      return Icons.local_shipping;
    }
  }

  // Get courier color
  static Color getCourierColor(String courierName) {
    final courier = courierName.toLowerCase();
    
    if (courier.contains('toko') || courier.contains('store')) {
      return Colors.green;
    } else if (courier.contains('jne')) {
      return Colors.red;
    } else if (courier.contains('tiki')) {
      return Colors.blue;
    } else if (courier.contains('pos')) {
      return Colors.orange;
    } else if (courier.contains('j&t') || courier.contains('jnt')) {
      return Colors.red.shade700;
    } else {
      return Colors.blue;
    }
  }

  // Format tracking number for display
  static String formatTrackingNumber(String trackingNumber) {
    // Add spaces every 4 characters for better readability
    if (trackingNumber.length > 8) {
      return trackingNumber.replaceAllMapped(
        RegExp(r'.{4}'),
        (match) => '${match.group(0)} ',
      ).trim();
    }
    return trackingNumber;
  }

  // Validate tracking number format
  static bool isValidTrackingNumber(String trackingNumber, String courierName) {
    final courier = courierName.toLowerCase();
    final tracking = trackingNumber.trim().toUpperCase();
    
    if (tracking.isEmpty) return false;
    
    // Basic validation - adjust patterns based on actual courier requirements
    if (courier.contains('jne')) {
      return tracking.length >= 10 && tracking.length <= 15;
    } else if (courier.contains('tiki')) {
      return tracking.length >= 10 && tracking.length <= 20;
    } else if (courier.contains('pos')) {
      return tracking.length >= 8 && tracking.length <= 15;
    } else if (courier.contains('j&t') || courier.contains('jnt')) {
      return tracking.length >= 10 && tracking.length <= 20;
    }
    
    // Default validation - at least 8 characters
    return tracking.length >= 8;
  }

  // Get shipping status color
  static Color getShippingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'preparing':
      case 'sedang disiapkan':
        return Colors.orange;
      case 'pickup':
      case 'dijemput':
      case 'sedang dikirim':
        return Colors.blue;
      case 'transit':
      case 'dalam perjalanan':
        return Colors.purple;
      case 'delivered':
      case 'sampai tujuan':
        return Colors.green;
      case 'received':
      case 'diterima':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  // Show tracking info dialog
  static void showTrackingInfoDialog(
    BuildContext context, 
    String trackingNumber, 
    String courierName,
  ) {
    final trackingUrl = getCourierTrackingUrl(courierName, trackingNumber);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(getCourierIcon(courierName), color: getCourierColor(courierName)),
            const SizedBox(width: 8),
            const Text('Info Tracking'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kurir: $courierName',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('Nomor Resi:'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatTrackingNumber(trackingNumber),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => copyToClipboard(context, trackingNumber),
                    icon: const Icon(Icons.copy),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          if (trackingUrl != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                launchCourierUrl(context, trackingUrl);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Track Online'),
              style: ElevatedButton.styleFrom(
                backgroundColor: getCourierColor(courierName),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}