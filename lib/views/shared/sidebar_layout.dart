import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SidebarLayout extends StatelessWidget {
  final Widget child;
  final String role; // 'facility' or 'admin'
  final String? facilityId;

  const SidebarLayout({
    super.key, 
    required this.child, 
    required this.role,
    this.facilityId,
  });

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (role == 'facility') {
      if (location.endsWith('/overview')) return 0;
      if (location.endsWith('/forecast')) return 1;
      if (location.endsWith('/indent')) return 2;
      if (location.endsWith('/logging')) return 3;
      if (location.endsWith('/alerts')) return 4;
      if (location.endsWith('/help')) return 5;
      return 0;
    } else {
      if (location.endsWith('/overview')) return 0;
      if (location.endsWith('/routing')) return 1;
      if (location.endsWith('/help')) return 2;
      return 0;
    }
  }

  void _onItemTapped(int index, BuildContext context) {
    if (role == 'facility' && facilityId != null) {
      switch (index) {
        case 0: context.go('/facility/$facilityId/overview'); break;
        case 1: context.go('/facility/$facilityId/forecast'); break;
        case 2: context.go('/facility/$facilityId/indent'); break;
        case 3: context.go('/facility/$facilityId/logging'); break;
        case 4: context.go('/facility/$facilityId/alerts'); break;
        case 5: context.go('/facility/$facilityId/help'); break;
      }
    } else if (role == 'admin') {
      switch (index) {
        case 0: context.go('/admin/overview'); break;
        case 1: context.go('/admin/routing'); break;
        case 2: context.go('/admin/help'); break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onItemTapped(index, context),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
            selectedLabelTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Icon(
                role == 'facility' ? Icons.local_hospital : Icons.admin_panel_settings,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                    onPressed: () => context.go('/'),
                  ),
                ),
              ),
            ),
            destinations: role == 'facility'
                ? const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
                    NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: Text('AI Forecast')),
                    NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Indents')),
                    NavigationRailDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: Text('Daily Log')),
                    NavigationRailDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: Text('Alerts')),
                    NavigationRailDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: Text('Help')),
                  ]
                : const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
                    NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: Text('Routing')),
                    NavigationRailDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: Text('Help')),
                  ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
