import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Importa las pantallas necesarias
import '../pages/add_edit_unidad_scout_screen.dart';
import '../services/firebase_service.dart';
import '../services/email_service.dart'; // Nuevo servicio para emails
import '../models/unidad_scout.dart';
import '../models/prestamo.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // GlobalKey para acceder al navegador desde cualquier parte
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Inicializar el servicio de notificaciones
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_initialized) return;

    // Guardar la referencia del navigator
    navigatorKey = navKey;

    // Inicializar las zonas horarias
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Manejar cuando se toca una notificación
  static void _onNotificationTapped(NotificationResponse response) async {
    print('Notificación tocada: ${response.payload}');

    if (response.payload != null) {
      if (response.payload!.startsWith('unidad_scout:')) {
        String unidadId = response.payload!.replaceFirst('unidad_scout:', '');
        await _navigateToEditUnidad(unidadId);
      } else if (response.payload!.startsWith('prestamo:')) {
        String prestamoId = response.payload!.replaceFirst('prestamo:', '');
        await _navigateToPrestamo(prestamoId);
      }
    }
  }

  /// Navegar a la pantalla de edición de unidad
  static Future<void> _navigateToEditUnidad(String unidadId) async {
    try {
      if (navigatorKey?.currentState == null) {
        print('Navigator no disponible');
        return;
      }

      // Obtener la unidad desde Firebase
      UnidadScout? unidad = await FirebaseService.getUnidadScoutById(unidadId);

      if (unidad != null) {
        // Navegar a la pantalla de edición
        navigatorKey!.currentState!.push(
          MaterialPageRoute(
            builder: (context) => AddEditUnidadScoutScreen(unidad: unidad),
          ),
        );
      } else {
        print('Unidad no encontrada: $unidadId');
        // Mostrar mensaje de error
        _showErrorSnackBar('La unidad ya no existe o fue eliminada');
      }
    } catch (e) {
      print('Error al navegar a la unidad: $e');
      _showErrorSnackBar('Error al abrir la unidad');
    }
  }

  /// Navegar a la pantalla de préstamo
  static Future<void> _navigateToPrestamo(String prestamoId) async {
    try {
      if (navigatorKey?.currentState == null) {
        print('Navigator no disponible');
        return;
      }

      // Obtener el préstamo desde Firebase
      Prestamo? prestamo = await FirebaseService.getPrestamoById(prestamoId);

      if (prestamo != null) {
        // Navegar a la pantalla de préstamos
        // Aquí deberías reemplazar 'PrestamoDetailScreen' con tu pantalla real
        navigatorKey!.currentState!.pushNamed(
          '/prestamo_detail',
          arguments: prestamo,
        );
      } else {
        print('Préstamo no encontrado: $prestamoId');
        _showErrorSnackBar('El préstamo ya no existe o fue eliminado');
      }
    } catch (e) {
      print('Error al navegar al préstamo: $e');
      _showErrorSnackBar('Error al abrir el préstamo');
    }
  }

  /// Mostrar mensaje de error
  static void _showErrorSnackBar(String message) {
    if (navigatorKey?.currentState?.context != null) {
      ScaffoldMessenger.of(navigatorKey!.currentState!.context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Solicitar permisos de notificación
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final bool? granted = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  // ==================== NOTIFICACIONES PARA UNIDADES SCOUT ====================

  /// Mostrar notificación inmediata para recordatorio de imagen
  static Future<void> mostrarNotificacionImagenUnidad({
    required String unidadId,
    required String nombreUnidad,
    required int diasRestantes,
  }) async {
    if (!_initialized) await initialize();

    String titulo;
    String cuerpo;

    if (diasRestantes <= 0) {
      titulo = '⚠️ Plazo vencido - Imagen requerida';
      cuerpo = 'La unidad "$nombreUnidad" necesita una imagen. Toca para agregar.';
    } else if (diasRestantes <= 5) {
      titulo = '⏰ Recordatorio urgente - Imagen requerida';
      cuerpo = 'Quedan $diasRestantes días para agregar imagen a "$nombreUnidad". Toca para agregar.';
    } else {
      titulo = '📸 Recordatorio - Imagen pendiente';
      cuerpo = 'Recuerda agregar una imagen a la unidad "$nombreUnidad". Toca para agregar.';
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'recordatorios_imagen',
      'Recordatorios de Imagen',
      channelDescription: 'Notificaciones para recordar agregar imágenes a unidades scout',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
      autoCancel: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      unidadId.hashCode,
      titulo,
      cuerpo,
      details,
      payload: 'unidad_scout:$unidadId',
    );
  }

  /// Programar notificación para imagen de unidad scout
  static Future<void> programarNotificacionImagenUnidad({
    required String unidadId,
    required String nombreUnidad,
    required DateTime fechaNotificacion,
  }) async {
    if (!_initialized) await initialize();

    // Cancelar notificación anterior si existe
    await _notifications.cancel(unidadId.hashCode);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'recordatorios_imagen',
      'Recordatorios de Imagen',
      channelDescription: 'Notificaciones para recordar agregar imágenes a unidades scout',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
      autoCancel: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Programar notificación para la fecha específica
    await _notifications.zonedSchedule(
      unidadId.hashCode,
      '📸 Recordatorio - Imagen pendiente',
      'Recuerda agregar una imagen a la unidad "$nombreUnidad". Toca para agregar.',
      _convertToTZDateTime(fechaNotificacion),
      details,
      payload: 'unidad_scout:$unidadId',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('Notificación programada para ${fechaNotificacion} - Unidad: $nombreUnidad');
  }

  // ==================== NOTIFICACIONES PARA PRÉSTAMOS ====================

  /// Programar todas las notificaciones para un préstamo
  static Future<void> programarNotificacionesPrestamo(Prestamo prestamo) async {
    if (!_initialized) await initialize();

    if (prestamo.id == null) {
      print('❌ Error: El préstamo no tiene ID asignado');
      return;
    }

    DateTime fechaDevolucion = prestamo.fechaDevolucionEsperada;
    DateTime ahora = DateTime.now();

    // Solo programar notificaciones futuras
    if (fechaDevolucion.isBefore(ahora)) {
      print('⚠️ La fecha de devolución ya pasó - No se programan notificaciones');
      return;
    }

    print('🔔 Programando notificaciones para préstamo: ${prestamo.id}');
    print('   - Solicitante: ${prestamo.nombreSolicitante}');
    print('   - Fecha devolución: $fechaDevolucion');

    try {
      // Obtener datos de la unidad scout
      UnidadScout? unidad = await FirebaseService.getUnidadScoutById(prestamo.unidadScoutId);

      // Verificar si el usuario tiene email configurado
      if (!usuarioTieneEmailConfigurado) {
        print('⚠️ Usuario no tiene email configurado - Solo se programarán notificaciones push');
      }

      // Programar notificación 3 días antes
      DateTime fecha3Dias = fechaDevolucion.subtract(const Duration(days: 3));
      if (fecha3Dias.isAfter(ahora)) {
        await programarNotificacionPrestamo(
          prestamoId: prestamo.id!,
          titulo: 'Recordatorio de Devolución',
          mensaje: 'Faltan 3 días para devolver los items prestados a "${prestamo.nombreSolicitante}"',
          fechaNotificacion: fecha3Dias,
          diasRestantes: 3,
        );
        print('   ✅ Notificación 3 días programada para: $fecha3Dias');
      }

      // Programar notificación 1 día antes (incluye email si está configurado)
      DateTime fecha1Dia = fechaDevolucion.subtract(const Duration(days: 1));
      if (fecha1Dia.isAfter(ahora)) {
        await programarNotificacionPrestamo(
          prestamoId: prestamo.id!,
          titulo: 'Devolución Urgente',
          mensaje: 'Mañana vence el préstamo de "${prestamo.nombreSolicitante}". Recuerda devolver los items.',
          fechaNotificacion: fecha1Dia,
          diasRestantes: 1,
        );
        print('   ✅ Notificación 1 día programada para: $fecha1Dia');

        // Programar email para 1 día antes (solo si hay email)
        if (usuarioTieneEmailConfigurado) {
          await _programarEmailRecordatorio(prestamo, unidad, 1);
          print('   ✅ Email recordatorio programado para: $fecha1Dia');
        }
      }

      // Programar notificación el día del vencimiento (incluye email si está configurado)
      if (fechaDevolucion.isAfter(ahora)) {
        await programarNotificacionPrestamo(
          prestamoId: prestamo.id!,
          titulo: 'Préstamo Vencido',
          mensaje: 'El préstamo de "${prestamo.nombreSolicitante}" ha vencido. Es necesario devolver los items.',
          fechaNotificacion: fechaDevolucion,
          diasRestantes: 0,
        );
        print('   ✅ Notificación vencimiento programada para: $fechaDevolucion');

        // Programar email para el día del vencimiento (solo si hay email)
        if (usuarioTieneEmailConfigurado) {
          await _programarEmailVencimiento(prestamo, unidad);
          print('   ✅ Email vencimiento programado para: $fechaDevolucion');
        }
      }

      print('🎉 Todas las notificaciones programadas exitosamente para préstamo: ${prestamo.id}');
    } catch (e) {
      print('❌ Error al programar notificaciones del préstamo: $e');
      throw Exception('Error al programar notificaciones: $e');
    }
  }

  static Future<void> debugEmailsProgramados() async {
    try {
      print('🔍 DEBUG: Verificando emails programados...');

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('emails_programados')
          .orderBy('fechaCreacion', descending: true)
          .limit(10)
          .get();

      print('   - Total emails en BD: ${snapshot.size}');

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('   - Email: ${data['asunto']}');
        print('     * Destinatario: ${data['destinatario']}');
        print('     * Fecha envío: ${data['fechaEnvio']}');
        print('     * Enviado: ${data['enviado'] ?? false}');
        print('     * Cancelado: ${data['cancelado'] ?? false}');
        print('     * Error: ${data['error'] ?? false}');
        print('     ---');
      }
    } catch (e) {
      print('❌ Error en debug de emails: $e');
    }
  }

  /// Programar una notificación específica de préstamo
  static Future<void> programarNotificacionPrestamo({
    required String prestamoId,
    required String titulo,
    required String mensaje,
    required DateTime fechaNotificacion,
    required int diasRestantes,
  }) async {
    // Generar ID único basado en préstamo y días restantes
    int notificationId = (prestamoId + diasRestantes.toString()).hashCode;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'recordatorios_prestamos',
      'Recordatorios de Préstamos',
      channelDescription: 'Notificaciones para recordatorios de devolución de préstamos',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
      autoCancel: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      titulo,
      mensaje,
      _convertToTZDateTime(fechaNotificacion),
      details,
      payload: 'prestamo:$prestamoId',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Programar email de recordatorio (1 día antes)
  static Future<void> _programarEmailRecordatorio(Prestamo prestamo, UnidadScout? unidad, int diasAntes) async {
    try {
      DateTime fechaEnvio = prestamo.fechaDevolucionEsperada.subtract(Duration(days: diasAntes));

      if (fechaEnvio.isBefore(DateTime.now())) return;

      // SOLUCIÓN: Obtener el email real del usuario actual
      String? emailUsuario = EmailService.emailUsuarioActual;

      if (emailUsuario == null) {
        print('⚠️ No se pudo obtener el email del usuario - Email no programado');
        return;
      }

      // Crear el contenido del email
      String asunto = 'Recordatorio: Devolución de préstamo - ${prestamo.nombreSolicitante}';
      String contenido = _generarContenidoEmailRecordatorio(prestamo, unidad, diasAntes);

      // Programar el envío del email con el email real del usuario
      await EmailService.programarEmail(
        destinatario: emailUsuario, // USAR EMAIL REAL
        asunto: asunto,
        contenido: contenido,
        fechaEnvio: fechaEnvio,
        prestamoId: prestamo.id, // AGREGAR PRESTAMO ID PARA MEJOR TRACKING
      );

      print('✅ Email de recordatorio programado para: $fechaEnvio - Usuario: $emailUsuario');
    } catch (e) {
      print('❌ Error al programar email de recordatorio: $e');
    }
  }

  /// Programar email de vencimiento
  static Future<void> _programarEmailVencimiento(Prestamo prestamo, UnidadScout? unidad) async {
    try {
      DateTime fechaEnvio = prestamo.fechaDevolucionEsperada;

      if (fechaEnvio.isBefore(DateTime.now())) return;

      // SOLUCIÓN: Obtener el email real del usuario actual
      String? emailUsuario = EmailService.emailUsuarioActual;

      if (emailUsuario == null) {
        print('⚠️ No se pudo obtener el email del usuario - Email no programado');
        return;
      }

      // Crear el contenido del email
      String asunto = 'PRÉSTAMO VENCIDO - ${prestamo.nombreSolicitante}';
      String contenido = _generarContenidoEmailVencimiento(prestamo, unidad);

      // Programar el envío del email con el email real del usuario
      await EmailService.programarEmail(
        destinatario: emailUsuario, // USAR EMAIL REAL
        asunto: asunto,
        contenido: contenido,
        fechaEnvio: fechaEnvio,
        prestamoId: prestamo.id, // AGREGAR PRESTAMO ID PARA MEJOR TRACKING
      );

      print('✅ Email de vencimiento programado para: $fechaEnvio - Usuario: $emailUsuario');
    } catch (e) {
      print('❌ Error al programar email de vencimiento: $e');
    }
  }
  /// Método para verificar si el usuario tiene email configurado
  static bool get usuarioTieneEmailConfigurado {
    String? email = EmailService.emailUsuarioActual;
    return email != null && email.isNotEmpty && email != 'usuario@example.com';
  }

  /// Generar contenido del email de recordatorio
  static String _generarContenidoEmailRecordatorio(Prestamo prestamo, UnidadScout? unidad, int diasAntes) {
    String fechaPrestamo = _formatDate(prestamo.fechaPrestamo);
    String fechaDevolucion = _formatDate(prestamo.fechaDevolucionEsperada);

    String itemsList = prestamo.items.map((item) =>
    '• ${item.nombreItem} (Cantidad: ${item.cantidadPrestada})'
    ).join('\n');

    return '''
Estimado usuario,

Este es un recordatorio de que faltan $diasAntes día(s) para la devolución de los siguientes items prestados:

INFORMACIÓN DEL PRÉSTAMO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━

Unidad Scout: ${prestamo.nombreSolicitante}
Responsable: ${unidad?.responsableUnidad ?? 'No disponible'}
Teléfono: ${prestamo.telefono}
Rama Scout: ${prestamo.ramaScout}

FECHAS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fecha de préstamo: $fechaPrestamo
Fecha límite de devolución: $fechaDevolucion

ITEMS PRESTADOS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━

$itemsList

${prestamo.observaciones != null && prestamo.observaciones!.isNotEmpty ? 'OBSERVACIONES:\n${prestamo.observaciones}\n\n' : ''}Por favor, coordine la devolución de los items antes de la fecha límite.

Saludos,
Sistema de Gestión de Inventario Scout
    ''';
  }

  /// Generar contenido del email de vencimiento
  static String _generarContenidoEmailVencimiento(Prestamo prestamo, UnidadScout? unidad) {
    String fechaPrestamo = _formatDate(prestamo.fechaPrestamo);
    String fechaDevolucion = _formatDate(prestamo.fechaDevolucionEsperada);

    String itemsList = prestamo.items.map((item) =>
    '• ${item.nombreItem} (Cantidad: ${item.cantidadPrestada})'
    ).join('\n');

    return '''
⚠️ PRÉSTAMO VENCIDO ⚠️

Estimado usuario,

El siguiente préstamo ha VENCIDO y requiere atención inmediata:

INFORMACIÓN DEL PRÉSTAMO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━

Unidad Scout: ${prestamo.nombreSolicitante}
Responsable: ${unidad?.responsableUnidad ?? 'No disponible'}
Teléfono: ${prestamo.telefono}
Rama Scout: ${prestamo.ramaScout}

FECHAS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fecha de préstamo: $fechaPrestamo
Fecha límite de devolución: $fechaDevolucion (VENCIDO)

ITEMS PENDIENTES DE DEVOLUCIÓN:
━━━━━━━━━━━━━━━━━━━━━━━━━━━

$itemsList

${prestamo.observaciones != null && prestamo.observaciones!.isNotEmpty ? 'OBSERVACIONES:\n${prestamo.observaciones}\n\n' : ''}🚨 ACCIÓN REQUERIDA: Por favor, contacte inmediatamente con la unidad scout para coordinar la devolución de los items.

Saludos,
Sistema de Gestión de Inventario Scout
    ''';
  }

  /// Cancelar todas las notificaciones de un préstamo específico
  static Future<void> cancelarNotificacionesPrestamo(String prestamoId) async {
    try {
      // Cancelar notificación de 3 días
      int id3Dias = (prestamoId + "3").hashCode;
      await _notifications.cancel(id3Dias);

      // Cancelar notificación de 1 día
      int id1Dia = (prestamoId + "1").hashCode;
      await _notifications.cancel(id1Dia);

      // Cancelar notificación de vencimiento
      int idVencimiento = (prestamoId + "0").hashCode;
      await _notifications.cancel(idVencimiento);

      // Cancelar emails programados
      await EmailService.cancelarEmails(prestamoId);

      print('Notificaciones canceladas para préstamo: $prestamoId');
    } catch (e) {
      print('Error al cancelar notificaciones del préstamo: $e');
    }
  }

  // ==================== MÉTODOS GENERALES ====================

  /// Reprogramar notificación para una fecha posterior (posponer)
  static Future<void> posponerNotificacionImagenUnidad({
    required String unidadId,
    required String nombreUnidad,
    required int diasPosponer,
  }) async {
    if (!_initialized) await initialize();

    DateTime nuevaFecha = DateTime.now().add(Duration(days: diasPosponer));

    await programarNotificacionImagenUnidad(
      unidadId: unidadId,
      nombreUnidad: nombreUnidad,
      fechaNotificacion: nuevaFecha,
    );

    print('Notificación pospuesta $diasPosponer días para unidad: $nombreUnidad');
  }

  /// Cancelar notificaciones de una unidad específica
  static Future<void> cancelarNotificacionesUnidad(String unidadId) async {
    await _notifications.cancel(unidadId.hashCode);
    print('Notificaciones canceladas para unidad ID: $unidadId');
  }

  /// Cancelar todas las notificaciones
  static Future<void> cancelarTodasLasNotificaciones() async {
    await _notifications.cancelAll();
    await EmailService.cancelarTodosLosEmails();
    print('Todas las notificaciones han sido canceladas');
  }

  /// Verificar si las notificaciones están habilitadas
  static Future<bool> notificacionesHabilitadas() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? enabled = await androidImplementation.areNotificationsEnabled();
        return enabled ?? false;
      }
    }
    return true; // En iOS asumimos que están habilitadas si se otorgaron permisos
  }

  /// Obtener notificaciones pendientes
  static Future<List<PendingNotificationRequest>> obtenerNotificacionesPendientes() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Verificar si existe una notificación pendiente para una unidad específica
  static Future<bool> tieneNotificacionPendiente(String unidadId) async {
    final pendientes = await obtenerNotificacionesPendientes();
    return pendientes.any((notif) => notif.id == unidadId.hashCode);
  }

  /// Convertir DateTime a TZDateTime (requerido para notificaciones programadas)
  static tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    // Usar la zona horaria de Bolivia (La Paz)
    final location = tz.getLocation('America/La_Paz');
    return tz.TZDateTime.from(dateTime, location);
  }

  /// Formatear fecha para mostrar
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ==================== MÉTODOS LEGACY (MANTENER COMPATIBILIDAD) ====================

  /// Programar notificación recurrente para recordatorios (método legacy mantenido para compatibilidad)
  static Future<void> programarNotificacionRecurrente({
    required String unidadId,
    required String nombreUnidad,
    required DateTime fechaRecordatorio,
  }) async {
    // Redirigir al nuevo método
    await programarNotificacionImagenUnidad(
      unidadId: unidadId,
      nombreUnidad: nombreUnidad,
      fechaNotificacion: fechaRecordatorio,
    );
  }
}