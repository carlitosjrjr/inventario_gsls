import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _reminderDaysBeforeKey = 'reminder_days_before';
  static const String _autoCleanupDaysKey = 'auto_cleanup_days';
  static const String _dailyReminderTimeKey = 'daily_reminder_time';

  static SharedPreferences? _prefs;

  /// Inicializar SharedPreferences
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Verificar si las notificaciones están habilitadas
  static bool get notificationsEnabled {
    return _prefs?.getBool(_notificationsEnabledKey) ?? true;
  }

  /// Habilitar/deshabilitar notificaciones
  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(_notificationsEnabledKey, enabled);
  }

  /// Obtener días antes del vencimiento para recordatorio
  static int get reminderDaysBefore {
    return _prefs?.getInt(_reminderDaysBeforeKey) ?? 5;
  }

  /// Establecer días antes del vencimiento para recordatorio
  static Future<void> setReminderDaysBefore(int days) async {
    await _prefs?.setInt(_reminderDaysBeforeKey, days);
  }

  /// Obtener días para limpieza automática
  static int get autoCleanupDays {
    return _prefs?.getInt(_autoCleanupDaysKey) ?? 90;
  }

  /// Establecer días para limpieza automática
  static Future<void> setAutoCleanupDays(int days) async {
    await _prefs?.setInt(_autoCleanupDaysKey, days);
  }

  /// Obtener hora de recordatorio diario (en minutos desde medianoche)
  static int get dailyReminderTime {
    return _prefs?.getInt(_dailyReminderTimeKey) ?? 540; // 9:00 AM por defecto
  }

  /// Establecer hora de recordatorio diario
  static Future<void> setDailyReminderTime(int minutesFromMidnight) async {
    await _prefs?.setInt(_dailyReminderTimeKey, minutesFromMidnight);
  }

  /// Convertir minutos desde medianoche a TimeOfDay
  static TimeOfDay minutesToTimeOfDay(int minutes) {
    int hours = minutes ~/ 60;
    int mins = minutes % 60;
    return TimeOfDay(hour: hours, minute: mins);
  }

  /// Convertir TimeOfDay a minutos desde medianoche
  static int timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  /// Obtener configuración como Map para debug
  static Map<String, dynamic> getAllSettings() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'reminderDaysBefore': reminderDaysBefore,
      'autoCleanupDays': autoCleanupDays,
      'dailyReminderTime': dailyReminderTime,
    };
  }

  /// Resetear todas las configuraciones a valores por defecto
  static Future<void> resetToDefaults() async {
    await _prefs?.clear();
  }

  static const String _notificationImageReminderKey = 'notification_image_reminder_days';

  /// Obtener días para recordatorio de imagen (por defecto 25 días)
  static int get imageReminderDays {
    return _prefs?.getInt(_notificationImageReminderKey) ?? 25;
  }

  /// Establecer días para recordatorio de imagen
  static Future<void> setImageReminderDays(int days) async {
    await _prefs?.setInt(_notificationImageReminderKey, days);
  }
}