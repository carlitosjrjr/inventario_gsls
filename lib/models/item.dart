enum TipoItem {
  herramientas('Herramientas'),
  equipos('Equipos'),
  materiales('Materiales'),
  accesorios('Accesorios'),
  electronica('Electrónica'),
  mobiliario('Mobiliario'),
  otros('Otros');

  const TipoItem(this.displayName);
  final String displayName;
}

enum EstadoItem {
  excelente('Excelente estado'),
  bueno('Buen estado'),
  malo('Mal estado'),
  perdida('Perdida');

  const EstadoItem(this.displayName);
  final String displayName;
}

class Item {
  final String? id;
  final String nombre;
  final int cantidad;
  final String ubicacionId;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final String? imagenUrl;
  final String? tipoId; // Nuevo: ID del tipo personalizado
  final TipoItem? tipo; // Mantener por compatibilidad (deprecated)
  final EstadoItem estado;

  Item({
    this.id,
    required this.nombre,
    required this.cantidad,
    required this.ubicacionId,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    this.imagenUrl,
    this.tipoId, // Nuevo parámetro
    this.tipo, // Mantener por compatibilidad
    this.estado = EstadoItem.excelente,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now(),
        fechaActualizacion = fechaActualizacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'nombre': nombre,
      'cantidad': cantidad,
      'ubicacionId': ubicacionId,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
      'imagenUrl': imagenUrl,
      'estado': estado.name,
    };

    // Priorizar tipoId sobre tipo enum
    if (tipoId != null) {
      map['tipoId'] = tipoId;
    } else if (tipo != null) {
      map['tipo'] = tipo!.name;
    }

    return map;
  }

  factory Item.fromMap(Map<String, dynamic> map, String id) {
    return Item(
      id: id,
      nombre: map['nombre'] ?? '',
      cantidad: map['cantidad'] ?? 0,
      ubicacionId: map['ubicacionId'] ?? '',
      fechaCreacion: DateTime.tryParse(map['fechaCreacion'] ?? '') ?? DateTime.now(),
      fechaActualizacion: DateTime.tryParse(map['fechaActualizacion'] ?? '') ?? DateTime.now(),
      imagenUrl: map['imagenUrl'],
      tipoId: map['tipoId'], // Nuevo campo
      tipo: map['tipo'] != null
          ? TipoItem.values.firstWhere(
            (e) => e.name == map['tipo'],
        orElse: () => TipoItem.otros,
      )
          : null, // Mantener compatibilidad
      estado: EstadoItem.values.firstWhere(
            (e) => e.name == map['estado'],
        orElse: () => EstadoItem.excelente,
      ),
    );
  }

  Item copyWith({
    String? id,
    String? nombre,
    int? cantidad,
    String? ubicacionId,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? imagenUrl,
    String? tipoId,
    TipoItem? tipo,
    EstadoItem? estado,
  }) {
    return Item(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      ubicacionId: ubicacionId ?? this.ubicacionId,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? DateTime.now(),
      imagenUrl: imagenUrl ?? this.imagenUrl,
      tipoId: tipoId ?? this.tipoId,
      tipo: tipo ?? this.tipo,
      estado: estado ?? this.estado,
    );
  }

  // Método auxiliar para obtener el tipo efectivo (prioriza tipoId)
  String get tipoEfectivo {
    if (tipoId != null) {
      return tipoId!;
    } else if (tipo != null) {
      return tipo!.name;
    }
    return 'otros';
  }

  // Método para verificar si usa el sistema nuevo de tipos
  bool get usaTiposPersonalizados => tipoId != null;
}