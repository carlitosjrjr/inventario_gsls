class Ubicacion {
  final String? id;
  final String nombre;
  final String celular;
  final String direccion;
  final DateTime fechaCreacion;

  Ubicacion({
    this.id,
    required this.nombre,
    required this.celular,
    required this.direccion,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'celular': celular,
      'direccion': direccion,
      'fechaCreacion': fechaCreacion.toIso8601String(),
    };
  }

  factory Ubicacion.fromMap(Map<String, dynamic> map, String id) {
    return Ubicacion(
      id: id,
      nombre: map['nombre'] ?? '',
      celular: map['celular'] ?? '',
      direccion: map['direccion']??'',
      fechaCreacion: DateTime.tryParse(map['fechaCreacion'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() => nombre;
}
