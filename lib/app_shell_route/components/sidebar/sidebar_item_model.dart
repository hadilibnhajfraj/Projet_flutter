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
              (submenus != null && submenus!.isNotEmpty),
          'Sub menus cannot be null or empty if the item type is submenu',
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
  // accueil => no top menu
  if (isAccueil) {
    return <SidebarItemModel>[];
  }

  // commercial => no dashboard top menu
  if (isCommercial) {
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
  // accueil => only Accueil
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

  // commercial => ONLY Commercial List + Commercial Profile
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
          
        ],
      ),
    ];
  }

  // other roles
  return <GroupedMenuModel>[
    GroupedMenuModel(
      name: 'Application',
      menus: [
        SidebarItemModel(
          name: 'users & projects management',
          iconPath: usersIcon,
          sidebarItemType: SidebarItemType.submenu,
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
          
            if (isCommercial)
              SidebarSubmenuModel(
                 name: "Commercial List",
              navigationPath: 'commercial-contacts',
              ),
             
            if (isAdmin)
              SidebarSubmenuModel(
                name: "User List",
                navigationPath: 'user-list',
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
           SidebarItemModel(
            name: 'Commercial List',
            iconPath: usersIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: '/users/commercial-contacts',
          ),
      ],
    ),
  ];
}