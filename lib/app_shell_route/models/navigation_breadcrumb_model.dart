import 'package:dash_master_toolkit/app_shell_route/components/common_imports.dart';

class NavigationBreadcrumbModel {
  final String title;
  final String parentRoute;
  final String childRoute;

  const NavigationBreadcrumbModel({
    required this.title,
    required this.parentRoute,
    required this.childRoute,
  });

  @override
  String toString() {
    return 'NavigationBreadcrumbModel(parentName: $parentRoute, childName: $childRoute)';
  }
}

Map<String, NavigationBreadcrumbModel> get routerParam {
  return {
    MyRoute.dashboardAcademicAdmin: NavigationBreadcrumbModel(
      title: 'Dashboard',
      parentRoute: 'Dashboard',
      childRoute: 'Academic Admin',
    ),
    MyRoute.dashboardSalesAdmin: NavigationBreadcrumbModel(
      title: 'Dashboard',
      parentRoute: 'Dashboard',
      childRoute: 'Sales Admin',
    ),
    MyRoute.dashboardFinanceAdmin: NavigationBreadcrumbModel(
      title: 'Dashboard',
      parentRoute: 'Dashboard',
      childRoute: 'finance Admin',
    ),
    MyRoute.dashboardEcommerceAdmin: NavigationBreadcrumbModel(
      title: 'Dashboard',
      parentRoute: 'Dashboard',
      childRoute: 'ecommerceAdmin',
    ),
    MyRoute.calendarScreen: NavigationBreadcrumbModel(
      title: 'Calendar',
      parentRoute: 'Application',
      childRoute: 'calendar',
    ),
    MyRoute.chatScreen: NavigationBreadcrumbModel(
      title: 'Chat',
      parentRoute: 'Application',
      childRoute: 'chat',
    ),
    MyRoute.kanbanScreen: NavigationBreadcrumbModel(
      title: 'kanban',
      parentRoute: 'Application',
      childRoute: 'kanban',
    ),
    MyRoute.userListScreen: NavigationBreadcrumbModel(
      title: 'usersList',
      parentRoute: 'Application / Users',
      childRoute: 'usersList',
    ),
    MyRoute.userGridScreen: NavigationBreadcrumbModel(
      title: 'usersGrid',
      parentRoute: 'Application / Users',
      childRoute: 'usersGrid',
    ),
    MyRoute.userProfileScreen: NavigationBreadcrumbModel(
      title: 'usersProfile',
      parentRoute: 'Application / Users',
      childRoute: 'usersProfile',
    ),
    MyRoute.projectsScreen: NavigationBreadcrumbModel(
      title: 'Projects',
      parentRoute: 'Pages',
      childRoute: 'projects',
    ),
    MyRoute.mapScreen: NavigationBreadcrumbModel(
      title: 'googleMap',
      parentRoute: 'Pages',
      childRoute: 'google_map',
    ),
    MyRoute.faqScreen: NavigationBreadcrumbModel(
      title: 'faqs',
      parentRoute: 'Pages',
      childRoute: 'faq',
    ),
    MyRoute.privacyPolicyScreen: NavigationBreadcrumbModel(
      title: 'privacyPolicy',
      parentRoute: 'Pages',
      childRoute: 'privacy_policy',
    ),
    MyRoute.termsConditionScreen: NavigationBreadcrumbModel(
      title: 'TermsConditions',
      parentRoute: 'Pages',
      childRoute: 'terms_condition',
    ),
    MyRoute.basicTablesScreen: NavigationBreadcrumbModel(
      title: 'basicTables',
      parentRoute: 'tables',
      childRoute: 'basicTables',
    ),
    MyRoute.stripedRowTableScreen: NavigationBreadcrumbModel(
      title: 'stripedRowTable',
      parentRoute: 'tables',
      childRoute: 'stripedRowTable',
    ),
    MyRoute.hoverTableScreen: NavigationBreadcrumbModel(
      title: 'hoverTable',
      parentRoute: 'tables',
      childRoute: 'hoverTable',
    ),
    MyRoute.dragDropTableScreen: NavigationBreadcrumbModel(
      title: 'dragDropTable',
      parentRoute: 'tables',
      childRoute: 'dragDropTable',
    ),
    MyRoute.formsBasicFieldsScreen: NavigationBreadcrumbModel(
      title: 'formsBasicFields',
      parentRoute: 'forms',
      childRoute: 'formsBasicFields',
    ),
    MyRoute.customFormScreen: NavigationBreadcrumbModel(
      title: 'customForm',
      parentRoute: 'forms',
      childRoute: 'customForm',
    ),
    MyRoute.validationFormScreen: NavigationBreadcrumbModel(
      title: 'validationForm',
      parentRoute: 'forms',
      childRoute: 'validationForm',
    ),
    MyRoute.buttonsScreen: NavigationBreadcrumbModel(
      title: 'buttons',
      parentRoute: 'components',
      childRoute: 'buttons',
    ),
    MyRoute.tabsScreen: NavigationBreadcrumbModel(
      title: 'tabs',
      parentRoute: 'components',
      childRoute: 'tabs',
    ),
    MyRoute.dialogScreen: NavigationBreadcrumbModel(
      title: 'dialog',
      parentRoute: 'components',
      childRoute: 'dialog',
    ),
    MyRoute.carouselScreen: NavigationBreadcrumbModel(
      title: 'carousel',
      parentRoute: 'components',
      childRoute: 'carousel',
    ),
    MyRoute.avatarScreen: NavigationBreadcrumbModel(
      title: 'avatar',
      parentRoute: 'components',
      childRoute: 'avatar',
    ),
    MyRoute.cardScreen: NavigationBreadcrumbModel(
      title: 'card',
      parentRoute: 'components',
      childRoute: 'card',
    ),
    MyRoute.toastScreen: NavigationBreadcrumbModel(
      title: 'toast',
      parentRoute: 'components',
      childRoute: 'toast',
    ),
    MyRoute.projectFormScreen: NavigationBreadcrumbModel(
      title: 'project',
      parentRoute: 'forms',
      childRoute: 'project',
    ),
    MyRoute.ratingScreen: NavigationBreadcrumbModel(
      title: 'rating',
      parentRoute: 'components',
      childRoute: 'rating',
    ),
    MyRoute.chartScreen: NavigationBreadcrumbModel(
      title: 'chart',
      parentRoute: 'others',
      childRoute: 'chart',
    ),
  };
}
