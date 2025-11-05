import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/unidad_scout.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../main.dart';

class AddEditUnidadScoutScreen extends StatefulWidget {
  final UnidadScout? unidad;

  const AddEditUnidadScoutScreen({super.key, this.unidad});

  @override
  State<AddEditUnidadScoutScreen> createState() => _AddEditUnidadScoutScreenState();
}

class _AddEditUnidadScoutScreenState extends State<AddEditUnidadScoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _responsableController = TextEditingController();
  final _telefonoController = TextEditingController();

  File? _imageFile;
  String? _currentImageUrl;
  bool _isLoading = false;
  RamaScout _selectedRama = RamaScout.lobatos;

  bool get _isEditing => widget.unidad != null;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();

    if (_isEditing) {
      _nombreController.text = widget.unidad!.nombreUnidad;
      _responsableController.text = widget.unidad!.responsableUnidad;
      _telefonoController.text = widget.unidad!.telefono;
      _selectedRama = widget.unidad!.ramaScout;
      _currentImageUrl = widget.unidad!.imagenUnidad;
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      // Pasar la clave del navegador si está disponible
      await NotificationService.initialize(navKey: MyApp.navigatorKey);
      bool hasPermission = await NotificationService.requestPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Los permisos de notificación son necesarios para los recordatorios'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error al inicializar notificaciones: $e');
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _responsableController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _imageFile = null;
      _currentImageUrl = null;
    });
  }

  Widget _buildRamaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rama Scout *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<RamaScout>(
              value: _selectedRama,
              isExpanded: true,
              onChanged: (RamaScout? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedRama = newValue;
                  });
                }
              },
              items: RamaScout.values.map((RamaScout rama) {
                return DropdownMenuItem<RamaScout>(
                  value: rama,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(rama.displayName),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Color _getRamaColor(RamaScout rama) {
    switch (rama) {
      case RamaScout.lobatos:
        return Colors.yellow;
      case RamaScout.exploradores:
        return Colors.blue;
      case RamaScout.pioneros:
        return Colors.red;
      case RamaScout.rovers:
        return Colors.green;
    }
  }

  Widget _buildImageSection() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final imageHeight = isTablet ? 250.0 : 200.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imagen de la Unidad',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (!_isEditing && _imageFile == null && _currentImageUrl == null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_outlined, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Se programará notificación',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: imageHeight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _imageFile != null
              ? Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _imageFile!,
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: _removeImage,
                  ),
                ),
              ),
            ],
          )
              : _currentImageUrl != null
              ? Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  Uri.parse(_currentImageUrl!).data!.contentAsBytes(),
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: _removeImage,
                  ),
                ),
              ),
            ],
          )
              : InkWell(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: imageHeight,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: isTablet ? 56 : 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Toca para agregar imagen',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: isTablet ? 18 : 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Sin imagen se programará una notificación',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: isTablet ? 14 : 12,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_imageFile != null || _currentImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit, size: 15),
                  label: const Text('Cambiar imagen', style: TextStyle(fontSize: 14)),
                ),
                TextButton.icon(
                  onPressed: _removeImage,
                  icon: const Icon(Icons.delete, color: Colors.red, size: 15),
                  label: const Text('Eliminar imagen', style: TextStyle(color: Colors.red, fontSize: 14)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _saveUnidad() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final unidad = UnidadScout(
        id: _isEditing ? widget.unidad!.id : null,
        nombreUnidad: _nombreController.text.trim(),
        responsableUnidad: _responsableController.text.trim(),
        telefono: _telefonoController.text.trim(),
        ramaScout: _selectedRama,
        imagenUnidad: _currentImageUrl,
      );

      if (_isEditing) {
        await FirebaseService.updateUnidadScout(
          widget.unidad!.id!,
          unidad,
          imageFile: _imageFile,
        );
      } else {
        // Validar que no exista una unidad con el mismo nombre
        bool isNameAvailable = await FirebaseService.isUnidadScoutNameAvailable(
          _nombreController.text.trim(),
        );

        if (!isNameAvailable) {
          throw Exception('Ya existe una unidad con un nombre similar');
        }

        await FirebaseService.createUnidadScout(unidad, imageFile: _imageFile);

        // Mostrar mensaje especial si no se agregó imagen
        if (_imageFile == null && _currentImageUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unidad creada. Se ha programado una notificación para recordarte agregar imagen en 25 días.',
                  textAlign: TextAlign.center,
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        if (!(_imageFile == null && _currentImageUrl == null && !_isEditing)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Unidad Scout actualizada exitosamente'
                  : 'Unidad Scout creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final horizontalPadding = isTablet ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        title: Text(
          _isEditing ? 'Editar Unidad Scout' : 'Nueva Unidad Scout',
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(horizontalPadding),
          children: [
            // Layout adaptativo para tablets
            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Columna izquierda - Información general
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: _buildInfoSection(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Columna derecha - Imagen
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: _buildImageSection(),
                          ),
                        ),
                        if (!_isEditing && _imageFile == null && _currentImageUrl == null)
                          _buildNotificationCard(),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              // Layout para móviles (original)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildInfoSection(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildImageSection(),
                ),
              ),
              if (!_isEditing && _imageFile == null && _currentImageUrl == null) ...[
                const SizedBox(height: 16),
                _buildNotificationCard(),
              ],
            ],
            const SizedBox(height: 24),
            _buildActionButtons(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información General',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la Unidad *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.group),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre de la unidad es obligatorio';
            }
            if (value.trim().length < 2) {
              return 'El nombre debe tener al menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _responsableController,
          decoration: const InputDecoration(
            labelText: 'Responsable de la Unidad *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El responsable es obligatorio';
            }
            if (value.trim().length < 2) {
              return 'El nombre del responsable debe tener al menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _telefonoController,
          decoration: const InputDecoration(
            labelText: 'Teléfono *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El teléfono es obligatorio';
            }
            if (value.trim().length < 8) {
              return 'El teléfono debe tener al menos 8 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildRamaSelector(),
      ],
    );
  }

  Widget _buildNotificationCard() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.notifications_outlined, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificación automática',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Si no agregas una imagen ahora, recibirás una notificación en 25 días para recordarte completar esta información.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 400) {
          // Botones en fila para pantallas más anchas
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveUnidad,
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
                    _isEditing ? 'Actualizar' : 'Guardar',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
              ),
            ],
          );
        } else {
          // Botones en columna para pantallas estrechas
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancelar'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveUnidad,
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
                    : Text(_isEditing ? 'Actualizar' : 'Guardar'),
              ),
            ],
          );
        }
      },
    );
  }
}