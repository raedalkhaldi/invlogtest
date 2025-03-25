import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission for notifications
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(initializationSettings);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> saveUserToken(String userId) async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': newToken,
      });
    });
  }

  Future<void> sendLikeNotification({
    required String checkInId,
    required String checkInUserId,
    required String likerUserId,
    required String likerUsername,
    required String restaurantName,
  }) async {
    try {
      // Get the check-in user's FCM token
      final userDoc = await _firestore.collection('users').doc(checkInUserId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken != null) {
        // Send notification via Cloud Functions
        await _firestore.collection('notifications').add({
          'type': 'like',
          'checkInId': checkInId,
          'userId': checkInUserId,
          'likerUserId': likerUserId,
          'likerUsername': likerUsername,
          'restaurantName': restaurantName,
          'fcmToken': fcmToken,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      print('Error sending like notification: $e');
    }
  }

  Future<void> sendCommentNotification({
    required String checkInId,
    required String checkInUserId,
    required String commentUserId,
    required String commentUsername,
    required String restaurantName,
    required String commentText,
  }) async {
    try {
      // Get the check-in user's FCM token
      final userDoc = await _firestore.collection('users').doc(checkInUserId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken != null) {
        // Send notification via Cloud Functions
        await _firestore.collection('notifications').add({
          'type': 'comment',
          'checkInId': checkInId,
          'userId': checkInUserId,
          'commentUserId': commentUserId,
          'commentUsername': commentUsername,
          'restaurantName': restaurantName,
          'commentText': commentText,
          'fcmToken': fcmToken,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      print('Error sending comment notification: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'checkin_notifications',
            'Check-in Notifications',
            channelDescription: 'Notifications for check-in interactions',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Handle notification tap when app is in background
    // Navigate to the appropriate screen based on the notification type
    // This will be implemented in the UI layer
  }

  Future<void> createLikeNotification({
    required String checkInId,
    required String checkInOwnerId,
    required String likerUserId,
    required String likerUsername,
  }) async {
    try {
      final notification = {
        'type': 'like',
        'checkInId': checkInId,
        'checkInOwnerId': checkInOwnerId,
        'likerUserId': likerUserId,
        'likerUsername': likerUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      // ... existing code ...
    } catch (e) {
      print('Error creating like notification: $e');
    }
  }
}

// This needs to be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  print('Handling background message: ${message.messageId}');
} 