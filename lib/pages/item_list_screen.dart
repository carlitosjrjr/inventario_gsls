import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/ubicacion.dart';
import '../models/tipo_item.dart';
import '../services/firebase_service.dart';
import '../widgets/base64_image_widget.dart';
import 'item_form_screen.dart';
import 'tipos_item_screen.dart';

class ItemsListScreen extends StatefulWidget {
  const ItemsListScreen({Key? key}) : super(key: key);

  @override
  State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  String _searchQuery = '';
  String? _filterUbicacionId;
  String? _filterTipoId;
  EstadoItem? _filterEstado;

  List<TipoItemPersonalizado> _tiposDisponibles = [];
  Map<String, TipoItemPersonalizado> _tiposCache = {};

  @override
  void initState() {
    super.initState();
    _loadTipos();
  }

  void _loadTipos() {
    FirebaseService.getTiposItem().listen((tipos) {
      setState(() {
        _tiposDisponibles = tipos;
        _tiposCache = {for (var tipo in tipos) tipo.id!: tipo};
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            color: const Color.fromRGBO(232, 238, 242, 1),
            onSelected: (value) {
              switch (value) {
                case 'filter_ubicacion':
                  _showUbicacionFilterDialog();
                  break;
                case 'filter_tipo':
                  _showTipoFilterDialog();
                  break;
                case 'filter_estado':
                  _showEstadoFilterDialog();
                  break;
                case 'clear_filters':
                  setState(() {
                    _filterUbicacionId = null;
                    _filterTipoId = null;
                    _filterEstado = null;
                  });
                  break;
                case 'manage_types':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TiposItemScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'filter_ubicacion',
                child: Row(
                  children: [
                    Icon(Icons.location_on),
                    SizedBox(width: 8),
                    Text('Filtrar por ubicación'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'filter_tipo',
                child: Row(
                  children: [
                    Icon(Icons.category),
                    SizedBox(width: 8),
                    Text('Filtrar por categoría'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'filter_estado',
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety),
                    SizedBox(width: 8),
                    Text('Filtrar por estado'),
                  ],
                ),
              ),
              if (_hasActiveFilters())
                const PopupMenuItem<String>(
                  value: 'clear_filters',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all),
                      SizedBox(width: 8),
                      Text('Limpiar filtros'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'manage_types',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Gestionar categorías'),
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

          // Indicadores de filtros activos
          if (_hasActiveFilters())
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_filterUbicacionId != null)
                    FutureBuilder<Ubicacion?>(
                      future: FirebaseService.getUbicacionById(_filterUbicacionId!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text('📍 ${snapshot.data!.nombre}'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _filterUbicacionId = null;
                                });
                              },
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  if (_filterTipoId != null && _tiposCache.containsKey(_filterTipoId))
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.category, size: 16, color: Color.fromRGBO(59, 122, 201, 1)),
                            const SizedBox(width: 4),
                            Text(_tiposCache[_filterTipoId]!.nombre),
                          ],
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _filterTipoId = null;
                          });
                        },
                      ),
                    ),
                  if (_filterEstado != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _getEstadoIcon(_filterEstado!),
                            const SizedBox(width: 4),
                            Text(_filterEstado!.displayName),
                          ],
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _filterEstado = null;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

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

                List<Item> items = snapshot.data ?? [];

                // Aplicar filtros
                items = _applyFilters(items);

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _hasActiveFilters() || _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _hasActiveFilters() || _searchQuery.isNotEmpty
                              ? 'No se encontraron items'
                              : 'No hay items registrados',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasActiveFilters() || _searchQuery.isNotEmpty
                              ? 'Intenta con otros términos de búsqueda o filtros'
                              : 'Toca el botón + para agregar tu primer item',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildItemCard(item);
                  },
                );
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
              builder: (context) => const ItemFormScreen(),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _filterUbicacionId != null || _filterTipoId != null || _filterEstado != null;
  }

  List<Item> _applyFilters(List<Item> items) {
    List<Item> filteredItems = items;

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        return item.nombre.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Filtrar por ubicación
    if (_filterUbicacionId != null) {
      filteredItems = filteredItems.where((item) {
        return item.ubicacionId == _filterUbicacionId;
      }).toList();
    }

    // Filtrar por tipo
    if (_filterTipoId != null) {
      filteredItems = filteredItems.where((item) {
        // Comparar con el ID del tipo personalizado
        if (item.tipoId != null) {
          return item.tipoId == _filterTipoId;
        }
        // Compatibilidad con enum antiguo
        else if (item.tipo != null) {
          TipoItemPersonalizado? tipo = _tiposDisponibles.cast<TipoItemPersonalizado?>().firstWhere(
                (t) => t?.nombre == item.tipo!.displayName,
            orElse: () => null,
          );
          return tipo?.id == _filterTipoId;
        }
        return false;
      }).toList();
    }

    // Filtrar por estado
    if (_filterEstado != null) {
      filteredItems = filteredItems.where((item) {
        return item.estado == _filterEstado;
      }).toList();
    }

    return filteredItems;
  }

  Widget _buildItemCard(Item item) {
    // Obtener el tipo del item
    TipoItemPersonalizado? tipo;
    if (item.tipoId != null && _tiposCache.containsKey(item.tipoId)) {
      tipo = _tiposCache[item.tipoId];
    } else if (item.tipo != null) {
      // Compatibilidad con enum antiguo
      tipo = _tiposDisponibles.cast<TipoItemPersonalizado?>().firstWhere(
            (t) => t?.nombre == item.tipo!.displayName,
        orElse: () => null,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: item.imagenUrl != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Base64ImageWidget(
            base64String: item.imagenUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorWidget: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.broken_image,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        )
            : Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.cantidad.toString(),
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'unid.',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 14),
              ),
            ),
          ],
        ),
        subtitle: FutureBuilder<Ubicacion?>(
          future: FirebaseService.getUbicacionById(item.ubicacionId),
          builder: (context, snapshot) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      snapshot.hasData ? snapshot.data!.nombre : 'Cargando...',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (tipo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(59, 122, 201, 1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromRGBO(59, 122, 201, 1).withOpacity(0.3)),
                    ),
                    child: Text(
                      tipo.nombre,
                      style: const TextStyle(
                        color: Color.fromRGBO(59, 122, 201, 1),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Sin categoría',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    _getEstadoIcon(item.estado),

                    const SizedBox(width: 4),
                    Text(
                      item.estado.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getEstadoColor(item.estado),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Actualizado: ${_formatDate(item.fechaActualizacion)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            );
          },
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemFormScreen(item: item),
                ),
              );
            } else if (value == 'delete') {
              _showDeleteConfirmation(item);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemFormScreen(item: item),
            ),
          );
        },
      ),
    );
  }

  Widget _getEstadoIcon(EstadoItem estado) {
    switch (estado) {
      case EstadoItem.excelente:
        return const Icon(Icons.star, color: Colors.green, size: 16);
      case EstadoItem.bueno:
        return const Icon(Icons.thumb_up, color: Colors.blue, size: 16);
      case EstadoItem.malo:
        return const Icon(Icons.warning, color: Colors.orange, size: 16);
      case EstadoItem.perdida:
        return const Icon(Icons.error, color: Colors.red, size: 16);
    }
  }

  Color _getEstadoColor(EstadoItem estado) {
    switch (estado) {
      case EstadoItem.excelente:
        return Colors.green;
      case EstadoItem.bueno:
        return Colors.blue;
      case EstadoItem.malo:
        return Colors.orange;
      case EstadoItem.perdida:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDeleteConfirmation(Item item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que deseas eliminar "${item.nombre}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseService.deleteItem(item.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.nombre} eliminado')),
                );
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showUbicacionFilterDialog() async {
    List<Ubicacion> ubicaciones = await FirebaseService.getUbicaciones().first;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
          title: const Text('Filtrar por ubicación',style: TextStyle(fontSize: 18),textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ubicaciones.map((ubicacion) {
              return RadioListTile<String>(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0,vertical: -10),
                dense: true,
                title: Text(ubicacion.nombre,style: const TextStyle(fontSize: 14)),
                value: ubicacion.id!,
                groupValue: _filterUbicacionId,
                onChanged: (String? value) {
                  Navigator.of(context).pop();
                  setState(() {
                    _filterUbicacionId = value;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showTipoFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
          title: const Text('Filtrar por categoría',style: TextStyle(fontSize: 18),textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _tiposDisponibles.map((tipo) {
              return RadioListTile<String>(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0,vertical: -10),
                dense: true,
                title: Text(tipo.nombre,style: const TextStyle(fontSize: 14)),
                value: tipo.id!,
                groupValue: _filterTipoId,
                onChanged: (String? value) {
                  Navigator.of(context).pop();
                  setState(() {
                    _filterTipoId = value;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showEstadoFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
          title: const Text('Filtrar por estado',style: TextStyle(fontSize: 18),textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: EstadoItem.values.map((estado) {
              return RadioListTile<EstadoItem>(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0,vertical: -10),
                dense: true,
                title: Row(
                  children: [
                    _getEstadoIcon(estado),
                    const SizedBox(width: 3),
                    Text(estado.displayName,style: const TextStyle(fontSize: 14)),
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
              child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }
}