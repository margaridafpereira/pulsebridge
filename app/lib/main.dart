import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'clinical/clinical_gate.dart';
import 'clinical/clinical_lock.dart';
import 'l10n/l10n.dart';
import 'monitor/monitor_controller.dart' show clockProvider;
import 'monitor/monitor_screen.dart';
import 'profile/profile_screen.dart';
import 'sessions/sessions_screen.dart';
import 'settings/settings.dart';
import 'settings/settings_screen.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: PulseBridgeApp()));
}

class PulseBridgeApp extends ConsumerWidget {
  const PulseBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider.select((s) => s.value?.language ?? 'system'));
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: buildTheme(),
      locale: language == 'system' ? null : Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        // Dates in reports and lists follow the app's language.
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return child!;
      },
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  /// How long the app may sit in the background before the clinical area locks.
  static const relockAfter = Duration(seconds: 30);

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;
  DateTime? _hiddenAt;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // A grace period, so sharing a report or answering the fingerprint dialog
    // does not lock the clinician out.
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = ref.read(clockProvider)(),
      onShow: () {
        final hiddenAt = _hiddenAt;
        _hiddenAt = null;
        if (hiddenAt != null && ref.read(clockProvider)().difference(hiddenAt) >= HomeShell.relockAfter) {
          ref.read(clinicalLockProvider.notifier).lock();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        // IndexedStack keeps the live monitor running while other tabs are open.
        body: IndexedStack(
          index: _tab,
          children: [
            const MonitorScreen(),
            _RecordingsTab(active: _tab == 1),
            const ProfileScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.monitor_heart_outlined), selectedIcon: const Icon(Icons.monitor_heart), label: l.tabMonitor),
            NavigationDestination(
                icon: const Icon(Icons.folder_outlined), selectedIcon: const Icon(Icons.folder), label: l.tabRecordings),
            NavigationDestination(
                icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.tabProfile),
            NavigationDestination(
                icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune), label: l.tabSettings),
          ],
        ),
      );
  }
}

/// The clinical area. Its own navigator keeps session review and reports
/// behind the gate: locking drops the whole stack, not just the list.
class _RecordingsTab extends StatelessWidget {
  const _RecordingsTab({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => ClinicalGate(child: _ClinicalNavigator(active: active));
}

class _ClinicalNavigator extends StatefulWidget {
  const _ClinicalNavigator({required this.active});
  final bool active;

  @override
  State<_ClinicalNavigator> createState() => _ClinicalNavigatorState();
}

class _ClinicalNavigatorState extends State<_ClinicalNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  late final _observer = _CanPopObserver(() {
    if (mounted) setState(() {});
  });

  @override
  Widget build(BuildContext context) => PopScope(
        // Android back pops inside the tab first, and only leaves the app from the list.
        canPop: !(widget.active && _observer.depth > 1),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigator.currentState?.maybePop();
        },
        child: Navigator(
          key: _navigator,
          observers: [_observer],
          onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const SessionsScreen()),
        ),
      );
}

/// Counts the routes on the tab's navigator, so the back button knows whether
/// there is anything to pop.
class _CanPopObserver extends NavigatorObserver {
  _CanPopObserver(this.onChange);
  final VoidCallback onChange;
  int depth = 0;

  void _set(int value) {
    depth = value;
    // Navigator callbacks run during a build; rebuild after it.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(depth + 1);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(depth - 1);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(depth - 1);
}
