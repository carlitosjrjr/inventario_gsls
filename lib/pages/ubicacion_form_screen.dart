import 'package:flutter/material.dart';
import '../models/ubicacion.dart';
import '../services/firebase_service.dart';

class UbicacionFormScreen extends StatefulWidget {
  final Ubicacion? ubicacion;

  const UbicacionFormScreen({Key? key, this.ubicacion}) : super(key: key);

  @override
  State<UbicacionFormScreen> createState() => _UbicacionFormScreenState();
}

class _UbicacionFormScreenState extends State<UbicacionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _celularController = TextEditingController();
  final _direccionController = TextEditingController();
  bool _isLoading = false;
  String? _nombreError;

  @override
  void initState() {
    super.initState();
    if (widget.ubicacion != null) {
      _nombreController.text = widget.ubicacion!.nombre;
      _celularController.text = widget.ubicacion!.celular ?? '';
      _direccionController.text = widget.ubicacion!.direccion ?? '';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _celularController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  bool get isEdit => widget.ubicacion != null;

  Future<void> _validateNombre(String nombre) async {
    if (nombre.trim().isEmpty) {
      setState(() {
        _nombreError = null;
      });
      return;
    }

    try {
      bool isAvailable = await FirebaseService.isUbicacionNameAvailable(
        nombre.trim(),
        excludeId: widget.ubicacion?.id,
      );

      if (mounted) {
        setState(() {
          _nombreError = isAvailable
              ? null
              : 'Ya existe una ubicación con un nombre similar';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nombreError = 'Error al validar el nombre';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Ubicación' : 'Nueva Ubicación',style: TextStyle(fontSize: 30)),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Diseño responsivo para el formulario
          if (constraints.maxWidth > 800) {
            // Desktop/Tablet: Formulario centrado con ancho máximo
            return Center(
              child: Container(
                width: 600,
                padding: const EdgeInsets.all(24),
                child: _buildForm(),
              ),
            );
          } else {
            // Móvil: Formulario a ancho completo
            return SingleChildScrollView(
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
          // Formulario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Campo de nombre con validación en tiempo real
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la ubicación',
                      labelStyle: const TextStyle(color: Colors.black),
                      hintText: 'Ej: Bodega Principal, Oficina Central',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on),
                      errorText: _nombreError,
                      helperText: 'No se permiten nombres similares (ej: "almacen 1" y "almacen1")',
                      helperStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el nombre de la ubicación';
                      }
                      if (value.trim().length < 2) {
                        return 'El nombre debe tener al menos 2 caracteres';
                      }
                      if (_nombreError != null) {
                        return _nombreError;
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Validar después de un pequeño retraso para evitar demasiadas consultas
                      if (value.trim().length >= 2) {
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_nombreController.text.trim() == value.trim()) {
                            _validateNombre(value);
                          }
                        });
                      } else {
                        setState(() {
                          _nombreError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _celularController,
                    decoration: const InputDecoration(
                      labelText: 'Celular de referencia',
                      labelStyle: TextStyle(color: Colors.black),
                      hintText: 'Ej: +591 70123456',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el celular de referencia';
                      }
                      if (value.trim().length < 8) {
                        return 'El celular debe tener al menos 8 caracteres';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _direccionController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      hintText: 'Ej: Av. Principal #123, Zona Central',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa una dirección';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancelar',style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isLoading || _nombreError != null) ? null : _saveUbicacion,
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
                      : Text(isEdit ? 'Actualizar' : 'Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveUbicacion() async {
    // Validar una última vez antes de guardar
    await _validateNombre(_nombreController.text.trim());

    if (!_formKey.currentState!.validate() || _nombreError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ubicacion = Ubicacion(
        id: widget.ubicacion?.id,
        nombre: _nombreController.text.trim(),
        celular: _celularController.text.trim(),
        direccion: _direccionController.text.trim(),
      );

      if (isEdit) {
        await FirebaseService.updateUbicacion(widget.ubicacion!.id!, ubicacion);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación actualizada exitosamente'),
            backgroundColor: Color.fromRGBO(59, 122, 201, 1),
          ),
        );
      } else {
        await FirebaseService.createUbicacion(ubicacion);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación creada exitosamente'),
            backgroundColor: Color.fromRGBO(59, 122, 201, 1),
          ),
        );
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}