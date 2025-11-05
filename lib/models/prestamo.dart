import 'item.dart';

class Prestamo {
  final String? id;
  final String nombreSolicitante;
  final String telefono;
  final String unidadScoutId; // Campo necesario para filtrar por unidad
  final String ramaScout; // Mantener para compatibilidad
  final DateTime fechaPrestamo;
  final DateTime fechaDevolucionEsperada;
  final DateTime? fechaDevolucionReal;
  final List<ItemPrestamo> items;
  final EstadoPrestamo estado;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final String? observaciones; // ⭐ CAMPO AGREGADO

  Prestamo({
    this.id,
    required this.nombreSolicitante,
    required this.telefono,
    required this.unidadScoutId, // Requerido
    required this.ramaScout,
    required this.fechaPrestamo,
    required this.fechaDevolucionEsperada,
    this.fechaDevolucionReal,
    required this.items,
    this.estado = EstadoPrestamo.activo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    this.observaciones, // ⭐ PARÁMETRO CORREGIDO
  }) : fechaCreacion = fechaCreacion ?? DateTime.now(),
        fechaActualizacion = fechaActualizacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nombreSolicitante': nombreSolicitante,
      'telefono': telefono,
      'unidadScoutId': unidadScoutId, // Incluir en el mapa
      'ramaScout': ramaScout,
      'fechaPrestamo': fechaPrestamo.toIso8601String(),
      'fechaDevolucionEsperada': fechaDevolucionEsperada.toIso8601String(),
      'fechaDevolucionReal': fechaDevolucionReal?.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'estado': estado.name,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
      'observaciones': observaciones, // ⭐ INCLUIR EN EL MAPA
    };
  }

  factory Prestamo.fromMap(Map<String, dynamic> map, String id) {
    return Prestamo(
      id: id,
      nombreSolicitante: map['nombreSolicitante'] ?? '',
      telefono: map['telefono'] ?? '',
      unidadScoutId: map['unidadScoutId'] ?? '', // Leer del mapa
      ramaScout: map['ramaScout'] ?? '',
      fechaPrestamo: DateTime.tryParse(map['fechaPrestamo'] ?? '') ?? DateTime.now(),
      fechaDevolucionEsperada: DateTime.tryParse(map['fechaDevolucionEsperada'] ?? '') ?? DateTime.now(),
      fechaDevolucionReal: map['fechaDevolucionReal'] != null
          ? DateTime.tryParse(map['fechaDevolucionReal'])
          : null,
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) => ItemPrestamo.fromMap(item as Map<String, dynamic>))
          .toList(),
      estado: EstadoPrestamo.values.firstWhere(
            (e) => e.name == map['estado'],
        orElse: () => EstadoPrestamo.activo,
      ),
      fechaCreacion: DateTime.tryParse(map['fechaCreacion'] ?? '') ?? DateTime.now(),
      fechaActualizacion: DateTime.tryParse(map['fechaActualizacion'] ?? '') ?? DateTime.now(),
      observaciones: map['observaciones'], // ⭐ LEER DEL MAPA
    );
  }

  Prestamo copyWith({
    String? id,
    String? nombreSolicitante,
    String? telefono,
    String? email,
    String? unidadScoutId,
    String? ramaScout,
    DateTime? fechaPrestamo,
    DateTime? fechaDevolucionEsperada,
    DateTime? fechaDevolucionReal,
    List<ItemPrestamo>? items,
    EstadoPrestamo? estado,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? observaciones, // ⭐ PARÁMETRO AGREGADO
  }) {
    return Prestamo(
      id: id ?? this.id,
      nombreSolicitante: nombreSolicitante ?? this.nombreSolicitante,
      telefono: telefono ?? this.telefono,
      unidadScoutId: unidadScoutId ?? this.unidadScoutId,
      ramaScout: ramaScout ?? this.ramaScout,
      fechaPrestamo: fechaPrestamo ?? this.fechaPrestamo,
      fechaDevolucionEsperada: fechaDevolucionEsperada ?? this.fechaDevolucionEsperada,
      fechaDevolucionReal: fechaDevolucionReal ?? this.fechaDevolucionReal,
      items: items ?? this.items,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? DateTime.now(),
      observaciones: observaciones ?? this.observaciones, // ⭐ INCLUIR EN COPYWITH
    );
  }

  bool get estaVencido => DateTime.now().isAfter(fechaDevolucionEsperada) &&
      estado != EstadoPrestamo.devuelto;

  int get totalItems => items.fold(0, (sum, item) => sum + item.cantidadPrestada);

  int get totalItemsDevueltos => items.fold(0, (sum, item) => sum + (item.cantidadDevuelta ?? 0));

  bool get estaCompleto => items.every((item) => item.estaCompleto);

  int get diasRestantes {
    if (estado == EstadoPrestamo.devuelto) return 0;
    return fechaDevolucionEsperada.difference(DateTime.now()).inDays;
  }
}

class ItemPrestamo {
  final String itemId;
  final String nombreItem;
  final int cantidadPrestada;
  final int? cantidadDevuelta;
  final EstadoItem estadoOriginal; // Estado cuando se prestó
  final EstadoItem? estadoDevuelto; // Estado al devolver
  final String? imagenEstadoDevuelto; // Imagen del item si cambió el estado

  ItemPrestamo({
    required this.itemId,
    required this.nombreItem,
    required this.cantidadPrestada,
    this.cantidadDevuelta,
    required this.estadoOriginal,
    this.estadoDevuelto,
    this.imagenEstadoDevuelto,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'nombreItem': nombreItem,
      'cantidadPrestada': cantidadPrestada,
      'cantidadDevuelta': cantidadDevuelta,
      'estadoOriginal': estadoOriginal.name,
      'estadoDevuelto': estadoDevuelto?.name,
      'imagenEstadoDevuelto': imagenEstadoDevuelto,
    };
  }

  factory ItemPrestamo.fromMap(Map<String, dynamic> map) {
    return ItemPrestamo(
      itemId: map['itemId'] ?? '',
      nombreItem: map['nombreItem'] ?? '',
      cantidadPrestada: map['cantidadPrestada'] ?? 0,
      cantidadDevuelta: map['cantidadDevuelta'],
      estadoOriginal: EstadoItem.values.firstWhere(
            (e) => e.name == map['estadoOriginal'],
        orElse: () => EstadoItem.excelente,
      ),
      estadoDevuelto: map['estadoDevuelto'] != null
          ? EstadoItem.values.firstWhere(
            (e) => e.name == map['estadoDevuelto'],
        orElse: () => EstadoItem.excelente,
      )
          : null,
      imagenEstadoDevuelto: map['imagenEstadoDevuelto'],
    );
  }

  ItemPrestamo copyWith({
    String? itemId,
    String? nombreItem,
    int? cantidadPrestada,
    int? cantidadDevuelta,
    EstadoItem? estadoOriginal,
    EstadoItem? estadoDevuelto,
    String? imagenEstadoDevuelto,
  }) {
    return ItemPrestamo(
      itemId: itemId ?? this.itemId,
      nombreItem: nombreItem ?? this.nombreItem,
      cantidadPrestada: cantidadPrestada ?? this.cantidadPrestada,
      cantidadDevuelta: cantidadDevuelta ?? this.cantidadDevuelta,
      estadoOriginal: estadoOriginal ?? this.estadoOriginal,
      estadoDevuelto: estadoDevuelto ?? this.estadoDevuelto,
      imagenEstadoDevuelto: imagenEstadoDevuelto ?? this.imagenEstadoDevuelto,
    );
  }

  bool get estaCompleto => cantidadDevuelta != null && cantidadDevuelta! >= cantidadPrestada;
  int get cantidadPendiente => cantidadPrestada - (cantidadDevuelta ?? 0);

  // Verificar si el estado cambió durante la devolución
  bool get estadoCambio => estadoDevuelto != null && estadoDevuelto != estadoOriginal;
}

enum EstadoPrestamo {
  activo,
  vencido,
  devuelto,
  parcial, // Cuando algunos items han sido devueltos pero no todos
}