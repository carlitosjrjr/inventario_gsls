import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pdf_export_service.dart';
import '../services/reports_service.dart';
import '../services/firebase_service.dart';
import '../models/unidad_scout.dart';
import '../models/ubicacion.dart';
import '../models/tipo_item.dart';
import '../models/item.dart';
import '../models/prestamo.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _fileNameFormatter = DateFormat('dd-MM-yyyy');

  // Controladores para fechas
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();

  // Estados de carga
  bool _generandoReporte = false;

  // Datos para filtros
  List<UnidadScout> _unidadesScout = [];
  List<Ubicacion> _ubicaciones = [];
  List<TipoItemPersonalizado> _tiposItem = [];

  // Filtros seleccionados
  String? _unidadSeleccionada;
  String? _ubicacionSeleccionada;
  String? _tipoSeleccionado;
  EstadoItem? _estadoSeleccionado;
  EstadoPrestamo? _estadoPrestamoSeleccionado;
  int _limitItemsSolicitados = 20;
  int _diasProximoVencimiento = 7;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar unidades scout
      FirebaseService.getUnidadesScout().listen((unidades) {
        setState(() {
          _unidadesScout = unidades;
        });
      });

      // Cargar ubicaciones
      FirebaseService.getUbicaciones().listen((ubicaciones) {
        setState(() {
          _ubicaciones = ubicaciones;
        });
      });

      // Cargar tipos de item
      FirebaseService.getTiposItem().listen((tipos) {
        setState(() {
          _tiposItem = tipos;
        });
      });
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Reportes'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // NUEVO: Botón de información de ubicación
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Ubicación de guardado',
            onPressed: () async {
              await PdfExportService.mostrarInfoUbicacion(context);
            },
          ),
          // NUEVO: Botón de verificar permisos
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'Verificar permisos',
            onPressed: () async {
              await _verificarPermisos();
            },
          ),
        ],
      ),
      body: _generandoReporte
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generando reporte...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeccionFechas(),
            const SizedBox(height: 24),
            _buildSeccionReportePrestamos(),
            const SizedBox(height: 24),
            _buildSeccionItemsSolicitados(),
            const SizedBox(height: 24),
            _buildSeccionVencimientos(),
            const SizedBox(height: 24),
            _buildSeccionInventario(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionFechas() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Rango de Fechas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSelectorFecha(
                    'Fecha Inicio',
                    _fechaInicio,
                        (fecha) => setState(() => _fechaInicio = fecha),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSelectorFecha(
                    'Fecha Fin',
                    _fechaFin,
                        (fecha) => setState(() => _fechaFin = fecha),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorFecha(
      String label, DateTime fecha, Function(DateTime) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: fecha,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(_dateFormatter.format(fecha)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionReportePrestamos() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16), // Aumenté el padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Importante: permite que el Column tome solo el espacio necesario
          children: [
            // Header del card
            Row(
              children: [
                Icon(Icons.assignment, color: Colors.green[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Reporte de Préstamos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Aumenté el espaciado

            // Dropdowns
            Column( // Cambié de Row a Column para mejor manejo del espacio
              children: [
                // Dropdown Unidad Scout
                Container(
                  width: double.infinity,
                  child: _buildDropdownUnidadScout(),
                ),
                const SizedBox(height: 12),

                // Dropdown Estado Préstamo
                Container(
                  width: double.infinity,
                  child: _buildDropdownEstadoPrestamo(),
                ),
              ],
            ),

            const SizedBox(height: 20), // Aumenté el espaciado

            // Botón generar reporte
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generarReportePrestamos,
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: const Text(
                  'Generar Reporte de Préstamos',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionItemsSolicitados() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Items Más Solicitados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Límite de items',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _limitItemsSolicitados,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [10, 20, 30, 50, 100].map((limite) {
                          return DropdownMenuItem(
                            value: limite,
                            child: Text('Top $limite'),
                          );
                        }).toList(),
                        onChanged: (valor) {
                          setState(() {
                            _limitItemsSolicitados = valor!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generarReporteItemsSolicitados,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generar Reporte de Items Solicitados'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionVencimientos() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Préstamos Vencidos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Días para próximo vencimiento',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _diasProximoVencimiento,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [3, 7, 14, 30].map((dias) {
                          return DropdownMenuItem(
                            value: dias,
                            child: Text('$dias días'),
                          );
                        }).toList(),
                        onChanged: (valor) {
                          setState(() {
                            _diasProximoVencimiento = valor!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generarReporteVencimientos,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generar Reporte de Vencimientos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionInventario() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Reporte de Inventario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Container(
                  child: _buildDropdownEstadoItem(),
                ),
                const SizedBox(height: 12),
                Container(
                  child: _buildDropdownTipoItem(),

                ),
                const SizedBox(height: 12),
                Container(
                  child: _buildDropdownUbicacion(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generarReporteInventario,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generar Reporte de Inventario'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownUnidadScout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Unidad Scout (Opcional)',
          style: TextStyle(fontWeight: FontWeight.w500,fontSize: 14),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _unidadSeleccionada,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          hint: const Text('Todas las unidades',style: TextStyle(fontSize: 14)),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Todas las unidades',style: TextStyle(fontSize: 14)),
            ),
            ..._unidadesScout.map((unidad) {
              return DropdownMenuItem<String>(
                value: unidad.id,
                child: Text(unidad.nombreUnidad,style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
          ],
          onChanged: (valor) {
            setState(() {
              _unidadSeleccionada = valor;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownEstadoPrestamo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado Préstamo (Opcional)',
          style: TextStyle(fontWeight: FontWeight.w500,fontSize: 14),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EstadoPrestamo>(
          value: _estadoPrestamoSeleccionado,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Todos los estados',style: TextStyle(fontSize: 14)),
          items: [
            const DropdownMenuItem<EstadoPrestamo>(
              value: null,
              child: Text('Todos los estados',style: TextStyle(fontSize: 14)),
            ),
            ...EstadoPrestamo.values.map((estado) {
              return DropdownMenuItem<EstadoPrestamo>(
                value: estado,
                child: Text(_getEstadoPrestamoDisplay(estado),style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
          ],
          onChanged: (valor) {
            setState(() {
              _estadoPrestamoSeleccionado = valor;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownEstadoItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado Item (Opcional)',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EstadoItem>(
          value: _estadoSeleccionado,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Todos los estados'),
          items: [
            const DropdownMenuItem<EstadoItem>(
              value: null,
              child: Text('Todos los estados'),
            ),
            ...EstadoItem.values.map((estado) {
              return DropdownMenuItem<EstadoItem>(
                value: estado,
                child: Text(estado.displayName),
              );
            }).toList(),
          ],
          onChanged: (valor) {
            setState(() {
              _estadoSeleccionado = valor;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownTipoItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo Item (Opcional)',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _tipoSeleccionado,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Todos los tipos'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Todos los tipos'),
            ),
            ..._tiposItem.map((tipo) {
              return DropdownMenuItem<String>(
                value: tipo.id,
                child: Text(tipo.nombre),
              );
            }).toList(),
          ],
          onChanged: (valor) {
            setState(() {
              _tipoSeleccionado = valor;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownUbicacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación (Opcional)',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _ubicacionSeleccionada,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Todas las ubicaciones'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Todas las ubicaciones'),
            ),
            ..._ubicaciones.map((ubicacion) {
              return DropdownMenuItem<String>(
                value: ubicacion.id,
                child: Text(ubicacion.nombre),
              );
            }).toList(),
          ],
          onChanged: (valor) {
            setState(() {
              _ubicacionSeleccionada = valor;
            });
          },
        ),
      ],
    );
  }

  // NUEVO: Método para verificar permisos
  Future<void> _verificarPermisos() async {
    bool tienePermisos = await PdfExportService.verificarPermisos();
    String ubicacion = await PdfExportService.obtenerInfoDirectorio();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              tienePermisos ? Icons.check_circle : Icons.warning,
              color: tienePermisos ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Estado de Permisos'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tienePermisos
                  ? 'Los permisos de almacenamiento están habilitados correctamente.'
                  : 'Permisos de almacenamiento limitados o denegados.',
              style: TextStyle(
                color: tienePermisos ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Ubicación de guardado:'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ubicacion,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
            if (!tienePermisos) ...[
              const SizedBox(height: 12),
              const Text(
                'Sin permisos completos, los archivos se guardan en el directorio de la aplicación.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          if (!tienePermisos)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                bool nuevosPermisos = await PdfExportService.verificarPermisos();
                _mostrarExito(nuevosPermisos
                    ? 'Permisos otorgados correctamente'
                    : 'No se pudieron obtener todos los permisos');
              },
              child: const Text('Solicitar Permisos'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // MÉTODOS PARA GENERAR REPORTES

  Future<void> _generarReportePrestamos() async {
    setState(() {
      _generandoReporte = true;
    });

    try {
      final pdfData = await ReportsService.generarReportePrestamos(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        unidadScoutId: _unidadSeleccionada,
        estado: _estadoPrestamoSeleccionado,
      );

      String nombreArchivo = 'reporte_prestamos_${_fileNameFormatter.format(_fechaInicio)}_a_${_fileNameFormatter.format(_fechaFin)}';

      await PdfExportService.guardarYCompartirPDF(
          context, pdfData, nombreArchivo);

      _mostrarExito('Reporte de préstamos generado. Se guardará en Downloads/Reportes GSLS/');
    } catch (e) {
      _mostrarError('Error al generar reporte de préstamos: $e');
    } finally {
      setState(() {
        _generandoReporte = false;
      });
    }
  }

  Future<void> _generarReporteItemsSolicitados() async {
    setState(() {
      _generandoReporte = true;
    });

    try {
      final pdfData = await ReportsService.generarReporteItemsSolicitados(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        limite: _limitItemsSolicitados,
      );

      String nombreArchivo = 'items_solicitados_${_fileNameFormatter.format(_fechaInicio)}_a_${_fileNameFormatter.format(_fechaFin)}';

      await PdfExportService.guardarYCompartirPDF(
          context, pdfData, nombreArchivo);

      _mostrarExito('Reporte de items solicitados generado. Se guardará en Downloads/Reportes GSLS/');
    } catch (e) {
      _mostrarError('Error al generar reporte de items solicitados: $e');
    } finally {
      setState(() {
        _generandoReporte = false;
      });
    }
  }

  Future<void> _generarReporteVencimientos() async {
    setState(() {
      _generandoReporte = true;
    });

    try {
      final pdfData = await ReportsService.generarReportePrestamosVencidos(
        diasProximoVencimiento: _diasProximoVencimiento,
      );

      String nombreArchivo = 'vencimientos_${DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now())}';

      await PdfExportService.guardarYCompartirPDF(
          context, pdfData, nombreArchivo);

      _mostrarExito('Reporte de vencimientos generado. Se guardará en Downloads/Reportes GSLS/');
    } catch (e) {
      _mostrarError('Error al generar reporte de vencimientos: $e');
    } finally {
      setState(() {
        _generandoReporte = false;
      });
    }
  }

  Future<void> _generarReporteInventario() async {
    setState(() {
      _generandoReporte = true;
    });

    try {
      final pdfData = await ReportsService.generarReporteItems(
        filtroEstado: _estadoSeleccionado,
        filtroTipoId: _tipoSeleccionado,
        filtroUbicacionId: _ubicacionSeleccionada,
      );

      String nombreArchivo = 'inventario_${DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now())}';

      await PdfExportService.guardarYCompartirPDF(
          context, pdfData, nombreArchivo);

      _mostrarExito('Reporte de inventario generado. Se guardará en Downloads/Reportes GSLS/');
    } catch (e) {
      _mostrarError('Error al generar reporte de inventario: $e');
    } finally {
      setState(() {
        _generandoReporte = false;
      });
    }
  }

// MÉTODOS AUXILIARES

  String _getEstadoPrestamoDisplay(EstadoPrestamo estado) {
    switch (estado) {
      case EstadoPrestamo.activo:
        return 'Activo';
      case EstadoPrestamo.vencido:
        return 'Vencido';
      case EstadoPrestamo.parcial:
        return 'Parcial';
      case EstadoPrestamo.devuelto:
        return 'Devuelto';
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _mostrarExito(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
