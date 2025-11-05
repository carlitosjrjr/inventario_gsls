import 'package:inventario_gsls/pages/login.dart';
import 'package:inventario_gsls/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:inventario_gsls/services/firebase_service.dart';
import 'firebase_options.dart';
import 'services/auth_google.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'services/notification_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Inicializar sistema de notificaciones
  await FirebaseServiceExtensions.inicializarSistemaNotificaciones();

  // Inicializar servicios
  await SettingsService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // GlobalKey para el navegador
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Inventario',
      // Asignar la clave del navegador
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      // Inicializar notificaciones después de que el widget esté construido
      builder: (context, child) {
        // Inicializar el servicio de notificaciones con la clave del navegador
        NotificationService.initialize(navKey: navigatorKey);
        return child!;
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize(navKey: MyApp.navigatorKey);
      await NotificationService.requestPermissions();
    } catch (e) {
      print('Error al inicializar notificaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Usuario autenticado, verificar si es el correo autorizado
          if (AuthService.isAuthorizedEmail(snapshot.data!.email)) {
            return const HomePage();
          } else {
            // Correo no autorizado, cerrar sesión automáticamente
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AuthService.logout();
            });
            return const LoginPage();
          }
        }

        // No hay usuario autenticado
        return const LoginPage();
      },
    );
  }
}