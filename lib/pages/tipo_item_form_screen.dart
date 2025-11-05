import 'package:flutter/material.dart';
import '../models/tipo_item.dart';
import '../services/firebase_service.dart';

class TipoItemFormScreen extends StatefulWidget {
  final TipoItemPersonalizado? tipo;

  const TipoItemFormScreen({Key? key, this.tipo}) : super(key: key);

  @override
  State<TipoItemFormScreen> createState() => _TipoItemFormScreenState();
}

class _TipoItemFormScreenState extends State<TipoItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.tipo != null;

    if (_isEditMode) {
      _nombreController.text = widget.tipo!.nombre;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Categoría' : 'Nueva Categoría'),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        actions: [
          if (_isEditMode)
            IconButton(
              onPressed: _showDeleteConfirmation,
              icon: const Icon(Icons.delete),
              tooltip: 'Eliminar categoría',
            ),
        ],
      ),
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
          // Formulario principal
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Categoría',
                      labelStyle: TextStyle(color: Colors.black),
                      hintText: 'Ej: Equipos deportivos, Libros de texto, Herramientas',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el nombre de la categoría';
                      }
                      if (value.trim().length < 2) {
                        return 'El nombre debe tener al menos 2 caracteres';
                      }
                      if (value.trim().length > 50) {
                        return 'El nombre no puede tener más de 50 caracteres';
                      }
                      return null;
                    },
                    onChanged: (value) => setState(() {}),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),

                  // Información adicional
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Las categorías te ayudan a organizar mejor tus items del inventario.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
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

          const SizedBox(height: 32),

          // Botones
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
                  onPressed: _isLoading ? null : _saveTipo,
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
                      : Text(_isEditMode ? 'Actualizar Categoría' : 'Guardar Categoría'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveTipo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tipo = TipoItemPersonalizado(
        id: _isEditMode ? widget.tipo!.id : null,
        nombre: _nombreController.text.trim(),
      );

      if (_isEditMode) {
        await FirebaseService.updateTipoItem(widget.tipo!.id!, tipo);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoría actualizada exitosamente'),
              backgroundColor: Color.fromRGBO(59, 122, 201, 1),
            ),
          );
        }
      } else {
        await FirebaseService.createTipoItem(tipo);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoría creada exitosamente'),
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
          title: const Text('Confirmar eliminación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Estás seguro de que deseas eliminar la categoría "${widget.tipo!.nombre}"?'),
              const SizedBox(height: 8),
              const Text(
                'Nota: Los items que usen esta categoría quedarán sin categoría asignada.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
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
                  await FirebaseService.deleteTipoItem(widget.tipo!.id!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Categoría eliminada exitosamente'),
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
    super.dispose();
  }
}