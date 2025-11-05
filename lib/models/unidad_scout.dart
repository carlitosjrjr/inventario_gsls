enum RamaScout {
  lobatos('Lobatos'),
  exploradores('Exploradores'),
  pioneros('Pioneros'),
  rovers('Rovers');

  const RamaScout(this.displayName);
  final String displayName;

  static RamaScout fromString(String value) {
    switch (value.toLowerCase()) {
      case 'lobatos':
        return RamaScout.lobatos;
      case 'exploradores':
        return RamaScout.exploradores;
      case 'pioneros':
        return RamaScout.pioneros;
      case 'rovers':
        return RamaScout.rovers;
      default:
        return RamaScout.lobatos;
    }
  }
}

class UnidadScout {
  final String? id;
  final String nombreUnidad;
  final String responsableUnidad;
  final String telefono;
  final RamaScout ramaScout;
  final String? imagenUnidad;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  UnidadScout({
    this.id,
    required this.nombreUnidad,
    required this.responsableUnidad,
    required this.telefono,
    required this.ramaScout,
    this.imagenUnidad,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now(),
        fechaActualizacion = fechaActualizacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nombreUnidad': nombreUnidad,
      'responsableUnidad': responsableUnidad,
      'telefono': telefono,
      'ramaScout': ramaScout.name,
      'imagenUnidad': imagenUnidad,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  factory UnidadScout.fromMap(Map<String, dynamic> map, String id) {
    return UnidadScout(
      id: id,
      nombreUnidad: map['nombreUnidad'] ?? '',
      responsableUnidad: map['responsableUnidad'] ?? '',
      telefono: map['telefono'] ?? '',
      ramaScout: map['ramaScout'] != null
          ? RamaScout.fromString(map['ramaScout'])
          : RamaScout.lobatos,
      imagenUnidad: map['imagenUnidad'],
      fechaCreacion: DateTime.parse(map['fechaCreacion'] ?? DateTime.now().toIso8601String()),
      fechaActualizacion: DateTime.parse(map['fechaActualizacion'] ?? DateTime.now().toIso8601String()),
    );
  }

  UnidadScout copyWith({
    String? id,
    String? nombreUnidad,
    String? responsableUnidad,
    String? telefono,
    RamaScout? ramaScout,
    String? imagenUnidad,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return UnidadScout(
      id: id ?? this.id,
      nombreUnidad: nombreUnidad ?? this.nombreUnidad,
      responsableUnidad: responsableUnidad ?? this.responsableUnidad,
      telefono: telefono ?? this.telefono,
      ramaScout: ramaScout ?? this.ramaScout,
      imagenUnidad: imagenUnidad ?? this.imagenUnidad,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  @override
  String toString() {
    return 'UnidadScout{id: $id, nombreUnidad: $nombreUnidad, responsableUnidad: $responsableUnidad, telefono: $telefono, ramaScout: ${ramaScout.displayName}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UnidadScout &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}