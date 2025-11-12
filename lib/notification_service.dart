// lib/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the notifications plugin.
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: iosInitializationSettings,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationResponse,
    );

    print("NotificationService initialized");
  }

  /// Callback triggered when a notification is tapped.
  static void onNotificationResponse(NotificationResponse response) {
    // Handle notification tap logic here (e.g., navigate to a specific screen)
    print("Notification tapped: ${response.payload}");
  }

  /// Schedules a notification at a specified date/time.
  /// [matchDateTimeComponents] can be used for repeating notifications (e.g., daily).
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledNotificationDateTime,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    print(
      "Scheduling notification (id: $id) for: $scheduledNotificationDateTime",
    );
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledNotificationDateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'your_channel_id', // Replace with your channel ID.
          'Your Channel Name', // Replace with your channel name.
          channelDescription:
              'Your channel description', // Replace with your channel description.
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: null,
    );
    print("Notification scheduled successfully");
  }
}
