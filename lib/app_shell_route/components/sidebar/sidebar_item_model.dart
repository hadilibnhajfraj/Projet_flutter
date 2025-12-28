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
              (submenus != null && submenus.isNotEmpty),
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

List<SidebarItemModel> get _topMenus {
  return <SidebarItemModel>[
    SidebarItemModel(
      name: 'Dashboard',
      iconPath: dashboardIcon,
      navigationPath: '/dashboard',
      sidebarItemType: SidebarItemType.submenu,
      submenus: [
        SidebarSubmenuModel(
          name: 'Academic Admin',
          navigationPath: 'academic-admin',
        ),
        SidebarSubmenuModel(
          name: 'ecommerceAdmin',
          navigationPath: 'ecommerce-admin',
        ),
        SidebarSubmenuModel(
          name: 'Sales Admin',
          navigationPath: 'sales-admin',
        ),
        SidebarSubmenuModel(
          name: 'finance Admin',
          navigationPath: 'finance-admin',
        ),
      ],
    ),
  ];
}

List<GroupedMenuModel> get _groupedMenus {
  return <GroupedMenuModel>[
    // Application Group
    GroupedMenuModel(
      name: 'Application',
      menus: [
        SidebarItemModel(
          name: 'Calendar',
          iconPath: calendarIcon,
          navigationPath: MyRoute.calendarScreen,
        ),
        SidebarItemModel(
          name: 'Chat',
          iconPath: chatIcon,
          navigationPath: MyRoute.chatScreen,
        ),
        SidebarItemModel(
          name: 'Kanban',
          iconPath: kanbanIcon,
          navigationPath: MyRoute.kanbanScreen,
        ),
        SidebarItemModel(
          name: 'users',
          iconPath: usersIcon,
          sidebarItemType: SidebarItemType.submenu,
          navigationPath: '/users',
          submenus: [
            SidebarSubmenuModel(
              name: "usersList",
              navigationPath: 'user_list',
              // isPage: true,
            ),
            SidebarSubmenuModel(
              name: "usersGrid",
              navigationPath: 'user_grid',
              // isPage: true,
            ),
            SidebarSubmenuModel(
              name: "usersProfile",
              navigationPath: 'user_profile',
              // isPage: true,
            ),
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
        SidebarItemModel(
          name: 'Authentication',
          iconPath: authenticationIcon,
          sidebarItemType: SidebarItemType.submenu,
          navigationPath: '/authentication',
          submenus: [
            SidebarSubmenuModel(
              name: "signUp",
              navigationPath: 'signup',
              isPage: true,
            ),
            SidebarSubmenuModel(
              name: "signIn",
              navigationPath: 'signin',
              isPage: true,
            ),
            SidebarSubmenuModel(
              name: "forgotPassword1",
              navigationPath: 'forgot_password',
              isPage: true,
            ),
            SidebarSubmenuModel(
              name: "resetPassword",
              navigationPath: 'reset_password',
              isPage: true,
            ),
          ],
        ),
        SidebarItemModel(
          name: 'faqs',
          iconPath: projectsIcon,
          navigationPath: MyRoute.faqScreen,
        ),
        SidebarItemModel(
          name: 'privacyPolicy',
          iconPath: projectsIcon,
          navigationPath: MyRoute.privacyPolicyScreen,
        ),
        SidebarItemModel(
          name: 'TermsConditions',
          iconPath: projectsIcon,
          navigationPath: MyRoute.termsConditionScreen,
        ),
      ],
    ),

    GroupedMenuModel(
      name: 'tablesAndForm',
      menus: [
        SidebarItemModel(
          name: 'tables',
          iconPath: tableIcon,
          sidebarItemType: SidebarItemType.submenu,
          navigationPath: '/tables',
          submenus: [
            SidebarSubmenuModel(
              name: 'basicTables',
              navigationPath: "basic_tables",
            ),
            SidebarSubmenuModel(
              name: 'stripedRowTable',
              navigationPath: "striped_row_table",
            ),
            SidebarSubmenuModel(
              name: 'hoverTable',
              navigationPath: "hover_table",
            ),
            SidebarSubmenuModel(
              name: 'dragDropTable',
              navigationPath: "drag_drop_table",
            ),
          ],
        ),
        SidebarItemModel(
          name: 'forms',
          iconPath: formsIcon,
          sidebarItemType: SidebarItemType.submenu,
          navigationPath: '/forms',
          submenus: [
            SidebarSubmenuModel(
              name: 'formsBasicFields',
              navigationPath: "forms_basic_fields",
            ),
            SidebarSubmenuModel(
              name: 'customForm',
              navigationPath: "custom_form",
            ),
            SidebarSubmenuModel(
              name: 'validationForm',
              navigationPath: "validation_form",
            ),
            SidebarSubmenuModel(
              name: 'Project', // ✅ texte direct
              navigationPath: "project",
            ),
          ],
        ),
      ],
    ),
    GroupedMenuModel(
      name: 'others',
      menus: [
        SidebarItemModel(
          name: 'chart',
          iconPath: chartIcon,
          navigationPath: MyRoute.chartScreen,
        ),
        SidebarItemModel(
          name: 'components',
          iconPath: componentsIcon,
          sidebarItemType: SidebarItemType.submenu,
          navigationPath: '/components',
          submenus: [
            SidebarSubmenuModel(
              name: 'buttons',
              navigationPath: "buttons",
            ),
            SidebarSubmenuModel(
              name: 'tabs',
              navigationPath: "tabs",
            ),
            SidebarSubmenuModel(
              name: 'dialog',
              navigationPath: "dialog",
            ),
            SidebarSubmenuModel(
              name: 'carousel',
              navigationPath: "carousel",
            ),
            SidebarSubmenuModel(
              name: 'avatar',
              navigationPath: "avatar",
            ),
            SidebarSubmenuModel(
              name: 'card',
              navigationPath: "card",
            ),
            SidebarSubmenuModel(
              name: 'rating',
              navigationPath: "rating",
            ),
            SidebarSubmenuModel(
              name: 'toast',
              navigationPath: "toast",
            ),
          ],
        ),
      ],
    ),
  ];
}
