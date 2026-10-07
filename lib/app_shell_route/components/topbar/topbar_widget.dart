
import 'package:responsive_framework/responsive_framework.dart' as rf;

import '../common_imports.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_topbar.dart';

class TopBarWidget extends StatelessWidget implements PreferredSizeWidget {
  const TopBarWidget({super.key, this.onMenuTap});

  final void Function()? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context);
    // Module Contrôle Qualité : recherche globale + identité (voir
    // quality_control_topbar.dart) — les autres modules sont inchangés.
    final width = MediaQuery.sizeOf(context).width;
    final qcSearch = qcTopbarSearchVisible(context);
    return AppBar(
      title: qcSearch && width >= 900 ? const QcTopbarSearch() : null,
      leading: rf.ResponsiveValue<Widget?>(
        context,
        conditionalValues: [
          rf.Condition.largerThan(
            name: BreakpointName.MD.name,
            value: null,
          ),
        ],
        defaultValue: IconButton(
          onPressed: onMenuTap,
          icon: Tooltip(
            message: lang.translate('openNavigationMenu'),
            waitDuration: const Duration(milliseconds: 350),
            child: const Icon(Icons.menu),
          ),
        ),
      ).value,
      toolbarHeight: rf.ResponsiveValue<double?>(
        context,
        conditionalValues: [
          rf.Condition.largerThan(name: BreakpointName.SM.name, value: 70)
        ],
      ).value,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (qcSearch && width < 900) const QcTopbarSearchButton(),
        // Language Dropdown
        Consumer<AppLanguageProvider>(
          builder: (context, lang, child) {
            return LanguagePopupMenuWidget();
          },
        ),

        ThemeToggleButton(), // Add the toggle button here

        // Notification Icon
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 0, end: 12),
          child: NotificationIconButton(),
        ),

        // User Avatar (+ identité du compte Contrôle Qualité)
        if (width >= 1000) const QcTopbarIdentity(),
        const UserProfileAvatar(),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size(double.infinity, 64);
}
