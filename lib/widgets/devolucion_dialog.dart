import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/prestamo.dart';
import '../models/item.dart';

class DevolucionDialog extends StatefulWidget {
  final List<ItemPrestamo> itemsPendientes;
  final Function(Map<String, ItemDevolucion>) onDevolver;

  const DevolucionDialog({
    super.key,
    required this.itemsPendientes,
    required this.onDevolver,
  });

  @override
  State<DevolucionDialog> createState() => _DevolucionDialogState();
}

class _DevolucionDialogState extends State<DevolucionDialog> {
  final ImagePicker _picker = ImagePicker();
  Map<String, ItemDevolucion> itemsDevolucion = {};

  @override
  void initState() {
    super.initState();
    // Inicializar el mapa de devolución
    for (var item in widget.itemsPendientes) {
      itemsDevolucion[item.itemId] = ItemDevolucion(
        itemId: item.itemId,
        nombreItem: item.nombreItem,
        cantidadPendiente: item.cantidadPendiente,
        cantidadADevolver: 0,
        estadoOriginal: item.estadoOriginal,
        estadoDevuelto: item.estadoOriginal, // Por defecto, mismo estado
        imagenEstado: null,
      );
    }
  }

  Future<void> _tomarFoto(String itemId) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          itemsDevolucion[itemId] = itemsDevolucion[itemId]!.copyWith(
            imagenEstado: File(photo.path),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Devolver Items'),
      contentPadding: const EdgeInsets.all(16), // Controlar padding del contenido
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9, // 90% del ancho de pantalla
        height: 600,
        child: Column(
          children: [
            const Text('Selecciona las cantidades y estados al devolver:'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero, // Eliminar padding del ListView
                itemCount: widget.itemsPendientes.length,
                itemBuilder: (context, index) {
                  final item = widget.itemsPendientes[index];
                  final devolucion = itemsDevolucion[item.itemId]!;
                  final estadoCambio = devolucion.estadoDevuelto != devolucion.estadoOriginal;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8), // Reducir margen del Card
                    child: Padding(
                      padding: const EdgeInsets.all(6), // Reducir padding interno
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nombreItem,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Pendiente: ${item.cantidadPendiente}'),
                          // Control de cantidad - VERSIÓN COMPACTA
                          // ...
                          Row(
                            mainAxisSize: MainAxisSize.min, // Asegura que la fila sea lo más compacta posible
                            children: [
                              const Text('Cantidad: ', style: TextStyle(fontSize: 14)),
                              IconButton(
                                onPressed: devolucion.cantidadADevolver > 0
                                    ? () {
                                  setState(() {
                                    itemsDevolucion[item.itemId] = devolucion.copyWith(
                                      cantidadADevolver: devolucion.cantidadADevolver - 1,
                                    );
                                  });
                                }
                                    : null,
                                icon: const Icon(Icons.remove),
                                iconSize: 16,
                                padding: EdgeInsets.zero, // Elimina el padding del IconButton
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  devolucion.cantidadADevolver.toString(),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                              // ... tu código
                              // ... tu código
                              IconButton(
                                onPressed: devolucion.cantidadADevolver < item.cantidadPendiente
                                    ? () {
                                  setState(() {
                                    itemsDevolucion[item.itemId] = devolucion.copyWith(
                                      cantidadADevolver: devolucion.cantidadADevolver + 1,
                                    );
                                  });
                                }
                                    : null,
                                icon: const Icon(Icons.add),
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                // Sigue siendo necesario para el IconButton
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    itemsDevolucion[item.itemId] = devolucion.copyWith(
                                      cantidadADevolver: item.cantidadPendiente,
                                    );
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero, // Elimina el padding del TextButton
                                  minimumSize: Size.zero,   // Elimina el tamaño mínimo del botón
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // <-- ¡Esta es la clave!
                                ),
                                child: const Text('Máximo', style: TextStyle(fontSize: 11, color: Colors.black)),
                              ),
// ... el resto de tu código
                            ],
                          ),
// ...


                          const SizedBox(height: 8),

                          // Estados
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estado original:', style: TextStyle(fontSize: 12)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getEstadoColor(devolucion.estadoOriginal),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  devolucion.estadoOriginal.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Estado al devolver:', style: TextStyle(fontSize: 12)),
                                  DropdownButton<EstadoItem>(
                                    value: devolucion.estadoDevuelto,
                                    isExpanded: true,
                                    items: EstadoItem.values.map((estado) {
                                      return DropdownMenuItem<EstadoItem>(
                                        value: estado,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 6 ,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: _getEstadoColor(estado),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(estado.displayName, style: TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (EstadoItem? newEstado) {
                                      if (newEstado != null) {
                                        setState(() {
                                          itemsDevolucion[item.itemId] = devolucion.copyWith(
                                            estadoDevuelto: newEstado,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Alerta y botón de foto si cambió el estado
                          if (estadoCambio) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'El estado cambió. Se requiere foto.',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _tomarFoto(item.itemId),
                                        icon: const Icon(Icons.camera_alt, size: 16),
                                        label: Text(devolucion.imagenEstado != null ? 'Cambiar foto' : 'Tomar foto'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                      ),
                                      if (devolucion.imagenEstado != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.green),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.file(
                                              devolucion.imagenEstado!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar',style: TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () {
            // Validar que al menos un item tenga cantidad > 0
            bool hayItemsADevolver = itemsDevolucion.values
                .any((dev) => dev.cantidadADevolver > 0);

            if (!hayItemsADevolver) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Selecciona al menos un item para devolver'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Validar que los items con estado cambiado tengan foto
            bool faltanFotos = itemsDevolucion.values.any((dev) =>
            dev.cantidadADevolver > 0 &&
                dev.estadoDevuelto != dev.estadoOriginal &&
                dev.imagenEstado == null);

            if (faltanFotos) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Debes tomar foto de los items que cambiaron de estado'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.of(context).pop();
            widget.onDevolver(itemsDevolucion);
          },
          child: const Text('Devolver',style: TextStyle(color: Colors.black)),
        ),
      ],
    );
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
}

class ItemDevolucion {
  final String itemId;
  final String nombreItem;
  final int cantidadPendiente;
  final int cantidadADevolver;
  final EstadoItem estadoOriginal;
  final EstadoItem estadoDevuelto;
  final File? imagenEstado;

  ItemDevolucion({
    required this.itemId,
    required this.nombreItem,
    required this.cantidadPendiente,
    required this.cantidadADevolver,
    required this.estadoOriginal,
    required this.estadoDevuelto,
    this.imagenEstado,
  });

  ItemDevolucion copyWith({
    String? itemId,
    String? nombreItem,
    int? cantidadPendiente,
    int? cantidadADevolver,
    EstadoItem? estadoOriginal,
    EstadoItem? estadoDevuelto,
    File? imagenEstado,
  }) {
    return ItemDevolucion(
      itemId: itemId ?? this.itemId,
      nombreItem: nombreItem ?? this.nombreItem,
      cantidadPendiente: cantidadPendiente ?? this.cantidadPendiente,
      cantidadADevolver: cantidadADevolver ?? this.cantidadADevolver,
      estadoOriginal: estadoOriginal ?? this.estadoOriginal,
      estadoDevuelto: estadoDevuelto ?? this.estadoDevuelto,
      imagenEstado: imagenEstado ?? this.imagenEstado,
    );
  }
}