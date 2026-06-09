part of 'sidebar_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (sidebar only)
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary  = Color(0xFF4F46E5);
const _kPrimaryL = Color(0xFF6366F1);
const _kHoverBg  = Color(0xFFEEF2FF);
const _kTextDark = Color(0xFF1E293B);
const _kTextSub  = Color(0xFF64748B);
const _kBorderC  = Color(0xFFE2E8F0);
const _kGroupLbl = Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────
class SidebarItemModel {
  final String           name;
  final IconData         icon;            // Flutter IconData (not SVG)
  final SidebarItemType  sidebarItemType;
  final List<SidebarSubmenuModel>? submenus;
  final String?          navigationPath;
  final bool             isPage;
  final int?             badge;           // optional count badge

  SidebarItemModel({
    required this.name,
    required this.icon,
    this.sidebarItemType = SidebarItemType.tile,
    this.submenus,
    this.navigationPath,
    this.isPage  = false,
    this.badge,
  }) : assert(
          sidebarItemType != SidebarItemType.submenu ||
              (submenus?.isNotEmpty ?? false),
        );
}

class SidebarSubmenuModel {
  final String   name;
  final String?  navigationPath;
  final bool     isPage;
  final IconData icon;
  final int?     badge;

  SidebarSubmenuModel({
    required this.name,
    this.navigationPath,
    this.isPage = false,
    this.icon   = Icons.circle,
    this.badge,
  });
}

class GroupedMenuModel {
  final String              name;
  final List<SidebarItemModel> menus;
  GroupedMenuModel({required this.name, required this.menus});
}

enum SidebarItemType { tile, submenu }

// ─────────────────────────────────────────────────────────────────────────────
// TOP MENUS  (single Dashboard tile → /kpi = DashboardScreen)
// ─────────────────────────────────────────────────────────────────────────────
List<SidebarItemModel> buildTopMenus({
  required bool isAccueil,
  required bool isCommercial,
}) {
  if (isAccueil || isCommercial) return [];
  return [
    _safeSubmenuItem(
      name:           'Dashboard',
      icon:           Icons.dashboard_outlined,
      navigationPath: '/dashboard',
      submenus: [
        SidebarSubmenuModel(
          name:           'KPI Projets CRM',
          navigationPath: 'kpi-projects',       // relatif → /dashboard/kpi-projects
          icon:           Icons.analytics_outlined,
        ),
        SidebarSubmenuModel(
          name:           'KPI Commercial Contacts',
          navigationPath: '/users/commercial-contacts-kpi', // absolu → navigation directe
          icon:           Icons.people_alt_outlined,
        ),
      ],
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUPED MENUS  (role-based)
// ─────────────────────────────────────────────────────────────────────────────
List<GroupedMenuModel> buildGroupedMenus({
  required bool isAdmin,
  required bool isCommercial,
  required bool isAccueil,
}) {
  // ── ACCUEIL ─────────────────────────────────────────────────────────────
  if (isAccueil) {
    return [
      GroupedMenuModel(
        name: 'ACCUEIL',
        menus: [
          SidebarItemModel(
            name:           'Accueil',
            icon:           Icons.home_outlined,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.accueilProfileScreen,
          ),
        ],
      ),
    ];
  }

  // ── COMMERCIAL ──────────────────────────────────────────────────────────
  if (isCommercial) {
    return [
      GroupedMenuModel(
        name: 'COMMERCIAL',
        menus: [
          SidebarItemModel(
            name:           'Commercial Contacts',
            icon:           Icons.contact_page_outlined,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: '/users/commercial-contacts',
          ),
          SidebarItemModel(
            name:           'Commercial Contacts Analytics',
            icon:           Icons.analytics_outlined,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: '/users/commercial-contacts-kpi',
          ),
          SidebarItemModel(
            name:           'Commercial Profile',
            icon:           Icons.person_search_outlined,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.commercialProfileScreen,
          ),
          SidebarItemModel(
            name:           'Client',
            icon:           Icons.people_outlined,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.clientsProfileScreen,
          ),
          SidebarItemModel(
            name:           'Projects',
            icon:           Icons.folder_outlined,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.projectFormScreen,
          ),
        ],
      ),
      GroupedMenuModel(
        name: 'TOOLS',
        menus: [
          _safeSubmenuItem(
            name:           'User & Project Management',
            icon:           Icons.manage_accounts_outlined,
            navigationPath: '/users',
            submenus: [
              SidebarSubmenuModel(
                name:           'Project Management',
                navigationPath: 'project-list',
                icon:           Icons.account_tree_outlined,
              ),
              SidebarSubmenuModel(
                name:           'Project List',
                navigationPath: 'user_project',
                icon:           Icons.list_alt_outlined,
              ),
              SidebarSubmenuModel(
                name:           'Applicateur List',
                navigationPath: 'applicateur',
                icon:           Icons.brush_outlined,
              ),
              SidebarSubmenuModel(
                name:           'Revendeur List',
                navigationPath: 'revendeur',
                icon:           Icons.storefront_outlined,
              ),
              if (isAdmin)
                SidebarSubmenuModel(
                  name:           'Client',
                  navigationPath: 'client',
                  icon:           Icons.person_pin_outlined,
                ),
              if (isAdmin)
                SidebarSubmenuModel(
                  name:           'Dashboard Commercial',
                  navigationPath: 'dashboard-commercial',
                  icon:           Icons.bar_chart_outlined,
                ),
            ],
          ),
        ],
      ),
    ];
  }

  // ── DEFAULT (admin / user / superadmin) ─────────────────────────────────
  return [
    GroupedMenuModel(
      name: 'PROJECT MANAGEMENT',
      menus: [
        _safeSubmenuItem(
          name:           'Projects',
          icon:           Icons.folder_copy_outlined,
          navigationPath: '/users',
          submenus: [
            SidebarSubmenuModel(
              name:           'Project Management',
              navigationPath: 'project-list',
              icon:           Icons.account_tree_outlined,
            ),
            SidebarSubmenuModel(
              name:           'Project List',
              navigationPath: 'user_project',
              icon:           Icons.list_alt_outlined,
            ),
            if (isAdmin)
              SidebarSubmenuModel(
                name:           'Commercial List',
                navigationPath: 'commercial-contacts',
                icon:           Icons.handshake_outlined,
              ),
          ],
        ),
      ],
    ),

    if (isAdmin) ...[
      GroupedMenuModel(
        name: 'USER MANAGEMENT',
        menus: [
          _safeSubmenuItem(
            name:           'Users',
            icon:           Icons.people_alt_outlined,
            navigationPath: '/users',
            submenus: [
              SidebarSubmenuModel(
                name:           'User List',
                navigationPath: 'user-list',
                icon:           Icons.person_outlined,
              ),
              SidebarSubmenuModel(
                name:           'Client',
                navigationPath: 'client',
                icon:           Icons.person_pin_outlined,
              ),
            ],
          ),
        ],
      ),
    ],

    GroupedMenuModel(
      name: 'TOOLS',
      menus: [
        SidebarItemModel(
          name:           'Google Map',
          icon:           Icons.map_outlined,
          navigationPath: MyRoute.mapScreen,
        ),
        SidebarItemModel(
          name:           'Calendar',
          icon:           Icons.calendar_month_outlined,
          navigationPath: MyRoute.calendarScreen,
        ),
      ],
    ),

    if (!isAdmin)
      GroupedMenuModel(
        name: 'MY PROJECTS',
        menus: [
          SidebarItemModel(
            name:           'Projects',
            icon:           Icons.folder_outlined,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.projectFormScreen,
          ),
        ],
      ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFE BUILDER  (prevents assert crash when submenus list is empty)
// ─────────────────────────────────────────────────────────────────────────────
SidebarItemModel _safeSubmenuItem({
  required String   name,
  required IconData icon,
  required String   navigationPath,
  required List<SidebarSubmenuModel> submenus,
}) {
  final clean = submenus.whereType<SidebarSubmenuModel>().toList();
  if (clean.isEmpty) {
    return SidebarItemModel(
      name:           name,
      icon:           icon,
      sidebarItemType: SidebarItemType.tile,
      navigationPath: navigationPath,
    );
  }
  return SidebarItemModel(
    name:           name,
    icon:           icon,
    sidebarItemType: SidebarItemType.submenu,
    navigationPath: navigationPath,
    submenus:       clean,
  );
}
