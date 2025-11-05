import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/unidad_scout.dart';
import '../services/firebase_service.dart';
import 'add_edit_unidad_scout_screen.dart';

class UnidadesScoutScreen extends StatefulWidget {
  const UnidadesScoutScreen({super.key});

  @override
  State<UnidadesScoutScreen> createState() => _UnidadesScoutScreenState();
}

class _UnidadesScoutScreenState extends State<UnidadesScoutScreen> {
  String _searchQuery = '';
  RamaScout? _selectedRamaFilter;

  // Método para obtener si es tablet/desktop
  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768;
  }

  // Método para obtener si es móvil pequeño
  bool _isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  // Método para obtener número de columnas según el tamaño de pantalla
  int _getCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4;
    if (width >= 800) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  void _showDeleteDialog(UnidadScout unidad) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            double dialogWidth = _isLargeScreen(context) ? 400 : constraints.maxWidth * 0.9;

            return AlertDialog(
              contentPadding: EdgeInsets.all(_isSmallMobile(context) ? 16 : 24),
              title: Text(
                'Eliminar Unidad Scout',
                style: TextStyle(
                  fontSize: _isSmallMobile(context) ? 18 : 20,
                ),
              ),
              content: Container(
                width: dialogWidth,
                child: Text(
                  '¿Estás seguro que deseas eliminar la unidad "${unidad.nombreUnidad}"?',
                  style: TextStyle(
                    fontSize: _isSmallMobile(context) ? 14 : 16,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: _isSmallMobile(context) ? 14 : 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await FirebaseService.deleteUnidadScout(unidad.id!);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Unidad Scout eliminada exitosamente',
                              style: TextStyle(
                                fontSize: _isSmallMobile(context) ? 14 : 16,
                              ),
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            margin: EdgeInsets.all(_isSmallMobile(context) ? 8 : 16),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al eliminar: $e',
                              style: TextStyle(
                                fontSize: _isSmallMobile(context) ? 14 : 16,
                              ),
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            margin: EdgeInsets.all(_isSmallMobile(context) ? 8 : 16),
                          ),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: Text(
                    'Eliminar',
                    style: TextStyle(
                      fontSize: _isSmallMobile(context) ? 14 : 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToAddEdit({UnidadScout? unidad}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditUnidadScoutScreen(unidad: unidad),
      ),
    );
  }

  IconData _getRamaIcon(RamaScout rama) {
    switch (rama) {
      case RamaScout.lobatos:
        return Icons.child_care;
      case RamaScout.exploradores:
        return Icons.explore;
      case RamaScout.pioneros:
        return Icons.handyman;
      case RamaScout.rovers:
        return Icons.groups;
    }
  }

  Color _getRamaColor(RamaScout rama) {
    switch (rama) {
      case RamaScout.lobatos:
        return Colors.orangeAccent;
      case RamaScout.exploradores:
        return Colors.blue;
      case RamaScout.pioneros:
        return Colors.red;
      case RamaScout.rovers:
        return Colors.green;
    }
  }

  List<UnidadScout> _filterUnidades(List<UnidadScout> unidades) {
    List<UnidadScout> filtered = unidades;

    // Filtrar por rama si hay una seleccionada
    if (_selectedRamaFilter != null) {
      filtered = filtered.where((unidad) => unidad.ramaScout == _selectedRamaFilter).toList();
    }

    // Filtrar por búsqueda de texto
    if (_searchQuery.isEmpty) {
      return filtered;
    }

    String query = _searchQuery.toLowerCase();
    return filtered.where((unidad) {
      return unidad.nombreUnidad.toLowerCase().contains(query) ||
          unidad.responsableUnidad.toLowerCase().contains(query) ||
          unidad.telefono.contains(query) ||
          unidad.ramaScout.displayName.toLowerCase().contains(query);
    }).toList();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return LayoutBuilder(
              builder: (context, constraints) {
                double dialogWidth = _isLargeScreen(context) ? 450 : constraints.maxWidth * 0.9;

                return AlertDialog(
                  contentPadding: EdgeInsets.all(_isSmallMobile(context) ? 16 : 24),
                  title: Text(
                    'Filtrar por Rama Scout',
                    style: TextStyle(
                      fontSize: _isSmallMobile(context) ? 18 : 20,
                    ),
                  ),
                  content: Container(
                    width: dialogWidth,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: _isSmallMobile(context) ? 8 : 16,
                            ),
                            title: Text(
                              'Todas las ramas',
                              style: TextStyle(
                                fontSize: _isSmallMobile(context) ? 14 : 16,
                              ),
                            ),
                            leading: Radio<RamaScout?>(
                              value: null,
                              groupValue: _selectedRamaFilter,
                              onChanged: (RamaScout? value) {
                                setState(() {
                                  _selectedRamaFilter = value;
                                });
                              },
                            ),
                          ),
                          ...RamaScout.values.map((rama) {
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: _isSmallMobile(context) ? 8 : 16,
                              ),
                              title: Text(
                                rama.displayName,
                                style: TextStyle(
                                  fontSize: _isSmallMobile(context) ? 14 : 16,
                                ),
                              ),
                              leading: Radio<RamaScout?>(
                                value: rama,
                                groupValue: _selectedRamaFilter,
                                onChanged: (RamaScout? value) {
                                  setState(() {
                                    _selectedRamaFilter = value;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: _isSmallMobile(context) ? 14 : 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        this.setState(() {});
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Aplicar',
                        style: TextStyle(
                          fontSize: _isSmallMobile(context) ? 14 : 16,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGridView(List<UnidadScout> filteredUnidades) {
    return GridView.builder(
      padding: EdgeInsets.all(_isSmallMobile(context) ? 8 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        childAspectRatio: _isLargeScreen(context) ? 1.2 : 0.85,
        crossAxisSpacing: _isSmallMobile(context) ? 8 : 16,
        mainAxisSpacing: _isSmallMobile(context) ? 8 : 16,
      ),
      itemCount: filteredUnidades.length,
      itemBuilder: (context, index) {
        final unidad = filteredUnidades[index];
        return _buildUnidadCard(unidad, isGridView: true);
      },
    );
  }

  Widget _buildListView(List<UnidadScout> filteredUnidades) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: _isSmallMobile(context) ? 8 : 16,
        vertical: 8,
      ),
      itemCount: filteredUnidades.length,
      itemBuilder: (context, index) {
        final unidad = filteredUnidades[index];
        return _buildUnidadCard(unidad, isGridView: false);
      },
    );
  }

  Widget _buildUnidadCard(UnidadScout unidad, {required bool isGridView}) {
    double avatarRadius = _isSmallMobile(context) ? 20 : 25;
    double titleFontSize = _isSmallMobile(context) ? 14 : 16;
    double subtitleFontSize = _isSmallMobile(context) ? 12 : 14;

    if (isGridView) {
      return Card(
        elevation: 2,
        child: InkWell(
          onTap: () => _navigateToAddEdit(unidad: unidad),
          child: Padding(
            padding: EdgeInsets.all(_isSmallMobile(context) ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                unidad.imagenUnidad != null
                    ? CircleAvatar(
                  backgroundImage: MemoryImage(
                    Uri.parse(unidad.imagenUnidad!).data!.contentAsBytes(),
                  ),
                  radius: avatarRadius + 5,
                )
                    : CircleAvatar(
                  backgroundColor: _getRamaColor(unidad.ramaScout),
                  radius: avatarRadius + 5,
                  child: Icon(
                    _getRamaIcon(unidad.ramaScout),
                    color: Colors.white,
                    size: _isSmallMobile(context) ? 20 : 24,
                  ),
                ),
                SizedBox(height: _isSmallMobile(context) ? 6 : 8),

                // Título
                Text(
                  unidad.nombreUnidad,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: _isSmallMobile(context) ? 4 : 6),

                // Rama Scout
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        unidad.ramaScout.displayName,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w500,
                          color: _getRamaColor(unidad.ramaScout),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isSmallMobile(context) ? 2 : 4),

                // Responsable
                Text(
                  'Resp: ${unidad.responsableUnidad}',
                  style: TextStyle(fontSize: subtitleFontSize - 1),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Teléfono
                Text(
                  unidad.telefono,
                  style: TextStyle(fontSize: subtitleFontSize - 1),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // Menú de acciones
                PopupMenuButton(
                  iconSize: _isSmallMobile(context) ? 16 : 20,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _navigateToAddEdit(unidad: unidad);
                        break;
                      case 'delete':
                        _showDeleteDialog(unidad);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: _isSmallMobile(context) ? 16 : 20),
                          title: Text(
                            'Editar',
                            style: TextStyle(
                              fontSize: _isSmallMobile(context) ? 14 : 16,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: _isSmallMobile(context) ? 16 : 20,
                          ),
                          title: Text(
                            'Eliminar',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: _isSmallMobile(context) ? 14 : 16,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Vista de lista
      return Card(
        margin: EdgeInsets.only(bottom: _isSmallMobile(context) ? 6 : 8),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isSmallMobile(context) ? 12 : 16,
            vertical: _isSmallMobile(context) ? 4 : 8,
          ),
          leading: unidad.imagenUnidad != null
              ? CircleAvatar(
            backgroundImage: MemoryImage(
              Uri.parse(unidad.imagenUnidad!).data!.contentAsBytes(),
            ),
            radius: avatarRadius,
          )
              : CircleAvatar(
            backgroundColor: _getRamaColor(unidad.ramaScout),
            radius: avatarRadius,
            child: Icon(
              _getRamaIcon(unidad.ramaScout),
              color: Colors.white,
              size: _isSmallMobile(context) ? 20 : 24,
            ),
          ),
          title: Text(
            unidad.nombreUnidad,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      unidad.ramaScout.displayName,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w500,
                        color: _getRamaColor(unidad.ramaScout),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                'Responsable: ${unidad.responsableUnidad}',
                style: TextStyle(fontSize: subtitleFontSize),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Teléfono: ${unidad.telefono}',
                style: TextStyle(fontSize: subtitleFontSize),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: PopupMenuButton(
            iconSize: _isSmallMobile(context) ? 16 : 20,
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _navigateToAddEdit(unidad: unidad);
                  break;
                case 'delete':
                  _showDeleteDialog(unidad);
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, size: _isSmallMobile(context) ? 16 : 20),
                    title: Text(
                      'Editar',
                      style: TextStyle(
                        fontSize: _isSmallMobile(context) ? 14 : 16,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: _isSmallMobile(context) ? 16 : 20,
                    ),
                    title: Text(
                      'Eliminar',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: _isSmallMobile(context) ? 14 : 16,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
          ),
          isThreeLine: true,
          onTap: () => _navigateToAddEdit(unidad: unidad),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        title: Text(
          'Unidades Scout',
          style: TextStyle(
            fontSize: _isSmallMobile(context) ? 20 : 24,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _selectedRamaFilter != null ? Colors.yellow : Colors.white,
              size: _isSmallMobile(context) ? 20 : 24,
            ),
            onPressed: _showFilterDialog,
          ),
          // Botón para cambiar vista en tablets/desktop
          if (_isLargeScreen(context))
            IconButton(
              icon: Icon(
                Icons.view_module,
                color: Colors.white,
                size: _isSmallMobile(context) ? 20 : 24,
              ),
              onPressed: () {
                // Aquí podrías implementar cambio de vista si lo deseas
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: EdgeInsets.all(_isSmallMobile(context) ? 12 : 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar unidades scout...',
                hintStyle: TextStyle(
                  fontSize: _isSmallMobile(context) ? 14 : 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: _isSmallMobile(context) ? 20 : 24,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: _isSmallMobile(context) ? 20 : 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _isSmallMobile(context) ? 12 : 16,
                  vertical: _isSmallMobile(context) ? 8 : 12,
                ),
              ),
              style: TextStyle(
                fontSize: _isSmallMobile(context) ? 14 : 16,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Chip de filtro activo
          if (_selectedRamaFilter != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isSmallMobile(context) ? 12 : 16,
              ),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      'Filtro: ${_selectedRamaFilter!.displayName}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _isSmallMobile(context) ? 12 : 14,
                      ),
                    ),
                    backgroundColor: _getRamaColor(_selectedRamaFilter!),
                    deleteIcon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: _isSmallMobile(context) ? 14 : 16,
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedRamaFilter = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          // Lista de unidades
          Expanded(
            child: StreamBuilder<List<UnidadScout>>(
              stream: FirebaseService.getUnidadesScout(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(_isSmallMobile(context) ? 16 : 24),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(
                          fontSize: _isSmallMobile(context) ? 14 : 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: _isSmallMobile(context) ? 3 : 4,
                    ),
                  );
                }

                final unidades = snapshot.data ?? [];
                final filteredUnidades = _filterUnidades(unidades);

                if (filteredUnidades.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(_isSmallMobile(context) ? 16 : 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FontAwesomeIcons.users,
                            size: _isSmallMobile(context) ? 48 : 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: _isSmallMobile(context) ? 12 : 16),
                          Text(
                            _searchQuery.isEmpty && _selectedRamaFilter == null
                                ? 'No hay unidades scout registradas'
                                : 'No se encontraron unidades que coincidan con los filtros aplicados',
                            style: TextStyle(
                              fontSize: _isSmallMobile(context) ? 16 : 18,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchQuery.isEmpty && _selectedRamaFilter == null) ...[
                            SizedBox(height: _isSmallMobile(context) ? 12 : 16),
                            ElevatedButton.icon(
                              onPressed: () => _navigateToAddEdit(),
                              icon: Icon(
                                Icons.add,
                                size: _isSmallMobile(context) ? 18 : 20,
                              ),
                              label: Text(
                                'Agregar primera unidad',
                                style: TextStyle(
                                  fontSize: _isSmallMobile(context) ? 14 : 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: _isSmallMobile(context) ? 16 : 20,
                                  vertical: _isSmallMobile(context) ? 8 : 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                // Usar grid view en pantallas grandes, list view en móviles
                return _isLargeScreen(context)
                    ? _buildGridView(filteredUnidades)
                    : _buildListView(filteredUnidades);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: _isSmallMobile(context) ? 20 : 24,
        ),
      ),
    );
  }
}