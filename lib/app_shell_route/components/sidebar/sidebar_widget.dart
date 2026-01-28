import 'package:responsive_framework/responsive_framework.dart' as rf;
import '../common_imports.dart';

// ✅ AJOUTE CET IMPORT (sinon AuthService introuvable)
import 'package:dash_master_toolkit/providers/auth_service.dart';

part 'sidebar_item_model.dart';

class SideBarWidget extends StatelessWidget {
  const SideBarWidget({
    super.key,
    required this.rootScaffoldKey,
    this.iconOnly = false,
  });

  final GlobalKey<ScaffoldState> rootScaffoldKey;
  final bool iconOnly;

  bool _isAdmin() {
    final role = AuthService().userRole ?? '';
    return role.toLowerCase() == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final themeController = Get.put(ThemeController());

    final isAdmin = _isAdmin();

    final topMenus = buildTopMenus();
    final groupedMenus = buildGroupedMenus(isAdmin: isAdmin);

    return Drawer(
      clipBehavior: Clip.none,
      width: iconOnly
          ? 80
          : rf.ResponsiveValue<double?>(
              context,
              conditionalValues: [
                rf.Condition.largerThan(
                  name: BreakpointName.SM.name,
                  value: 280,
                ),
              ],
            ).value,
      child: SafeArea(
        child: rf.ResponsiveRowColumn(
          layout: rf.ResponsiveRowColumnType.COLUMN,
          columnCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            rf.ResponsiveRowColumnItem(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 16),
                child: CompanyHeaderWidget(
                  showIconOnly: iconOnly,
                  showBottomBorder: true,
                  onTap: () {
                    rootScaffoldKey.currentState?.closeDrawer();
                    context.go(MyRoute.dashboardSalesAdmin);
                  },
                ),
              ),
            ),

            rf.ResponsiveRowColumnItem(
              columnFit: FlexFit.tight,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: SingleChildScrollView(
                  child: rf.ResponsiveRowColumn(
                    layout: rf.ResponsiveRowColumnType.COLUMN,
                    columnCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Top menus
                      ...topMenus.map((menu) {
                        final selectedInfo = _isSelected(context, menu);
                        return rf.ResponsiveRowColumnItem(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(bottom: 16),
                            child: SidebarMenuItem(
                              iconOnly: iconOnly,
                              menuTile: menu,
                              groupName: lang.translate(menu.name),
                              isSelected: selectedInfo.$1,
                              selectedSubmenu: selectedInfo.$2,
                              onTap: () => _handleNavigation(context, menu),
                              onSubmenuTap: (value) => _handleNavigation(
                                context,
                                menu,
                                submenu: value,
                              ),
                            ),
                          ),
                        );
                      }),

                      // ✅ Grouped menus
                      ...groupedMenus.map(
                        (groupedMenu) => rf.ResponsiveRowColumnItem(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!iconOnly)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    margin: const EdgeInsetsDirectional.only(start: 10, bottom: 16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: themeController.isDarkMode ? colorDarkG1 : colorPrimary0,
                                    ),
                                    child: Text(
                                      lang.translate(groupedMenu.name),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                ...groupedMenu.menus.map((menu) {
                                  final selectedInfo0 = _isSelected(context, menu);
                                  return Padding(
                                    padding: const EdgeInsetsDirectional.only(bottom: 16),
                                    child: SidebarMenuItem(
                                      iconOnly: iconOnly,
                                      menuTile: menu,
                                      groupName: lang.translate(menu.name),
                                      isSelected: selectedInfo0.$1,
                                      selectedSubmenu: selectedInfo0.$2,
                                      onTap: () => _handleNavigation(context, menu),
                                      onSubmenuTap: (value) => _handleNavigation(
                                        context,
                                        menu,
                                        submenu: value,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (bool isSelectedMenu, SidebarSubmenuModel? selectedSubMenu) _isSelected(
    BuildContext context,
    SidebarItemModel menu,
  ) {
    final isSubmenu = menu.sidebarItemType == SidebarItemType.submenu;
    final currentRoute =
        GoRouter.of(context).routerDelegate.currentConfiguration.fullPath;

    final nav = (menu.navigationPath ?? '').toLowerCase().trim();
    final isSelectedMenu = nav.isNotEmpty ? currentRoute.startsWith(nav) : false;

    if (isSubmenu) {
      final routeSegments = currentRoute
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();

      if (routeSegments.length > 1) {
        final selectedSubMenu = menu.submenus?.firstWhereOrNull(
          (submenu) =>
              submenu.navigationPath?.split('/').last == routeSegments.last,
        );
        if (selectedSubMenu != null) {
          return (true, selectedSubMenu);
        }
      }
    }

    return (isSelectedMenu, null);
  }

  void _handleNavigation(
    BuildContext context,
    SidebarItemModel menu, {
    SidebarSubmenuModel? submenu,
  }) {
    rootScaffoldKey.currentState?.closeDrawer();
    String? route;

    if (menu.sidebarItemType == SidebarItemType.tile) {
      route = menu.navigationPath;
    } else if (menu.sidebarItemType == SidebarItemType.submenu) {
      final mainRoute = menu.navigationPath;
      final submenuRoute = submenu?.navigationPath;
      if (mainRoute != null && submenuRoute != null) {
        route = '$mainRoute/$submenuRoute';
      }
    }

    if (route == null || route.isEmpty) {
      ScaffoldMessenger.of(rootScaffoldKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate("unknownRoute")),
        ),
      );
      return;
    }

    final currentPath =
        GoRouter.of(context).routerDelegate.currentConfiguration.fullPath;
    if (currentPath == route) return;

    context.go(route);
  }
}

/* ===========================================================
   ✅ SidebarMenuItem (OBLIGATOIRE sinon erreur “not defined”)
   =========================================================== */

class SidebarMenuItem extends StatelessWidget {
  const SidebarMenuItem({
    super.key,
    this.iconOnly = false,
    required this.menuTile,
    this.isSelected = false,
    this.selectedSubmenu,
    this.onSubmenuTap,
    this.onTap,
    this.groupName,
  });

  final bool iconOnly;
  final SidebarItemModel menuTile;
  final bool isSelected;
  final SidebarSubmenuModel? selectedSubmenu;
  final void Function(SidebarSubmenuModel? value)? onSubmenuTap;
  final void Function()? onTap;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context);
    final themeController = Get.put(ThemeController());

    if (menuTile.sidebarItemType == SidebarItemType.submenu) {
      if (iconOnly) {
        return Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: PopupMenuButton<SidebarSubmenuModel?>(
            offset: const Offset(80 - 16, 0),
            clipBehavior: Clip.antiAlias,
            tooltip: lang.translate(menuTile.name),
            color: themeController.isDarkMode ? colorDark : colorWhite,
            itemBuilder: (context) => [
              if (groupName != null)
                _CustomIconOnlySubmenu(
                  enabled: false,
                  child: Container(
                    margin: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang.translate(groupName!),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SvgPicture.asset(
                          chevronDownIcon,
                          width: 15,
                          height: 15,
                          colorFilter: ColorFilter.mode(
                            themeController.isDarkMode ? colorWhite : colorGrey900,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ...?menuTile.submenus?.map((submenu) {
                return _CustomIconOnlySubmenu<SidebarSubmenuModel>(
                  value: submenu,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                    child: _buildSubmenu(
                      context,
                      submenu,
                      onChanged: (value) {
                        Navigator.pop(context, value);
                        onSubmenuTap?.call(value);
                      },
                    ),
                  ),
                );
              }),
            ],
            child: _buildMenu(context, onTap: null),
          ),
        );
      }

      return ExpansionWidget(
        titleBuilder: (aV, eIV, iE, tF) => _buildMenu(
          context,
          onTap: () => tF(animated: true),
          isExpanded: iE,
        ),
        initiallyExpanded: isSelected,
        content: Padding(
          padding: const EdgeInsetsDirectional.only(top: 8, start: 36),
          child: Column(
            children: [
              ...?menuTile.submenus?.map(
                (submenu) => _buildSubmenu(
                  context,
                  submenu,
                  onChanged: onSubmenuTap,
                ),
              )
            ],
          ),
        ),
      );
    }

    if (iconOnly) {
      return Tooltip(
        message: lang.translate(menuTile.name),
        child: _buildMenu(context, onTap: onTap),
      );
    }
    return _buildMenu(context, onTap: onTap);
  }

  Widget _buildMenu(
    BuildContext context, {
    required void Function()? onTap,
    bool isExpanded = false,
  }) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context);
    const selectedPrimaryColor = Colors.white;
    final themeController = Get.put(ThemeController());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: BoxConstraints.tight(const Size.fromHeight(48)),
        alignment: AlignmentDirectional.center,
        decoration: ShapeDecoration(
          color: isSelected ? colorPrimary100 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
        ),
        padding: EdgeInsetsDirectional.only(
          start: iconOnly ? 8 : (isSelected ? 0 : 16),
          end: 16,
        ),
        child: Row(
          mainAxisAlignment: iconOnly ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (!iconOnly && isSelected)
              Container(
                width: 6,
                decoration: BoxDecoration(
  borderRadius: const BorderRadius.only(
    topRight: Radius.circular(10),
    bottomRight: Radius.circular(10),
  ),
  color: colorPrimary25,
),

              ),
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: iconOnly ? 0 : (isSelected ? 16 : 0),
                ),
                child: Row(
                  mainAxisAlignment: iconOnly ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      menuTile.iconPath,
                      height: 20,
                      width: 20,
                      colorFilter: ColorFilter.mode(
                        isSelected ? selectedPrimaryColor : theme.textTheme.bodyLarge!.color!,
                        BlendMode.srcIn,
                      ),
                    ),
                    if (!iconOnly)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  lang.translate(menuTile.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: isSelected ? selectedPrimaryColor : null,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (menuTile.submenus != null)
                                SvgPicture.asset(
                                  isExpanded ? chevronDownIcon : chevronRightIcon,
                                  width: 15,
                                  height: 15,
                                  colorFilter: ColorFilter.mode(
                                    isSelected
                                        ? selectedPrimaryColor
                                        : (themeController.isDarkMode ? colorWhite : colorGrey900),
                                    BlendMode.srcIn,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmenu(
    BuildContext context,
    SidebarSubmenuModel submenu, {
    void Function(SidebarSubmenuModel? value)? onChanged,
  }) {
    final theme = Theme.of(context);
    final isSelectedSubmenu = selectedSubmenu == submenu;
    final lang = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () => onChanged?.call(submenu),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        tileColor: isSelectedSubmenu ? colorPrimary25 : null,
        title: Text(lang.translate(submenu.name)),
        leading: const Icon(Icons.circle, size: 8),
        minLeadingWidth: 0,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
        titleTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: isSelectedSubmenu ? colorPrimary300 : null,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: EdgeInsetsDirectional.only(
          start: iconOnly ? 8 : 16,
          end: 8,
        ),
        iconColor: isSelectedSubmenu ? colorPrimary300 : null,
      ),
    );
  }
}

class _CustomIconOnlySubmenu<T> extends StatefulWidget implements PopupMenuEntry<T> {
  const _CustomIconOnlySubmenu({
    super.key,
    this.enabled = true,
    this.value,
    required this.child,
  });

  final bool enabled;
  final T? value;
  final Widget child;

  @override
  State<_CustomIconOnlySubmenu> createState() => _CustomIconOnlySubmenuState<T>();

  @override
  double get height => 0;

  @override
  bool represents(value) => value == this.value;
}

class _CustomIconOnlySubmenuState<T> extends State<_CustomIconOnlySubmenu<T>> {
  @protected
  void handleTap() => Navigator.pop<T>(context, widget.value);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      hoverColor: Colors.transparent,
      onTap: widget.enabled ? handleTap : null,
      child: widget.child,
    );
  }
}
