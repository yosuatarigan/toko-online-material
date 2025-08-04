import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String adminId;
  final String? productId;
  final String? productName;
  final String? productImageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isUserRead;
  final bool isAdminRead;
  final DateTime createdAt;
  final int unreadCount;

  Chat({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.adminId,
    this.productId,
    this.productName,
    this.productImageUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isUserRead,
    required this.isAdminRead,
    required this.createdAt,
    this.unreadCount = 0,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      adminId: data['adminId'] ?? '',
      productId: data['productId'],
      productName: data['productName'],
      productImageUrl: data['productImageUrl'],
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      isUserRead: data['isUserRead'] ?? false,
      isAdminRead: data['isAdminRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      unreadCount: data['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'adminId': adminId,
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'isUserRead': isUserRead,
      'isAdminRead': isAdminRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'unreadCount': unreadCount,
    };
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderRole; // 'user' or 'admin'
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String type; // 'text', 'image'
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.type = 'text',
    this.isRead = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderRole: data['senderRole'] ?? '',
      senderName: data['senderName'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'text',
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderRole': senderRole,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'isRead': isRead,
    };
  }

  bool get isFromUser => senderRole == 'user';
  bool get isFromAdmin => senderRole == 'admin';
}