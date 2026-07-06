import 'package:flutter/material.dart';

import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart';
import 'responsive/breakpoints.dart';

/// Top-level adaptive navigation shell.
///
/// Hosts the app's primary destinations and switches its navigation affordance
/// by window size — a bottom [NavigationBar] on phones and a side
/// [NavigationRail] on tablets / large or landscape screens. Destination
/// screens live in an [IndexedStack] so switching keeps each one's state and
/// scroll position. Each destination brings its own [Scaffold]/app bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<_Destination> _destinations = [
    _Destination(
      label: 'Library',
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
    ),
    _Destination(
      label: 'Settings',
      icon: Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune),
    ),
  ];

  void _select(int i) {
    if (i != _index) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);

    final body = IndexedStack(
      index: _index,
      children: const [LibraryScreen(), SettingsScreen()],
    );

    final Widget scaffold;
    if (size.useNavigationRail) {
      scaffold = Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: d.label,
              ),
          ],
        ),
      );
    }

    // On a non-Library tab, the Android system back gesture returns to Library
    // instead of leaving the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: scaffold,
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final Widget icon;
  final Widget selectedIcon;
}
