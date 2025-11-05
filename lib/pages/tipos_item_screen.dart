import 'package:flutter/material.dart';
import '../models/tipo_item.dart';
import '../services/firebase_service.dart';
import 'tipo_item_form_screen.dart';

class TiposItemScreen extends StatefulWidget {
  const TiposItemScreen({Key? key}) : super(key: key);

  @override
  State<TiposItemScreen> createState() => _TiposItemScreenState();
}

class _TiposItemScreenState extends State<TiposItemScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: const Text('Gestionar Categorías'),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar categorías...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Lista de tipos
          Expanded(
            child: StreamBuilder<List<TipoItemPersonalizado>>(
              stream: FirebaseService.getTiposItem(),
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

                List<TipoItemPersonalizado> tipos = snapshot.data ?? [];

                // Aplicar filtros
                tipos = _applyFilters(tipos);

                if (tipos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.category_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No se encontraron categorías'
                              : 'No hay categorías registradas',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Intenta con otros términos de búsqueda'
                              : 'Toca el botón + para crear tu primera categoría',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tipos.length,
                  itemBuilder: (context, index) {
                    final tipo = tipos[index];
                    return _buildTipoCard(tipo);
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
              builder: (context) => const TipoItemFormScreen(),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  List<TipoItemPersonalizado> _applyFilters(List<TipoItemPersonalizado> tipos) {
    List<TipoItemPersonalizado> filteredTipos = tipos;

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filteredTipos = filteredTipos.where((tipo) {
        return tipo.nombre.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return filteredTipos;
  }

  Widget _buildTipoCard(TipoItemPersonalizado tipo) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(59, 122, 201, 1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color.fromRGBO(59, 122, 201, 1).withOpacity(0.3)),
          ),
          child: const Icon(
            Icons.category,
            color: Color.fromRGBO(59, 122, 201, 1),
            size: 24,
          ),
        ),
        title: Text(
          tipo.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Creado: ${_formatDate(tipo.fechaCreacion)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            if (tipo.fechaActualizacion.isAfter(tipo.fechaCreacion.add(const Duration(minutes: 1))))
              Text(
                'Actualizado: ${_formatDate(tipo.fechaActualizacion)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TipoItemFormScreen(tipo: tipo),
                ),
              );
            } else if (value == 'delete') {
              _showDeleteConfirmation(tipo);
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
              builder: (context) => TipoItemFormScreen(tipo: tipo),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(TipoItemPersonalizado tipo) {
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
              Text('¿Estás seguro de que deseas eliminar la categoría "${tipo.nombre}"?'),
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

                try {
                  await FirebaseService.deleteTipoItem(tipo.id!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Categoría eliminada exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}