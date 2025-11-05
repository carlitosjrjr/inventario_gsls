class TipoItemPersonalizado {
  final String? id;
  final String nombre;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  TipoItemPersonalizado({
    this.id,
    required this.nombre,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now(),
        fechaActualizacion = fechaActualizacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  factory TipoItemPersonalizado.fromMap(Map<String, dynamic> map, String id) {
    return TipoItemPersonalizado(
      id: id,
      nombre: map['nombre'] ?? '',
      fechaCreacion: DateTime.tryParse(map['fechaCreacion'] ?? '') ?? DateTime.now(),
      fechaActualizacion: DateTime.tryParse(map['fechaActualizacion'] ?? '') ?? DateTime.now(),
    );
  }

  TipoItemPersonalizado copyWith({
    String? id,
    String? nombre,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return TipoItemPersonalizado(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? DateTime.now(),
    );
  }
}