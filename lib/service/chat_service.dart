import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat.dart';
import '../models/product.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Create or get existing chat
  Future<String?> createOrGetChat({
    Product? product,
    String? existingChatId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return null;

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userName = userData?['name'] ?? 'User';

      // Get admin (first admin found)
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        throw Exception('Admin tidak ditemukan');
      }

      final adminDoc = adminQuery.docs.first;

      // If existing chat ID provided, return it
      if (existingChatId != null) {
        final chatExists = await _firestore
            .collection('chats')
            .doc(existingChatId)
            .get();
        if (chatExists.exists) {
          return existingChatId;
        }
      }

      // Check if chat already exists for this user and product
      Query query = _firestore
          .collection('chats')
          .where('userId', isEqualTo: user.uid)
          .where('adminId', isEqualTo: adminDoc.id);

      if (product != null) {
        query = query.where('productId', isEqualTo: product.id);
      }

      final existingChats = await query.limit(1).get();

      if (existingChats.docs.isNotEmpty) {
        return existingChats.docs.first.id;
      }

      // Create new chat
      final chatData = {
        'userId': user.uid,
        'userName': userName,
        'userEmail': user.email ?? '',
        'adminId': adminDoc.id,
        'productId': product?.id,
        'productName': product?.name,
        'productImageUrl': product?.imageUrls.isNotEmpty == true ? product!.imageUrls.first : null,
        'lastMessage': product != null 
            ? 'Tertarik dengan produk: ${product.name}'
            : 'Memulai percakapan',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'isUserRead': true,
        'isAdminRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      };

      final chatRef = await _firestore.collection('chats').add(chatData);

      // Send initial message if from product
      if (product != null) {
        await sendMessage(
          chatRef.id,
          'Halo, saya tertarik dengan produk: ${product.name}',
        );
      }

      return chatRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  // Send message
  Future<bool> sendMessage(String chatId, String message) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Get user role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userRole = userData?['role'] ?? 'user';
      final userName = userData?['name'] ?? (userRole == 'admin' ? 'Admin' : 'User');

      final messageData = {
        'senderId': user.uid,
        'senderRole': userRole,
        'senderName': userName,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'isRead': false,
      };

      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat last message
      final updateData = {
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      if (userRole == 'user') {
        updateData['isUserRead'] = true;
        updateData['isAdminRead'] = false;
      } else {
        updateData['isAdminRead'] = true;
        updateData['isUserRead'] = false;
      }

      await _firestore.collection('chats').doc(chatId).update(updateData);

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Get messages stream
  Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  // Get user chats stream
  Stream<List<Chat>> getUserChatsStream() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('userId', isEqualTo: user.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Chat.fromFirestore(doc))
            .toList());
  }

  // Get admin chats stream
  Stream<List<Chat>> getAdminChatsStream() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('adminId', isEqualTo: user.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Chat.fromFirestore(doc))
            .toList());
  }

  // Mark messages as read
  Future<void> markAsRead(String chatId, String userRole) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (userRole == 'user') {
        updateData['isUserRead'] = true;
      } else if (userRole == 'admin') {
        updateData['isAdminRead'] = true;
      }

      await _firestore.collection('chats').doc(chatId).update(updateData);

      // Mark individual messages as read
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderRole', isNotEqualTo: userRole)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // Get unread count for user
  Stream<int> getUnreadCountStream() {
    final user = currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('userId', isEqualTo: user.uid)
        .where('isUserRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get unread count for admin
  Stream<int> getAdminUnreadCountStream() {
    final user = currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('adminId', isEqualTo: user.uid)
        .where('isAdminRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Delete chat
  Future<bool> deleteChat(String chatId) async {
    try {
      // Delete all messages first
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete chat
      await _firestore.collection('chats').doc(chatId).delete();
      return true;
    } catch (e) {
      print('Error deleting chat: $e');
      return false;
    }
  }
}