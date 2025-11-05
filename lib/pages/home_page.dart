import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventario_gsls/pages/item_list_screen.dart';
import 'package:inventario_gsls/pages/notification_settings_screen.dart';
import 'package:inventario_gsls/pages/prestamos_list_screen.dart';
import 'package:inventario_gsls/pages/reports_dashboard.dart';
import 'package:inventario_gsls/pages/ubicaciones_screen.dart';
import 'package:inventario_gsls/pages/unidades_scout_screen.dart';
import '../services/auth_google.dart';
import '../services/notification_service.dart';
import '../widgets/note_icon_button_outlined.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      await NotificationService.requestPermissions();
    } catch (e) {
      print('Error inicializando notificaciones: $e');
    }
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      // El AuthWrapper se encargará de navegar al login automáticamente
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(232, 238, 242, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(59, 122, 201, 1),
        title: const Text(
          'Inventario GSLS',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(onPressed: _showLogoutDialog, child: const Text('Cerrar Sesión',style: TextStyle(color: Colors.white),)),
        ],

      ),
      body: Column(
        children: [

          // Grid de opciones principales
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(8.0),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              crossAxisCount: 2,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  child: NoteIconButtonOutlined(
                    icon: FontAwesomeIcons.clipboardList,
                    text: 'Inventario',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ItemsListScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: NoteIconButtonOutlined(
                    icon: FontAwesomeIcons.handHoldingDollar,
                    text: 'Prestamos',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrestamosListScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: NoteIconButtonOutlined(
                    icon: FontAwesomeIcons.locationDot,
                    text: 'Ubicaciones',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UbicacionesScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: NoteIconButtonOutlined(
                    icon: FontAwesomeIcons.warehouse,
                    text: 'Reportes',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportsDashboard(),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: NoteIconButtonOutlined(
                    icon: FontAwesomeIcons.users,
                    text: 'Unidades Scout',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UnidadesScoutScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: NoteIconButtonOutlined(
                    icon: Icons.notifications_outlined,
                    text: 'Configuración de Notificaciones',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}