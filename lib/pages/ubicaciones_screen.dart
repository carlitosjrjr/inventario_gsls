import 'package:flutter/material.dart';
import 'package:inventario_gsls/pages/ubicacion_form_screen.dart';
import '../models/ubicacion.dart';
import '../services/firebase_service.dart';

class UbicacionesScreen extends StatefulWidget {
  const UbicacionesScreen({Key? key}) : super(key: key);

  @override
  State<UbicacionesScreen> createState() => _UbicacionesScreenState();
}

class _UbicacionesScreenState extends State<UbicacionesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        title: const Text('Ubicaciones',style: TextStyle(fontSize: 30)),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Ubicacion>>(
        stream: FirebaseService.getUbicaciones(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
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

          List<Ubicacion> ubicaciones = snapshot.data ?? [];

          if (ubicaciones.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No hay ubicaciones registradas',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Toca el botón + para agregar tu primera ubicación',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Diseño responsivo basado en el ancho de pantalla
              if (constraints.maxWidth > 1200) {
                // Desktop: Grid de 3 columnas
                return _buildGridView(ubicaciones, 3);
              } else if (constraints.maxWidth > 800) {
                // Tablet: Grid de 2 columnas
                return _buildGridView(ubicaciones, 2);
              } else {
                // Móvil: Lista vertical
                return _buildListView(ubicaciones);
              }
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToUbicacionForm(),
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(List<Ubicacion> ubicaciones) {
    return ListView.builder(
      itemCount: ubicaciones.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ubicacion = ubicaciones[index];
        return _buildUbicacionCard(ubicacion, isCompact: true);
      },
    );
  }

  Widget _buildGridView(List<Ubicacion> ubicaciones, int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: ubicaciones.length,
      itemBuilder: (context, index) {
        final ubicacion = ubicaciones[index];
        return _buildUbicacionCard(ubicacion, isCompact: false);
      },
    );
  }

  Widget _buildUbicacionCard(Ubicacion ubicacion, {required bool isCompact}) {
    if (isCompact) {
      // Diseño para lista (móvil)
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: const Icon(
              Icons.location_on,
              color: Color.fromRGBO(59, 122, 201, 1),
            ),
          ),
          title: Text(
            ubicacion.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: _buildSubtitle(ubicacion),
          trailing: PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, ubicacion),
            itemBuilder: (BuildContext context) => _buildMenuItems(),
          ),
          onTap: () => _navigateToUbicacionForm(ubicacion: ubicacion),
        ),
      );
    } else {
      // Diseño para grid (tablet/desktop)
      return Card(
        elevation: 4,
        child: InkWell(
          onTap: () => _navigateToUbicacionForm(ubicacion: ubicacion),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(
                        Icons.location_on,
                        color: Color.fromRGBO(59, 122, 201, 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ubicacion.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleMenuAction(value, ubicacion),
                      itemBuilder: (BuildContext context) => _buildMenuItems(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ubicacion.celular != null && ubicacion.celular!.isNotEmpty)
                        _buildInfoRow(Icons.phone, 'Celular: ${ubicacion.celular!}'),
                      if (ubicacion.direccion != null && ubicacion.direccion!.isNotEmpty)
                        _buildInfoRow(Icons.location_city, 'Dirección: ${ubicacion.direccion!}'),
                      const Spacer(),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Creado: ${_formatDate(ubicacion.fechaCreacion)}',
                        isSmall: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: isSmall ? 14 : 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isSmall ? 11 : 13,
                color: isSmall ? Colors.grey.shade600 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(Ubicacion ubicacion) {
    if (ubicacion.direccion != null &&
        ubicacion.direccion!.isNotEmpty &&
        ubicacion.celular != null &&
        ubicacion.celular!.isNotEmpty) {
      return Text('Celular: ${ubicacion.celular!}\nDirección: ${ubicacion.direccion!}');
    }
    return Text(
      'Creado: ${_formatDate(ubicacion.fechaCreacion)}',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade600,
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    return <PopupMenuEntry<String>>[
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
    ];
  }

  void _handleMenuAction(String action, Ubicacion ubicacion) {
    switch (action) {
      case 'edit':
        _navigateToUbicacionForm(ubicacion: ubicacion);
        break;
      case 'delete':
        _showDeleteConfirmation(ubicacion);
        break;
    }
  }

  void _navigateToUbicacionForm({Ubicacion? ubicacion}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UbicacionFormScreen(ubicacion: ubicacion),
      ),
    );
  }

  void _showDeleteConfirmation(Ubicacion ubicacion) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(232, 238, 242	, 1),
          title: const Text('Confirmar eliminación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Estás seguro de que deseas eliminar "${ubicacion.nombre}"?'),
              const SizedBox(height: 8),
              const Text(
                'Advertencia: Esto podría afectar los items que están asociados a esta ubicación.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar',style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseService.deleteUbicacion(ubicacion.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ubicación eliminada exitosamente'),
                      backgroundColor: Color.fromRGBO(59, 122, 201, 1),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
