import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/email_service.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  Map<String, bool> _config = {};
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadStats();
    _checkConfig();
    _startStatsTimer(); // NUEVO: Iniciar timer de estadísticas
  }
  @override
  void dispose() {
    _statsTimer?.cancel(); // NUEVO: Cancelar timer al cerrar
    super.dispose();
  }

  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadStats();
        _checkConfig();
      }
    });
  }

  Future<void> _debugSistemaCompleto() async {
    setState(() => _isLoading = true);

    try {
      print('Ejecutando debug completo del sistema...');

      // Ejecutar debug completo
      await FirebaseServiceExtensions.debugSistemaCompleto();

      // Refrescar todas las estadísticas
      await _loadStats();
      await _checkConfig();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debug completo ejecutado - Revisa la consola'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error en debug completo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en debug: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSettings() async {
    await SettingsService.initialize();
    setState(() {
      _notificationsEnabled = SettingsService.notificationsEnabled;
    });
  }

  Future<void> _loadStats() async {
    if (!mounted) return;

    try {
      print('Cargando estadísticas...');
      Map<String, dynamic> stats = await FirebaseServiceExtensions.obtenerEstadisticasNotificaciones();

      if (mounted) {
        setState(() {
          _stats = stats;
        });
        print('Estadísticas cargadas: $stats');
      }
    } catch (e) {
      print('Error al cargar estadísticas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estadísticas: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _checkConfig() async {
    if (!mounted) return;

    try {
      print('Verificando configuración...');
      Map<String, bool> config = await FirebaseServiceExtensions.verificarConfiguracion();

      if (mounted) {
        setState(() {
          _config = config;
        });
        print('Configuración verificada: $config');
      }
    } catch (e) {
      print('Error al verificar configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar configuración: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _isLoading = true);

    try {
      await SettingsService.setNotificationsEnabled(value);
      setState(() {
        _notificationsEnabled = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                value
                    ? 'Notificaciones habilitadas'
                    : 'Notificaciones deshabilitadas'
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    try {
      bool granted = await NotificationService.requestPermissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                granted
                    ? 'Permisos de notificación otorgados'
                    : 'Permisos de notificación denegados'
            ),
            backgroundColor: granted ? Colors.green : Colors.red,
          ),
        );
      }
      await _checkConfig();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar permisos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _isLoading = true);

    try {
      await NotificationService.mostrarNotificacionImagenUnidad(
        unidadId: 'test',
        nombreUnidad: 'Prueba',
        diasRestantes: 5,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación de prueba enviada'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // NUEVO: Refrescar estadísticas después de enviar
      await Future.delayed(const Duration(seconds: 1));
      await _loadStats();

    } catch (e) {
      print('Error en _sendTestNotification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar notificación de prueba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendTestEmail() async {
    setState(() => _isLoading = true);

    try {
      String? email = EmailService.emailUsuarioActual;
      if (email != null) {
        print('Enviando email de prueba a: $email');
        await EmailService.enviarEmailPrueba(email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email de prueba enviado a: $email'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // NUEVO: Refrescar estadísticas después de enviar
        await Future.delayed(const Duration(seconds: 2));
        await _loadStats();

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener el email del usuario'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error en _sendTestEmail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar email de prueba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cleanOldData() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Datos Antiguos'),
        content: const Text('¿Estás seguro de que deseas eliminar los emails y notificaciones antiguos (más de 30 días)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        print('Limpiando datos antiguos...');
        await FirebaseServiceExtensions.limpiarDatosAntiguos();

        // NUEVO: Refrescar estadísticas después de limpiar
        await _loadStats();
        await _checkConfig();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos antiguos eliminados exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error en _cleanOldData: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al limpiar datos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  Future<void> _processEmailsNow() async {
    setState(() => _isLoading = true);

    try {
      print('Forzando procesamiento de emails...');

      // Llamar directamente al método de procesamiento
      await EmailService.forzarProcesamientoEmails();

      // Refrescar estadísticas
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emails procesados manualmente'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error al procesar emails: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar emails: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  Future<void> _reinitializeServices() async {
    setState(() => _isLoading = true);

    try {
      print('Reinicializando servicios...');

      // Reinicializar EmailService
      EmailService.dispose();
      await EmailService.initialize();

      // Refrescar todo
      await _loadStats();
      await _checkConfig();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicios reinicializados'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error al reinicializar servicios: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reinicializar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: Text(
          'Configuración de Notificaciones',
          style: TextStyle(fontSize: isTablet ? 24 : 20),
        ),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          await _checkConfig();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              SizedBox(height: isTablet ? 20 : 16),
              _buildSettingsCard(),
              SizedBox(height: isTablet ? 20 : 16),
              _buildStatsCard(),
              SizedBox(height: isTablet ? 20 : 16),
              _buildActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    bool sistemaCompleto = _config['sistemaCompleto'] ?? false;
    bool notificacionesHabilitadas = _config['notificacionesHabilitadas'] ?? false;
    bool emailConfigurado = _config['emailConfigurado'] ?? false;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sistemaCompleto ? Icons.check_circle : Icons.warning,
                  color: sistemaCompleto ? Colors.green : Colors.orange,
                  size: isTablet ? 28 : 24,
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Text(
                  'Estado del Sistema',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),
            _buildStatusItem(
              'Notificaciones Push',
              notificacionesHabilitadas,
              isTablet,
            ),
            const Divider(height: 16),
            _buildStatusItem(
              'Configuración de Email',
              emailConfigurado,
              isTablet,
            ),
            const Divider(height: 16),
            _buildStatusItem(
              'Sistema Completo',
              sistemaCompleto,
              isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, bool status, bool isTablet) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle_outline : Icons.error_outline,
          color: status ? Colors.green : Colors.red,
          size: isTablet ? 24 : 20,
        ),
        SizedBox(width: isTablet ? 12 : 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          status ? 'Activo' : 'Inactivo',
          style: TextStyle(
            color: status ? Colors.green : Colors.red,
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            SwitchListTile(
              title: Text(
                'Habilitar Notificaciones',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
              subtitle: Text(
                'Recibir notificaciones push para préstamos',
                style: TextStyle(fontSize: isTablet ? 14 : 12),
              ),
              value: _notificationsEnabled,
              onChanged: _isLoading ? null : _toggleNotifications,
              activeColor: const Color.fromRGBO(59, 122, 201, 1),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(
                'Email Usuario Actual',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
              subtitle: Text(
                EmailService.emailUsuarioActual ?? 'No disponible',
                style: TextStyle(fontSize: isTablet ? 14 : 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            if (isTablet)
              Row(
                children: [
                  Expanded(child: _buildStatColumn('Emails')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatColumn('Notificaciones')),
                ],
              )
            else ...[
              _buildStatColumn('Emails'),
              const SizedBox(height: 16),
              _buildStatColumn('Notificaciones'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String type) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (type == 'Emails') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emails',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatItem('Pendientes', _stats['emailsPendientes'] ?? 0, isTablet),
          _buildStatItem('Enviados', _stats['emailsEnviados'] ?? 0, isTablet),
          _buildStatItem('Cancelados', _stats['emailsCancelados'] ?? 0, isTablet),
          _buildStatItem('Con Error', _stats['emailsConError'] ?? 0, isTablet),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notificaciones',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatItem('Préstamos Pendientes', _stats['notificacionesPendientes'] ?? 0, isTablet),
          _buildStatItem('Total Pendientes', _stats['totalNotificacionesPendientes'] ?? 0, isTablet),
        ],
      );
    }
  }

  Widget _buildStatItem(String label, int value, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: isTablet ? 14 : 12),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),

            // SECCIÓN PRINCIPAL
            if (isTablet)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _requestPermissions,
                      icon: const Icon(Icons.notifications),
                      label: const Text('Solicitar Permisos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendTestNotification,
                      icon: const Icon(Icons.notification_add),
                      label: const Text('Prueba Notificación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _requestPermissions,
                  icon: const Icon(Icons.notifications),
                  label: const Text('Solicitar Permisos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendTestNotification,
                  icon: const Icon(Icons.notification_add),
                  label: const Text('Prueba Notificación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],

            SizedBox(height: isTablet ? 16 : 12),

            // SECCIÓN EMAILS Y LIMPIEZA
            if (isTablet)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendTestEmail,
                      icon: const Icon(Icons.email),
                      label: const Text('Prueba Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _cleanOldData,
                      icon: const Icon(Icons.cleaning_services),
                      label: const Text('Limpiar Datos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendTestEmail,
                  icon: const Icon(Icons.email),
                  label: const Text('Prueba Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _cleanOldData,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Limpiar Datos Antiguos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],

            // NUEVA SECCIÓN DEBUG
            SizedBox(height: isTablet ? 20 : 16),
            Divider(color: Colors.grey.shade400),
            SizedBox(height: isTablet ? 16 : 12),

            Text(
              'Debug y Mantenimiento',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),

            if (isTablet)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _processEmailsNow,
                      icon: const Icon(Icons.send_time_extension),
                      label: const Text('Procesar Emails'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _reinitializeServices,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reinicializar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _processEmailsNow,
                  icon: const Icon(Icons.send_time_extension),
                  label: const Text('Procesar Emails Pendientes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _reinitializeServices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reinicializar Servicios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              SizedBox(height: isTablet ? 16 : 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _debugSistemaCompleto,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Debug Sistema Completo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              SizedBox(height: isTablet ? 16 : 12),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información de Debug',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Usuario: ${EmailService.emailUsuarioActual ?? "No logueado"}',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Última actualización: ${_stats['ultimaActualizacion'] ?? "N/A"}',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (_stats.containsKey('error'))
                      Text(
                        'Error: ${_stats['error']}',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: Colors.red.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}