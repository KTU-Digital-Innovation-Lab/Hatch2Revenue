import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezone
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    await requestPermissions();
  }

  /// Android 13+ gates notifications behind a runtime permission —
  /// without this request nothing the app schedules is ever shown.
  Future<void> requestPermissions() async {
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('NotificationService: permission request failed: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'poultry_channel',
      'Poultry Notifications',
      channelDescription: 'Notifications for vaccination reminders and alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'poultry_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled vaccination reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      // Inexact: fires within a few minutes of the target, which is
      // plenty for a day-before reminder — and unlike exact alarms it
      // needs no special permission on Android 14+ (where exact is
      // denied by default and silently killed every reminder).
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // A failed reminder must never break the save flow it rides on.
      debugPrint('NotificationService: schedule failed: $e');
    }
  }

  /// Two reminders per vaccination, because one is easy to miss:
  ///   1. the evening/day before, at the hour chosen in Settings, and
  ///   2. the morning it is due, at 06:30, before work starts.
  /// Reminders already in the past are simply skipped.
  Future<void> scheduleVaccinationReminders({
    required String vaccinationId,
    required String vaccineName,
    required String batchLabel,
    required DateTime dueDate,
    required int dayBeforeHour,
  }) async {
    final ids = reminderIds(vaccinationId);
    await cancelNotification(ids.$1);
    await cancelNotification(ids.$2);

    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    // 1. Day before, at the farmer's chosen hour.
    final dayBefore = due
        .subtract(const Duration(days: 1))
        .add(Duration(hours: dayBeforeHour));
    if (dayBefore.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: ids.$1,
        title: 'Vaccination tomorrow',
        body: '$vaccineName for $batchLabel is due tomorrow.',
        scheduledDate: dayBefore,
      );
    }

    // 2. Morning of, at 06:30.
    final morningOf = due.add(const Duration(hours: 6, minutes: 30));
    if (morningOf.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: ids.$2,
        title: 'Vaccination due today',
        body: '$vaccineName for $batchLabel is due today.',
        scheduledDate: morningOf,
      );
    }
  }

  /// Stable pair of notification ids for a vaccination. Kept inside a
  /// safe 32-bit range so both fit an Android notification id.
  (int, int) reminderIds(String vaccinationId) {
    final base = vaccinationId.hashCode.abs() % 100000000;
    return (base * 2, base * 2 + 1);
  }

  Future<void> cancelVaccinationReminders(String vaccinationId) async {
    final ids = reminderIds(vaccinationId);
    await cancelNotification(ids.$1);
    await cancelNotification(ids.$2);
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
