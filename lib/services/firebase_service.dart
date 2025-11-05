import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/item.dart';
import '../models/ubicacion.dart';
import '../models/prestamo.dart';
import '../models/tipo_item.dart';
import '../models/unidad_scout.dart';
import '../services/notification_service.dart';
import '../widgets/devolucion_dialog.dart';
import '../services/email_service.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colecciones
  static const String _itemsCollection = 'items';
  static const String _ubicacionesCollection = 'ubicaciones';
  static const String _prestamosCollection = 'prestamos';
  static const String _tiposItemCollection = 'tipos_item';
  static const String _unidadesScoutCollection = 'unidades_scout';

  // Función para normalizar nombres
  static String _normalizeString(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  // Convertir imagen a Base64 con compresión
  static Future<String?> convertImageToBase64(File imageFile) async {
    try {
      // Leer los bytes del archivo
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Si la imagen es muy grande, podríamos comprimirla aquí
      // Por ahora, convertimos directamente a Base64
      String base64String = base64Encode(imageBytes);

      // Agregar el prefijo del tipo de imagen
      String imageExtension = imageFile.path.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg'; // Por defecto JPEG

      if (imageExtension == 'png') {
        mimeType = 'image/png';
      } else if (imageExtension == 'gif') {
        mimeType = 'image/gif';
      }

      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      throw Exception('Error al convertir imagen: $e');
    }
  }

  // CRUD para Tipos de Items Personalizados

  /// Crear un nuevo tipo de item
  static Future<String> createTipoItem(TipoItemPersonalizado tipo) async {
    try {
      // Verificar que no exista un tipo con el mismo nombre
      final existingQuery = await _firestore
          .collection(_tiposItemCollection)
          .where('nombre', isEqualTo: tipo.nombre)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('Ya existe un tipo con el nombre "${tipo.nombre}"');
      }

      DocumentReference docRef = await _firestore
          .collection(_tiposItemCollection)
          .add(tipo.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear tipo de item: $e');
    }
  }

  /// Obtener todos los tipos de items
  static Stream<List<TipoItemPersonalizado>> getTiposItem() {
    return _firestore
        .collection(_tiposItemCollection)
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TipoItemPersonalizado.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener un tipo de item por ID
  static Future<TipoItemPersonalizado?> getTipoItemById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_tiposItemCollection)
          .doc(id)
          .get();

      if (doc.exists) {
        return TipoItemPersonalizado.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener tipo de item: $e');
    }
  }

  /// Obtener tipo de item por nombre (para migración)
  static Future<TipoItemPersonalizado?> getTipoItemByNombre(String nombre) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_tiposItemCollection)
          .where('nombre', isEqualTo: nombre)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return TipoItemPersonalizado.fromMap(
          query.docs.first.data() as Map<String, dynamic>,
          query.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error al buscar tipo de item: $e');
    }
  }

  /// Actualizar un tipo de item
  static Future<void> updateTipoItem(String id, TipoItemPersonalizado tipo) async {
    try {
      // Verificar que no exista otro con el mismo nombre
      final existingQuery = await _firestore
          .collection(_tiposItemCollection)
          .where('nombre', isEqualTo: tipo.nombre)
          .get();

      for (var doc in existingQuery.docs) {
        if (doc.id != id) {
          throw Exception('Ya existe un tipo con el nombre "${tipo.nombre}"');
        }
      }

      await _firestore
          .collection(_tiposItemCollection)
          .doc(id)
          .update(tipo.copyWith(fechaActualizacion: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Error al actualizar tipo de item: $e');
    }
  }

  /// Eliminar un tipo de item
  static Future<void> deleteTipoItem(String id) async {
    try {
      // Verificar que el tipo existe
      DocumentSnapshot tipoDoc = await _firestore
          .collection(_tiposItemCollection)
          .doc(id)
          .get();

      if (!tipoDoc.exists) {
        throw Exception('Tipo de item no encontrado');
      }


      // Buscar si hay items que usen este tipo
      QuerySnapshot itemsWithType = await _firestore
          .collection(_itemsCollection)
          .where('tipoId', isEqualTo: id)
          .get();

      WriteBatch batch = _firestore.batch();

      // Si hay items que usan este tipo, eliminar la referencia (quedará null)
      for (var itemDoc in itemsWithType.docs) {
        batch.update(itemDoc.reference, {
          'tipoId': null,
          'fechaActualizacion': DateTime.now().toIso8601String(),
        });
      }

      // Eliminar el tipo
      batch.delete(_firestore.collection(_tiposItemCollection).doc(id));

      await batch.commit();
    } catch (e) {
      throw Exception('Error al eliminar tipo de item: $e');
    }
  }

  // Validar si ya existe una ubicación con nombre similar
  static Future<bool> isUbicacionNameAvailable(String nombre, {String? excludeId}) async {
    try {
      String normalizedName = _normalizeString(nombre);

      QuerySnapshot snapshot = await _firestore
          .collection(_ubicacionesCollection)
          .get();

      for (var doc in snapshot.docs) {
        if (excludeId != null && doc.id == excludeId) {
          continue;
        }

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String existingName = data['nombre'] ?? '';
        String normalizedExistingName = _normalizeString(existingName);

        if (normalizedExistingName == normalizedName) {
          return false;
        }
      }

      return true;
    } catch (e) {
      throw Exception('Error al validar nombre de ubicación: $e');
    }
  }

  // CRUD para Items

  /// Crear un nuevo item
  static Future<String> createItem(Item item, {File? imageFile}) async {
    try {
      Map<String, dynamic> itemData = item.toMap();

      // Si hay imagen, convertirla a Base64
      if (imageFile != null) {
        String? base64Image = await convertImageToBase64(imageFile);
        if (base64Image != null) {
          itemData['imagenUrl'] = base64Image;
        }
      }

      // Convertir el enum TipoItem a ID de tipo personalizado si es necesario
      if (itemData.containsKey('tipo')) {
        String tipoName = _getTipoNameFromEnum(itemData['tipo']);
        TipoItemPersonalizado? tipoPersonalizado = await getTipoItemByNombre(tipoName);

        if (tipoPersonalizado != null) {
          itemData['tipoId'] = tipoPersonalizado.id;
          itemData.remove('tipo'); // Remover el enum antiguo
        }
      }

      DocumentReference docRef = await _firestore
          .collection(_itemsCollection)
          .add(itemData);

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear item: $e');
    }
  }

  /// Obtener todos los items
  static Stream<List<Item>> getItems() {
    return _firestore
        .collection(_itemsCollection)
        .orderBy('fechaActualizacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Item.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener items filtrados por tipo personalizado
  static Stream<List<Item>> getItemsByTipoPersonalizado(String tipoId) {
    return _firestore
        .collection(_itemsCollection)
        .where('tipoId', isEqualTo: tipoId)
        .orderBy('fechaActualizacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Item.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener items filtrados por estado
  static Stream<List<Item>> getItemsByEstado(EstadoItem estado) {
    return _firestore
        .collection(_itemsCollection)
        .where('estado', isEqualTo: estado.name)
        .orderBy('fechaActualizacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Item.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener un item por ID
  static Future<Item?> getItemById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_itemsCollection)
          .doc(id)
          .get();

      if (doc.exists) {
        return Item.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener item: $e');
    }
  }

  /// Actualizar un item
  static Future<void> updateItem(String id, Item item, {File? imageFile}) async {
    try {
      Map<String, dynamic> updateData = item.copyWith(fechaActualizacion: DateTime.now()).toMap();

      // Si hay nueva imagen, convertirla a Base64
      if (imageFile != null) {
        String? base64Image = await convertImageToBase64(imageFile);
        if (base64Image != null) {
          updateData['imagenUrl'] = base64Image;
        }
      }

      await _firestore
          .collection(_itemsCollection)
          .doc(id)
          .update(updateData);
    } catch (e) {
      throw Exception('Error al actualizar item: $e');
    }
  }

  /// Eliminar un item
  static Future<void> deleteItem(String id) async {
    try {
      await _firestore
          .collection(_itemsCollection)
          .doc(id)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar item: $e');
    }
  }

  /// Método auxiliar para convertir enum TipoItem a nombre
  static String _getTipoNameFromEnum(String enumValue) {
    switch (enumValue) {
      case 'herramientas':
        return 'Herramientas';
      case 'equipos':
        return 'Equipos';
      case 'materiales':
        return 'Materiales';
      case 'accesorios':
        return 'Accesorios';
      case 'electronica':
        return 'Electrónica';
      case 'mobiliario':
        return 'Mobiliario';
      case 'otros':
      default:
        return 'Otros';
    }
  }

  // CRUD para Ubicaciones

  /// Crear una nueva ubicación
  static Future<String> createUbicacion(Ubicacion ubicacion) async {
    try {
      bool isAvailable = await isUbicacionNameAvailable(ubicacion.nombre);
      if (!isAvailable) {
        throw Exception('Ya existe una ubicación con un nombre similar a "${ubicacion.nombre}"');
      }

      DocumentReference docRef = await _firestore
          .collection(_ubicacionesCollection)
          .add(ubicacion.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear ubicación: $e');
    }
  }

  /// Obtener todas las ubicaciones
  static Stream<List<Ubicacion>> getUbicaciones() {
    return _firestore
        .collection(_ubicacionesCollection)
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Ubicacion.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener una ubicación por ID
  static Future<Ubicacion?> getUbicacionById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_ubicacionesCollection)
          .doc(id)
          .get();

      if (doc.exists) {
        return Ubicacion.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener ubicación: $e');
    }
  }

  /// Actualizar una ubicación
  static Future<void> updateUbicacion(String id, Ubicacion ubicacion) async {
    try {
      bool isAvailable = await isUbicacionNameAvailable(ubicacion.nombre, excludeId: id);
      if (!isAvailable) {
        throw Exception('Ya existe una ubicación con un nombre similar a "${ubicacion.nombre}"');
      }

      await _firestore
          .collection(_ubicacionesCollection)
          .doc(id)
          .update(ubicacion.toMap());
    } catch (e) {
      throw Exception('Error al actualizar ubicación: $e');
    }
  }

  /// Eliminar una ubicación
  static Future<void> deleteUbicacion(String id) async {
    try {
      await _firestore
          .collection(_ubicacionesCollection)
          .doc(id)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar ubicación: $e');
    }
  }

  /// Obtener items por ubicación
  static Stream<List<Item>> getItemsByUbicacion(String ubicacionId) {
    return _firestore
        .collection(_itemsCollection)
        .where('ubicacionId', isEqualTo: ubicacionId)
        .orderBy('fechaActualizacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Item.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // CRUD para Préstamos

  /// Crear un nuevo préstamo
  static Future<String> createPrestamo(Prestamo prestamo) async {
    try {
      return await _firestore.runTransaction<String>((transaction) async {
        for (ItemPrestamo itemPrestamo in prestamo.items) {
          DocumentReference itemRef = _firestore
              .collection(_itemsCollection)
              .doc(itemPrestamo.itemId);

          DocumentSnapshot itemDoc = await transaction.get(itemRef);
          if (!itemDoc.exists) {
            throw Exception('Item ${itemPrestamo.nombreItem} no encontrado');
          }

          Item item = Item.fromMap(itemDoc.data() as Map<String, dynamic>, itemDoc.id);
          if (item.cantidad < itemPrestamo.cantidadPrestada) {
            throw Exception('No hay suficiente cantidad de ${itemPrestamo.nombreItem}. Disponible: ${item.cantidad}');
          }

          transaction.update(itemRef, {
            'cantidad': item.cantidad - itemPrestamo.cantidadPrestada,
            'fechaActualizacion': DateTime.now().toIso8601String(),
          });
        }

        DocumentReference prestamoRef = _firestore
            .collection(_prestamosCollection)
            .doc();

        transaction.set(prestamoRef, prestamo.toMap());

        return prestamoRef.id;
      });
    } catch (e) {
      throw Exception('Error al crear préstamo: $e');
    }
  }

  /// Obtener todos los préstamos
  static Stream<List<Prestamo>> getPrestamos() {
    return _firestore
        .collection(_prestamosCollection)
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Prestamo.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener un préstamo por ID
  static Future<Prestamo?> getPrestamoById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_prestamosCollection)
          .doc(id)
          .get();

      if (doc.exists) {
        return Prestamo.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener préstamo: $e');
    }
  }

  /// Actualizar un préstamo
  static Future<void> updatePrestamo(String id, Prestamo prestamo) async {
    try {
      await _firestore
          .collection(_prestamosCollection)
          .doc(id)
          .update(prestamo.copyWith(fechaActualizacion: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Error al actualizar préstamo: $e');
    }
  }

  /// Buscar item existente con el mismo nombre y estado
  static Future<Item?> _buscarItemExistente(
      Transaction transaction,
      String nombre,
      EstadoItem estado,
      String ubicacionId,
      String? tipoId,
      ) async {
    try {
      // Buscar por nombre exacto, estado, ubicación y tipo
      Query query = _firestore
          .collection(_itemsCollection)
          .where('nombre', isEqualTo: nombre)
          .where('estado', isEqualTo: estado.name)
          .where('ubicacionId', isEqualTo: ubicacionId);

      // Agregar filtro por tipo si existe
      if (tipoId != null) {
        query = query.where('tipoId', isEqualTo: tipoId);
      }

      // Ejecutar la consulta dentro de la transacción
      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        // Retornar el primer item encontrado
        DocumentSnapshot doc = snapshot.docs.first;
        return Item.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }

      return null;
    } catch (e) {
      print('Error al buscar item existente: $e');
      return null;
    }
  }

  /// Devolver items de un préstamo con estados y creación de nuevos items
  static Future<void> devolverItemsConEstado(
      String prestamoId,
      Map<String, ItemDevolucion> itemsDevolucion,
      ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference prestamoRef = _firestore
            .collection(_prestamosCollection)
            .doc(prestamoId);

        DocumentSnapshot prestamoDoc = await transaction.get(prestamoRef);
        if (!prestamoDoc.exists) {
          throw Exception('Préstamo no encontrado');
        }

        Prestamo prestamo = Prestamo.fromMap(
          prestamoDoc.data() as Map<String, dynamic>,
          prestamoDoc.id,
        );

        List<ItemPrestamo> itemsActualizados = [];

        // PASO 1: Convertir todas las imágenes a Base64 ANTES de la transacción
        Map<String, String?> imagenesBase64 = {};
        for (var entry in itemsDevolucion.entries) {
          if (entry.value.imagenEstado != null) {
            imagenesBase64[entry.key] = await convertImageToBase64(entry.value.imagenEstado!);
          }
        }

        // PASO 2: Leer todos los documentos de items primero
        Map<String, Item> itemsInventario = {};
        for (ItemPrestamo itemPrestamo in prestamo.items) {
          if (itemsDevolucion.containsKey(itemPrestamo.itemId)) {
            DocumentReference itemRef = _firestore
                .collection(_itemsCollection)
                .doc(itemPrestamo.itemId);
            DocumentSnapshot itemDoc = await transaction.get(itemRef);

            if (itemDoc.exists) {
              itemsInventario[itemPrestamo.itemId] = Item.fromMap(
                itemDoc.data() as Map<String, dynamic>,
                itemDoc.id,
              );
            }
          }
        }

        // PASO 3: Procesar las devoluciones
        for (ItemPrestamo itemPrestamo in prestamo.items) {
          ItemDevolucion? devolucion = itemsDevolucion[itemPrestamo.itemId];

          if (devolucion != null && devolucion.cantidadADevolver > 0) {
            // Procesar devolución
            int cantidadDevueltaAnterior = itemPrestamo.cantidadDevuelta ?? 0;
            int nuevaCantidadDevuelta = cantidadDevueltaAnterior + devolucion.cantidadADevolver;

            String? imagenBase64 = imagenesBase64[itemPrestamo.itemId];

            // Obtener el item original del inventario
            Item? inventarioItem = itemsInventario[itemPrestamo.itemId];

            if (inventarioItem != null) {
              DocumentReference itemRef = _firestore
                  .collection(_itemsCollection)
                  .doc(itemPrestamo.itemId);

              // Si el estado no cambió, simplemente devolver al inventario original
              if (devolucion.estadoDevuelto == devolucion.estadoOriginal) {
                transaction.update(itemRef, {
                  'cantidad': inventarioItem.cantidad + devolucion.cantidadADevolver,
                  'fechaActualizacion': DateTime.now().toIso8601String(),
                });
              } else {
                // Si el estado cambió, buscar item existente o crear uno nuevo
                await _procesarCambioEstadoEnTransaccion(
                  transaction,
                  inventarioItem,
                  devolucion,
                  imagenBase64,
                );
              }
            }

            // Actualizar el item del préstamo
            itemsActualizados.add(itemPrestamo.copyWith(
              cantidadDevuelta: nuevaCantidadDevuelta,
              estadoDevuelto: devolucion.estadoDevuelto,
              imagenEstadoDevuelto: imagenBase64,
            ));
          } else {
            // Item sin cambios
            itemsActualizados.add(itemPrestamo);
          }
        }

        // Determinar el nuevo estado del préstamo
        bool todoDevuelto = itemsActualizados.every((item) => item.estaCompleto);
        bool algunoDevuelto = itemsActualizados.any((item) => (item.cantidadDevuelta ?? 0) > 0);

        EstadoPrestamo nuevoEstado;
        DateTime? fechaDevolucionReal;

        if (todoDevuelto) {
          nuevoEstado = EstadoPrestamo.devuelto;
          fechaDevolucionReal = DateTime.now();
        } else if (algunoDevuelto) {
          nuevoEstado = EstadoPrestamo.parcial;
        } else {
          nuevoEstado = prestamo.estaVencido ? EstadoPrestamo.vencido : EstadoPrestamo.activo;
        }

        // Actualizar el préstamo
        Prestamo prestamoActualizado = prestamo.copyWith(
          items: itemsActualizados,
          estado: nuevoEstado,
          fechaDevolucionReal: fechaDevolucionReal,
        );

        transaction.update(prestamoRef, prestamoActualizado.toMap());
      });
    } catch (e) {
      throw Exception('Error al devolver items: $e');
    }
  }

  /// Procesar cambio de estado en la transacción (buscar existente o crear nuevo)
  static Future<void> _procesarCambioEstadoEnTransaccion(
      Transaction transaction,
      Item itemOriginal,
      ItemDevolucion devolucion,
      String? imagenBase64,
      ) async {
    try {
      // Buscar si ya existe un item con el mismo nombre y nuevo estado
      Item? itemExistente = await _buscarItemExistente(
        transaction,
        itemOriginal.nombre,
        devolucion.estadoDevuelto,
        itemOriginal.ubicacionId,
        itemOriginal.tipoId,
      );

      if (itemExistente != null) {
        // Si existe, agregar cantidad al item existente
        DocumentReference itemExistenteRef = _firestore
            .collection(_itemsCollection)
            .doc(itemExistente.id!);

        transaction.update(itemExistenteRef, {
          'cantidad': itemExistente.cantidad + devolucion.cantidadADevolver,
          'fechaActualizacion': DateTime.now().toIso8601String(),
        });

        print('Item existente encontrado: ${itemExistente.nombre} - Estado: ${devolucion.estadoDevuelto.displayName}');
      } else {
        // Si no existe, crear un nuevo item
        _crearNuevoItemConEstadoCambiadoEnTransaccion(
          transaction,
          itemOriginal,
          devolucion,
          imagenBase64,
        );

        print('Nuevo item creado: ${itemOriginal.nombre} - Estado: ${devolucion.estadoDevuelto.displayName}');
      }
    } catch (e) {
      throw Exception('Error al procesar cambio de estado: $e');
    }
  }

  /// Crear un nuevo item cuando el estado cambió durante la devolución (versión para transacción)
  static void _crearNuevoItemConEstadoCambiadoEnTransaccion(
      Transaction transaction,
      Item itemOriginal,
      ItemDevolucion devolucion,
      String? imagenBase64,
      ) {
    try {
      // Crear nuevo item con el estado cambiado, manteniendo el nombre original
      Item nuevoItem = itemOriginal.copyWith(
        id: null, // Nuevo ID se asignará automáticamente
        cantidad: devolucion.cantidadADevolver,
        estado: devolucion.estadoDevuelto,
        imagenUrl: imagenBase64,
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
      );

      Map<String, dynamic> nuevoItemData = nuevoItem.toMap();
      // Mantener el nombre original, sin sufijos
      nuevoItemData['nombre'] = itemOriginal.nombre;

      // Crear el nuevo item en una nueva referencia
      DocumentReference nuevoItemRef = _firestore
          .collection(_itemsCollection)
          .doc(); // Firebase generará el ID automáticamente

      transaction.set(nuevoItemRef, nuevoItemData);
    } catch (e) {
      throw Exception('Error al crear nuevo item: $e');
    }
  }

  /// Obtener préstamos activos
  static Stream<List<Prestamo>> getPrestamosActivos() {
    return _firestore
        .collection(_prestamosCollection)
        .where('estado', whereIn: ['activo', 'vencido', 'parcial'])
        .orderBy('fechaDevolucionEsperada')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Prestamo.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener préstamos por solicitante
  static Stream<List<Prestamo>> getPrestamosBySolicitante(String email) {
    return _firestore
        .collection(_prestamosCollection)
        .where('email', isEqualTo: email)
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Prestamo.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  static Future<int> getCantidadDisponible(String itemId) async {
    try {
      DocumentSnapshot itemDoc = await _firestore.collection('items').doc(itemId).get();
      if (!itemDoc.exists) return 0;

      Item item = Item.fromMap(itemDoc.data() as Map<String, dynamic>, itemDoc.id);
      int cantidadTotal = item.cantidad;

      QuerySnapshot prestamosSnapshot = await _firestore
          .collection('prestamos')
          .where('estado', whereIn: ['activo', 'vencido', 'parcial'])
          .get();

      int cantidadPrestada = 0;

      for (var doc in prestamosSnapshot.docs) {
        Prestamo prestamo = Prestamo.fromMap(doc.data() as Map<String, dynamic>, doc.id);

        for (var itemPrestamo in prestamo.items) {
          if (itemPrestamo.itemId == itemId) {
            cantidadPrestada += itemPrestamo.cantidadPendiente;
          }
        }
      }

      return cantidadTotal - cantidadPrestada;
    } catch (e) {
      throw Exception('Error al calcular cantidad disponible: $e');
    }
  }

  // CRUD para Unidades Scout

  /// Crear una nueva unidad scout
  static Future<String> createUnidadScout(UnidadScout unidad, {File? imageFile}) async {
    try {
      Map<String, dynamic> unidadData = unidad.toMap();

      // Si hay imagen, convertirla a Base64
      if (imageFile != null) {
        String? base64Image = await convertImageToBase64(imageFile);
        if (base64Image != null) {
          unidadData['imagenUnidad'] = base64Image;
        }
      }

      DocumentReference docRef = await _firestore
          .collection(_unidadesScoutCollection)
          .add(unidadData);

      // Programar notificación si no tiene imagen
      if (imageFile == null && unidad.imagenUnidad == null) {
        try {
          DateTime fechaNotificacion = unidad.fechaCreacion.add(const Duration(minutes: 1));
          await NotificationService.programarNotificacionImagenUnidad(
            unidadId: docRef.id,
            nombreUnidad: unidad.nombreUnidad,
            fechaNotificacion: fechaNotificacion,
          );

          print('Notificación programada para unidad: ${unidad.nombreUnidad}');
        } catch (e) {
          print('Error al programar notificación: $e');
          // No lanzar excepción para no afectar la creación de la unidad
        }
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear unidad scout: $e');
    }
  }

  /// Obtener todas las unidades scout
  static Stream<List<UnidadScout>> getUnidadesScout() {
    return _firestore
        .collection(_unidadesScoutCollection)
        .orderBy('nombreUnidad')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UnidadScout.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Obtener una unidad scout por ID
  static Future<UnidadScout?> getUnidadScoutById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_unidadesScoutCollection)
          .doc(id)
          .get();

      if (doc.exists) {
        return UnidadScout.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener unidad scout: $e');
    }
  }

  /// Actualizar una unidad scout
  static Future<void> updateUnidadScout(String id, UnidadScout unidad, {File? imageFile}) async {
    try {
      Map<String, dynamic> updateData = unidad.copyWith(fechaActualizacion: DateTime.now()).toMap();

      bool imagenAgregada = false;

      // Si hay nueva imagen, convertirla a Base64
      if (imageFile != null) {
        String? base64Image = await convertImageToBase64(imageFile);
        if (base64Image != null) {
          updateData['imagenUnidad'] = base64Image;
          imagenAgregada = true;
        }
      } else if (unidad.imagenUnidad != null && unidad.imagenUnidad!.isNotEmpty) {
        // Si se está estableciendo una imagen en los datos de la unidad
        imagenAgregada = true;
      }

      await _firestore
          .collection(_unidadesScoutCollection)
          .doc(id)
          .update(updateData);

      // Si se agregó una imagen, cancelar notificaciones pendientes
      if (imagenAgregada) {
        try {
          await NotificationService.cancelarNotificacionesUnidad(id);
          print('Notificaciones canceladas para unidad: ${unidad.nombreUnidad}');
        } catch (e) {
          print('Error al cancelar notificaciones: $e');
        }
      }
    } catch (e) {
      throw Exception('Error al actualizar unidad scout: $e');
    }
  }

  /// Eliminar una unidad scout
  static Future<void> deleteUnidadScout(String id) async {
    try {
      // Cancelar notificaciones antes de eliminar
      await NotificationService.cancelarNotificacionesUnidad(id);

      await _firestore
          .collection(_unidadesScoutCollection)
          .doc(id)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar unidad scout: $e');
    }
  }

  /// Validar si ya existe una unidad scout con nombre similar
  static Future<bool> isUnidadScoutNameAvailable(String nombreUnidad, {String? excludeId}) async {
    try {
      String normalizedName = _normalizeString(nombreUnidad);

      QuerySnapshot snapshot = await _firestore
          .collection(_unidadesScoutCollection)
          .get();

      for (var doc in snapshot.docs) {
        if (excludeId != null && doc.id == excludeId) {
          continue;
        }

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String existingName = data['nombreUnidad'] ?? '';
        String normalizedExistingName = _normalizeString(existingName);

        if (normalizedExistingName == normalizedName) {
          return false;
        }
      }

      return true;
    } catch (e) {
      throw Exception('Error al validar nombre de unidad scout: $e');
    }
  }
}
class FirebaseServiceExtensions {

  /// Crear un nuevo préstamo con notificaciones automáticas
  static Future<String> createPrestamoConNotificaciones(Prestamo prestamo) async {
    try {
      print('💼 Creando préstamo con notificaciones...');
      print('   - Solicitante: ${prestamo.nombreSolicitante}');
      print('   - Fecha devolución: ${prestamo.fechaDevolucionEsperada}');

      // Crear el préstamo usando el método existente
      String prestamoId = await FirebaseService.createPrestamo(prestamo);
      print('✅ Préstamo creado con ID: $prestamoId');

      // Crear una copia del préstamo con el ID generado
      Prestamo prestamoConId = prestamo.copyWith(id: prestamoId);

      // Verificar que el usuario tenga email antes de programar
      String? emailUsuario = EmailService.emailUsuarioActual;
      if (emailUsuario == null) {
        print('⚠️ Usuario sin email - Solo se programarán notificaciones push');
      }

      // Programar todas las notificaciones para este préstamo
      await NotificationService.programarNotificacionesPrestamo(prestamoConId);
      print('✅ Notificaciones programadas para préstamo: $prestamoId');

      // Verificar que los emails se programaron correctamente
      await EmailService.verificarEmailsProgramados();

      return prestamoId;
    } catch (e) {
      print('❌ Error al crear préstamo con notificaciones: $e');
      throw Exception('Error al crear préstamo con notificaciones: $e');
    }
  }

  /// Actualizar un préstamo y reprogramar notificaciones si es necesario
  static Future<void> updatePrestamoConNotificaciones(String id, Prestamo prestamo) async {
    try {
      // Obtener el préstamo anterior para comparar fechas
      Prestamo? prestamoAnterior = await FirebaseService.getPrestamoById(id);

      // Actualizar el préstamo usando el método existente
      await FirebaseService.updatePrestamo(id, prestamo);

      // Si cambió la fecha de devolución o el estado, reprogramar notificaciones
      if (prestamoAnterior != null &&
          (prestamoAnterior.fechaDevolucionEsperada != prestamo.fechaDevolucionEsperada ||
              prestamoAnterior.estado != prestamo.estado)) {

        // Cancelar notificaciones anteriores
        await NotificationService.cancelarNotificacionesPrestamo(id);

        // Solo reprogramar si el préstamo sigue activo
        if (prestamo.estado == EstadoPrestamo.activo ||
            prestamo.estado == EstadoPrestamo.vencido ||
            prestamo.estado == EstadoPrestamo.parcial) {

          Prestamo prestamoConId = prestamo.copyWith(id: id);
          await NotificationService.programarNotificacionesPrestamo(prestamoConId);
        }
      }

      print('Préstamo actualizado con notificaciones: $id');
    } catch (e) {
      throw Exception('Error al actualizar préstamo con notificaciones: $e');
    }
  }

  /// Devolver items con actualización automática de notificaciones
  static Future<void> devolverItemsConNotificaciones(
      String prestamoId,
      Map<String, ItemDevolucion> itemsDevolucion,
      ) async {
    try {
      // Realizar la devolución usando el método existente
      await FirebaseService.devolverItemsConEstado(prestamoId, itemsDevolucion);

      // Obtener el préstamo actualizado
      Prestamo? prestamoActualizado = await FirebaseService.getPrestamoById(prestamoId);

      if (prestamoActualizado != null) {
        // Si el préstamo está completamente devuelto, cancelar notificaciones
        if (prestamoActualizado.estado == EstadoPrestamo.devuelto) {
          await NotificationService.cancelarNotificacionesPrestamo(prestamoId);
          print('Notificaciones canceladas - Préstamo completamente devuelto: $prestamoId');
        }
        // Si es devolución parcial, las notificaciones siguen activas
        else if (prestamoActualizado.estado == EstadoPrestamo.parcial) {
          print('Devolución parcial - Notificaciones mantienen activas: $prestamoId');
        }
      }
    } catch (e) {
      throw Exception('Error al devolver items con notificaciones: $e');
    }
  }

  /// Verificar y actualizar estados de préstamos vencidos
  static Future<void> actualizarPrestamosVencidos() async {
    try {
      DateTime ahora = DateTime.now();

      // Obtener préstamos activos que ya vencieron
      FirebaseService.getPrestamosActivos().listen((prestamos) async {
        for (Prestamo prestamo in prestamos) {
          if (prestamo.estado == EstadoPrestamo.activo &&
              prestamo.fechaDevolucionEsperada.isBefore(ahora)) {

            // Actualizar estado a vencido
            await FirebaseService.updatePrestamo(
              prestamo.id!,
              prestamo.copyWith(estado: EstadoPrestamo.vencido),
            );

            print('Préstamo marcado como vencido: ${prestamo.id}');
          }
        }
      });
    } catch (e) {
      print('Error al actualizar préstamos vencidos: $e');
    }
  }

  /// Programar verificación automática de préstamos vencidos (ejecutar diariamente)
  static void iniciarVerificacionAutomatica() {
    Timer.periodic(const Duration(hours: 24), (timer) {
      actualizarPrestamosVencidos();
    });

    print('Verificación automática de préstamos vencidos iniciada');
  }

  /// Obtener estadísticas de notificaciones de préstamos
  static Future<Map<String, dynamic>> obtenerEstadisticasNotificaciones() async {
    try {
      print('📊 Obteniendo estadísticas completas...');

      // Obtener estadísticas de emails con método mejorado
      Map<String, int> statsEmails = await EmailService.obtenerEstadisticasEmails();
      print('📧 Stats emails: $statsEmails');

      // Obtener notificaciones pendientes
      List<PendingNotificationRequest> notificationsPendientes =
      await NotificationService.obtenerNotificacionesPendientes();
      print('🔔 Notificaciones pendientes totales: ${notificationsPendientes.length}');

      // Filtrar notificaciones de préstamos vs unidades
      int notificacionesPrestamos = 0;
      int notificacionesUnidades = 0;

      for (var notif in notificationsPendientes) {
        if (notif.payload?.startsWith('prestamo:') ?? false) {
          notificacionesPrestamos++;
        } else if (notif.payload?.startsWith('unidad_scout:') ?? false) {
          notificacionesUnidades++;
        }
      }

      Map<String, dynamic> resultado = {
        // Estadísticas de emails
        'emailsPendientes': statsEmails['pendientes'] ?? 0,
        'emailsEnviados': statsEmails['enviados'] ?? 0,
        'emailsCancelados': statsEmails['cancelados'] ?? 0,
        'emailsConError': statsEmails['conError'] ?? 0,

        // Estadísticas de notificaciones
        'notificacionesPendientes': notificacionesPrestamos,
        'notificacionesUnidades': notificacionesUnidades,
        'totalNotificacionesPendientes': notificationsPendientes.length,

        // Metadata adicional
        'ultimaActualizacion': DateTime.now().toIso8601String(),
        'usuarioEmail': EmailService.emailUsuarioActual,
      };

      print('📈 Estadísticas completas: $resultado');
      return resultado;

    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return {
        'emailsPendientes': 0,
        'emailsEnviados': 0,
        'emailsCancelados': 0,
        'emailsConError': 0,
        'notificacionesPendientes': 0,
        'notificacionesUnidades': 0,
        'totalNotificacionesPendientes': 0,
        'error': e.toString(),
      };
    }
  }

  /// Limpiar datos antiguos de notificaciones y emails
  static Future<void> limpiarDatosAntiguos() async {
    try {
      // Limpiar emails antiguos
      await EmailService.limpiarEmailsAntiguos();

      print('Limpieza de datos antiguos completada');
    } catch (e) {
      print('Error al limpiar datos antiguos: $e');
    }
  }

  /// Enviar notificación de prueba para préstamos
  static Future<void> enviarNotificacionPrueba(String prestamoId) async {
    try {
      Prestamo? prestamo = await FirebaseService.getPrestamoById(prestamoId);

      if (prestamo != null) {
        // Mostrar notificación inmediata de prueba
        await NotificationService.programarNotificacionPrestamo(
          prestamoId: prestamoId,
          titulo: '🧪 Notificación de Prueba',
          mensaje: 'Esta es una notificación de prueba para el préstamo de "${prestamo.nombreSolicitante}"',
          fechaNotificacion: DateTime.now().add(const Duration(seconds: 5)),
          diasRestantes: 999, // Valor especial para prueba
        );

        print('Notificación de prueba programada para: $prestamoId');
      }
    } catch (e) {
      print('Error al enviar notificación de prueba: $e');
    }
  }

  /// Enviar email de prueba para préstamos
  static Future<void> enviarEmailPrueba(String destinatario) async {
    try {
      await EmailService.enviarEmailPrueba(destinatario);
      print('Email de prueba enviado a: $destinatario');
    } catch (e) {
      print('Error al enviar email de prueba: $e');
      throw e;
    }
  }

  /// Verificar configuración completa del sistema de notificaciones
  static Future<Map<String, bool>> verificarConfiguracion() async {
    try {
      print('🔍 Verificando configuración del sistema...');

      // Verificar notificaciones
      bool notificacionesHabilitadas = await NotificationService.notificacionesHabilitadas();
      print('🔔 Notificaciones habilitadas: $notificacionesHabilitadas');

      // Verificar email
      bool emailConfigurado = await EmailService.verificarConfiguracion();
      print('📧 Email configurado: $emailConfigurado');

      // Verificar usuario logueado
      String? emailUsuario = EmailService.emailUsuarioActual;
      bool usuarioLogueado = emailUsuario != null && emailUsuario.isNotEmpty;
      print('👤 Usuario logueado con email: $usuarioLogueado ($emailUsuario)');

      bool sistemaCompleto = notificacionesHabilitadas && emailConfigurado && usuarioLogueado;

      Map<String, bool> config = {
        'notificacionesHabilitadas': notificacionesHabilitadas,
        'emailConfigurado': emailConfigurado,
        'usuarioLogueado': usuarioLogueado,
        'sistemaCompleto': sistemaCompleto,
      };

      print('⚙️ Configuración final: $config');
      return config;

    } catch (e) {
      print('❌ Error al verificar configuración: $e');
      return {
        'notificacionesHabilitadas': false,
        'emailConfigurado': false,
        'usuarioLogueado': false,
        'sistemaCompleto': false,
      };
    }
  }

  /// Método para inicializar completamente el sistema de notificaciones
  static Future<void> inicializarSistemaNotificaciones() async {
    try {
      print('🔧 Iniciando sistema de notificaciones...');

      // Inicializar NotificationService
      await NotificationService.initialize();
      print('✅ NotificationService inicializado');

      // Inicializar EmailService con verificación
      bool emailOk = await EmailService.initializeConVerificacion();
      if (emailOk) {
        print('✅ EmailService inicializado correctamente');
      } else {
        print('⚠️ EmailService inicializado con problemas');
      }

      // Iniciar verificación automática de préstamos vencidos
      iniciarVerificacionAutomatica();
      print('✅ Verificación automática iniciada');

      // Verificar configuración final
      Map<String, bool> config = await verificarConfiguracion();
      print('📊 Configuración final: $config');

      if (config['sistemaCompleto'] == true) {
        print('🎉 Sistema de notificaciones inicializado completamente');
      } else {
        print('⚠️ Sistema de notificaciones inicializado con advertencias:');
        if (!(config['notificacionesHabilitadas'] ?? false)) {
          print('  - Notificaciones push no habilitadas');
        }
        if (!(config['emailConfigurado'] ?? false)) {
          print('  - Email no configurado correctamente');
        }
      }

    } catch (e) {
      print('❌ Error crítico al inicializar sistema de notificaciones: $e');
      throw Exception('Error al inicializar sistema: $e');
    }
  }

  static Future<void> debugSistemaCompleto() async {
    try {
      print('🔍 === DEBUG COMPLETO DEL SISTEMA ===');

      // 1. Verificar configuración
      Map<String, bool> config = await verificarConfiguracion();
      print('1️⃣ Configuración: $config');

      // 2. Verificar estadísticas
      Map<String, dynamic> stats = await obtenerEstadisticasNotificaciones();
      print('2️⃣ Estadísticas: $stats');

      // 3. Verificar emails programados
      await EmailService.verificarEmailsProgramados();

      // 4. Verificar notificaciones pendientes
      await NotificationService.debugEmailsProgramados();

      print('🏁 === FIN DEBUG SISTEMA ===');

    } catch (e) {
      print('❌ Error en debug del sistema: $e');
    }
  }
}