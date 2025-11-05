import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/item.dart';
import '../models/ubicacion.dart';
import '../models/tipo_item.dart';
import '../services/firebase_service.dart';
import '../widgets/base64_image_widget.dart';
import 'tipos_item_screen.dart';

class ItemFormScreen extends StatefulWidget {
  final Item? item;

  const ItemFormScreen({Key? key, this.item}) : super(key: key);

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();

  Ubicacion? _selectedUbicacion;
  List<Ubicacion> _ubicaciones = [];
  TipoItemPersonalizado? _selectedTipo;
  List<TipoItemPersonalizado> _tiposDisponibles = [];
  EstadoItem _selectedEstado = EstadoItem.excelente;
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _isEditMode = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.item != null;

    if (_isEditMode) {
      _nombreController.text = widget.item!.nombre;
      _cantidadController.text = widget.item!.cantidad.toString();
      _selectedEstado = widget.item!.estado;
      _currentImageUrl = widget.item!.imagenUrl;
    }

    _loadUbicaciones();
    _loadTipos();
  }

  void _loadUbicaciones() async {
    FirebaseService.getUbicaciones().listen((ubicaciones) {
      setState(() {
        _ubicaciones = ubicaciones;

        if (_isEditMode && _selectedUbicacion == null && _ubicaciones.isNotEmpty) {
          try {
            _selectedUbicacion = _ubicaciones.firstWhere(
                  (u) => u.id == widget.item!.ubicacionId,
            );
          } catch (e) {
            // Si no encuentra la ubicación, selecciona la primera disponible
            _selectedUbicacion = _ubicaciones.first;
          }
        }
      });
    });
  }

  void _loadTipos() async {
    FirebaseService.getTiposItem().listen((tipos) {
      setState(() {
        _tiposDisponibles = tipos;

        if (_isEditMode && _selectedTipo == null && _tiposDisponibles.isNotEmpty) {
          if (widget.item!.tipoId != null) {
            // Buscar por ID del tipo personalizado
            try {
              _selectedTipo = _tiposDisponibles.firstWhere(
                    (t) => t.id == widget.item!.tipoId,
              );
            } catch (e) {
              // Si no encuentra el tipo, no seleccionar ninguno
              _selectedTipo = null;
            }
          } else if (widget.item!.tipo != null) {
            // Migración: buscar por nombre del enum antiguo
            try {
              _selectedTipo = _tiposDisponibles.firstWhere(
                    (t) => t.nombre == widget.item!.tipo!.displayName,
              );
            } catch (e) {
              // Si no encuentra el tipo, no seleccionar ninguno
              _selectedTipo = null;
            }
          }
        }
      });
    });
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir la cámara: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir la galería: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
          title: const Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
              // Solo mostrar opción de eliminar si está en modo edición
              if (_isEditMode && (_selectedImage != null || _currentImageUrl != null))
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Eliminar imagen'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImage = null;
                      _currentImageUrl = null;
                    });
                  },
                ),
            ],
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

  // Función para validar si tiene imagen
  bool _hasImage() {
    return _selectedImage != null || (_isEditMode && _currentImageUrl != null);
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Imagen del Item',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Indicador de campo obligatorio solo en modo creación
                if (!_isEditMode)
                  const Text(
                    ' *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                    width: !_isEditMode && !_hasImage() ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                )
                    : _currentImageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Base64ImageWidget(
                    base64String: _currentImageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: 50,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca para agregar imagen',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    if (!_isEditMode)
                      Text(
                        'Campo obligatorio',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Mensaje de error si no hay imagen en modo creación
            if (!_isEditMode && !_hasImage())
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'La imagen es obligatoria para crear un item',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoDropdown() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<TipoItemPersonalizado>(
            value: _selectedTipo,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              labelStyle: TextStyle(color: Colors.black),
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: [
              const DropdownMenuItem<TipoItemPersonalizado>(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Sin categoría', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              ..._tiposDisponibles.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Row(
                    children: [
                      const Icon(Icons.category, size: 16, color: Color.fromRGBO(59, 122, 201, 1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tipo.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            onChanged: (TipoItemPersonalizado? value) {
              setState(() {
                _selectedTipo = value;
              });
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TiposItemScreen(),
              ),
            );
            // Recargar tipos después de volver de la pantalla de gestión
            _loadTipos();
          },
          icon: const Icon(Icons.settings),
          tooltip: 'Gestionar categorías',
        ),
      ],
    );
  }

  Future<void> _saveItem() async {
    // Validar formulario
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar ubicación seleccionada
    if (_selectedUbicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una ubicación'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar imagen obligatoria solo en modo creación
    if (!_isEditMode && !_hasImage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La imagen es obligatoria para crear un item'),
          backgroundColor: Colors.red,
        ),
      );

      // Hacer scroll hacia arriba para mostrar la sección de imagen
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      return;
    }

    setState(() => _isLoading = true);

    try {
      final item = Item(
        id: _isEditMode ? widget.item!.id : null,
        nombre: _nombreController.text.trim(),
        cantidad: int.parse(_cantidadController.text),
        ubicacionId: _selectedUbicacion!.id!,
        tipoId: _selectedTipo?.id, // Puede ser null
        estado: _selectedEstado,
        imagenUrl: _currentImageUrl,
      );

      if (_isEditMode) {
        await FirebaseService.updateItem(widget.item!.id!, item, imageFile: _selectedImage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item actualizado exitosamente'),
              backgroundColor: Color.fromRGBO(59, 122, 201, 1),
            ),
          );
        }
      } else {
        await FirebaseService.createItem(item, imageFile: _selectedImage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item creado exitosamente'),
              backgroundColor: Color.fromRGBO(59, 122, 201, 1),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Item' : 'Nuevo Item'),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        actions: [
          if (_isEditMode)
            IconButton(
              onPressed: _showDeleteConfirmation,
              icon: const Icon(Icons.delete),
              tooltip: 'Eliminar item',
            ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Center(
              child: Container(
                width: 600,
                padding: const EdgeInsets.all(24),
                child: _buildForm(),
              ),
            );
          } else {
            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: _buildForm(),
            );
          }
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen del item
          _buildImageSection(),
          const SizedBox(height: 16),

          // Formulario principal
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Item *',
                      labelStyle: TextStyle(color: Colors.black),
                      hintText: 'Ej: Cuerdas, Pasadores',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el nombre del Item';
                      }
                      if (value.trim().length < 2) {
                        return 'El nombre debe tener al menos 2 caracteres';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Fila con cantidad y categoría
                  TextFormField(
                    controller: _cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad *',
                      labelStyle: TextStyle(color: Colors.black),
                      hintText: 'Ej: 15',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la cantidad';
                      }
                      if (int.tryParse(value) == null || int.parse(value) < 0) {
                        return 'Cantidad inválida';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  _buildTipoDropdown(),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<EstadoItem>(
                    value: _selectedEstado,
                    decoration: const InputDecoration(
                      labelText: 'Estado *',
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.health_and_safety),
                    ),
                    items: EstadoItem.values.map((estado) {
                      return DropdownMenuItem(
                        value: estado,
                        child: Row(
                          children: [
                            _getEstadoIcon(estado),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                estado.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (EstadoItem? value) {
                      setState(() {
                        _selectedEstado = value ?? EstadoItem.excelente;
                      });
                    },
                    isExpanded: true,
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<Ubicacion>(
                    value: _selectedUbicacion,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación *',
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    items: _ubicaciones.map((ubicacion) {
                      return DropdownMenuItem(
                        value: ubicacion,
                        child: Text(
                          ubicacion.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (Ubicacion? value) {
                      setState(() {
                        _selectedUbicacion = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Por favor selecciona una ubicación';
                      }
                      return null;
                    },
                    isExpanded: true,
                  ),
                ],
              ),
            ),
          ),

          if (_ubicaciones.isEmpty)
            const SizedBox(height: 16),

          if (_ubicaciones.isEmpty)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'No hay ubicaciones disponibles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Necesitas crear al menos una ubicación antes de agregar items',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ],
                ),
              ),
            ),

          if (_tiposDisponibles.isEmpty)
            const SizedBox(height: 16),

          if (_tiposDisponibles.isEmpty)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.category, color: Colors.blue, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'No hay categorías disponibles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Puedes crear categorías para organizar mejor tus items',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TiposItemScreen(),
                          ),
                        );
                        _loadTipos();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Crear Categorías'),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_ubicaciones.isEmpty || _isLoading)
                      ? null
                      : _saveItem,
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
                      : Text(_isEditMode ? 'Actualizar Item' : 'Guardar Item'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getEstadoIcon(EstadoItem estado) {
    switch (estado) {
      case EstadoItem.excelente:
        return const Icon(Icons.star, color: Colors.green, size: 20);
      case EstadoItem.bueno:
        return const Icon(Icons.thumb_up, color: Colors.blue, size: 20);
      case EstadoItem.malo:
        return const Icon(Icons.warning, color: Colors.orange, size: 20);
      case EstadoItem.perdida:
        return const Icon(Icons.error, color: Colors.red, size: 20);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que deseas eliminar "${widget.item!.nombre}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isLoading = true);

                try {
                  await FirebaseService.deleteItem(widget.item!.id!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item eliminado exitosamente'),
                        backgroundColor: Color.fromRGBO(59, 122, 201, 1),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cantidadController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}