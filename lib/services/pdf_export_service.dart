import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PdfExportService {
  ///Verificar y solicitar permisos para Downloads
  static Future<bool> _solicitarPermisosStorage() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      print('Versión de Android: ${androidInfo.version.sdkInt}');

      // Android 13+ (API 33+) - Permisos granulares
      if (androidInfo.version.sdkInt >= 33) {
        // Para Android 13+, verificar MANAGE_EXTERNAL_STORAGE o usar SAF
        final manageStorage = await Permission.manageExternalStorage.status;

        if (manageStorage.isGranted) {
          return true;
        }

        // Solicitar permiso de gestión de almacenamiento
        final result = await Permission.manageExternalStorage.request();
        if (result.isGranted) {
          return true;
        }

        // Si no se otorga, intentar con permisos normales
        final storage = await Permission.storage.request();
        return storage.isGranted || storage.isLimited;
      }
      // Android 11-12 (API 30-32) - Scoped Storage
      else if (androidInfo.version.sdkInt >= 30) {
        final storage = await Permission.storage.status;
        if (storage.isGranted) {
          return true;
        }

        final result = await Permission.storage.request();
        return result.isGranted || result.isLimited;
      }
      // Android 6-10 (API 23-29) - Permisos tradicionales
      else if (androidInfo.version.sdkInt >= 23) {
        final storage = await Permission.storage.status;
        if (storage.isGranted) {
          return true;
        }

        final result = await Permission.storage.request();
        return result.isGranted;
      }
      // Android 5 y anteriores - Sin permisos runtime
      else {
        return true;
      }
    } else if (Platform.isIOS) {
      return true;
    }
    return false;
  }

  ///Obtener directorio Downloads con carpeta personalizada
  static Future<Directory> _obtenerDirectorioDownloads() async {
    try {
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        // Intentar diferentes rutas de Downloads según la versión de Android
        List<String> possiblePaths = [
          '/storage/emulated/0/Download',
          '/sdcard/Download',
          '/storage/self/primary/Download',
        ];

        // Intentar obtener el directorio de downloads del sistema
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Navegar hacia Downloads desde el directorio externo
            String externalPath = externalDir.path;
            // Típicamente: /storage/emulated/0/Android/data/com.app/files
            String downloadPath = externalPath.split('/Android')[0] + '/Download';
            possiblePaths.insert(0, downloadPath);
          }
        } catch (e) {
          print('No se pudo obtener directorio externo: $e');
        }

        // Probar cada ruta posible
        for (String path in possiblePaths) {
          Directory testDir = Directory(path);
          if (await testDir.exists()) {
            try {
              // Probar si se puede escribir
              final testFile = File('$path/.test_write_gsls');
              await testFile.writeAsString('test');
              await testFile.delete();
              downloadsDir = testDir;
              print('Directorio Downloads encontrado: $path');
              break;
            } catch (e) {
              print('No se puede escribir en $path: $e');
              continue;
            }
          }
        }

        // Si no se encontró Downloads accesible, usar directorio de la app
        if (downloadsDir == null) {
          print('No se pudo acceder a Downloads, usando directorio de la app');
          final appDir = await getApplicationDocumentsDirectory();
          downloadsDir = Directory('${appDir.path}/Downloads');
        }

      } else if (Platform.isIOS) {
        // Para iOS, usar directorio de documentos
        final appDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${appDir.path}/Downloads');
      } else {
        // Para otras plataformas
        downloadsDir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      }

      // Crear la carpeta "Reportes GSLS" dentro de Downloads
      final reportesDir = Directory('${downloadsDir.path}/Reportes GSLS');

      if (!await reportesDir.exists()) {
        await reportesDir.create(recursive: true);
        print('Carpeta "Reportes GSLS" creada en: ${reportesDir.path}');
      }

      // Verificar que se puede escribir en la carpeta
      final testFile = File('${reportesDir.path}/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();

      print('Directorio final verificado: ${reportesDir.path}');
      return reportesDir;

    } catch (e) {
      print('Error al obtener directorio Downloads: $e');
      // Fallback al directorio de documentos de la app
      final appDir = await getApplicationDocumentsDirectory();
      final fallbackDir = Directory('${appDir.path}/Reportes GSLS');

      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }

      print('Usando directorio fallback: ${fallbackDir.path}');
      return fallbackDir;
    }
  }

  /// Mostrar diálogo con opciones de exportación - COMPLETO
  static Future<void> _mostrarOpcionesExportacion(
      BuildContext context,
      Uint8List pdfData,
      String nombreArchivo,
      ) async {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Opciones del Reporte',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se guardará en Downloads/Reportes GSLS/',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Opción: Previsualizar
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.visibility, color: Colors.blue[700]),
                  ),
                  title: const Text('Previsualizar'),
                  subtitle: const Text('Ver el reporte antes de guardarlo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await previsualizarPDF(context, pdfData, nombreArchivo);
                    } catch (e) {
                      _mostrarMensajeError(context, 'Error al previsualizar: $e');
                    }
                  },
                ),

                const Divider(height: 1),

                // Opción: Guardar en Downloads
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.download, color: Colors.green[700]),
                  ),
                  title: const Text('Guardar en Downloads'),
                  subtitle: const Text('Guardar en Downloads/Reportes GSLS/'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      File archivo = await guardarPDF(pdfData, nombreArchivo);
                      _mostrarMensajeExito(context, 'PDF guardado en: Downloads/Reportes GSLS/${archivo.uri.pathSegments.last}');
                    } catch (e) {
                      print('Error al guardar: $e');
                      await _mostrarDialogoAlternativo(context, pdfData, nombreArchivo, e.toString());
                    }
                  },
                ),

                const Divider(height: 1),

                // Opción: Compartir
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.share, color: Colors.orange[700]),
                  ),
                  title: const Text('Compartir'),
                  subtitle: const Text('Compartir usando otras aplicaciones'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await compartirPDF(pdfData, nombreArchivo);
                      _mostrarMensajeExito(context, 'Archivo compartido exitosamente');
                    } catch (e) {
                      _mostrarMensajeError(context, 'Error al compartir: $e');
                    }
                  },
                ),

                const Divider(height: 1),

                // Opción: Imprimir
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.print, color: Colors.purple[700]),
                  ),
                  title: const Text('Imprimir'),
                  subtitle: const Text('Enviar a imprimir o guardar como PDF'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await imprimirPDF(pdfData, nombreArchivo);
                    } catch (e) {
                      _mostrarMensajeError(context, 'Error al imprimir: $e');
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Botón Cancelar
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Previsualizar PDF antes de guardar o compartir
  static Future<void> previsualizarPDF(
      BuildContext context,
      Uint8List pdfData,
      String titulo,
      ) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfData,
            titulo: titulo,
          ),
        ),
      );
    } catch (e) {
      throw Exception('Error al mostrar previsualización: $e');
    }
  }

  /// Verificar y solicitar permisos de almacenamiento actualizado para Android
  static Future<bool> _solicitarPermisos() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Para Android 13+ (API 33+), usar permisos específicos
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ no necesita WRITE_EXTERNAL_STORAGE
        return true;
      }
      // Para Android 10-12 (API 29-32)
      else if (androidInfo.version.sdkInt >= 29) {
        // Verificar si ya tenemos permisos
        if (await Permission.storage.isGranted) {
          return true;
        }

        // Solicitar permisos si no los tenemos
        final status = await Permission.storage.request();
        return status.isGranted || status.isLimited;
      }
      // Para Android 9 y anteriores (API 28-)
      else {
        if (await Permission.storage.isGranted) {
          return true;
        }

        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      // Para iOS no necesitamos permisos especiales para documentos de la app
      return true;
    }
    return false;
  }

  /// Obtener el directorio apropiado para guardar PDFs
  static Future<Directory> _obtenerDirectorioGuardado() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        // Para Android 13+ usar directorio de documentos de la app
        if (androidInfo.version.sdkInt >= 33) {
          final directory = await getApplicationDocumentsDirectory();
          final reportsDir = Directory('${directory.path}/reportes');
          if (!await reportsDir.exists()) {
            await reportsDir.create(recursive: true);
          }
          return reportsDir;
        }
        // Para versiones anteriores, intentar directorio público primero
        else {
          try {
            // Intentar crear en Downloads
            final directory = Directory('/storage/emulated/0/Download/ReportesScout');
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }

            // Verificar si podemos escribir
            final testFile = File('${directory.path}/.test');
            await testFile.writeAsString('test');
            await testFile.delete();

            return directory;
          } catch (e) {
            // Si falla, usar directorio de la app
            print('No se pudo acceder a Downloads, usando directorio de la app: $e');
            final directory = await getApplicationDocumentsDirectory();
            final reportsDir = Directory('${directory.path}/reportes');
            if (!await reportsDir.exists()) {
              await reportsDir.create(recursive: true);
            }
            return reportsDir;
          }
        }
      } else {
        // Para iOS, usar el directorio de documentos de la app
        final directory = await getApplicationDocumentsDirectory();
        final reportsDir = Directory('${directory.path}/reportes');
        if (!await reportsDir.exists()) {
          await reportsDir.create(recursive: true);
        }
        return reportsDir;
      }
    } catch (e) {
      print('Error al obtener directorio: $e');
      // Fallback al directorio temporal
      final tempDir = await getTemporaryDirectory();
      return tempDir;
    }
  }

  /// Guardar PDF en el dispositivo
  static Future<File> guardarPDF(Uint8List pdfData, String nombreArchivo) async {
    try {
      print('Iniciando guardado de PDF: $nombreArchivo');

      // 1. LIMPIAR NOMBRE DEL ARCHIVO
      String nombreLimpio = _limpiarNombreArchivo(nombreArchivo);

      // 2. VERIFICAR PERMISOS
      bool tienePermisos = await _solicitarPermisosStorage();
      print('Permisos de almacenamiento: $tienePermisos');

      // 3. OBTENER DIRECTORIO (Downloads o fallback)
      Directory directorio = await _obtenerDirectorioDownloads();

      // 4. CREAR ARCHIVO CON NOMBRE ÚNICO
      File archivo = await _crearArchivoUnico(directorio, nombreLimpio);

      // 5. ESCRIBIR DATOS
      await archivo.writeAsBytes(pdfData);

      print('PDF guardado exitosamente en: ${archivo.path}');
      return archivo;

    } catch (e) {
      print('Error al guardar PDF: $e');
      throw Exception('No se pudo guardar el archivo en Downloads: $e');
    }
  }

  /// LIMPIAR NOMBRE DE ARCHIVO - Eliminar caracteres problemáticos
  static String _limpiarNombreArchivo(String nombre) {
    // Reemplazar caracteres problemáticos
    String nombreLimpio = nombre
        .replaceAll('/', '_')           // Reemplazar barras
        .replaceAll('\\', '_')          // Reemplazar barras invertidas
        .replaceAll(':', '_')           // Reemplazar dos puntos
        .replaceAll('*', '_')           // Reemplazar asteriscos
        .replaceAll('?', '_')           // Reemplazar signos de pregunta
        .replaceAll('"', '_')           // Reemplazar comillas
        .replaceAll('<', '_')           // Reemplazar menor que
        .replaceAll('>', '_')           // Reemplazar mayor que
        .replaceAll('|', '_')           // Reemplazar pipe
        .replaceAll(' ', '_')           // Reemplazar espacios
        .trim();                        // Eliminar espacios al inicio/final

    // Asegurar extensión .pdf
    if (!nombreLimpio.toLowerCase().endsWith('.pdf')) {
      nombreLimpio += '.pdf';
    }

    // Limitar longitud del nombre
    if (nombreLimpio.length > 100) {
      nombreLimpio = nombreLimpio.substring(0, 96) + '.pdf';
    }

    print('📁 Nombre de archivo limpio: $nombreLimpio');
    return nombreLimpio;
  }

  /// OBTENER DIRECTORIO SEGURO - Siempre funcional
  static Future<Directory> _obtenerDirectorioSeguro() async {
    try {
      Directory directorio;

      if (Platform.isAndroid) {
        // Para Android, usar siempre el directorio de documentos de la app
        // Es más confiable que intentar acceder al almacenamiento externo
        final appDir = await getApplicationDocumentsDirectory();
        directorio = Directory('${appDir.path}/reportes_pdf');

      } else if (Platform.isIOS) {
        // Para iOS, usar directorio de documentos
        final appDir = await getApplicationDocumentsDirectory();
        directorio = Directory('${appDir.path}/reportes_pdf');

      } else {
        // Para otras plataformas, usar directorio temporal
        directorio = await getTemporaryDirectory();
      }

      // Crear directorio si no existe
      if (!await directorio.exists()) {
        await directorio.create(recursive: true);
        print('📁 Directorio creado: ${directorio.path}');
      }

      // Verificar que se puede escribir
      final archivoTest = File('${directorio.path}/.test_write');
      await archivoTest.writeAsString('test');
      await archivoTest.delete();

      print('📁 Directorio verificado: ${directorio.path}');
      return directorio;

    } catch (e) {
      print('❌ Error al obtener directorio seguro: $e');
      // Fallback absoluto: directorio temporal
      final tempDir = await getTemporaryDirectory();
      print('📁 Usando directorio temporal como fallback: ${tempDir.path}');
      return tempDir;
    }
  }

  /// CREAR ARCHIVO CON NOMBRE ÚNICO - Evitar conflictos
  static Future<File> _crearArchivoUnico(Directory directorio, String nombreBase) async {
    File archivo = File('${directorio.path}/$nombreBase');

    // Si el archivo no existe, usarlo
    if (!await archivo.exists()) {
      return archivo;
    }

    // Si existe, crear versión numerada
    String nombreSinExt = nombreBase.replaceAll('.pdf', '');
    int contador = 1;

    do {
      String nombreNumerado = '${nombreSinExt}_$contador.pdf';
      archivo = File('${directorio.path}/$nombreNumerado');
      contador++;
    } while (await archivo.exists() && contador < 100);

    print('📁 Archivo único creado: ${archivo.path}');
    return archivo;
  }

  /// VERIFICAR PERMISOS - Actualizado
  static Future<bool> verificarPermisos() async {
    return await _solicitarPermisosStorage();
  }

  /// OBTENER INFORMACIÓN DEL DIRECTORIO
  static Future<String> obtenerInfoDirectorio() async {
    try {
      Directory dir = await _obtenerDirectorioDownloads();
      return dir.path;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// COMPARTIR PDF - Sin cambios, ya funciona bien
  static Future<void> compartirPDF(
      Uint8List pdfData,
      String nombreArchivo, {
        String? texto,
        Rect? sharePositionOrigin,
      }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      String nombreLimpio = _limpiarNombreArchivo(nombreArchivo);
      final tempFile = File('${tempDir.path}/$nombreLimpio');
      await tempFile.writeAsBytes(pdfData);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: texto ?? 'Reporte generado desde el Sistema de Inventario Scout',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      throw Exception('Error al compartir PDF: $e');
    }
  }

  /// IMPRIMIR PDF
  static Future<void> imprimirPDF(
      Uint8List pdfData,
      String nombreDocumento,
      ) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) => pdfData,
        name: _limpiarNombreArchivo(nombreDocumento),
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      throw Exception('Error al imprimir PDF: $e');
    }
  }

  /// GUARDAR Y COMPARTIR CON OPCIONES - Mejorado
  static Future<void> guardarYCompartirPDF(
      BuildContext context,
      Uint8List pdfData,
      String nombreArchivo, {
        bool mostrarOpciones = true,
      }) async {
    try {
      if (mostrarOpciones) {
        await _mostrarOpcionesExportacion(context, pdfData, nombreArchivo);
      } else {
        try {
          File archivo = await guardarPDF(pdfData, nombreArchivo);
          _mostrarMensajeExito(context, 'PDF guardado en Downloads/Reportes GSLS/${archivo.uri.pathSegments.last}');
        } catch (e) {
          print('Error al guardar directamente: $e');
          await _mostrarDialogoAlternativo(context, pdfData, nombreArchivo, e.toString());
        }
      }
    } catch (e) {
      _mostrarMensajeError(context, 'Error: $e');
    }
  }

  /// Mostrar diálogo alternativo cuando falla el guardado
  static Future<void> _mostrarDialogoAlternativo(
      BuildContext context,
      Uint8List pdfData,
      String nombreArchivo,
      String errorDetalle,
      ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('No se pudo guardar en Downloads'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No se pudo guardar el archivo en Downloads/Reportes GSLS/.'),
            const SizedBox(height: 8),
            const Text('Posibles causas:'),
            const Text('• Permisos de almacenamiento denegados'),
            const Text('• Espacio insuficiente en el dispositivo'),
            const Text('• Directorio no accesible'),
            const SizedBox(height: 12),
            const Text('Opciones disponibles:'),
            const Text('• Compartir usando otras aplicaciones'),
            const Text('• Enviar a imprimir'),
            const Text('• Previsualizar el documento'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await previsualizarPDF(context, pdfData, nombreArchivo);
              } catch (e) {
                _mostrarMensajeError(context, 'Error al previsualizar: $e');
              }
            },
            child: const Text('Previsualizar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await imprimirPDF(pdfData, nombreArchivo);
              } catch (e) {
                _mostrarMensajeError(context, 'Error al imprimir: $e');
              }
            },
            child: const Text('Imprimir'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await compartirPDF(pdfData, nombreArchivo);
                _mostrarMensajeExito(context, 'Archivo compartido exitosamente');
              } catch (e) {
                _mostrarMensajeError(context, 'Error al compartir: $e');
              }
            },
            child: const Text('Compartir'),
          ),
        ],
      ),
    );
  }

  /// Mostrar mensaje de éxito
  static void _mostrarMensajeExito(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Mostrar mensaje de error
  static void _mostrarMensajeError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Obtener lista de archivos PDF guardados
  static Future<List<File>> obtenerReportesGuardados() async {
    try {
      Directory directory = await _obtenerDirectorioGuardado();
      List<FileSystemEntity> archivos = directory.listSync();

      return archivos
          .where((archivo) => archivo is File && archivo.path.toLowerCase().endsWith('.pdf'))
          .cast<File>()
          .toList();
    } catch (e) {
      print('Error al obtener reportes guardados: $e');
      return [];
    }
  }

  /// Eliminar archivo PDF
  static Future<bool> eliminarReporte(File archivo) async {
    try {
      if (await archivo.exists()) {
        await archivo.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error al eliminar reporte: $e');
      return false;
    }
  }
  /// MOSTRAR DIÁLOGO INFORMATIVO SOBRE LA UBICACIÓN
  static Future<void> mostrarInfoUbicacion(BuildContext context) async {
    try {
      String ubicacion = await obtenerInfoDirectorio();
      bool permisos = await verificarPermisos();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.folder, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Ubicación de Reportes'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Los reportes se guardan en:'),
              const SizedBox(height: 8),
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
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    permisos ? Icons.check_circle : Icons.warning,
                    color: permisos ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    permisos ? 'Permisos OK' : 'Permisos limitados',
                    style: TextStyle(
                      color: permisos ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (!permisos) ...[
                const SizedBox(height: 8),
                const Text(
                  'Si no tienes permisos completos, los archivos se guardarán en el directorio de la aplicación.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            if (!permisos)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _solicitarPermisosStorage();
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener información: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Pantalla de previsualización de PDF
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfData;
  final String titulo;

  const PdfPreviewScreen({
    Key? key,
    required this.pdfData,
    required this.titulo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vista Previa: $titulo'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // Botón Compartir
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
            onPressed: () async {
              try {
                await PdfExportService.compartirPDF(pdfData, titulo);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Archivo compartido exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al compartir: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          // Botón Imprimir
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir',
            onPressed: () async {
              try {
                await PdfExportService.imprimirPDF(pdfData, titulo);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al imprimir: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfData,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canDebug: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            File archivo = await PdfExportService.guardarPDF(pdfData, titulo);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF guardado en Downloads/Reportes GSLS/${archivo.uri.pathSegments.last}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          } catch (e) {
            // Si falla guardar en Downloads, ofrecer alternativas
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Error al guardar en Downloads'),
                content: Text('No se pudo guardar en Downloads/Reportes GSLS/\n\nError: $e\n\n¿Deseas compartirlo en su lugar?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      try {
                        await PdfExportService.compartirPDF(pdfData, titulo);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Archivo compartido exitosamente'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al compartir: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Compartir'),
                  ),
                ],
              ),
            );
          }
        },
        icon: const Icon(Icons.download),
        label: const Text('Guardar en Downloads'),
        backgroundColor: Colors.green,
      ),
    );
  }

}