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
List<SidebarItemModel> buildTopMenus() {
  return <SidebarItemModel>[
    SidebarItemModel(
      name: 'Dashboard',
      iconPath: dashboardIcon,
      navigationPath: '/dashboard',
      sidebarItemType: SidebarItemType.submenu,
      submenus: [
        SidebarSubmenuModel(name: 'KPI PROJECT', navigationPath: 'kpi-project'),
        SidebarSubmenuModel(name: 'KPI PROJECTS', navigationPath: 'kpi-projects'),
      ],
    ),
  ];
}

// =======================
// ✅ GROUPED MENUS (role-based)
// =======================
List<GroupedMenuModel> buildGroupedMenus({required bool isAdmin}) {
  return <GroupedMenuModel>[
    GroupedMenuModel(
      name: 'Application',
      menus: [
        SidebarItemModel(
          name: 'users',
          iconPath: usersIcon,
          sidebarItemType: SidebarItemType.submenu,
          navigationPath: '/users',
          submenus: isAdmin
              ? [
                  SidebarSubmenuModel(name: "usersList", navigationPath: 'user_list'),
                ]
              : [
                  SidebarSubmenuModel(name: "Project List", navigationPath: 'project-list'),
                  /*SidebarSubmenuModel(name: "usersProfile", navigationPath: 'user_profile'),*/
                ],
        ),
      ],
    ),
    GroupedMenuModel(
      name: 'Pages',
      menus: [
        SidebarItemModel(
          name: 'googleMap',
          iconPath: projectsIcon,
          navigationPath: MyRoute.mapScreen,
        ),
      ],
    ),
    GroupedMenuModel(
      name: 'Projects',
      menus: [
        if (!isAdmin)
          SidebarItemModel(
            name: 'projects',
            iconPath: formsIcon,
            sidebarItemType: SidebarItemType.tile,
            navigationPath: MyRoute.projectFormScreen,
          ),
      ],
    ),
  ];
}