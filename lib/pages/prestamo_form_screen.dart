import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:typed_data'; // Importación agregada
import '../models/item.dart';
import '../models/prestamo.dart';
import '../models/unidad_scout.dart';
import '../models/ubicacion.dart';
import '../services/firebase_service.dart';

class PrestamoFormScreen extends StatefulWidget {
  const PrestamoFormScreen({Key? key}) : super(key: key);

  @override
  State<PrestamoFormScreen> createState() => _PrestamoFormScreenState();
}

class _PrestamoFormScreenState extends State<PrestamoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _observacionesController = TextEditingController();

  DateTime _fechaPrestamo = DateTime.now();
  DateTime _fechaDevolucion = DateTime.now().add(const Duration(days: 7));

  List<Item> _itemsDisponibles = [];
  List<ItemSeleccionado> _itemsSeleccionados = [];
  List<UnidadScout> _unidadesScout = [];
  List<Ubicacion> _ubicaciones = [];
  Map<String, List<Item>> _itemsPorUbicacion = {};
  UnidadScout? _unidadSeleccionada;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadUnidadesScout();
    _loadUbicaciones();
  }

  void _loadItems() {
    FirebaseService.getItems().listen((items) {
      setState(() {
        _itemsDisponibles = items.where((item) => item.cantidad > 0).toList();
        _organizarItemsPorUbicacion();
      });
    });
  }

  void _loadUnidadesScout() {
    FirebaseService.getUnidadesScout().listen((unidades) {
      setState(() {
        _unidadesScout = unidades;
      });
    });
  }

  void _loadUbicaciones() {
    FirebaseService.getUbicaciones().listen((ubicaciones) {
      setState(() {
        _ubicaciones = ubicaciones;
        _organizarItemsPorUbicacion();
      });
    });
  }

  void _organizarItemsPorUbicacion() {
    _itemsPorUbicacion.clear();

    for (var item in _itemsDisponibles) {
      String ubicacionId = item.ubicacionId;
      if (!_itemsPorUbicacion.containsKey(ubicacionId)) {
        _itemsPorUbicacion[ubicacionId] = [];
      }
      _itemsPorUbicacion[ubicacionId]!.add(item);
    }
  }

  String _getNombreUbicacion(String ubicacionId) {
    try {
      return _ubicaciones.firstWhere((u) => u.id == ubicacionId).nombre;
    } catch (e) {
      return 'Ubicación desconocida';
    }
  }

  Future<void> _savePrestamo() async {
    if (!_formKey.currentState!.validate()) return;

    if (_unidadSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una unidad scout'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_itemsSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // PASO 1: Validar disponibilidad de todos los items ANTES de crear la transacción
      for (var itemSeleccionado in _itemsSeleccionados) {
        int disponible = await FirebaseService.getCantidadDisponible(itemSeleccionado.item.id!);
        if (itemSeleccionado.cantidad > disponible) {
          throw Exception('${itemSeleccionado.item.nombre}: solo hay $disponible disponibles, solicitado: ${itemSeleccionado.cantidad}');
        }
      }

      // PASO 2: Crear el préstamo con el método corregido
      final prestamo = Prestamo(
        nombreSolicitante: _unidadSeleccionada!.nombreUnidad,
        telefono: _unidadSeleccionada!.telefono,
        unidadScoutId: _unidadSeleccionada?.id as String,
        ramaScout: _unidadSeleccionada!.ramaScout.displayName,
        items: _itemsSeleccionados.map((sel) => ItemPrestamo(
          itemId: sel.item.id!,
          nombreItem: sel.item.nombre,
          cantidadPrestada: sel.cantidad,
          estadoOriginal: sel.item.estado,
        )).toList(),
        fechaPrestamo: _fechaPrestamo,
        fechaDevolucionEsperada: _fechaDevolucion,
        observaciones: _observacionesController.text.trim().isEmpty
            ? null
            : _observacionesController.text.trim(),
      );

      // PASO 3: Intentar crear préstamo con notificaciones automáticas
      String prestamoId;
      bool notificacionesExitosas = false;
      String? errorNotificaciones;

      try {
        // Intentar primero con notificaciones
        prestamoId = await FirebaseServiceExtensions.createPrestamoConNotificaciones(prestamo);
        notificacionesExitosas = true;
      } catch (e) {
        print('Error con notificaciones: $e');

        // Si fallan las notificaciones, crear préstamo sin ellas
        if (e.toString().contains('exact_alarms_not_permitted') ||
            e.toString().contains('NotificationService') ||
            e.toString().contains('notificaciones')) {

          errorNotificaciones = e.toString();
          print('Creando préstamo sin notificaciones...');
          prestamoId = await FirebaseService.createPrestamo(prestamo);
          notificacionesExitosas = false;
        } else {
          // Si es otro error, relanzar
          rethrow;
        }
      }

      if (mounted) {
        if (notificacionesExitosas) {
          // Mostrar mensaje de éxito completo
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Préstamo creado exitosamente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📱 Notificaciones programadas para:',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade100),
                  ),
                  Text(
                    '• 3 días antes del vencimiento',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade50),
                  ),
                  Text(
                    '• 1 día antes (notificación + email)',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade50),
                  ),
                  Text(
                    '• Día del vencimiento (notificación + email)',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade50),
                  ),
                ],
              ),
              backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          // Mostrar mensaje de éxito parcial con advertencia
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Préstamo creado exitosamente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '⚠️ Sin notificaciones automáticas',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                  const Text(
                    'Recordatorio: Revisa manualmente las fechas de devolución',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _mostrarDialogoPermisos();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '🔧 Configurar notificaciones',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error al crear préstamo:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _obtenerMensajeErrorAmigable(e.toString()),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

// Método para mostrar diálogo explicativo sobre permisos
  void _mostrarDialogoPermisos() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notification_important, color: Colors.orange),
              SizedBox(width: 8),
              Text('Configurar Notificaciones'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para recibir recordatorios automáticos de préstamos, necesitas habilitar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildPermisoItem('📱', 'Notificaciones', 'Permite mostrar recordatorios'),
              const SizedBox(height: 8),
              _buildPermisoItem('⏰', 'Alarmas y recordatorios', 'Programa notificaciones exactas'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cómo configurar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1. Ve a Configuración del dispositivo\n'
                          '2. Aplicaciones > Gestión de Inventarios\n'
                          '3. Permisos > Habilitar notificaciones\n'
                          '4. Permisos especiales > Alarmas y recordatorios',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Más tarde'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Intentar abrir configuración de la app
                _abrirConfiguracionApp();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ir a Configuración'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermisoItem(String emoji, String titulo, String descripcion) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                descripcion,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

// Método para intentar abrir configuración de la app
  Future<void> _abrirConfiguracionApp() async {
    try {
      // Usar permission_handler para abrir configuración
      await openAppSettings();
    } catch (e) {
      print('No se pudo abrir configuración automáticamente: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Ve manualmente a: Configuración > Aplicaciones > Gestión de Inventarios > Permisos'
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

// Método para obtener mensajes de error más amigables
  String _obtenerMensajeErrorAmigable(String errorOriginal) {
    if (errorOriginal.contains('exact_alarms_not_permitted')) {
      return 'Las notificaciones automáticas requieren permisos especiales. '
          'El préstamo se creó correctamente, pero sin recordatorios automáticos.';
    } else if (errorOriginal.contains('NotificationService')) {
      return 'Problema con el sistema de notificaciones. '
          'El préstamo se creó correctamente, pero revisa manualmente las fechas.';
    } else if (errorOriginal.contains('Network')) {
      return 'Error de conexión. Verifica tu conexión a internet e intenta nuevamente.';
    } else if (errorOriginal.contains('FirebaseException')) {
      return 'Error en la base de datos. Intenta nuevamente en unos momentos.';
    } else if (errorOriginal.contains('cantidad')) {
      return errorOriginal; // Mantener errores de cantidad tal como están
    } else {
      return 'Error inesperado. Si persiste, contacta al soporte técnico.';
    }
  }

// Método auxiliar para manejar la transacción de creación del préstamo
  Future<void> _createPrestamoTransaction(Prestamo prestamo) async {
    final firestore = FirebaseFirestore.instance;

    await firestore.runTransaction((transaction) async {
      // PASO 1: Leer todos los documentos de items primero
      Map<String, DocumentSnapshot> itemDocs = {};
      Map<String, Item> items = {};

      for (ItemPrestamo itemPrestamo in prestamo.items) {
        DocumentReference itemRef = firestore
            .collection('items')
            .doc(itemPrestamo.itemId);

        DocumentSnapshot itemDoc = await transaction.get(itemRef);
        if (!itemDoc.exists) {
          throw Exception('Item ${itemPrestamo.nombreItem} no encontrado');
        }

        itemDocs[itemPrestamo.itemId] = itemDoc;
        Item item = Item.fromMap(itemDoc.data() as Map<String, dynamic>, itemDoc.id);
        items[itemPrestamo.itemId] = item;

        // Validar cantidad final antes de proceder
        if (item.cantidad < itemPrestamo.cantidadPrestada) {
          throw Exception('No hay suficiente cantidad de ${itemPrestamo.nombreItem}. Disponible: ${item.cantidad}, Solicitado: ${itemPrestamo.cantidadPrestada}');
        }
      }

      // PASO 2: Realizar todas las actualizaciones de items
      for (ItemPrestamo itemPrestamo in prestamo.items) {
        Item item = items[itemPrestamo.itemId]!;
        DocumentReference itemRef = firestore
            .collection('items')
            .doc(itemPrestamo.itemId);

        transaction.update(itemRef, {
          'cantidad': item.cantidad - itemPrestamo.cantidadPrestada,
          'fechaActualizacion': DateTime.now().toIso8601String(),
        });
      }

      // PASO 3: Crear el documento del préstamo
      DocumentReference prestamoRef = firestore
          .collection('prestamos')
          .doc();

      transaction.set(prestamoRef, prestamo.toMap());
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final horizontalPadding = isTablet ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: Text(
          'Nuevo Préstamo',
          style: TextStyle(fontSize: isTablet ? 24 : 20),
        ),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Primera fila: Unidad Scout y Fechas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildUnidadCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFechasCard(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Segunda fila: Items
          _buildItemsCard(),
          const SizedBox(height: 16),
          // Tercera fila: Observaciones y Botones
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildObservacionesCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButtons(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUnidadCard(),
          const SizedBox(height: 16),
          _buildFechasCard(),
          const SizedBox(height: 16),
          _buildItemsCard(),
          const SizedBox(height: 16),
          _buildObservacionesCard(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildUnidadCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unidad Scout',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            DropdownButtonFormField<UnidadScout>(
              value: _unidadSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Seleccionar Unidad Scout',
                labelStyle: TextStyle(color: Colors.black),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.groups),
              ),
              items: _unidadesScout.map((unidad) {
                return DropdownMenuItem<UnidadScout>(
                  value: unidad,
                  child: Text(
                    unidad.nombreUnidad,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (UnidadScout? newValue) {
                setState(() {
                  _unidadSeleccionada = newValue;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Por favor selecciona una unidad scout';
                }
                return null;
              },
              isExpanded: true,
              menuMaxHeight: 300,
            ),

            // Mostrar información del responsable si hay unidad seleccionada
            if (_unidadSeleccionada != null) ...[
              SizedBox(height: isTablet ? 20 : 16),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person,
                            size: isTablet ? 18 : 16,
                            color: Colors.blue.shade700),
                        SizedBox(width: isTablet ? 10 : 8),
                        Text(
                          'Responsable de la Unidad:',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _unidadSeleccionada!.responsableUnidad,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isTablet ? 12 : 8),
                    Row(
                      children: [
                        Icon(Icons.phone,
                            size: isTablet ? 18 : 16,
                            color: Colors.blue.shade700),
                        SizedBox(width: isTablet ? 10 : 8),
                        Text(
                          'Teléfono:',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _unidadSeleccionada!.telefono,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isTablet ? 12 : 8),
                    Row(
                      children: [
                        Icon(Icons.nature_people,
                            size: isTablet ? 18 : 16,
                            color: Colors.blue.shade700),
                        SizedBox(width: isTablet ? 10 : 8),
                        Text(
                          'Rama Scout:',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _unidadSeleccionada!.ramaScout.displayName,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRamaColor(_unidadSeleccionada!.ramaScout),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _unidadSeleccionada!.ramaScout.displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildFechasCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fechas del Préstamo',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            if (isTablet)
              Column(
                children: [
                  _buildFechaListTile(true),
                  const Divider(),
                  _buildFechaListTile(false),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildFechaListTile(true)),
                  Expanded(child: _buildFechaListTile(false)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFechaListTile(bool esFechaPrestamo) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        esFechaPrestamo ? 'Fecha de Préstamo' : 'Fecha de Devolución',
        style: TextStyle(fontSize: isTablet ? 14 : 12),
      ),
      subtitle: Text(
        esFechaPrestamo ? _formatDate(_fechaPrestamo) : _formatDate(_fechaDevolucion),
        style: TextStyle(fontSize: isTablet ? 16 : 13),
      ),
      leading: Icon(esFechaPrestamo ? Icons.calendar_today : Icons.event),
      onTap: () => _selectFecha(context, esFechaPrestamo),
    );
  }

  Widget _buildItemsCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items a Prestar',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showItemSelector,
                  icon: Icon(Icons.add, size: isTablet ? 18 : 15),
                  label: Text(
                    'Agregar Item',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(isTablet ? 12 : 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),
            if (_itemsSeleccionados.isEmpty)
              Container(
                padding: EdgeInsets.all(isTablet ? 40 : 32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: isTablet ? 56 : 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: isTablet ? 12 : 8),
                    Text(
                      'No hay items seleccionados',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: isTablet ? 18 : 16,
                      ),
                    ),
                  ],
                ),
              )
            else
            // Layout responsivo para items seleccionados
              isTablet && _itemsSeleccionados.length > 2
                  ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 8,
                ),
                itemCount: _itemsSeleccionados.length,
                itemBuilder: (context, index) {
                  final itemSel = _itemsSeleccionados[index];
                  return _buildSelectedItemCard(itemSel, index);
                },
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _itemsSeleccionados.length,
                itemBuilder: (context, index) {
                  final itemSel = _itemsSeleccionados[index];
                  return _buildSelectedItemCard(itemSel, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservacionesCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Observaciones (Opcional)',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            TextFormField(
              controller: _observacionesController,
              decoration: const InputDecoration(
                hintText: 'Observaciones adicionales...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: isTablet ? 4 : 3,
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isTablet || constraints.maxWidth > 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
              SizedBox(height: isTablet ? 16 : 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _savePrestamo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
                ),
                child: _isLoading
                    ? SizedBox(
                  height: isTablet ? 24 : 20,
                  width: isTablet ? 24 : 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  'Crear Préstamo',
                  style: TextStyle(fontSize: isTablet ? 16 : 14),
                ),
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePrestamo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('Crear Préstamo'),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // Método para obtener el color según la rama scout
  Color _getRamaColor(RamaScout rama) {
    switch (rama) {
      case RamaScout.lobatos:
        return Colors.orange;
      case RamaScout.exploradores:
        return Colors.blue;
      case RamaScout.pioneros:
        return Colors.red;
      case RamaScout.rovers:
        return Colors.green;
    }
  }

  Widget _buildSelectedItemCard(ItemSeleccionado itemSel, int index) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
        child: Row(
          children: [
            // Imagen del item
            Container(
              width: isTablet ? 70 : 60,
              height: isTablet ? 70 : 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              child: itemSel.item.imagenUrl != null && itemSel.item.imagenUrl!.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _decodeBase64Image(itemSel.item.imagenUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.inventory,
                        size: isTablet ? 35 : 30, color: Colors.grey.shade400);
                  },
                ),
              )
                  : Icon(Icons.inventory,
                  size: isTablet ? 35 : 30, color: Colors.grey.shade400),
            ),
            SizedBox(width: isTablet ? 16 : 12),
            // Información del item
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemSel.item.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 18 : 16,
                    ),
                  ),
                  SizedBox(height: isTablet ? 6 : 4),
                  Text(
                    'Ubicación: ${_getNombreUbicacion(itemSel.item.ubicacionId)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                  SizedBox(height: isTablet ? 6 : 4),
                  Text(
                    'Disponible: ${itemSel.item.cantidad}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A prestar: ${itemSel.cantidad}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getEstadoColor(itemSel.item.estado),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getEstadoText(itemSel.item.estado),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Botones de acción alineados a la derecha
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: isTablet ? 22 : 18),
                            onPressed: () => _editCantidad(index),
                            padding: const EdgeInsets.all(4),
                            constraints: BoxConstraints(
                              minWidth: isTablet ? 32 : 28,
                              minHeight: isTablet ? 32 : 28,
                            ),
                          ),
                          SizedBox(width: isTablet ? 8 : 4),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red, size: isTablet ? 22 : 18),
                            onPressed: () => _removeItem(index),
                            padding: const EdgeInsets.all(4),
                            constraints: BoxConstraints(
                              minWidth: isTablet ? 32 : 28,
                              minHeight: isTablet ? 32 : 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectFecha(BuildContext context, bool esFechaPrestamo) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: esFechaPrestamo ? _fechaPrestamo : _fechaDevolucion,
      firstDate: esFechaPrestamo ? DateTime.now() : _fechaPrestamo,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (esFechaPrestamo) {
          _fechaPrestamo = picked;
          // Si la fecha de préstamo es posterior a la de devolución, ajustar
          if (_fechaDevolucion.isBefore(_fechaPrestamo)) {
            _fechaDevolucion = _fechaPrestamo.add(const Duration(days: 7));
          }
        } else {
          _fechaDevolucion = picked;
        }
      });
    }
  }

  void _showItemSelector() {
    if (_itemsDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay items disponibles para préstamo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(
            width: isTablet
                ? screenSize.width * 0.8
                : screenSize.width * 0.9,
            height: isTablet
                ? screenSize.height * 0.7
                : screenSize.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(59, 122, 201, 1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.white),
                      SizedBox(width: isTablet ? 16 : 12),
                      Text(
                        'Seleccionar Items por Ubicación',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _itemsPorUbicacion.isEmpty
                      ? const Center(
                    child: Text('No hay items disponibles'),
                  )
                      : ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    itemCount: _itemsPorUbicacion.keys.length,
                    itemBuilder: (context, index) {
                      String ubicacionId = _itemsPorUbicacion.keys.elementAt(index);
                      List<Item> items = _itemsPorUbicacion[ubicacionId]!;
                      String nombreUbicacion = _getNombreUbicacion(ubicacionId);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header de ubicación
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                vertical: isTablet ? 12 : 8,
                                horizontal: isTablet ? 16 : 12
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: isTablet ? 18 : 16,
                                    color: Colors.grey.shade600),
                                SizedBox(width: isTablet ? 12 : 8),
                                Text(
                                  nombreUbicacion,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                                SizedBox(width: isTablet ? 12 : 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${items.length} items',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: isTablet ? 12 : 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Items de la ubicación
                          ...items.map((item) => _buildItemSelectorCard(item)),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ),
                // Footer
                Container(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cerrar',
                          style: TextStyle(fontSize: isTablet ? 16 : 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemSelectorCard(Item item) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final yaSeleccionado = _itemsSeleccionados.any((sel) => sel.item.id == item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          width: isTablet ? 60 : 50,
          height: isTablet ? 60 : 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _decodeBase64Image(item.imagenUrl!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.inventory,
                    size: isTablet ? 28 : 24, color: Colors.grey.shade400);
              },
            ),
          )
              : Icon(Icons.inventory,
              size: isTablet ? 28 : 24, color: Colors.grey.shade400),
        ),
        title: Text(
          item.nombre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: yaSeleccionado ? Colors.grey : Colors.black,
            fontSize: isTablet ? 16 : 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disponible: ${item.cantidad}',
              style: TextStyle(
                color: yaSeleccionado ? Colors.grey : Colors.grey.shade600,
                fontSize: isTablet ? 14 : 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getEstadoColor(item.estado),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getEstadoText(item.estado),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (yaSeleccionado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.green.shade700, size: isTablet ? 18 : 16),
                        const SizedBox(width: 4),
                        Text(
                          'Seleccionado',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: yaSeleccionado ? null : Icon(
          Icons.add_circle_outline,
          color: Colors.blue.shade700,
          size: isTablet ? 28 : 24,
        ),
        enabled: !yaSeleccionado,
        onTap: yaSeleccionado ? null : () {
          Navigator.of(context).pop();
          _selectCantidad(item);
        },
      ),
    );
  }

  void _selectCantidad(Item item) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final cantidadController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              // Imagen del item
              Container(
                width: isTablet ? 50 : 40,
                height: isTablet ? 50 : 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade200,
                ),
                child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    _decodeBase64Image(item.imagenUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.inventory,
                          size: isTablet ? 24 : 20, color: Colors.grey.shade400);
                    },
                  ),
                )
                    : Icon(Icons.inventory,
                    size: isTablet ? 24 : 20, color: Colors.grey.shade400),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.nombre,
                      style: TextStyle(fontSize: isTablet ? 18 : 16),
                    ),
                    Text(
                      _getNombreUbicacion(item.ubicacionId),
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(item.estado),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getEstadoText(item.estado),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.blue.shade700, size: isTablet ? 18 : 16),
                    SizedBox(width: isTablet ? 12 : 8),
                    Text(
                      'Cantidad disponible: ${item.cantidad}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isTablet ? 20 : 16),
              TextFormField(
                controller: cantidadController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad a prestar',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add_box),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final cantidad = int.tryParse(cantidadController.text);
                if (cantidad == null || cantidad <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa una cantidad válida'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (cantidad > item.cantidad) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Solo hay ${item.cantidad} disponibles'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  _itemsSeleccionados.add(ItemSeleccionado(
                    item: item,
                    cantidad: cantidad,
                  ));
                });

                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Agregar',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editCantidad(int index) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final itemSel = _itemsSeleccionados[index];
    final cantidadController = TextEditingController(
      text: itemSel.cantidad.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              // Imagen del item
              Container(
                width: isTablet ? 50 : 40,
                height: isTablet ? 50 : 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade200,
                ),
                child: itemSel.item.imagenUrl != null && itemSel.item.imagenUrl!.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    _decodeBase64Image(itemSel.item.imagenUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.inventory,
                          size: isTablet ? 24 : 20, color: Colors.grey.shade400);
                    },
                  ),
                )
                    : Icon(Icons.inventory,
                    size: isTablet ? 24 : 20, color: Colors.grey.shade400),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Editar: ${itemSel.item.nombre}',
                      style: TextStyle(fontSize: isTablet ? 18 : 16),
                    ),
                    Text(
                      _getNombreUbicacion(itemSel.item.ubicacionId),
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(itemSel.item.estado),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getEstadoText(itemSel.item.estado),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.orange.shade700, size: isTablet ? 18 : 16),
                    SizedBox(width: isTablet ? 12 : 8),
                    Text(
                      'Cantidad disponible: ${itemSel.item.cantidad}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isTablet ? 20 : 16),
              TextFormField(
                controller: cantidadController,
                decoration: const InputDecoration(
                  labelText: 'Nueva cantidad a prestar',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final cantidad = int.tryParse(cantidadController.text);
                if (cantidad == null || cantidad <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa una cantidad válida'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (cantidad > itemSel.item.cantidad) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Solo hay ${itemSel.item.cantidad} disponibles'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  _itemsSeleccionados[index] = ItemSeleccionado(
                    item: itemSel.item,
                    cantidad: cantidad,
                  );
                });

                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Actualizar',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ),
          ],
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() {
      _itemsSeleccionados.removeAt(index);
    });
  }

  // Método corregido para decodificar imágenes Base64
  Uint8List _decodeBase64Image(String base64String) {
    try {
      // Remover el prefijo data:image/...;base64, si existe
      String base64Data = base64String;
      if (base64String.contains(',')) {
        base64Data = base64String.split(',')[1];
      }

      return Uint8List.fromList(base64.decode(base64Data));
    } catch (e) {
      throw Exception('Error al decodificar imagen: $e');
    }
  }

  // Métodos corregidos para manejar el estado del item
  Color _getEstadoColor(EstadoItem estado) {
    switch (estado) {
      case EstadoItem.excelente:
        return Colors.green;
      case EstadoItem.bueno:
        return Colors.blue;
      case EstadoItem.malo:
        return Colors.red;
      case EstadoItem.perdida:
        return Colors.grey;
    }
  }

  String _getEstadoText(EstadoItem estado) {
    switch (estado) {
      case EstadoItem.excelente:
        return 'EXCELENTE';
      case EstadoItem.bueno:
        return 'BUENO';
      case EstadoItem.malo:
        return 'MALO';
      case EstadoItem.perdida:
        return 'PERDIDA';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }
}

class ItemSeleccionado {
  final Item item;
  final int cantidad;

  ItemSeleccionado({
    required this.item,
    required this.cantidad,
  });
}