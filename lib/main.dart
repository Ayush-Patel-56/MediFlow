import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'views/auth/role_selection_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/shared/sidebar_layout.dart';

// Facility Pages
import 'views/facility/facility_overview.dart';
import 'views/facility/ai_forecast_page.dart';
import 'views/facility/indent_creation_page.dart';
import 'views/facility/daily_logging_page.dart';
import 'views/facility/alerts_page.dart';

// Admin Pages
import 'views/admin/admin_overview.dart';
import 'views/admin/route_optimization_map.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _facilityShellNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _adminShellNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Auth now strictly managed by LoginScreen
  runApp(const ProviderScope(child: MediFlowApp()));
}

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/login/:role',
      builder: (context, state) {
        final role = state.pathParameters['role']!;
        return LoginScreen(role: role);
      },
    ),
    
    // Facility Shell
    ShellRoute(
      navigatorKey: _facilityShellNavigatorKey,
      builder: (context, state, child) {
        final pathParams = state.pathParameters;
        return SidebarLayout(role: 'facility', facilityId: pathParams['id'], child: child);
      },
      routes: [
        GoRoute(
          path: '/facility/:id/overview',
          builder: (context, state) => FacilityOverview(facilityId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/facility/:id/forecast',
          builder: (context, state) => AIForecastPage(facilityId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/facility/:id/indent',
          builder: (context, state) => IndentCreationPage(facilityId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/facility/:id/logging',
          builder: (context, state) => DailyLoggingPage(facilityId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/facility/:id/alerts',
          builder: (context, state) => AlertsPage(facilityId: state.pathParameters['id']!),
        ),
      ],
    ),

    // Admin Shell
    ShellRoute(
      navigatorKey: _adminShellNavigatorKey,
      builder: (context, state, child) {
        return SidebarLayout(role: 'admin', child: child);
      },
      routes: [
        GoRoute(
          path: '/admin/overview',
          builder: (context, state) => const AdminOverview(),
        ),
        GoRoute(
          path: '/admin/routing',
          builder: (context, state) => const RouteOptimizationMap(),
        ),
      ],
    ),
  ],
);

class MediFlowApp extends StatelessWidget {
  const MediFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MediFlow Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      routerConfig: _router,
    );
  }
}
