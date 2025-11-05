import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prestamo.dart';
import '../models/item.dart';
import '../services/firebase_service.dart';
import 'reports_screen.dart';

class ReportsDashboard extends StatefulWidget {
  const ReportsDashboard({Key? key}) : super(key: key);

  @override
  State<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<ReportsDashboard> {
  bool _cargando = true;

  // Estadísticas
  int _totalItems = 0;
  int _totalPrestamos = 0;
  int _prestamosActivos = 0;
  int _prestamosVencidos = 0;
  int _prestamosProximosVencer = 0;
  int _itemsExcelente = 0;
  int _itemsBueno = 0;
  int _itemsMalo = 0;
  int _itemsPerdidos = 0;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    try {
      setState(() {
        _cargando = true;
      });

      // Cargar estadísticas de items
      await _cargarEstadisticasItems();

      // Cargar estadísticas de préstamos
      await _cargarEstadisticasPrestamos();

    } catch (e) {
      print('Error al cargar estadísticas: $e');
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  Future<void> _cargarEstadisticasItems() async {
    QuerySnapshot itemsSnapshot = await FirebaseFirestore.instance
        .collection('items')
        .get();

    _totalItems = itemsSnapshot.docs.length;
    _itemsExcelente = 0;
    _itemsBueno = 0;
    _itemsMalo = 0;
    _itemsPerdidos = 0;

    for (var doc in itemsSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String estado = data['estado'] ?? 'excelente';

      switch (estado) {
        case 'excelente':
          _itemsExcelente++;
          break;
        case 'bueno':
          _itemsBueno++;
          break;
        case 'malo':
          _itemsMalo++;
          break;
        case 'perdida':
          _itemsPerdidos++;
          break;
      }
    }
  }

  Future<void> _cargarEstadisticasPrestamos() async {
    QuerySnapshot prestamosSnapshot = await FirebaseFirestore.instance
        .collection('prestamos')
        .get();

    _totalPrestamos = prestamosSnapshot.docs.length;
    _prestamosActivos = 0;
    _prestamosVencidos = 0;
    _prestamosProximosVencer = 0;

    DateTime ahora = DateTime.now();
    DateTime limiteFuturo = ahora.add(const Duration(days: 7));

    for (var doc in prestamosSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String estado = data['estado'] ?? 'activo';

      if (estado == 'activo' || estado == 'parcial') {
        _prestamosActivos++;

        // Verificar si está vencido o próximo a vencer
        String fechaDevolucionStr = data['fechaDevolucionEsperada'] ?? '';
        DateTime? fechaDevolucion = DateTime.tryParse(fechaDevolucionStr);

        if (fechaDevolucion != null) {
          if (fechaDevolucion.isBefore(ahora)) {
            _prestamosVencidos++;
          } else if (fechaDevolucion.isBefore(limiteFuturo)) {
            _prestamosProximosVencer++;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard de Reportes'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEstadisticas,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeccionEstadisticasGenerales(),
            const SizedBox(height: 10),
            _buildSeccionEstadisticasItems(),
            const SizedBox(height: 10),
            _buildSeccionEstadisticasPrestamos(),
            const SizedBox(height: 10),
            _buildSeccionAlertas(),
            const SizedBox(height: 60),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportsScreen()),
          );
        },
        icon: const Icon(Icons.assessment,size: 18,color: Colors.white),
        label: const Text('Generar Reportes',style: TextStyle(fontSize: 15,color: Colors.white)),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  Widget _buildSeccionEstadisticasGenerales() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Resumen General',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaEstadistica(
                    'Total Items',
                    _totalItems.toString(),
                    Icons.inventory,
                    Colors.blue[600]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTarjetaEstadistica(
                    'Total Préstamos',
                    _totalPrestamos.toString(),
                    Icons.assignment,
                    Colors.green[600]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaEstadistica(
                    'Préstamos Activos',
                    _prestamosActivos.toString(),
                    Icons.hourglass_empty,
                    Colors.orange[600]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTarjetaEstadistica(
                    'Items Perdidos',
                    _itemsPerdidos.toString(),
                    Icons.warning,
                    Colors.red[600]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEstadisticasItems() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Estado del Inventario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBarraProgreso(
              'Excelente Estado',
              _itemsExcelente,
              _totalItems,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildBarraProgreso(
              'Buen Estado',
              _itemsBueno,
              _totalItems,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildBarraProgreso(
              'Mal Estado',
              _itemsMalo,
              _totalItems,
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildBarraProgreso(
              'Perdidos',
              _itemsPerdidos,
              _totalItems,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEstadisticasPrestamos() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_late, color: Colors.amber[700]),
                const SizedBox(width: 8),
                Text(
                  'Estado de Préstamos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTarjetaIndicador(
                    'Activos',
                    _prestamosActivos.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTarjetaIndicador(
                    'Vencidos',
                    _prestamosVencidos.toString(),
                    Colors.red,
                    Icons.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTarjetaIndicador(
                    'Por Vencer',
                    _prestamosProximosVencer.toString(),
                    Colors.orange,
                    Icons.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionAlertas() {
    List<Widget> alertas = [];

    if (_prestamosVencidos > 0) {
      alertas.add(_buildAlerta(
        'Préstamos Vencidos',
        'Hay $_prestamosVencidos préstamos vencidos que requieren atención inmediata.',
        Colors.red,
        Icons.error,
      ));
    }

    if (_prestamosProximosVencer > 0) {
      alertas.add(_buildAlerta(
        'Próximos a Vencer',
        'Hay $_prestamosProximosVencer préstamos que vencen en los próximos 7 días.',
        Colors.orange,
        Icons.warning,
      ));
    }

    if (_itemsPerdidos > 0) {
      alertas.add(_buildAlerta(
        'Items Perdidos',
        'Hay $_itemsPerdidos items marcados como perdidos en el inventario.',
        Colors.purple,
        Icons.help_outline,
      ));
    }

    if (alertas.isEmpty) {
      alertas.add(_buildAlerta(
        'Todo en Orden',
        'No hay alertas importantes en este momento.',
        Colors.green,
        Icons.check_circle,
      ));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Alertas y Notificaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alertas,
          ],
        ),
      ),
    );
  }


  Widget _buildTarjetaEstadistica(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaIndicador(String titulo, String valor, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraProgreso(String titulo, int valor, int total, Color color) {
    double porcentaje = total > 0 ? valor / total : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('$valor de $total', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: porcentaje,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildAlerta(String titulo, String descripcion, Color color, IconData icono) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccionRapida(String titulo, IconData icono, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navegarAReportes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsScreen()),
    );
  }
}