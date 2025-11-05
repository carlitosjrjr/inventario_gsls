import 'dart:async';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailService {
  // Configuración del servidor SMTP - ACTUALIZAR CON TUS DATOS
  static const String _smtpServer = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _emailRemitente = 'silvino.carlino@gmail.com'; // CAMBIAR POR TU EMAIL
  static const String _passwordRemitente = 'bcyj eofz bjwc jbzn'; // CAMBIAR POR TU APP PASSWORD DE GMAIL

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _emailTimer;

  /// Inicializar el servicio de emails
  static Future<void> initialize() async {
    print('Inicializando EmailService...');

    // Procesar emails pendientes inmediatamente al inicializar
    await _procesarEmailsPendientes();

    // Iniciar el timer para verificar emails pendientes cada minuto
    _emailTimer?.cancel(); // Cancelar timer anterior si existe
    _emailTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _procesarEmailsPendientes();
    });

    print('EmailService inicializado - Timer configurado para cada minuto');
  }

  /// Detener el servicio
  static void dispose() {
    _emailTimer?.cancel();
    _emailTimer = null;
  }

  /// Obtener el email del usuario actual logueado
  static String? get emailUsuarioActual {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? email = user?.email;
      print('📧 Email usuario actual: ${email ?? "No disponible"}');
      return email;
    } catch (e) {
      print('❌ Error al obtener email del usuario: $e');
      return null;
    }
  }

  static Future<bool> initializeConVerificacion() async {
    try {
      print('🔧 Inicializando EmailService con verificación...');

      // Verificar configuración primero
      bool configOk = await verificarConfiguracion();
      if (!configOk) {
        print('⚠️ Configuración de email no válida');
        return false;
      }

      // Verificar que hay usuario logueado
      String? email = emailUsuarioActual;
      if (email == null) {
        print('⚠️ No hay usuario logueado con email');
        return false;
      }

      // Procesar emails pendientes inmediatamente
      await _procesarEmailsPendientes();

      // Iniciar timer
      _emailTimer?.cancel();
      _emailTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        print('⏰ Timer ejecutándose - procesando emails...');
        _procesarEmailsPendientes();
      });

      print('✅ EmailService inicializado completamente');
      return true;

    } catch (e) {
      print('❌ Error al inicializar EmailService: $e');
      return false;
    }
  }

  /// Programar un email para envío futuro
  static Future<void> programarEmail({
    required String destinatario,
    required String asunto,
    required String contenido,
    required DateTime fechaEnvio,
    String? prestamoId,
  }) async {
    try {
      print('📧 Programando email...');
      print('   - Destinatario original: $destinatario');

      // FIXED: Changed variable name to avoid conflict with static getter
      String? emailDelUsuario = emailUsuarioActual;
      String emailDestino;

      if (emailDelUsuario != null && emailDelUsuario.isNotEmpty) {
        emailDestino = emailDelUsuario;
        print('   - Usando email del usuario logueado: $emailDestino');
      } else {
        emailDestino = destinatario;
        print(
            '   - Usuario no logueado, usando destinatario proporcionado: $emailDestino');
      }

      print('   - Asunto: $asunto');
      print('   - Fecha envío: $fechaEnvio');
      print('   - Préstamo ID: ${prestamoId ?? "N/A"}');

      // Guardar el email programado en Firestore
      DocumentReference docRef = await _firestore.collection(
          'emails_programados').add({
        'destinatario': emailDestino,
        'asunto': asunto,
        'contenido': contenido,
        'fechaEnvio': fechaEnvio.toIso8601String(),
        'prestamoId': prestamoId,
        'enviado': false,
        'cancelado': false,
        'error': false,
        'intentos': 0,
        'fechaCreacion': DateTime.now().toIso8601String(),
      });

      print('✅ Email programado exitosamente con ID: ${docRef.id}');
    } catch (e) {
      print('❌ Error al programar email: $e');
      throw Exception('Error al programar email: $e');
    }
  }

  static Future<void> verificarEmailsProgramados() async {
    try {
      print('🔍 Verificando emails programados en Firestore...');

      QuerySnapshot snapshot = await _firestore
          .collection('emails_programados')
          .orderBy('fechaCreacion', descending: true)
          .limit(5)
          .get();

      print('📊 Emails encontrados: ${snapshot.size}');

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        print('📧 Email ${doc.id}:');
        print('   - Destinatario: ${data['destinatario']}');
        print('   - Asunto: ${data['asunto']}');
        print('   - Fecha envío: ${data['fechaEnvio']}');
        print('   - Enviado: ${data['enviado'] ?? false}');
        print('   - Cancelado: ${data['cancelado'] ?? false}');
        print('   - Error: ${data['error'] ?? false}');
        print('   - Intentos: ${data['intentos'] ?? 0}');

        // Verificar si ya debería haberse enviado
        DateTime fechaEnvio = DateTime.parse(data['fechaEnvio']);
        DateTime ahora = DateTime.now();
        bool deberiaEnviarse = fechaEnvio.isBefore(ahora) || fechaEnvio.isAtSameMomentAs(ahora);
        print('   - Debería enviarse: $deberiaEnviarse');
        print('   ---');
      }
    } catch (e) {
      print('❌ Error al verificar emails programados: $e');
    }
  }

  static Future<void> forzarProcesamientoEmails() async {
    try {
      print('🚀 Forzando procesamiento inmediato de emails...');
      await _procesarEmailsPendientes();
      print('✅ Procesamiento de emails completado');
    } catch (e) {
      print('❌ Error al forzar procesamiento: $e');
      throw Exception('Error al procesar emails: $e');
    }
  }

  /// Procesar emails pendientes de envío
  static Future<void> _procesarEmailsPendientes() async {
    try {
      DateTime ahora = DateTime.now();
      print('Procesando emails pendientes... Hora actual: $ahora');

      // Buscar emails pendientes que ya deberían haberse enviado
      // IMPORTANTE: No usar filtros complejos, Firebase puede tener problemas
      QuerySnapshot snapshot = await _firestore
          .collection('emails_programados')
          .where('enviado', isEqualTo: false)
          .get();

      print('Emails encontrados en BD: ${snapshot.docs.length}');

      List<QueryDocumentSnapshot> emailsParaEnviar = [];

      // Filtrar manualmente los que deben enviarse
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Verificar que no esté cancelado
        if (data['cancelado'] == true) continue;

        // Verificar que no tenga error
        if (data['error'] == true) continue;

        // Verificar fecha de envío
        String fechaEnvioStr = data['fechaEnvio'];
        DateTime fechaEnvio = DateTime.parse(fechaEnvioStr);

        if (fechaEnvio.isBefore(ahora) || fechaEnvio.isAtSameMomentAs(ahora)) {
          emailsParaEnviar.add(doc);
        }
      }

      print('Emails que deben enviarse: ${emailsParaEnviar.length}');

      for (QueryDocumentSnapshot doc in emailsParaEnviar) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        try {
          print('Enviando email a: ${data['destinatario']}');

          await _enviarEmail(
            destinatario: data['destinatario'],
            asunto: data['asunto'],
            contenido: data['contenido'],
          );

          // Marcar como enviado
          await doc.reference.update({
            'enviado': true,
            'fechaEnviado': DateTime.now().toIso8601String(),
          });

          print('Email enviado exitosamente a: ${data['destinatario']}');
        } catch (e) {
          print('Error al enviar email a ${data['destinatario']}: $e');

          // Incrementar contador de intentos
          int intentos = data['intentos'] ?? 0;
          if (intentos >= 2) {
            // Marcar como error después de 3 intentos fallidos
            await doc.reference.update({
              'error': true,
              'ultimoError': e.toString(),
              'fechaError': DateTime.now().toIso8601String(),
            });
            print('Email marcado como error después de 3 intentos');
          } else {
            await doc.reference.update({
              'intentos': intentos + 1,
              'ultimoIntento': DateTime.now().toIso8601String(),
            });
            print('Intento ${intentos + 1} fallido, se reintentará');
          }
        }
      }
    } catch (e) {
      print('Error general al procesar emails pendientes: $e');
    }
  }

  /// Enviar un email inmediatamente
  static Future<void> enviarEmailInmediato({
    required String destinatario,
    required String asunto,
    required String contenido,
  }) async {
    try {
      await _enviarEmail(
        destinatario: destinatario,
        asunto: asunto,
        contenido: contenido,
      );
      print('Email enviado inmediatamente a: $destinatario');
    } catch (e) {
      print('Error al enviar email inmediato: $e');
      throw Exception('Error al enviar email: $e');
    }
  }

  /// Método interno para enviar el email
  static Future<void> _enviarEmail({
    required String destinatario,
    required String asunto,
    required String contenido,
  }) async {
    try {
      // Configurar el servidor SMTP
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        ssl: false,
        allowInsecure: false,
        username: _emailRemitente,
        password: _passwordRemitente,
      );

      // Crear el mensaje
      final message = Message()
        ..from = Address(_emailRemitente, 'Sistema Scout')
        ..recipients.add(destinatario)
        ..subject = asunto
        ..html = _convertirTextoAHtml(contenido);

      // Enviar el email
      final sendReport = await send(message, smtpServer);
      print('Email enviado: ${sendReport.toString()}');
    } catch (e) {
      print('Error interno al enviar email: $e');
      throw Exception('Fallo en el envío del email: $e');
    }
  }

  /// Convertir texto plano a HTML básico para mejor presentación
  static String _convertirTextoAHtml(String textoPlano) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body {
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
            }
            .header {
                background-color: #3B7AC9;
                color: white;
                padding: 20px;
                border-radius: 8px 8px 0 0;
                text-align: center;
            }
            .content {
                background-color: #f9f9f9;
                padding: 20px;
                border: 1px solid #ddd;
                border-radius: 0 0 8px 8px;
            }
            .section-title {
                color: #3B7AC9;
                border-bottom: 2px solid #3B7AC9;
                padding-bottom: 5px;
                margin-top: 20px;
                margin-bottom: 10px;
            }
            .item-list {
                background-color: white;
                padding: 15px;
                border-radius: 5px;
                margin: 10px 0;
            }
            .footer {
                text-align: center;
                margin-top: 30px;
                padding: 15px;
                background-color: #f0f0f0;
                border-radius: 5px;
                font-size: 12px;
                color: #666;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h2>🏕️ Sistema de Gestión Scout</h2>
        </div>
        <div class="content">
            ${_formatearContenidoHtml(textoPlano)}
        </div>
        <div class="footer">
            <p>Este es un email automático del Sistema de Gestión de Inventario Scout.</p>
            <p>Por favor, no responder a este correo.</p>
        </div>
    </body>
    </html>
    ''';
  }

  /// Formatear el contenido texto a HTML con estilos
  static String _formatearContenidoHtml(String texto) {
    return texto
        .replaceAll('━━━━━━━━━━━━━━━━━━━━━━━━━━━', '<hr style="border: 2px solid #3B7AC9; margin: 15px 0;">')
        .replaceAll('INFORMACIÓN DEL PRÉSTAMO:', '<div class="section-title">📋 INFORMACIÓN DEL PRÉSTAMO</div>')
        .replaceAll('FECHAS:', '<div class="section-title">📅 FECHAS</div>')
        .replaceAll('ITEMS PRESTADOS:', '<div class="section-title">📦 ITEMS PRESTADOS</div>')
        .replaceAll('ITEMS PENDIENTES DE DEVOLUCIÓN:', '<div class="section-title">⚠️ ITEMS PENDIENTES DE DEVOLUCIÓN</div>')
        .replaceAll('OBSERVACIONES:', '<div class="section-title">📝 OBSERVACIONES</div>')
        .replaceAll('⚠️ PRÉSTAMO VENCIDO ⚠️', '<div style="background-color: #ff4444; color: white; padding: 15px; border-radius: 5px; text-align: center; font-weight: bold; font-size: 18px;">⚠️ PRÉSTAMO VENCIDO ⚠️</div>')
        .replaceAll('🚨 ACCIÓN REQUERIDA:', '<div style="background-color: #ff9900; color: white; padding: 10px; border-radius: 5px; font-weight: bold;">🚨 ACCIÓN REQUERIDA:</div>')
        .replaceAll('\n', '<br>');
  }

  /// Cancelar emails programados para un préstamo específico
  static Future<void> cancelarEmails(String prestamoId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('emails_programados')
          .where('prestamoId', isEqualTo: prestamoId)
          .where('enviado', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        batch.update(doc.reference, {
          'cancelado': true,
          'fechaCancelacion': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      print('Emails cancelados para préstamo: $prestamoId');
    } catch (e) {
      print('Error al cancelar emails: $e');
    }
  }

  /// Cancelar todos los emails programados
  static Future<void> cancelarTodosLosEmails() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('emails_programados')
          .where('enviado', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        batch.update(doc.reference, {
          'cancelado': true,
          'fechaCancelacion': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      print('Todos los emails programados han sido cancelados');
    } catch (e) {
      print('Error al cancelar todos los emails: $e');
    }
  }

  /// Obtener estadísticas de emails
  static Future<Map<String, int>> obtenerEstadisticasEmails() async {
    try {
      print('Obteniendo estadísticas de emails...');

      // Obtener todos los emails para análisis manual
      QuerySnapshot allEmails = await _firestore
          .collection('emails_programados')
          .get();

      print('Total de emails en BD: ${allEmails.size}');

      int pendientes = 0;
      int enviados = 0;
      int cancelados = 0;
      int conError = 0;

      for (var doc in allEmails.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['cancelado'] == true) {
          cancelados++;
        } else if (data['error'] == true) {
          conError++;
        } else if (data['enviado'] == true) {
          enviados++;
        } else {
          pendientes++;
        }
      }

      Map<String, int> stats = {
        'pendientes': pendientes,
        'enviados': enviados,
        'cancelados': cancelados,
        'conError': conError,
      };

      print('Estadísticas calculadas: $stats');
      return stats;

    } catch (e) {
      print('Error al obtener estadísticas de emails: $e');
      return {
        'pendientes': 0,
        'enviados': 0,
        'cancelados': 0,
        'conError': 0,
      };
    }
  }

  /// Limpiar emails antiguos (más de 30 días)
  static Future<void> limpiarEmailsAntiguos() async {
    try {
      DateTime fechaLimite = DateTime.now().subtract(const Duration(days: 30));

      QuerySnapshot snapshot = await _firestore
          .collection('emails_programados')
          .where('fechaCreacion', isLessThan: fechaLimite.toIso8601String())
          .get();

      WriteBatch batch = _firestore.batch();

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('${snapshot.size} emails antiguos eliminados');
    } catch (e) {
      print('Error al limpiar emails antiguos: $e');
    }
  }

  /// Enviar email de prueba
  static Future<void> enviarEmailPrueba(String destinatario) async {
    try {
      await enviarEmailInmediato(
        destinatario: destinatario,
        asunto: 'Prueba del Sistema de Notificaciones Scout',
        contenido: '''
Estimado usuario,

Este es un email de prueba del Sistema de Gestión de Inventario Scout.

Si recibes este mensaje, la configuración de emails está funcionando correctamente.

CONFIGURACIÓN ACTUAL:
━━━━━━━━━━━━━━━━━━━━━━━━━━━

Servidor SMTP: $_smtpServer
Puerto: $_smtpPort
Email remitente: $_emailRemitente
Fecha de prueba: ${DateTime.now()}

Si tienes algún problema, por favor verifica la configuración del servicio de emails.

Saludos,
Sistema de Gestión de Inventario Scout
        ''',
      );
    } catch (e) {
      print('Error al enviar email de prueba: $e');
      throw Exception('Error al enviar email de prueba: $e');
    }
  }

  /// Verificar configuración del servicio
  static Future<bool> verificarConfiguracion() async {
    try {
      if (_emailRemitente == 'tu-email@gmail.com' ||
          _passwordRemitente == 'tu-app-password') {
        print('⚠️ CONFIGURACIÓN PENDIENTE: Actualiza las credenciales del EmailService');
        return false;
      }

      return true;
    } catch (e) {
      print('Error al verificar configuración: $e');
      return false;
    }
  }
}