import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/prestamo.dart';
import '../models/item.dart';
import '../models/unidad_scout.dart';
import '../services/firebase_service.dart';
import '../widgets/devolucion_dialog.dart';

class PrestamoDetailScreen extends StatefulWidget {
  final Prestamo prestamo;

  const PrestamoDetailScreen({Key? key, required this.prestamo}) : super(key: key);

  @override
  State<PrestamoDetailScreen> createState() => _PrestamoDetailScreenState();
}

class _PrestamoDetailScreenState extends State<PrestamoDetailScreen> {
  late Prestamo _prestamo;
  bool _isLoading = false;
  UnidadScout? _unidadScout;

  @override
  void initState() {
    super.initState();
    _prestamo = widget.prestamo;
    _loadUnidadScout();
  }

  void _loadUnidadScout() async {
    try {
      // Buscar la unidad scout por nombre
      final unidadesStream = FirebaseService.getUnidadesScout();
      final unidades = await unidadesStream.first;

      _unidadScout = unidades.firstWhere(
            (unidad) => unidad.nombreUnidad == _prestamo.nombreSolicitante,
        orElse: () => UnidadScout(
          nombreUnidad: _prestamo.nombreSolicitante,
          responsableUnidad: 'Responsable no encontrado',
          telefono: _prestamo.telefono,
          ramaScout: RamaScout.fromString(_prestamo.ramaScout), // Convertir String a RamaScout
        ),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // En caso de error, crear una unidad temporal con la información disponible
      _unidadScout = UnidadScout(
        nombreUnidad: _prestamo.nombreSolicitante,
        responsableUnidad: 'No disponible',
        telefono: _prestamo.telefono,
        ramaScout: RamaScout.fromString(_prestamo.ramaScout), // Convertir String a RamaScout
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final crossAxisCount = isTablet ? 2 : 1;
    final horizontalPadding = isTablet ? 32.0 : 16.0;

    Color estadoColor = _getEstadoColor(_prestamo.estado);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: Text(
          'Detalle del Préstamo',
          style: TextStyle(fontSize: isTablet ? 24 : 20),
        ),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        actions: [
          if (_prestamo.estado == EstadoPrestamo.activo ||
              _prestamo.estado == EstadoPrestamo.parcial ||
              _prestamo.estado == EstadoPrestamo.vencido)
            IconButton(
              icon: const Icon(Icons.assignment_return),
              onPressed: _showDevolucionDialog,
              tooltip: 'Devolver items',
            ),
        ],
      ),
      body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Primera fila: Información de unidad y estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildUnidadCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEstadoCard(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Segunda fila: Items y observaciones
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildItemsCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    if (_prestamo.observaciones != null && _prestamo.observaciones!.isNotEmpty)
                      _buildObservacionesCard(),
                    const SizedBox(height: 16),
                    _buildActionButton(),
                  ],
                ),
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
          _buildEstadoCard(),
          const SizedBox(height: 16),
          _buildItemsCard(),
          const SizedBox(height: 16),
          if (_prestamo.observaciones != null && _prestamo.observaciones!.isNotEmpty)
            _buildObservacionesCard(),
          const SizedBox(height: 32),
          _buildActionButton(),
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
            Row(
              children: [
                Icon(Icons.groups, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Información de la Unidad Scout',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mostrar imagen de la unidad si existe
            if (_unidadScout?.imagenUnidad != null && _unidadScout!.imagenUnidad!.isNotEmpty)
              Center(
                child: Container(
                  width: isTablet ? 100 : 80,
                  height: isTablet ? 100 : 80,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _decodeBase64Image(_unidadScout!.imagenUnidad!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.groups,
                            size: isTablet ? 50 : 40, color: Colors.grey.shade400);
                      },
                    ),
                  ),
                ),
              ),

            _buildInfoRow('Nombre de la Unidad', _prestamo.nombreSolicitante, Icons.groups_outlined),

            if (_unidadScout != null) ...[
              _buildInfoRow('Responsable de la Unidad', _unidadScout!.responsableUnidad, Icons.person_outline),
              _buildInfoRow('Teléfono del Responsable', _unidadScout!.telefono, Icons.phone_outlined),
              _buildInfoRow(
                'Rama Scout',
                _unidadScout!.ramaScout.displayName,
                Icons.nature_people_outlined,
                showBadge: true,
                badgeColor: _getRamaColor(_unidadScout!.ramaScout),
              ),
            ] else ...[
              // Mostrar información básica mientras se carga
              _buildInfoRow('Responsable', 'Cargando...', Icons.person_outline),
              _buildInfoRow('Teléfono', _prestamo.telefono, Icons.phone_outlined),
              _buildInfoRow(
                'Rama Scout',
                _prestamo.ramaScout,
                Icons.nature_people_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoCard() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    Color estadoColor = _getEstadoColor(_prestamo.estado);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Estado y Fechas',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: estadoColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getEstadoIcon(_prestamo.estado),
                      color: estadoColor, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _getEstadoText(_prestamo.estado),
                      style: TextStyle(
                        color: estadoColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Fecha de Préstamo',
                _formatDate(_prestamo.fechaPrestamo),
                Icons.calendar_today),
            _buildInfoRow('Fecha de Devolución Esperada',
                _formatDate(_prestamo.fechaDevolucionEsperada),
                Icons.event),
            if (_prestamo.fechaDevolucionReal != null)
              _buildInfoRow('Fecha de Devolución Real',
                  _formatDate(_prestamo.fechaDevolucionReal!),
                  Icons.check_circle),
            if (_prestamo.estado != EstadoPrestamo.devuelto)
              _buildInfoRow(
                'Días Restantes',
                _prestamo.estaVencido
                    ? 'Vencido (${_prestamo.diasRestantes.abs()} días)'
                    : '${_prestamo.diasRestantes} días',
                _prestamo.estaVencido ? Icons.warning : Icons.schedule,
                textColor: _prestamo.estaVencido ? Colors.red : Colors.green,
              ),
          ],
        ),
      ),
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
              children: [
                Icon(Icons.inventory, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Items Prestados',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Layout responsivo para items
            if (isTablet && _prestamo.items.length > 3)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 8,
                ),
                itemCount: _prestamo.items.length,
                itemBuilder: (context, index) {
                  return _buildItemCard(_prestamo.items[index]);
                },
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _prestamo.items.length,
                itemBuilder: (context, index) {
                  final item = _prestamo.items[index];
                  return _buildItemCard(item);
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
            Row(
              children: [
                Icon(Icons.note, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Observaciones',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _prestamo.observaciones!,
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (_prestamo.estado == EstadoPrestamo.activo ||
        _prestamo.estado == EstadoPrestamo.parcial ||
        _prestamo.estado == EstadoPrestamo.vencido) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _showDevolucionDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
          ),
          icon: _isLoading
              ? const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Icon(Icons.assignment_return),
          label: Text(
            _isLoading ? 'Procesando...' : 'Devolver Items',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {
    Color? textColor,
    bool showBadge = false,
    Color? badgeColor,
  }) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: isTablet ? 22 : 20, color: Colors.grey.shade600),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    if (showBadge && badgeColor != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método para obtener el color según la rama scout
  Color _getRamaColor(RamaScout rama) {
    switch (rama) {
      case RamaScout.lobatos:
        return Colors.orange;
      case RamaScout.exploradores:
        return Colors.green;
      case RamaScout.pioneros:
        return Colors.blue;
      case RamaScout.rovers:
        return Colors.red;
    }
  }

  // Método para obtener el color desde string (fallback)
  Color _getRamaColorFromString(String ramaString) {
    switch (ramaString.toLowerCase()) {
      case 'lobatos':
        return Colors.orange;
      case 'exploradores':
        return Colors.green;
      case 'pioneros':
        return Colors.blue;
      case 'rovers':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Método corregido _buildItemCard en PrestamoDetailScreen
  Widget _buildItemCard(ItemPrestamo item) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    bool estaCompleto = item.estaCompleto;
    int cantidadPendiente = item.cantidadPendiente;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: estaCompleto ? Colors.green.shade50 : null,
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: estaCompleto
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  radius: isTablet ? 20 : 16,
                  child: Text(
                    item.cantidadPrestada.toString(),
                    style: TextStyle(
                      color: estaCompleto
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nombreItem,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 16 : 14,
                          decoration: estaCompleto ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        'Cantidad prestada: ${item.cantidadPrestada}',
                        style: TextStyle(fontSize: isTablet ? 14 : 12),
                      ),
                      if (item.cantidadDevuelta != null)
                        Text(
                          'Cantidad devuelta: ${item.cantidadDevuelta}',
                          style: TextStyle(fontSize: isTablet ? 14 : 12),
                        ),
                      if (!estaCompleto && cantidadPendiente > 0)
                        Text(
                          'Pendiente: $cantidadPendiente',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 14 : 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (estaCompleto)
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: isTablet ? 28 : 24)
                else
                  Icon(Icons.pending, color: Colors.orange.shade600, size: isTablet ? 28 : 24),
              ],
            ),
            SizedBox(height: isTablet ? 12 : 8),

            // Estados del item - Layout responsivo
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                // Estado original
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado al prestar:',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getEstadoItemColor(item.estadoOriginal),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.estadoOriginal.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Estado devuelto (si existe)
                if (item.estadoDevuelto != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado al devolver:',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getEstadoItemColor(item.estadoDevuelto!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.estadoDevuelto!.displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (item.estadoCambio) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.warning,
                              color: Colors.orange.shade600,
                              size: isTablet ? 18 : 16,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),

            // Mostrar imagen del estado cambiado si existe
            if (item.imagenEstadoDevuelto != null) ...[
              SizedBox(height: isTablet ? 12 : 8),
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto del item al cambiar estado:',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    SizedBox(height: isTablet ? 12 : 8),
                    Container(
                      height: isTablet ? 80 : 60,
                      width: isTablet ? 80 : 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade200,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _decodeBase64Image(item.imagenEstadoDevuelto!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image_not_supported,
                                size: isTablet ? 40 : 30, color: Colors.grey.shade400);
                          },
                        ),
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

  Color _getEstadoItemColor(EstadoItem estado) {
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

  void _showDevolucionDialog() {
    // Filtrar solo los items que no están completamente devueltos
    List<ItemPrestamo> itemsPendientes = _prestamo.items
        .where((item) => !item.estaCompleto)
        .toList();

    if (itemsPendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los items ya han sido devueltos'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DevolucionDialog(
          itemsPendientes: itemsPendientes,
          onDevolver: _procesarDevolucionConEstado,
        );
      },
    );
  }

  void _procesarDevolucionConEstado(Map<String, ItemDevolucion> itemsDevolucion) async {
    setState(() => _isLoading = true);

    try {
      // Filtrar solo los items que tienen cantidad a devolver
      Map<String, ItemDevolucion> itemsADevolver = {};
      for (var entry in itemsDevolucion.entries) {
        if (entry.value.cantidadADevolver > 0) {
          itemsADevolver[entry.key] = entry.value;
        }
      }

      if (itemsADevolver.isEmpty) {
        throw Exception('No hay items para devolver');
      }

      // Llamar al nuevo método de Firebase Service
      await FirebaseService.devolverItemsConEstado(_prestamo.id!, itemsADevolver);

      // Recargar el préstamo actualizado
      Prestamo? prestamoActualizado = await FirebaseService.getPrestamoById(_prestamo.id!);
      if (prestamoActualizado != null) {
        setState(() {
          _prestamo = prestamoActualizado;
        });
      }

      // Mostrar mensaje de éxito con información adicional
      int itemsConCambioEstado = itemsADevolver.values
          .where((dev) => dev.estadoDevuelto != dev.estadoOriginal)
          .length;

      String mensaje = 'Items devueltos exitosamente';
      if (itemsConCambioEstado > 0) {
        mensaje += '. Se crearon $itemsConCambioEstado nuevos items con estado cambiado';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al devolver items: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método para decodificar imágenes Base64
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

  String _getEstadoText(EstadoPrestamo estado) {
    switch (estado) {
      case EstadoPrestamo.activo:
        return 'Activo';
      case EstadoPrestamo.vencido:
        return 'Vencido';
      case EstadoPrestamo.devuelto:
        return 'Devuelto';
      case EstadoPrestamo.parcial:
        return 'Parcialmente Devuelto';
    }
  }

  Color _getEstadoColor(EstadoPrestamo estado) {
    switch (estado) {
      case EstadoPrestamo.activo:
        return Colors.blue;
      case EstadoPrestamo.vencido:
        return Colors.red;
      case EstadoPrestamo.devuelto:
        return Colors.green;
      case EstadoPrestamo.parcial:
        return Colors.orange;
    }
  }

  IconData _getEstadoIcon(EstadoPrestamo estado) {
    switch (estado) {
      case EstadoPrestamo.activo:
        return Icons.assignment;
      case EstadoPrestamo.vencido:
        return Icons.warning;
      case EstadoPrestamo.devuelto:
        return Icons.check_circle;
      case EstadoPrestamo.parcial:
        return Icons.pending;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}