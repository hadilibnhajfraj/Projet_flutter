part of 'sidebar_widget.dart';

class SidebarItemModel {
  final String name;
  final String iconPath;
  final SidebarItemType sidebarItemType;
  final List<SidebarSubmenuModel>? submenus;
  final String? navigationPath;
  final bool isPage;

  SidebarItemModel({
    required this.name,
    required this.iconPath,
    this.sidebarItemType = SidebarItemType.tile,
    this.submenus,
    this.navigationPath,
    this.isPage = false,
  }) : assert(
          sidebarItemType != SidebarItemType.submenu ||
              (submenus?.isNotEmpty ?? false),
        );
}

class SidebarSubmenuModel {
  final String name;
  final String? navigationPath;
  final bool isPage;

  SidebarSubmenuModel({
    required this.name,
    this.navigationPath,
    this.isPage = false,
  });
}

class GroupedMenuModel {
  final String name;
  final List<SidebarItemModel> menus;

  GroupedMenuModel({
    required this.name,
    required this.menus,
  });
}

enum SidebarItemType { tile, submenu }

// =======================
// ✅ TOP MENUS
// =======================
List<SidebarItemModel> buildTopMenus({
  required bool isAccueil,
  required bool isCommercial,
}) {
  if (isAccueil || isCommercial) {
    return <SidebarItemModel>[];
  }

  return <SidebarItemModel>[
    SidebarItemModel(
      name: 'Dashboard',
      iconPath: dashboardIcon,
      navigationPath: '/dashboard',
      sidebarItemType: SidebarItemType.submenu,
      submenus: [
        SidebarSubmenuModel(
          name: 'Project Performance Analytics',
          navigationPath: 'kpi-project',
        ),
        SidebarSubmenuModel(
          name: 'Project Validation & Success KPIs',
          navigationPath: 'kpi-projects',
        ),
        SidebarSubmenuModel(
          name: 'Dashboard KPI',
          navigationPath: 'kpi',
        ),
      ],
    ),
  ];
}

// =======================
// ✅ GROUPED MENUS (role-based)
// =======================
List<GroupedMenuModel> buildGroupedMenus({
  required bool isAdmin,
  required bool isCommercial,
  required bool isAccueil,
}) {
  // =======================
  // ACCUEIL
  // =======================
  if (isAccueil) {
    return <GroupedMenuModel>[
      GroupedMenuModel(
        name: 'Accueil',
        menus: [
          SidebarItemModel(
            name: 'Accueil',
            iconPath: usersIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.accueilProfileScreen,
          ),
        ],
      ),
    ];
  }

  // =======================
  // COMMERCIAL
  // =======================
  if (isCommercial) {
    return <GroupedMenuModel>[
      GroupedMenuModel(
        name: 'Commercial',
        menus: [
          SidebarItemModel(
            name: 'Commercial List',
            iconPath: usersIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: '/users/commercial-contacts',
          ),
          SidebarItemModel(
            name: 'Commercial Profile',
            iconPath: usersIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.commercialProfileScreen,
          ),
          SidebarItemModel(
            name: 'Client',
            iconPath: usersIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.clientsProfileScreen,
          ),
          SidebarItemModel(
            name: 'Projects',
            iconPath: formsIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.projectFormScreen,
          ),
        ],
      ),

      // =======================
      // APPLICATION
      // =======================
      GroupedMenuModel(
        name: 'Application',
        menus: [
          _safeSubmenuItem(
            name: 'users & projects management',
            icon: usersIcon,
            navigationPath: '/users',
            submenus: [
              SidebarSubmenuModel(
                name: "Project Management",
                navigationPath: 'project-list',
              ),
              SidebarSubmenuModel(
                name: "Project List",
                navigationPath: 'user_project',
              ),
              SidebarSubmenuModel(
                name: "Applicateur List",
                navigationPath: 'applicateur',
              ),
              SidebarSubmenuModel(
                name: "Revendeur List",
                navigationPath: 'revendeur',
              ),
              if (isAdmin)
                SidebarSubmenuModel(
                  name: "Client",
                  navigationPath: 'client',
                ),
              if (isAdmin)
                SidebarSubmenuModel(
                  name: "Dashboard Commercial",
                  navigationPath: 'dashboard-commercial',
                ),
            ],
          ),
        ],
      ),
    ];
  }

  // =======================
  // DEFAULT ROLES
  // =======================
  return <GroupedMenuModel>[
    GroupedMenuModel(
      name: 'Projets',
      menus: [
        _safeSubmenuItem(
          name: 'Projects management',
          icon: usersIcon,
          navigationPath: '/users',
          submenus: [
            SidebarSubmenuModel(
              name: "Project Management",
              navigationPath: 'project-list',
            ),
            SidebarSubmenuModel(
              name: "Project List",
              navigationPath: 'user_project',
            ),
            if (isAdmin)
              SidebarSubmenuModel(
                name: "Commercial List",
                navigationPath: 'commercial-contacts',
              ),
            if (isCommercial)
              SidebarSubmenuModel(
                name: "Commercial List",
                navigationPath: 'commercial-contacts',
              ),
          ],
        ),
      ],
    ),

    // Visible uniquement pour admin / superadmin
    if (isAdmin) ...[
      GroupedMenuModel(
        name: 'Users',
        menus: [
          _safeSubmenuItem(
            name: 'Users management',
            icon: usersIcon,
            navigationPath: '/users',
            submenus: [
              SidebarSubmenuModel(
                name: "User List",
                navigationPath: 'user-list',
              ),
              SidebarSubmenuModel(
                name: "Client",
                navigationPath: 'client',
              ),
            ],
          ),
        ],
      ),
    ],

    GroupedMenuModel(
      name: 'Pages',
      menus: [
        SidebarItemModel(
          name: 'Google Map',
          iconPath: projectsIcon,
          navigationPath: MyRoute.mapScreen,
        ),
        SidebarItemModel(
          name: 'Calendar',
          iconPath: calendarIcon,
          navigationPath: MyRoute.calendarScreen,
        ),
      ],
    ),

    GroupedMenuModel(
      name: 'Projects',
      menus: [
        if (!isAdmin)
          SidebarItemModel(
            name: 'Projects',
            iconPath: formsIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.projectFormScreen,
          ),
      ],
    ),
  ];
}

// =======================
// ✅ SAFE BUILDER (IMPORTANT FIX)
// =======================
SidebarItemModel _safeSubmenuItem({
  required String name,
  required String icon,
  required String navigationPath,
  required List<SidebarSubmenuModel> submenus,
}) {
  final cleanSubmenus = submenus.whereType<SidebarSubmenuModel>().toList();

  if (cleanSubmenus.isEmpty) {
    return SidebarItemModel(
      name: name,
      iconPath: icon,
      sidebarItemType: SidebarItemType.tile,
      navigationPath: navigationPath,
    );
  }

  return SidebarItemModel(
    name: name,
    iconPath: icon,
    sidebarItemType: SidebarItemType.submenu,
    navigationPath: navigationPath,
    submenus: cleanSubmenus,
  );
}