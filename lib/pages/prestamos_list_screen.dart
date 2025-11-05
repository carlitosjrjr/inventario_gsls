import 'package:flutter/material.dart';
import '../models/prestamo.dart';
import '../services/firebase_service.dart';
import 'prestamo_form_screen.dart';
import 'prestamo_detail_screen.dart';

class PrestamosListScreen extends StatefulWidget {
  const PrestamosListScreen({Key? key}) : super(key: key);

  @override
  State<PrestamosListScreen> createState() => _PrestamosListScreenState();
}

class _PrestamosListScreenState extends State<PrestamosListScreen> {
  String _searchQuery = '';
  EstadoPrestamo? _filterEstado;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Préstamos',
          style: TextStyle(fontSize: isTablet ? 24 : 20),
        ),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'filter') {
                _showFilterDialog();
              } else if (value == 'clear_filter') {
                setState(() {
                  _filterEstado = null;
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'filter',
                child: Row(
                  children: [
                    const Icon(Icons.filter_list),
                    SizedBox(width: isTablet ? 12 : 8),
                    Text(
                      'Filtrar por estado',
                      style: TextStyle(fontSize: isTablet ? 16 : 14),
                    ),
                  ],
                ),
              ),
              if (_filterEstado != null)
                PopupMenuItem<String>(
                  value: 'clear_filter',
                  child: Row(
                    children: [
                      const Icon(Icons.clear),
                      SizedBox(width: isTablet ? 12 : 8),
                      Text(
                        'Limpiar filtro',
                        style: TextStyle(fontSize: isTablet ? 16 : 14),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre de unidad...',
                hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
                prefixIcon: Icon(Icons.search, size: isTablet ? 24 : 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
              ),
              style: TextStyle(fontSize: isTablet ? 16 : 14),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Indicador de filtro activo
          if (_filterEstado != null)
            Container(
              margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Chip(
                label: Text(
                  'Filtrado por: ${_getEstadoText(_filterEstado!)}',
                  style: TextStyle(fontSize: isTablet ? 14 : 12),
                ),
                deleteIcon: Icon(Icons.close, size: isTablet ? 20 : 18),
                onDeleted: () {
                  setState(() {
                    _filterEstado = null;
                  });
                },
              ),
            ),

          // Lista de préstamos
          Expanded(
            child: StreamBuilder<List<Prestamo>>(
              stream: FirebaseService.getPrestamos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: isTablet ? 80 : 64, color: Colors.red),
                        SizedBox(height: isTablet ? 20 : 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(fontSize: isTablet ? 16 : 14),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 24 : 20,
                              vertical: isTablet ? 16 : 12,
                            ),
                          ),
                          child: Text(
                            'Reintentar',
                            style: TextStyle(fontSize: isTablet ? 16 : 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                List<Prestamo> prestamos = snapshot.data ?? [];

                // Aplicar filtros
                if (_searchQuery.isNotEmpty) {
                  prestamos = prestamos.where((prestamo) {
                    return prestamo.nombreSolicitante.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (_filterEstado != null) {
                  prestamos = prestamos.where((prestamo) {
                    return prestamo.estado == _filterEstado;
                  }).toList();
                }

                if (prestamos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty || _filterEstado != null
                              ? Icons.search_off
                              : Icons.assignment_outlined,
                          size: isTablet ? 80 : 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterEstado != null
                              ? 'No se encontraron préstamos'
                              : 'No hay préstamos registrados',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isTablet ? 12 : 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Text(
                            _searchQuery.isNotEmpty || _filterEstado != null
                                ? 'Intenta con otros términos de búsqueda'
                                : 'Toca el botón + para crear tu primer préstamo',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: isTablet ? 16 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Layout adaptativo para la lista
                if (isTablet && prestamos.length > 3) {
                  return GridView.builder(
                    padding: EdgeInsets.all(horizontalPadding),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: prestamos.length,
                    itemBuilder: (context, index) {
                      final prestamo = prestamos[index];
                      return _buildPrestamoCard(prestamo, isGrid: true);
                    },
                  );
                } else {
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    itemCount: prestamos.length,
                    itemBuilder: (context, index) {
                      final prestamo = prestamos[index];
                      return _buildPrestamoCard(prestamo);
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrestamoFormScreen(),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        child: Icon(Icons.add, size: isTablet ? 28 : 24),
      ),
    );
  }

  // Método actualizado _buildPrestamoCard en PrestamosListScreen
  Widget _buildPrestamoCard(Prestamo prestamo, {bool isGrid = false}) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    Color estadoColor = _getEstadoColor(prestamo.estado);
    IconData estadoIcon = _getEstadoIcon(prestamo.estado);

    // Contar items con estado cambiado
    int itemsConCambioEstado = prestamo.items
        .where((item) => item.estadoCambio)
        .length;

    if (isGrid) {
      // Layout para grid (tablets)
      return Card(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrestamoDetailScreen(prestamo: prestamo),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con avatar y estado
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: estadoColor.withOpacity(0.2),
                          radius: 20,
                          child: Icon(
                            estadoIcon,
                            color: estadoColor,
                            size: 20,
                          ),
                        ),
                        // Indicador de items con estado cambiado
                        if (itemsConCambioEstado > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  itemsConCambioEstado.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prestamo.nombreSolicitante,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: estadoColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getEstadoText(prestamo.estado),
                              style: TextStyle(
                                color: estadoColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Información detallada
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rama Scout
                      Row(
                        children: [
                          Icon(Icons.nature_people, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              prestamo.ramaScout,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _getRamaColorFromString(prestamo.ramaScout),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              prestamo.ramaScout,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Items
                      Row(
                        children: [
                          Icon(Icons.inventory, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('${prestamo.items.length} items', style: const TextStyle(fontSize: 12)),
                          if (itemsConCambioEstado > 0) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.warning, size: 12, color: Colors.orange.shade600),
                            const SizedBox(width: 2),
                            Text(
                              '$itemsConCambioEstado',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Fecha
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Hasta: ${_formatDate(prestamo.fechaDevolucionEsperada)}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Días restantes
                      if (prestamo.estado == EstadoPrestamo.activo ||
                          prestamo.estado == EstadoPrestamo.parcial ||
                          prestamo.estado == EstadoPrestamo.vencido)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            prestamo.estaVencido ? 'Vencido' : '${prestamo.diasRestantes} días',
                            style: TextStyle(
                              color: prestamo.estaVencido ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Layout para lista (móviles y tablets)
      return Card(
        margin: EdgeInsets.only(bottom: isTablet ? 8 : 4),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 12 : 8,
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: estadoColor.withOpacity(0.2),
                radius: isTablet ? 24 : 20,
                child: Icon(
                  estadoIcon,
                  color: estadoColor,
                  size: isTablet ? 24 : 20,
                ),
              ),
              // Indicador de items con estado cambiado
              if (itemsConCambioEstado > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: isTablet ? 18 : 16,
                    height: isTablet ? 18 : 16,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        itemsConCambioEstado.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 11 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            prestamo.nombreSolicitante,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 18 : 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isTablet ? 4 : 2),
              // Rama Scout con badge de color
              Row(
                children: [
                  Icon(Icons.nature_people,
                      size: isTablet ? 18 : 16,
                      color: Colors.grey.shade600),
                  SizedBox(width: isTablet ? 6 : 4),
                  Text(
                    prestamo.ramaScout,
                    style: TextStyle(fontSize: isTablet ? 14 : 12),
                  ),
                  SizedBox(width: isTablet ? 10 : 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRamaColorFromString(prestamo.ramaScout),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      prestamo.ramaScout,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 11 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 4 : 2),
              Row(
                children: [
                  Icon(Icons.inventory,
                      size: isTablet ? 18 : 16,
                      color: Colors.grey.shade600),
                  SizedBox(width: isTablet ? 6 : 4),
                  Text(
                    '${prestamo.items.length} items',
                    style: TextStyle(fontSize: isTablet ? 14 : 12),
                  ),
                  if (itemsConCambioEstado > 0) ...[
                    SizedBox(width: isTablet ? 10 : 8),
                    Icon(Icons.warning,
                        size: isTablet ? 18 : 16,
                        color: Colors.orange.shade600),
                    SizedBox(width: isTablet ? 6 : 4),
                    Text(
                      '$itemsConCambioEstado con cambio',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: isTablet ? 13 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isTablet ? 4 : 2),
              Row(
                children: [
                  Icon(Icons.event,
                      size: isTablet ? 18 : 16,
                      color: Colors.grey.shade600),
                  SizedBox(width: isTablet ? 6 : 4),
                  Text(
                    'Hasta: ${_formatDate(prestamo.fechaDevolucionEsperada)}',
                    style: TextStyle(fontSize: isTablet ? 14 : 12),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 6 : 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getEstadoText(prestamo.estado),
                      style: TextStyle(
                        color: estadoColor,
                        fontSize: isTablet ? 13 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (itemsConCambioEstado > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera,
                              size: isTablet ? 12 : 10,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 2),
                          Text(
                            'FOTOS',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: isTablet ? 10 : 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (prestamo.estado == EstadoPrestamo.activo ||
                  prestamo.estado == EstadoPrestamo.parcial ||
                  prestamo.estado == EstadoPrestamo.vencido)
                Text(
                  prestamo.estaVencido ? 'Vencido' : '${prestamo.diasRestantes} días',
                  style: TextStyle(
                    color: prestamo.estaVencido ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 13 : 12,
                  ),
                ),
              Icon(Icons.chevron_right, size: isTablet ? 24 : 20),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrestamoDetailScreen(prestamo: prestamo),
              ),
            );
          },
        ),
      );
    }
  }

  // Método para obtener el color desde string (rama scout)
  Color _getRamaColorFromString(String ramaString) {
    switch (ramaString.toLowerCase()) {
      case 'lobatos':
        return Colors.yellow;
      case 'exploradores':
        return Colors.blue;
      case 'pioneros':
        return Colors.red;
      case 'rovers':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showFilterDialog() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Filtrar por estado',
            style: TextStyle(fontSize: isTablet ? 20 : 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: EstadoPrestamo.values.map((estado) {
              return RadioListTile<EstadoPrestamo>(
                title: Text(
                  _getEstadoText(estado),
                  style: TextStyle(fontSize: isTablet ? 16 : 14),
                ),
                value: estado,
                groupValue: _filterEstado,
                onChanged: (EstadoPrestamo? value) {
                  Navigator.of(context).pop();
                  setState(() {
                    _filterEstado = value;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ),
          ],
        );
      },
    );
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
        return 'Parcial';
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