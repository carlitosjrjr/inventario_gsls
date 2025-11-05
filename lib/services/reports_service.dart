import 'package:flutter/cupertino.dart';
import 'package:inventario_gsls/services/pdf_export_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/item.dart';
import '../models/prestamo.dart';
import '../models/ubicacion.dart';
import '../models/tipo_item.dart';
import '../models/unidad_scout.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Clase para estadísticas de items más solicitados
class ItemSolicitado {
  final String itemId;
  final String nombre;
  final int totalSolicitado;
  final int vecesPrestado;
  final String tipoNombre;
  final EstadoItem estado;

  ItemSolicitado({
    required this.itemId,
    required this.nombre,
    required this.totalSolicitado,
    required this.vecesPrestado,
    required this.tipoNombre,
    required this.estado,
  });
}

// Clase para estadísticas de reportes
class EstadisticasReporte {
  final int totalItems;
  final int totalPrestamos;
  final int prestamosActivos;
  final int prestamosVencidos;
  final int prestamosProximosAVencer;
  final Map<EstadoItem, int> itemsPorEstado;
  final Map<String, int> itemsPorTipo;

  EstadisticasReporte({
    required this.totalItems,
    required this.totalPrestamos,
    required this.prestamosActivos,
    required this.prestamosVencidos,
    required this.prestamosProximosAVencer,
    required this.itemsPorEstado,
    required this.itemsPorTipo,
  });
}

class ReportsService {
  static final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

  // Generar encabezado común para los reportes
  static pw.Widget _buildHeader(String titulo, String subtitulo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GRUPO SCOUT - SISTEMA DE INVENTARIO',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            subtitulo,
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            height: 2,
            color: PdfColors.blue900,
          ),
        ],
      ),
    );
  }

  // Generar pie de página
  static pw.Widget _buildFooter(int pageNumber, int totalPages) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        'Página $pageNumber de $totalPages - Generado el ${_dateTimeFormatter.format(DateTime.now())}',
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColors.grey600,
        ),
      ),
    );
  }
  // MÉTODO CORREGIDO PARA GENERAR REPORTE DE PRÉSTAMOS
  static Future<Uint8List> generarReportePrestamos({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? unidadScoutId,
    EstadoPrestamo? estado,
  }) async {
    try {
      // Obtener datos
      List<Prestamo> prestamos = await _obtenerPrestamos(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        estado: estado,
      );

      Map<String, UnidadScout> unidades = await _obtenerUnidadesScout();
      Map<String, Ubicacion> ubicaciones = await _obtenerUbicaciones();
      Map<String, Item> itemsCache = await _obtenerTodosLosItems();

      final pdf = pw.Document();

      // Filtrar préstamos por unidad si se especifica (CORREGIDO)
      if (unidadScoutId != null) {
        prestamos = prestamos.where((p) => p.unidadScoutId == unidadScoutId).toList();
      }

      String subtitulo = 'Período: ${_dateFormatter.format(fechaInicio)} - ${_dateFormatter.format(fechaFin)}';
      if (unidadScoutId != null && unidades.containsKey(unidadScoutId)) {
        subtitulo += ' | Unidad: ${unidades[unidadScoutId]!.nombreUnidad}';
      }
      if (estado != null) {
        subtitulo += ' | Estado: ${_getEstadoPrestamoDisplay(estado)}';
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildHeader('REPORTE DE PRÉSTAMOS', subtitulo),
          footer: (context) => _buildFooter(context.pageNumber, context.pagesCount),
          build: (context) {
            List<pw.Widget> widgets = [];

            // Estadísticas generales
            widgets.add(_buildEstadisticasPrestamos(prestamos));
            widgets.add(pw.SizedBox(height: 20));

            if (prestamos.isEmpty) {
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    'No se encontraron préstamos para el período seleccionado.',
                    style: const pw.TextStyle(fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              );
            } else {
              // Tabla de préstamos CON DETALLES DE ITEMS
              widgets.add(_buildTablaPrestamosDetallada(prestamos, unidades, itemsCache));
            }

            return widgets;
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      throw Exception('Error al generar reporte de préstamos: $e');
    }
  }

// Nuevo método auxiliar para obtener todos los items
  static Future<Map<String, Item>> _obtenerTodosLosItems() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('items').get();
    Map<String, Item> items = {};
    for (var doc in snapshot.docs) {
      items[doc.id] = Item.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return items;
  }

// Nuevo método para construir tabla de préstamos con detalles
  static pw.Widget _buildTablaPrestamosDetallada(
      List<Prestamo> prestamos,
      Map<String, UnidadScout> unidades,
      Map<String, Item> itemsCache,
      ) {
    List<pw.Widget> widgets = [];

    for (int i = 0; i < prestamos.length; i++) {
      Prestamo prestamo = prestamos[i];
      UnidadScout? unidad = unidades[prestamo.unidadScoutId];

      // Encabezado del préstamo
      widgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          margin: const pw.EdgeInsets.only(bottom: 5),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            border: pw.Border.all(color: PdfColors.blue300),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PRÉSTAMO #${i + 1}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      color: PdfColors.blue800,
                    ),
                  ),
                  _buildEstadoPill(prestamo.estado),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Solicitante: ${prestamo.nombreSolicitante}',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Teléfono: ${prestamo.telefono}',
                            style: const pw.TextStyle(fontSize: 10)),
                        if (unidad != null) ...[
                          pw.Text('Unidad: ${unidad.nombreUnidad}',
                              style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Responsable: ${unidad.responsableUnidad}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Fecha Préstamo: ${_dateFormatter.format(prestamo.fechaPrestamo)}',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Fecha Devolución: ${_dateFormatter.format(prestamo.fechaDevolucionEsperada)}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Tabla de items del préstamo
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Encabezado de items
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildCellHeader('Item'),
                _buildCellHeader('Cant. Prestada'),
                _buildCellHeader('Cant. Devuelta'),
                _buildCellHeader('Pendiente'),
                _buildCellHeader('Estado Dev.'),
              ],
            ),
            // Items del préstamo
            ...prestamo.items.map((itemPrestamo) {
              Item? item = itemsCache[itemPrestamo.itemId];
              return pw.TableRow(
                children: [
                  _buildCell(item?.nombre ?? 'Item no encontrado'),
                  _buildCell(itemPrestamo.cantidadPrestada.toString()),
                  _buildCell((itemPrestamo.cantidadDevuelta ?? 0).toString()),
                  _buildCell(itemPrestamo.cantidadPendiente.toString()),
                  _buildCell(itemPrestamo.estadoDevuelto?.displayName ?? 'Pendiente'),
                ],
              );
            }).toList(),
          ],
        ),
      );

      // Espacio entre préstamos
      widgets.add(pw.SizedBox(height: 15));
    }

    return pw.Column(children: widgets);
  }

// Nuevo método para crear pills de estado
  static pw.Widget _buildEstadoPill(EstadoPrestamo estado) {
    PdfColor color;
    switch (estado) {
      case EstadoPrestamo.activo:
        color = PdfColors.green;
        break;
      case EstadoPrestamo.vencido:
        color = PdfColors.red;
        break;
      case EstadoPrestamo.parcial:
        color = PdfColors.orange;
        break;
      case EstadoPrestamo.devuelto:
        color = PdfColors.blue;
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.2),
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Text(
        _getEstadoPrestamoDisplay(estado),
        style: pw.TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

// MÉTODO AUXILIAR CORREGIDO PARA OBTENER PRÉSTAMOS
  // En reports_service.dart - Reemplazar el método _obtenerPrestamos

  static Future<List<Prestamo>> _obtenerPrestamos({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    EstadoPrestamo? estado,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection('prestamos');

      // Filtrar por rango de fechas
      query = query
          .where('fechaCreacion', isGreaterThanOrEqualTo: fechaInicio.toIso8601String())
          .where('fechaCreacion', isLessThanOrEqualTo: fechaFin.toIso8601String())
          .orderBy('fechaCreacion', descending: true);

      QuerySnapshot snapshot = await query.get();
      List<Prestamo> prestamos = snapshot.docs
          .map((doc) => Prestamo.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Filtrar por estado si se especifica
      if (estado != null) {
        prestamos = prestamos.where((p) => p.estado == estado).toList();
      }

      return prestamos;
    } catch (e) {
      print('Error al obtener préstamos: $e');
      throw Exception('Error al obtener préstamos: $e');
    }
  }

// MÉTODO AUXILIAR CORREGIDO PARA CONSTRUIR TABLA DE PRÉSTAMOS
  static pw.Widget _buildTablaPrestamos(
      List<Prestamo> prestamos,
      Map<String, UnidadScout> unidades,
      Map<String, Ubicacion> ubicaciones,
      ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            _buildCellHeader('Solicitante'),
            _buildCellHeader('Rama Scout'),
            _buildCellHeader('Fecha Préstamo'),
            _buildCellHeader('Fecha Devolución'),
            _buildCellHeader('Estado'),
          ],
        ),
        // Datos
        ...prestamos.map((prestamo) {

          return pw.TableRow(
            children: [
              _buildCell('${prestamo.nombreSolicitante}\nTel: ${prestamo.telefono}'),
              _buildCell('${prestamo.ramaScout}\n'),
              _buildCell(_dateFormatter.format(prestamo.fechaPrestamo)),
              _buildCell(
                  _dateFormatter.format(prestamo.fechaDevolucionEsperada)),
              _buildCellEstado(prestamo.estado),
            ],
          );
        }).toList(),
      ],
    );
  }
  // 2. REPORTE DE ITEMS MÁS SOLICITADOS
  static Future<Uint8List> generarReporteItemsSolicitados({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int limite = 20,
  }) async {
    try {
      List<ItemSolicitado> itemsSolicitados = await _calcularItemsSolicitados(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        limite: limite,
      );

      final pdf = pw.Document();
      String subtitulo =
          'Período: ${_dateFormatter.format(fechaInicio)} - ${_dateFormatter.format(fechaFin)} | Top $limite items';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildHeader('ITEMS MÁS SOLICITADOS', subtitulo),
          footer: (context) =>
              _buildFooter(context.pageNumber, context.pagesCount),
          build: (context) {
            List<pw.Widget> widgets = [];

            if (itemsSolicitados.isEmpty) {
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    'No se encontraron items solicitados en el período especificado.',
                    style: const pw.TextStyle(fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              );
            } else {
              widgets.add(_buildTablaItemsSolicitados(itemsSolicitados));
            }

            return widgets;
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      throw Exception('Error al generar reporte de items solicitados: $e');
    }
  }

  // 3. REPORTE DE PRÉSTAMOS VENCIDOS Y PRÓXIMOS A VENCER
  static Future<Uint8List> generarReportePrestamosVencidos({
    int diasProximoVencimiento = 7,
  }) async {
    try {
      DateTime ahora = DateTime.now();
      DateTime limiteFuturo = ahora.add(Duration(days: diasProximoVencimiento));

      List<Prestamo> prestamosVencidos = [];
      List<Prestamo> prestamosProximosAVencer = [];

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('prestamos')
          .where('estado', whereIn: ['activo', 'vencido', 'parcial']).get();

      for (var doc in snapshot.docs) {
        Prestamo prestamo =
        Prestamo.fromMap(doc.data() as Map<String, dynamic>, doc.id);

        if (prestamo.fechaDevolucionEsperada.isBefore(ahora)) {
          prestamosVencidos.add(prestamo);
        } else if (prestamo.fechaDevolucionEsperada.isBefore(limiteFuturo)) {
          prestamosProximosAVencer.add(prestamo);
        }
      }

      Map<String, UnidadScout> unidades = await _obtenerUnidadesScout();
      Map<String, Ubicacion> ubicaciones = await _obtenerUbicaciones();

      final pdf = pw.Document();
      String subtitulo =
          'Vencidos y próximos a vencer (${diasProximoVencimiento} días) - ${_dateFormatter.format(ahora)}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) =>
              _buildHeader('PRÉSTAMOS VENCIDOS Y PRÓXIMOS A VENCER', subtitulo),
          footer: (context) =>
              _buildFooter(context.pageNumber, context.pagesCount),
          build: (context) {
            List<pw.Widget> widgets = [];

            // Estadísticas
            widgets.add(_buildEstadisticasVencimientos(
                prestamosVencidos, prestamosProximosAVencer));
            widgets.add(pw.SizedBox(height: 20));

            // Préstamos vencidos
            if (prestamosVencidos.isNotEmpty) {
              widgets.add(_buildSeccionPrestamosVencidos(
                  prestamosVencidos, unidades, ubicaciones));
              widgets.add(pw.SizedBox(height: 20));
            }

            // Préstamos próximos a vencer
            if (prestamosProximosAVencer.isNotEmpty) {
              widgets.add(_buildSeccionPrestamosProximosVencer(
                  prestamosProximosAVencer, unidades, ubicaciones));
            }

            if (prestamosVencidos.isEmpty && prestamosProximosAVencer.isEmpty) {
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.green400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    '✓ No hay préstamos vencidos ni próximos a vencer.',
                    style:
                    pw.TextStyle(fontSize: 14, color: PdfColors.green800),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              );
            }

            return widgets;
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      throw Exception('Error al generar reporte de vencimientos: $e');
    }
  }

  // 4. REPORTE COMPLETO DE ITEMS
  static Future<Uint8List> generarReporteItems({
    EstadoItem? filtroEstado,
    String? filtroTipoId,
    String? filtroUbicacionId,
  }) async {
    try {
      List<Item> items = await _obtenerItemsFiltrados(
        estado: filtroEstado,
        tipoId: filtroTipoId,
        ubicacionId: filtroUbicacionId,
      );

      Map<String, TipoItemPersonalizado> tipos = await _obtenerTiposItem();
      Map<String, Ubicacion> ubicaciones = await _obtenerUbicaciones();
      EstadisticasReporte estadisticas = await _calcularEstadisticasItems();

      final pdf = pw.Document();

      String subtitulo = 'Inventario completo';
      if (filtroEstado != null)
        subtitulo += ' | Estado: ${filtroEstado.displayName}';
      if (filtroTipoId != null && tipos.containsKey(filtroTipoId)) {
        subtitulo += ' | Tipo: ${tipos[filtroTipoId]!.nombre}';
      }
      if (filtroUbicacionId != null &&
          ubicaciones.containsKey(filtroUbicacionId)) {
        subtitulo += ' | Ubicación: ${ubicaciones[filtroUbicacionId]!.nombre}';
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildHeader('REPORTE DE INVENTARIO', subtitulo),
          footer: (context) =>
              _buildFooter(context.pageNumber, context.pagesCount),
          build: (context) {
            List<pw.Widget> widgets = [];

            // Estadísticas generales
            widgets.add(_buildEstadisticasItems(estadisticas));
            widgets.add(pw.SizedBox(height: 20));

            if (items.isEmpty) {
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    'No se encontraron items con los filtros aplicados.',
                    style: const pw.TextStyle(fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              );
            } else {
              // Tabla de items
              widgets.add(_buildTablaItems(items, tipos, ubicaciones));
            }

            return widgets;
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      throw Exception('Error al generar reporte de items: $e');
    }
  }

  // MÉTODOS AUXILIARES PARA OBTENER DATOS

  static Future<Map<String, UnidadScout>> _obtenerUnidadesScout() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('unidades_scout').get();
    Map<String, UnidadScout> unidades = {};
    for (var doc in snapshot.docs) {
      unidades[doc.id] =
          UnidadScout.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return unidades;
  }

  static Future<Map<String, Ubicacion>> _obtenerUbicaciones() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('ubicaciones').get();
    Map<String, Ubicacion> ubicaciones = {};
    for (var doc in snapshot.docs) {
      ubicaciones[doc.id] =
          Ubicacion.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return ubicaciones;
  }

  static Future<Map<String, TipoItemPersonalizado>> _obtenerTiposItem() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('tipos_item').get();
    Map<String, TipoItemPersonalizado> tipos = {};
    for (var doc in snapshot.docs) {
      tipos[doc.id] = TipoItemPersonalizado.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    }
    return tipos;
  }

  static Future<List<Item>> _obtenerItemsFiltrados({
    EstadoItem? estado,
    String? tipoId,
    String? ubicacionId,
  }) async {
    Query query = FirebaseFirestore.instance.collection('items');

    if (estado != null) {
      query = query.where('estado', isEqualTo: estado.name);
    }
    if (tipoId != null) {
      query = query.where('tipoId', isEqualTo: tipoId);
    }
    if (ubicacionId != null) {
      query = query.where('ubicacionId', isEqualTo: ubicacionId);
    }

    QuerySnapshot snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Item.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  static Future<List<ItemSolicitado>> _calcularItemsSolicitados({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required int limite,
  }) async {
    Map<String, ItemSolicitado> itemsMap = {};

    QuerySnapshot prestamosSnapshot = await FirebaseFirestore.instance
        .collection('prestamos')
        .where('fechaCreacion',
        isGreaterThanOrEqualTo: fechaInicio.toIso8601String())
        .where('fechaCreacion', isLessThanOrEqualTo: fechaFin.toIso8601String())
        .get();

    Map<String, Item> itemsCache = {};
    Map<String, TipoItemPersonalizado> tiposCache = await _obtenerTiposItem();

    for (var doc in prestamosSnapshot.docs) {
      Prestamo prestamo =
      Prestamo.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      for (ItemPrestamo itemPrestamo in prestamo.items) {
        String itemId = itemPrestamo.itemId;

        if (!itemsCache.containsKey(itemId)) {
          Item? item = await FirebaseService.getItemById(itemId);
          if (item != null) {
            itemsCache[itemId] = item;
          } else {
            continue;
          }
        }

        Item item = itemsCache[itemId]!;
        String tipoNombre = 'Sin tipo';

        if (item.tipoId != null && tiposCache.containsKey(item.tipoId)) {
          tipoNombre = tiposCache[item.tipoId]!.nombre;
        }

        if (itemsMap.containsKey(itemId)) {
          ItemSolicitado existing = itemsMap[itemId]!;
          itemsMap[itemId] = ItemSolicitado(
            itemId: itemId,
            nombre: existing.nombre,
            totalSolicitado:
            existing.totalSolicitado + itemPrestamo.cantidadPrestada,
            vecesPrestado: existing.vecesPrestado + 1,
            tipoNombre: existing.tipoNombre,
            estado: existing.estado,
          );
        } else {
          itemsMap[itemId] = ItemSolicitado(
            itemId: itemId,
            nombre: item.nombre,
            totalSolicitado: itemPrestamo.cantidadPrestada,
            vecesPrestado: 1,
            tipoNombre: tipoNombre,
            estado: item.estado,
          );
        }
      }
    }

    List<ItemSolicitado> items = itemsMap.values.toList();
    items.sort((a, b) => b.totalSolicitado.compareTo(a.totalSolicitado));

    return items.take(limite).toList();
  }

  static Future<EstadisticasReporte> _calcularEstadisticasItems() async {
    QuerySnapshot itemsSnapshot =
    await FirebaseFirestore.instance.collection('items').get();
    QuerySnapshot prestamosSnapshot =
    await FirebaseFirestore.instance.collection('prestamos').get();

    Map<EstadoItem, int> itemsPorEstado = {};
    Map<String, int> itemsPorTipo = {};
    Map<String, TipoItemPersonalizado> tiposCache = await _obtenerTiposItem();

    int prestamosActivos = 0;
    int prestamosVencidos = 0;
    int prestamosProximosAVencer = 0;
    DateTime ahora = DateTime.now();
    DateTime limiteFuturo = ahora.add(const Duration(days: 7));

    // Contar préstamos por estado
    for (var doc in prestamosSnapshot.docs) {
      Prestamo prestamo =
      Prestamo.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      if (prestamo.estado == EstadoPrestamo.activo ||
          prestamo.estado == EstadoPrestamo.parcial) {
        prestamosActivos++;

        if (prestamo.fechaDevolucionEsperada.isBefore(ahora)) {
          prestamosVencidos++;
        } else if (prestamo.fechaDevolucionEsperada.isBefore(limiteFuturo)) {
          prestamosProximosAVencer++;
        }
      }
    }

    // Contar items por estado y tipo
    for (var doc in itemsSnapshot.docs) {
      Item item = Item.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Por estado
      itemsPorEstado[item.estado] = (itemsPorEstado[item.estado] ?? 0) + 1;

      // Por tipo
      String tipoNombre = 'Sin tipo';
      if (item.tipoId != null && tiposCache.containsKey(item.tipoId)) {
        tipoNombre = tiposCache[item.tipoId]!.nombre;
      }
      itemsPorTipo[tipoNombre] = (itemsPorTipo[tipoNombre] ?? 0) + 1;
    }

    return EstadisticasReporte(
      totalItems: itemsSnapshot.docs.length,
      totalPrestamos: prestamosSnapshot.docs.length,
      prestamosActivos: prestamosActivos,
      prestamosVencidos: prestamosVencidos,
      prestamosProximosAVencer: prestamosProximosAVencer,
      itemsPorEstado: itemsPorEstado,
      itemsPorTipo: itemsPorTipo,
    );
  }

  // MÉTODOS PARA CONSTRUIR WIDGETS DEL PDF

  static pw.Widget _buildEstadisticasPrestamos(List<Prestamo> prestamos) {
    Map<EstadoPrestamo, int> estadisticas = {};
    double valorTotal = 0;

    for (var prestamo in prestamos) {
      estadisticas[prestamo.estado] = (estadisticas[prestamo.estado] ?? 0) + 1;
      valorTotal += prestamo.items.length; // O usar valor real si existe
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUMEN ESTADÍSTICO',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total de préstamos: ${prestamos.length}'),
                  pw.Text('Items prestados: ${valorTotal.toInt()}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  ...estadisticas.entries.map(
                        (entry) => pw.Text(
                        '${_getEstadoPrestamoDisplay(entry.key)}: ${entry.value}'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }


  static pw.Widget _buildTablaItemsSolicitados(List<ItemSolicitado> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            _buildCellHeader('#'),
            _buildCellHeader('Item'),
            _buildCellHeader('Tipo'),
            _buildCellHeader('Total Solicitado'),
            _buildCellHeader('Veces Prestado'),
            _buildCellHeader('Estado'),
          ],
        ),
        // Datos
        ...items.asMap().entries.map((entry) {
          int index = entry.key + 1;
          ItemSolicitado item = entry.value;
          return pw.TableRow(
            children: [
              _buildCell(index.toString()),
              _buildCell(item.nombre),
              _buildCell(item.tipoNombre),
              _buildCell(item.totalSolicitado.toString()),
              _buildCell(item.vecesPrestado.toString()),
              _buildCellEstadoItem(item.estado),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTablaItems(
      List<Item> items,
      Map<String, TipoItemPersonalizado> tipos,
      Map<String, Ubicacion> ubicaciones,
      ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            _buildCellHeader('Item'),
            _buildCellHeader('Tipo'),
            _buildCellHeader('Ubicación'),
            _buildCellHeader('Cantidad'),
            _buildCellHeader('Estado'),
          ],
        ),
        // Datos
        ...items.map((item) {
          String tipoNombre = 'Sin tipo';
          if (item.tipoId != null && tipos.containsKey(item.tipoId)) {
            tipoNombre = tipos[item.tipoId]!.nombre;
          }
          String ubicacionNombre =
              ubicaciones[item.ubicacionId]?.nombre ?? 'N/A';

          return pw.TableRow(
            children: [
              _buildCell(item.nombre),
              _buildCell(tipoNombre),
              _buildCell(ubicacionNombre),
              _buildCell(item.cantidad.toString()),
              _buildCellEstadoItem(item.estado),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildEstadisticasItems(EstadisticasReporte estadisticas) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUMEN ESTADÍSTICO DEL INVENTARIO',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ITEMS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total de items: ${estadisticas.totalItems}'),
                    pw.SizedBox(height: 8),
                    pw.Text('POR ESTADO:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ...estadisticas.itemsPorEstado.entries.map(
                          (entry) => pw.Text(
                          '${entry.key.displayName}: ${entry.value}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PRÉSTAMOS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total: ${estadisticas.totalPrestamos}'),
                    pw.Text('Activos: ${estadisticas.prestamosActivos}'),
                    pw.Text('Vencidos: ${estadisticas.prestamosVencidos}'),
                    pw.Text(
                        'Próximos a vencer: ${estadisticas.prestamosProximosAVencer}'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('POR TIPO:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ...estadisticas.itemsPorTipo.entries.take(8).map(
                          (entry) => pw.Text('${entry.key}: ${entry.value}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                    if (estadisticas.itemsPorTipo.length > 8)
                      pw.Text(
                          '... y ${estadisticas.itemsPorTipo.length - 8} más',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEstadisticasVencimientos(
      List<Prestamo> vencidos,
      List<Prestamo> proximosVencer,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border.all(color: PdfColors.red200),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text(
                '${vencidos.length}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red800,
                ),
              ),
              pw.Text('VENCIDOS',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                '${proximosVencer.length}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange800,
                ),
              ),
              pw.Text('PRÓXIMOS A VENCER',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSeccionPrestamosVencidos(
      List<Prestamo> prestamos,
      Map<String, UnidadScout> unidades,
      Map<String, Ubicacion> ubicaciones,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const pw.BoxDecoration(color: PdfColors.red100),
          child: pw.Text(
            'PRÉSTAMOS VENCIDOS (${prestamos.length})',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
          ),
        ),
        pw.SizedBox(height: 5),
        _buildTablaPrestamosVencidos(prestamos, unidades, ubicaciones, true),
      ],
    );
  }

  static pw.Widget _buildSeccionPrestamosProximosVencer(
      List<Prestamo> prestamos,
      Map<String, UnidadScout> unidades,
      Map<String, Ubicacion> ubicaciones,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const pw.BoxDecoration(color: PdfColors.orange100),
          child: pw.Text(
            'PRÓXIMOS A VENCER (${prestamos.length})',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.orange800),
          ),
        ),
        pw.SizedBox(height: 5),
        _buildTablaPrestamosVencidos(prestamos, unidades, ubicaciones, false),
      ],
    );
  }

  static pw.Widget _buildTablaPrestamosVencidos(
      List<Prestamo> prestamos,
      Map<String, UnidadScout> unidades,
      Map<String, Ubicacion> ubicaciones,
      bool esVencido,
      ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: esVencido ? PdfColors.red100 : PdfColors.orange100,
          ),
          children: [
            _buildCellHeader('Solicitante'),
            _buildCellHeader('Unidad Scout'),
            _buildCellHeader('Fecha Devolución'),
            _buildCellHeader('Días'),
            _buildCellHeader('Teléfono'),
          ],
        ),
        // Datos
        ...prestamos.map((prestamo) {
          String nombreUnidad =
              unidades[prestamo.unidadScoutId]?.nombreUnidad ?? 'N/A';
          int diasDiferencia = DateTime.now()
              .difference(prestamo.fechaDevolucionEsperada)
              .inDays;
          String diasTexto = esVencido ? '+$diasDiferencia' : '$diasDiferencia';

          return pw.TableRow(
            children: [
              _buildCell('${prestamo.nombreSolicitante}\n${prestamo.telefono}'),
              _buildCell(nombreUnidad),
              _buildCell(
                  _dateFormatter.format(prestamo.fechaDevolucionEsperada)),
              _buildCell(diasTexto),
              _buildCell(prestamo.telefono),
            ],
          );
        }).toList(),
      ],
    );
  }

  // MÉTODOS AUXILIARES PARA CELDAS

  static pw.Widget _buildCellHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  static pw.Widget _buildCellEstado(EstadoPrestamo estado) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: pw.Text(
          _getEstadoPrestamoDisplay(estado),
          style: pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _buildCellEstadoItem(EstadoItem estado) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),

        child: pw.Text(
          estado.displayName,
          style: pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  // MÉTODOS AUXILIARES

  static String _getEstadoPrestamoDisplay(EstadoPrestamo estado) {
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

  // MÉTODO PARA GUARDAR PDF
  static Future<File> guardarPDF(
      Uint8List pdfData, String nombreArchivo) async {
    try {
      // Usar el nuevo servicio de exportación
      return await PdfExportService.guardarPDF(pdfData, nombreArchivo);
    } catch (e) {
      throw Exception('Error al guardar PDF: $e');
    }
  }

  // MÉTODO PARA COMPARTIR PDF
  static Future<void> compartirPDF(
      Uint8List pdfData, String nombreArchivo) async {
    try {
      // Usar el nuevo servicio de exportación
      await PdfExportService.compartirPDF(pdfData, nombreArchivo);
    } catch (e) {
      throw Exception('Error al compartir PDF: $e');
    }
  }

  // MÉTODO PARA EXPORTAR CON OPCIONES
  static Future<void> exportarPDFConOpciones(
      BuildContext context,
      Uint8List pdfData,
      String nombreArchivo,
      ) async {
    try {
      await PdfExportService.guardarYCompartirPDF(
          context, pdfData, nombreArchivo);
    } catch (e) {
      throw Exception('Error al exportar PDF: $e');
    }
  }

  // MÉTODO PARA OBTENER ESTADÍSTICAS RÁPIDAS
  static Future<Map<String, dynamic>> obtenerEstadisticasRapidas() async {
    try {
      EstadisticasReporte estadisticas = await _calcularEstadisticasItems();

      DateTime ahora = DateTime.now();
      DateTime inicioMes = DateTime(ahora.year, ahora.month, 1);

      List<Prestamo> prestamosMes = await _obtenerPrestamos(
        fechaInicio: inicioMes,
        fechaFin: ahora,
      );

      return {
        'totalItems': estadisticas.totalItems,
        'totalPrestamos': estadisticas.totalPrestamos,
        'prestamosActivos': estadisticas.prestamosActivos,
        'prestamosVencidos': estadisticas.prestamosVencidos,
        'prestamosProximosVencer': estadisticas.prestamosProximosAVencer,
        'prestamosMesActual': prestamosMes.length,
        'itemsPorEstado': estadisticas.itemsPorEstado,
        'itemsPorTipo': estadisticas.itemsPorTipo,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  // MÉTODO PARA GENERAR REPORTE PERSONALIZADO
  static Future<Uint8List> generarReportePersonalizado({
    required String tipoReporte,
    Map<String, dynamic>? parametros,
  }) async {
    try {
      switch (tipoReporte) {
        case 'prestamos_rango':
          return await generarReportePrestamos(
            fechaInicio: parametros?['fechaInicio'] ??
                DateTime.now().subtract(const Duration(days: 30)),
            fechaFin: parametros?['fechaFin'] ?? DateTime.now(),
            unidadScoutId: parametros?['unidadScoutId'],
            estado: parametros?['estado'],
          );

        case 'items_solicitados':
          return await generarReporteItemsSolicitados(
            fechaInicio: parametros?['fechaInicio'] ??
                DateTime.now().subtract(const Duration(days: 30)),
            fechaFin: parametros?['fechaFin'] ?? DateTime.now(),
            limite: parametros?['limite'] ?? 20,
          );

        case 'vencimientos':
          return await generarReportePrestamosVencidos(
            diasProximoVencimiento: parametros?['dias'] ?? 7,
          );

        case 'inventario':
          return await generarReporteItems(
            filtroEstado: parametros?['estado'],
            filtroTipoId: parametros?['tipoId'],
            filtroUbicacionId: parametros?['ubicacionId'],
          );

        default:
          throw Exception('Tipo de reporte no reconocido: $tipoReporte');
      }
    } catch (e) {
      throw Exception('Error al generar reporte personalizado: $e');
    }
  }
}
