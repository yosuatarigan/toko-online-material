// // lib/service/store_delivery_notifications.dart
// import 'package:flutter/material.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class StoreDeliveryNotificationService {
//   static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
//   static final FlutterLocalNotificationsPlugin _localNotifications = 
//       FlutterLocalNotificationsPlugin();
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   /// Initialize notification service
//   static Future<void> initialize() async {
//     await _initializeLocalNotifications();
//     await _initializeFCM();
//   }

//   static Future<void> _initializeLocalNotifications() async {
//     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosSettings = DarwinInitializationSettings(
//       requestSoundPermission: true,
//       requestBadgePermission: true,
//       requestAlertPermission: true,
//     );

//     const settings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     await _localNotifications.initialize(
//       settings,
//       onDidReceiveNotificationResponse: _onNotificationTapped,
//     );
//   }

//   static Future<void> _initializeFCM() async {
//     await _firebaseMessaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );

//     // Get FCM token
//     final token = await _firebaseMessaging.getToken();
//     if (token != null) {
//       await _saveFCMToken(token);
//     }

//     // Listen for token refresh
//     _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

//     // Handle foreground messages
//     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

//     // Handle background messages
//     FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
//   }

//   static Future<void> _saveFCMToken(String token) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       await _firestore.collection('user_tokens').doc(user.uid).set({
//         'fcmToken': token,
//         'platform': Theme.of(NavigationService.navigatorKey.currentContext!).platform,
//         'updatedAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));
//     }
//   }

//   static Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     final notification = message.notification;
//     if (notification != null) {
//       await _showLocalNotification(
//         title: notification.title ?? 'Toko Barokah',
//         body: notification.body ?? '',
//         data: message.data,
//       );
//     }
//   }

//   static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
//     // Handle background message
//     print('Background message: ${message.messageId}');
//   }

//   static void _onNotificationTapped(NotificationResponse response) {
//     final payload = response.payload;
//     if (payload != null) {
//       // Navigate based on notification data
//       _handleNotificationNavigation(payload);
//     }
//   }

//   static void _handleNotificationNavigation(String payload) {
//     // Parse payload and navigate accordingly
//     final context = NavigationService.navigatorKey.currentContext;
//     if (context != null) {
//       // Navigate to appropriate page based on payload
//     }
//   }

//   /// Show local notification
//   static Future<void> _showLocalNotification({
//     required String title,
//     required String body,
//     Map<String, dynamic>? data,
//   }) async {
//     final androidDetails = AndroidNotificationDetails(
//       'store_delivery_channel',
//       'Store Delivery',
//       channelDescription: 'Notifications for store delivery updates',
//       importance: Importance.high,
//       priority: Priority.high,
//       icon: '@mipmap/ic_launcher',
//       color: const Color(0xFF2E7D32),
//       playSound: true,
//       enableVibration: true,
//     );

//     const iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );

//     final details = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );

//     await _localNotifications.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       title,
//       body,
//       details,
//       payload: data != null ? data.toString() : null,
//     );
//   }

//   /// Send notification to customer about order status
//   static Future<void> sendOrderStatusNotification({
//     required String userId,
//     required String orderId,
//     required String status,
//     required String customerName,
//     String? additionalMessage,
//   }) async {
//     final notification = _getOrderStatusNotification(
//       status,
//       orderId,
//       customerName,
//       additionalMessage,
//     );

//     // Send FCM notification
//     await _sendFCMNotification(
//       userId: userId,
//       title: notification.title,
//       body: notification.body,
//       data: {
//         'type': 'order_status',
//         'orderId': orderId,
//         'status': status,
//       },
//     );

//     // Save notification to database
//     await _saveNotificationToDatabase(
//       userId: userId,
//       title: notification.title,
//       body: notification.body,
//       type: 'order_status',
//       data: {
//         'orderId': orderId,
//         'status': status,
//       },
//     );
//   }

//   /// Send notification to admin about new order
//   static Future<void> sendNewOrderNotificationToAdmin({
//     required String orderId,
//     required String customerName,
//     required double totalAmount,
//     required String address,
//   }) async {
//     final title = 'Pesanan Baru - Pengiriman Toko';
//     final body = 'Pesanan baru dari $customerName senilai Rp ${_formatCurrency(totalAmount)}';

//     // Get admin user IDs
//     final adminUsers = await _getAdminUsers();

//     for (final adminId in adminUsers) {
//       await _sendFCMNotification(
//         userId: adminId,
//         title: title,
//         body: body,
//         data: {
//           'type': 'new_order',
//           'orderId': orderId,
//           'customerName': customerName,
//         },
//       );

//       await _saveNotificationToDatabase(
//         userId: adminId,
//         title: title,
//         body: body,
//         type: 'new_order',
//         data: {
//           'orderId': orderId,
//           'customerName': customerName,
//           'totalAmount': totalAmount,
//         },
//       );
//     }
//   }

//   /// Send delivery reminder notification
//   static Future<void> sendDeliveryReminderNotification({
//     required String userId,
//     required String orderId,
//     required String customerName,
//     required DateTime estimatedTime,
//   }) async {
//     final title = 'Pengingat Pengiriman';
//     final body = 'Pesanan Anda ($orderId) akan tiba dalam 30 menit';

//     await _sendFCMNotification(
//       userId: userId,
//       title: title,
//       body: body,
//       data: {
//         'type': 'delivery_reminder',
//         'orderId': orderId,
//       },
//     );

//     await _saveNotificationToDatabase(
//       userId: userId,
//       title: title,
//       body: body,
//       type: 'delivery_reminder',
//       data: {
//         'orderId': orderId,
//         'estimatedTime': estimatedTime.toIso8601String(),
//       },
//     );
//   }

//   /// Send feedback request notification after delivery
//   static Future<void> sendFeedbackRequestNotification({
//     required String userId,
//     required String orderId,
//   }) async {
//     const title = 'Bagaimana Pengalaman Anda?';
//     const body = 'Berikan rating dan ulasan untuk pengiriman toko kami';

//     await _sendFCMNotification(
//       userId: userId,
//       title: title,
//       body: body,
//       data: {
//         'type': 'feedback_request',
//         'orderId': orderId,
//       },
//     );

//     await _saveNotificationToDatabase(
//       userId: userId,
//       title: title,
//       body: body,
//       type: 'feedback_request',
//       data: {
//         'orderId': orderId,
//       },
//     );
//   }

//   /// Send promo notification for store delivery
//   static Future<void> sendStoreDeliveryPromoNotification({
//     required List<String> userIds,
//     required String promoTitle,
//     required String promoDescription,
//     String? promoCode,
//   }) async {
//     for (final userId in userIds) {
//       await _sendFCMNotification(
//         userId: userId,
//         title: promoTitle,
//         body: promoDescription,
//         data: {
//           'type': 'promo',
//           'promoCode': promoCode,
//         },
//       );

//       await _saveNotificationToDatabase(
//         userId: userId,
//         title: promoTitle,
//         body: promoDescription,
//         type: 'promo',
//         data: {
//           'promoCode': promoCode,
//         },
//       );
//     }
//   }

//   /// Get notification history for user
//   static Future<List<NotificationItem>> getNotificationHistory(String userId) async {
//     try {
//       final snapshot = await _firestore
//           .collection('notifications')
//           .where('userId', isEqualTo: userId)
//           .orderBy('createdAt', descending: true)
//           .limit(50)
//           .get();

//       return snapshot.docs
//           .map((doc) => NotificationItem.fromFirestore(doc.data()))
//           .toList();
//     } catch (e) {
//       print('Error getting notification history: $e');
//       return [];
//     }
//   }

//   /// Mark notification as read
//   static Future<void> markNotificationAsRead(String notificationId) async {
//     try {
//       await _firestore
//           .collection('notifications')
//           .doc(notificationId)
//           .update({
//         'isRead': true,
//         'readAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error marking notification as read: $e');
//     }
//   }

//   /// Get unread notification count
//   static Future<int> getUnreadNotificationCount(String userId) async {
//     try {
//       final snapshot = await _firestore
//           .collection('notifications')
//           .where('userId', isEqualTo: userId)
//           .where('isRead', isEqualTo: false)
//           .count()
//           .get();

//       return snapshot.count;
//     } catch (e) {
//       print('Error getting unread count: $e');
//       return 0;
//     }
//   }

//   // Private helper methods

//   static Future<void> _sendFCMNotification({
//     required String userId,
//     required String title,
//     required String body,
//     Map<String, dynamic>? data,
//   }) async {
//     try {
//       // Get user's FCM token
//       final tokenDoc = await _firestore
//           .collection('user_tokens')
//           .doc(userId)
//           .get();

//       if (!tokenDoc.exists) return;

//       final token = tokenDoc.data()?['fcmToken'] as String?;
//       if (token == null) return;

//       // In a real implementation, you would send this to your backend
//       // which would then send the FCM message to the token
//       print('Would send FCM notification to token: $token');
//       print('Title: $title');
//       print('Body: $body');
//       print('Data: $data');

//     } catch (e) {
//       print('Error sending FCM notification: $e');
//     }
//   }

//   static Future<void> _saveNotificationToDatabase({
//     required String userId,
//     required String title,
//     required String body,
//     required String type,
//     Map<String, dynamic>? data,
//   }) async {
//     try {
//       await _firestore.collection('notifications').add({
//         'userId': userId,
//         'title': title,
//         'body': body,
//         'type': type,
//         'data': data ?? {},
//         'isRead': false,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error saving notification to database: $e');
//     }
//   }

//   static Future<List<String>> _getAdminUsers() async {
//     try {
//       final snapshot = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: 'admin')
//           .get();

//       return snapshot.docs.map((doc) => doc.id).toList();
//     } catch (e) {
//       print('Error getting admin users: $e');
//       return [];
//     }
//   }

//   static OrderStatusNotification _getOrderStatusNotification(
//     String status,
//     String orderId,
//     String customerName,
//     String? additionalMessage,
//   ) {
//     switch (status) {
//       case 'confirmed':
//         return OrderStatusNotification(
//           title: 'Pesanan Dikonfirmasi',
//           body: 'Pesanan $orderId telah dikonfirmasi dan sedang disiapkan',
//         );
//       case 'preparing':
//         return OrderStatusNotification(
//           title: 'Pesanan Sedang Disiapkan',
//           body: 'Tim kami sedang menyiapkan pesanan $orderId',
//         );
//       case 'on_delivery':
//         return OrderStatusNotification(
//           title: 'Pesanan Dalam Perjalanan',
//           body: 'Pesanan $orderId sedang dalam perjalanan ke alamat Anda',
//         );
//       case 'delivered':
//         return OrderStatusNotification(
//           title: 'Pesanan Telah Tiba',
//           body: 'Pesanan $orderId telah berhasil diterima. Terima kasih!',
//         );
//       case 'cancelled':
//         return OrderStatusNotification(
//           title: 'Pesanan Dibatalkan',
//           body: 'Pesanan $orderId telah dibatalkan${additionalMessage != null ? ': $additionalMessage' : ''}',
//         );
//       default:
//         return OrderStatusNotification(
//           title: 'Update Pesanan',
//           body: 'Status pesanan $orderId telah diperbarui',
//         );
//     }
//   }

//   static String _formatCurrency(double amount) {
//     return amount.toStringAsFixed(0).replaceAllMapped(
//       RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
//       (Match m) => '${m[1]}.',
//     );
//   }
// }

// /// Schedule automatic notifications
// class StoreDeliveryNotificationScheduler {
//   /// Schedule delivery reminder 30 minutes before estimated time
//   static Future<void> scheduleDeliveryReminder({
//     required String userId,
//     required String orderId,
//     required String customerName,
//     required DateTime estimatedDeliveryTime,
//   }) async {
//     final reminderTime = estimatedDeliveryTime.subtract(const Duration(minutes: 30));
    
//     if (reminderTime.isAfter(DateTime.now())) {
//       // In a real implementation, you would use a job scheduler
//       // For now, we'll just set a timer
//       final delay = reminderTime.difference(DateTime.now());
      
//       Future.delayed(delay, () {
//         StoreDeliveryNotificationService.sendDeliveryReminderNotification(
//           userId: userId,
//           orderId: orderId,
//           customerName: customerName,
//           estimatedTime: estimatedDeliveryTime,
//         );
//       });
//     }
//   }

//   /// Schedule feedback request 1 hour after delivery
//   static Future<void> scheduleFeedbackRequest({
//     required String userId,
//     required String orderId,
//   }) async {
//     const delay = Duration(hours: 1);
    
//     Future.delayed(delay, () {
//       StoreDeliveryNotificationService.sendFeedbackRequestNotification(
//         userId: userId,
//         orderId: orderId,
//       );
//     });
//   }

//   /// Schedule daily summary for admin
//   static Future<void> scheduleDailySummary() async {
//     // Schedule daily at 8 PM
//     final now = DateTime.now();
//     final scheduledTime = DateTime(now.year, now.month, now.day, 20, 0);
//     final nextSchedule = scheduledTime.isBefore(now) 
//         ? scheduledTime.add(const Duration(days: 1))
//         : scheduledTime;
    
//     final delay = nextSchedule.difference(now);
    
//     Future.delayed(delay, () async {
//       await _sendDailySummaryToAdmin();
//       // Reschedule for next day
//       scheduleDailySummary();
//     });
//   }

//   static Future<void> _sendDailySummaryToAdmin() async {
//     // Get today's stats and send to admin
//     final stats = await StoreDeliveryService.getDeliveryStats(
//       startDate: DateTime.now().subtract(const Duration(days: 1)),
//       endDate: DateTime.now(),
//     );

//     final title = 'Ringkasan Harian - Pengiriman Toko';
//     final body = 'Hari ini: ${stats.deliveredOrders} pesanan terkirim, pendapatan Rp ${_formatCurrency(stats.totalRevenue)}';

//     final adminUsers = await _getAdminUsers();
//     for (final adminId in adminUsers) {
//       await StoreDeliveryNotificationService._sendFCMNotification(
//         userId: adminId,
//         title: title,
//         body: body,
//         data: {
//           'type': 'daily_summary',
//           'delivered_orders': stats.deliveredOrders.toString(),
//           'total_revenue': stats.totalRevenue.toString(),
//         },
//       );
//     }
//   }

//   static Future<List<String>> _getAdminUsers() async {
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .where('role', isEqualTo: 'admin')
//           .get();

//       return snapshot.docs.map((doc) => doc.id).toList();
//     } catch (e) {
//       return [];
//     }
//   }

//   static String _formatCurrency(double amount) {
//     return amount.toStringAsFixed(0).replaceAllMapped(
//       RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
//       (Match m) => '${m[1]}.',
//     );
//   }
// }

// // Models

// class NotificationItem {
//   final String id;
//   final String userId;
//   final String title;
//   final String body;
//   final String type;
//   final Map<String, dynamic> data;
//   final bool isRead;
//   final DateTime createdAt;
//   final DateTime? readAt;

//   NotificationItem({
//     required this.id,
//     required this.userId,
//     required this.title,
//     required this.body,
//     required this.type,
//     required this.data,
//     required this.isRead,
//     required this.createdAt,
//     this.readAt,
//   });

//   factory NotificationItem.fromFirestore(Map<String, dynamic> data) {
//     return NotificationItem(
//       id: data['id'] ?? '',
//       userId: data['userId'] ?? '',
//       title: data['title'] ?? '',
//       body: data['body'] ?? '',
//       type: data['type'] ?? '',
//       data: Map<String, dynamic>.from(data['data'] ?? {}),
//       isRead: data['isRead'] ?? false,
//       createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       readAt: (data['readAt'] as Timestamp?)?.toDate(),
//     );
//   }

//   IconData get icon {
//     switch (type) {
//       case 'order_status':
//         return Icons.local_shipping;
//       case 'new_order':
//         return Icons.shopping_cart;
//       case 'delivery_reminder':
//         return Icons.access_time;
//       case 'feedback_request':
//         return Icons.star_rate;
//       case 'promo':
//         return Icons.local_offer;
//       case 'daily_summary':
//         return Icons.assessment;
//       default:
//         return Icons.notifications;
//     }
//   }

//   Color get color {
//     switch (type) {
//       case 'order_status':
//         return const Color(0xFF2E7D32);
//       case 'new_order':
//         return Colors.blue;
//       case 'delivery_reminder':
//         return Colors.orange;
//       case 'feedback_request':
//         return Colors.purple;
//       case 'promo':
//         return Colors.red;
//       case 'daily_summary':
//         return Colors.indigo;
//       default:
//         return Colors.grey;
//     }
//   }
// }

// class OrderStatusNotification {
//   final String title;
//   final String body;

//   OrderStatusNotification({
//     required this.title,
//     required this.body,
//   });
// }

// // Navigation service for handling navigation from notifications
// class NavigationService {
//   static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// }