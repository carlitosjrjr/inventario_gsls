import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/item.dart';
import '../services/firebase_service.dart';

class ItemsCambioEstadoScreen extends StatefulWidget {
  const ItemsCambioEstadoScreen({Key? key}) : super(key: key);

  @override
  State<ItemsCambioEstadoScreen> createState() => _ItemsCambioEstadoScreenState();
}

class _ItemsCambioEstadoScreenState extends State<ItemsCambioEstadoScreen> {
  String _searchQuery = '';
  EstadoItem? _filterEstado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: const Text('Items por Cambio de Estado'),
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
              const PopupMenuItem<String>(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_list),
                    SizedBox(width: 8),
                    Text('Filtrar por estado'),
                  ],
                ),
              ),
              if (_filterEstado != null)
                const PopupMenuItem<String>(
                  value: 'clear_filter',
                  child: Row(
                    children: [
                      Icon(Icons.clear),
                      SizedBox(width: 8),
                      Text('Limpiar filtro'),
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
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Información explicativa
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estos items se crearon automáticamente cuando su estado cambió durante una devolución.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Indicador de filtro activo
          if (_filterEstado != null) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                label: Text('Filtrado por: ${_filterEstado!.displayName}'),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () {
                  setState(() {
                    _filterEstado = null;
                  });
                },
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Lista de items
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: FirebaseService.getItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                List<Item> allItems = snapshot.data ?? [];

                // Filtrar solo items creados por cambio de estado (buscar por sufijos en el nombre)
                List<Item> itemsCambioEstado = allItems.where((item) {
                  return item.nombre.contains('(Restaurado)') ||
                      item.nombre.contains('(Usado)') ||
                      item.nombre.contains('(Dañado)') ||
                      item.nombre.contains('(Recuperado)');
                }).toList();

                // Aplicar filtros adicionales
                if (_searchQuery.isNotEmpty) {
                  itemsCambioEstado = itemsCambioEstado.where((item) {
                    return item.nombre.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (_filterEstado != null) {
                  itemsCambioEstado = itemsCambioEstado.where((item) {
                    return item.estado == _filterEstado;
                  }).toList();
                }

                if (itemsCambioEstado.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty || _filterEstado != null
                              ? Icons.search_off
                              : Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterEstado != null
                              ? 'No se encontraron items'
                              : 'No hay items creados por cambio de estado',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _filterEstado != null
                              ? 'Intenta con otros filtros'
                              : 'Los items aparecerán aquí cuando se devuelvan con estado cambiado',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: itemsCambioEstado.length,
                  itemBuilder: (context, index) {
                    final item = itemsCambioEstado[index];
                    return _buildItemCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
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
                    size: 24, color: Colors.grey.shade400);
              },
            ),
          )
              : Icon(Icons.inventory,
              size: 24, color: Colors.grey.shade400),
        ),
        title: Text(
          item.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Cantidad: ${item.cantidad}'),
            const SizedBox(height: 2),
            Text(
              'Creado: ${_formatDate(item.fechaCreacion)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getEstadoColor(item.estado),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.estado.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                      Icon(Icons.photo_camera, size: 10, color: Colors.orange.shade700),
                      const SizedBox(width: 2),
                      Text(
                        'CAMBIO ESTADO',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 9,
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showItemDetail(item);
        },
      ),
    );
  }

  void _showItemDetail(Item item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item.nombre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imagenUrl != null && item.imagenUrl!.isNotEmpty)
                Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _decodeBase64Image(item.imagenUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.inventory,
                              size: 50, color: Colors.grey.shade400);
                        },
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('Cantidad', item.cantidad.toString()),
              _buildDetailRow('Estado', item.estado.displayName),
              _buildDetailRow('Creado', _formatDate(item.fechaCreacion)),
              _buildDetailRow('Actualizado', _formatDate(item.fechaActualizacion)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filtrar por estado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: EstadoItem.values.map((estado) {
              return RadioListTile<EstadoItem>(
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getEstadoColor(estado),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(estado.displayName),
                  ],
                ),
                value: estado,
                groupValue: _filterEstado,
                onChanged: (EstadoItem? value) {
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
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Uint8List _decodeBase64Image(String base64String) {
    try {
      String base64Data = base64String;
      if (base64String.contains(',')) {
        base64Data = base64String.split(',')[1];
      }
      return Uint8List.fromList(base64.decode(base64Data));
    } catch (e) {
      throw Exception('Error al decodificar imagen: $e');
    }
  }

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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}