import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'orario_screen.dart';
import 'badge_screen.dart';
import 'aule_libere_screen.dart';
import 'altro_screen.dart';

/// Destinazioni principali nella barra inferiore: Orario, Aule, Badge
/// (che raccoglie anche rilevazione e storico presenze) e Altro.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.onLogout,
  });

  final AuthService authService;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  late final List<Widget> _pages = [
    OrarioScreen(authService: widget.authService),
    AuleLibereScreen(api: widget.authService.api),
    BadgeScreen(authService: widget.authService),
    AltroScreen(authService: widget.authService),
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 28, borderRadius: 7),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _titleFor(_index, l10n),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.toggleThemeTooltip,
            icon: Icon(
              SettingsService.instance.isDarkMode(context)
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => SettingsService.instance.toggleTheme(context),
          ),
          PopupMenuButton<String>(
            icon: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mare,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (user?.nome.isNotEmpty == true ? user!.nome[0] : '?')
                    .toUpperCase(),
                style: AppTheme.numerico(size: 14, color: AppColors.pietra),
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  user?.nomeCompleto ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.logout),
                  ],
                ),
              ),
            ],
            onSelected: (v) async {
              if (v == 'logout') {
                await widget.authService.logout();
                widget.onLogout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_today),
              label: l10n.navOrario,
            ),
            NavigationDestination(
              icon: const Icon(Icons.meeting_room_outlined),
              selectedIcon: const Icon(Icons.meeting_room),
              label: l10n.navAule,
            ),
            NavigationDestination(
              icon: const Icon(Icons.badge_outlined),
              selectedIcon: const Icon(Icons.badge),
              label: l10n.navBadge,
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view),
              label: l10n.navAltro,
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(int i, AppLocalizations l10n) {
    switch (i) {
      case 0:
        return l10n.titleOrario;
      case 1:
        return l10n.titleAule;
      case 2:
        return l10n.titleBadge;
      case 3:
        return l10n.titleAltro;
      default:
        return '';
    }
  }
}
