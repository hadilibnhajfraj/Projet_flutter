import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/app_shell_route/app_shell.dart';

import 'package:dash_master_toolkit/application/calendar/view/calendar_view_screen.dart';
import 'package:dash_master_toolkit/application/chat/view/chat_screen.dart';
import 'package:dash_master_toolkit/application/kanban/view/kanban_view_screen.dart';
import 'package:dash_master_toolkit/application/users/view/user_grid_screen.dart';
import 'package:dash_master_toolkit/application/users/view/user_list_screen.dart';
import 'package:dash_master_toolkit/application/users/view/user_profile_screen.dart';

import 'package:dash_master_toolkit/dashboard/academic/view/academic_dashboard_screen.dart';
import 'package:dash_master_toolkit/dashboard/ecommerce/view/ecommerce_dashboard_screen.dart';
import 'package:dash_master_toolkit/dashboard/finance/view/finance_dashboard_screen.dart';
import 'package:dash_master_toolkit/dashboard/sales/view/sales_dashboard_screen.dart';

import 'package:dash_master_toolkit/forms/view/basic_form_fields_screen.dart';
import 'package:dash_master_toolkit/forms/view/custom_form_screen.dart';
import 'package:dash_master_toolkit/forms/view/validation_form_screen.dart';
import 'package:dash_master_toolkit/forms/view/project_form_screen.dart';

import 'package:dash_master_toolkit/others/chart/view/chart_screen.dart';
import 'package:dash_master_toolkit/others/components/view/avtar_screen.dart';
import 'package:dash_master_toolkit/others/components/view/buttons_screen.dart';
import 'package:dash_master_toolkit/others/components/view/card_screen.dart';
import 'package:dash_master_toolkit/others/components/view/carousel_screen.dart';
import 'package:dash_master_toolkit/others/components/view/dialogs_screen.dart';
import 'package:dash_master_toolkit/others/components/view/ratting_screen.dart';
import 'package:dash_master_toolkit/others/components/view/tabs_screen.dart';
import 'package:dash_master_toolkit/others/components/view/toast_screen.dart';

import 'package:dash_master_toolkit/pages/auth/view/forgot_password_screen.dart';
import 'package:dash_master_toolkit/pages/auth/view/reset_password_screen.dart';
import 'package:dash_master_toolkit/pages/auth/view/sign_in_screen.dart';
import 'package:dash_master_toolkit/pages/auth/view/sign_up_screen.dart';

import 'package:dash_master_toolkit/pages/faq/view/faq_screen.dart';
import 'package:dash_master_toolkit/pages/google_map/google_map_screen.dart';
import 'package:dash_master_toolkit/pages/privacy_term_condition/view/privacy_screen.dart';
import 'package:dash_master_toolkit/pages/privacy_term_condition/view/terms_condition_screen.dart';
import 'package:dash_master_toolkit/pages/projects/view/projects_screen.dart';

import 'package:dash_master_toolkit/tables/view/basic_table_screen.dart';
import 'package:dash_master_toolkit/tables/view/drag_and_drop_table_screen.dart';
import 'package:dash_master_toolkit/tables/view/hover_table_screen.dart';
import 'package:dash_master_toolkit/tables/view/stripped_row_table_screen.dart';
import 'package:dash_master_toolkit/forms/view/ProjectCommentScreen.dart';

import 'package:go_router/go_router.dart';

import '../providers/auth_service.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

class MyRoute {
  static const login = '/login';
  static const dashboard = '/dashboard';

  static const academicAdmin = '/academic-admin';
  static const dashboardAcademicAdmin = '/dashboard/academic-admin';

  static const salesAdmin = '/sales-admin';
  static const dashboardSalesAdmin = '/dashboard/sales-admin';

  static const financeAdmin = '/finance-admin';
  static const dashboardFinanceAdmin = '/dashboard/finance-admin';

  static const ecommerceAdmin = '/ecommerce-admin';
  static const dashboardEcommerceAdmin = '/dashboard/ecommerce-admin';

  static const calendarScreen = '/calendar';
  static const chatScreen = '/chat';
  static const kanbanScreen = '/kanban';
  static const projectsScreen = '/projects';
  static const mapScreen = '/google_map';
  static const faqScreen = '/faq';
  static const privacyPolicyScreen = '/privacy_policy';
  static const termsConditionScreen = '/terms_condition';

  static const basicTablesScreen = '/tables/basic_tables';
  static const stripedRowTableScreen = '/tables/striped_row_table';
  static const hoverTableScreen = '/tables/hover_table';
  static const dragDropTableScreen = '/tables/drag_drop_table';

  static const formsBasicFieldsScreen = '/forms/forms_basic_fields';
  static const customFormScreen = '/forms/custom_form';
  static const validationFormScreen = '/forms/validation_form';
  static const projectCommentScreen = '/users/user_grid';

  // ✅ IMPORTANT : c’est bien /forms/project (pas null)
  static const projectFormScreen = '/forms/project';

  static const buttonsScreen = '/components/buttons';
  static const tabsScreen = '/components/tabs';
  static const dialogScreen = '/components/dialog';
  static const carouselScreen = '/components/carousel';
  static const avatarScreen = '/components/avatar';
  static const cardScreen = '/components/card';
  static const toastScreen = '/components/toast';
  static const ratingScreen = '/components/rating';

  static const chartScreen = '/chart';

  static const userListScreen = '/users/user_list';
  static const userGridScreen = '/users/user_grid';
  static const userProfileScreen = '/users/user_profile';

  static const signInScreen = '/authentication/signin';
  static const signUpScreen = '/authentication/signup';
  static const forgotPasswordScreen = '/authentication/forgot_password';
  static const resetPasswordScreen = '/authentication/reset_password';

  static const initialPath = '/';
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: signInScreen,
    refreshListenable: AuthService(),

    redirect: (context, state) {
      final loggedIn = AuthService().isLoggedIn;

      final isAuthRoute = state.matchedLocation == signInScreen ||
          state.matchedLocation == signUpScreen ||
          state.matchedLocation == forgotPasswordScreen ||
          state.matchedLocation == resetPasswordScreen;

      if (state.matchedLocation == initialPath) {
        return signInScreen;
      }

      if (!loggedIn && !isAuthRoute) return signInScreen;

      return null;
    },

    routes: [
      GoRoute(
        path: initialPath,
        redirect: (context, state) {
          final appLangProvider = Provider.of<AppLanguageProvider>(context);
          if (state.uri.queryParameters['rtl'] == 'true') {
            appLangProvider.isRTL = true;
          }
          return signInScreen;
        },
      ),

      // AUTH
      GoRoute(
        path: signInScreen,
        pageBuilder: (context, state) =>
            const NoTransitionPage<void>(child: SignInScreen()),
      ),
      GoRoute(
        path: signUpScreen,
        pageBuilder: (context, state) =>
            const NoTransitionPage<void>(child: SignUpScreen()),
      ),
      GoRoute(
        path: forgotPasswordScreen,
        pageBuilder: (context, state) =>
            const NoTransitionPage<void>(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: resetPasswordScreen,
        pageBuilder: (context, state) =>
            const NoTransitionPage<void>(child: ResetPasswordScreen()),
      ),

      // APP SHELL
      ShellRoute(
        navigatorKey: rootNavigatorKey,
        pageBuilder: (context, state, child) =>
            NoTransitionPage(child: AppShell(child: child)),
        routes: [
          // Dashboard
          GoRoute(
            path: dashboard,
            redirect: (context, state) {
              if (state.fullPath == dashboard) return dashboardAcademicAdmin;
              return null;
            },
            routes: [
              GoRoute(
                path: academicAdmin,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AcademicDashboardScreen()),
              ),
              GoRoute(
                path: salesAdmin,
                pageBuilder: (context, state) =>
                    NoTransitionPage(child: SalesDashboardScreen()),
              ),
              GoRoute(
                path: financeAdmin,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: FinanceDashboardScreen()),
              ),
              GoRoute(
                path: ecommerceAdmin,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: EcommerceDashboardScreen()),
              ),
            ],
          ),

          // Applications
          GoRoute(
            path: calendarScreen,
            pageBuilder: (context, state) =>
                NoTransitionPage(child: CalendarViewScreen()),
          ),
          GoRoute(
            path: chatScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: kanbanScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KanbanViewScreen()),
          ),

          // Users
          GoRoute(
            path: '/users',
            redirect: (context, state) {
              if (state.fullPath == '/users') return userListScreen;
              return null;
            },
            routes: [
              GoRoute(
                path: 'user_list',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: UserListScreen()),
              ),
              GoRoute(
                path: 'user_grid',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: UserGridScreen()),
              ),
              GoRoute(
                path: 'user_profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: UserProfileScreen()),
              ),
            ],
          ),

          // Pages
          GoRoute(
            path: projectsScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProjectsScreen()),
          ),
          GoRoute(
            path: mapScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: GoogleMapScreen()),
          ),
          GoRoute(
            path: faqScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FaqScreen()),
          ),
          GoRoute(
            path: privacyPolicyScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PrivacyScreen()),
          ),
          GoRoute(
            path: termsConditionScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TermsConditionScreen()),
          ),

          // Tables
          GoRoute(
            path: '/tables',
            redirect: (context, state) {
              if (state.fullPath == '/tables') return basicTablesScreen;
              return null;
            },
            routes: [
              GoRoute(
                path: 'basic_tables',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: BasicTableScreen()),
              ),
              GoRoute(
                path: 'striped_row_table',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: StrippedRowTableScreen()),
              ),
              GoRoute(
                path: 'hover_table',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HoverTableScreen()),
              ),
              GoRoute(
                path: 'drag_drop_table',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DragAndDropTableScreen()),
              ),
            ],
          ),

          // Forms
          GoRoute(
            path: '/forms',
            redirect: (context, state) {
              if (state.fullPath == '/forms') return formsBasicFieldsScreen;
              return null;
            },
            routes: [
              GoRoute(
                path: 'forms_basic_fields',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: BasicFormFieldsScreen()),
              ),
              GoRoute(
                path: 'custom_form',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CustomFormScreen()),
              ),
              GoRoute(
                path: 'validation_form',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ValidationFormScreen()),
              ),
              // ✅ /forms/project?id=...
              GoRoute(
                path: 'project',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProjectFormScreen()),
              ),
            ],
          ),

          // Other
          GoRoute(
            path: chartScreen,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChartScreen()),
          ),
          GoRoute(
            path: '/components',
            redirect: (context, state) {
              if (state.fullPath == '/components') return buttonsScreen;
              return null;
            },
            routes: [
              GoRoute(
                path: 'buttons',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ButtonsScreen()),
              ),
              GoRoute(
                path: 'tabs',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TabsScreen()),
              ),
              GoRoute(
                path: 'dialog',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DialogsScreen()),
              ),
              GoRoute(
                path: 'carousel',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CarouselScreen()),
              ),
              GoRoute(
                path: 'avatar',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AvtarScreen()),
              ),
              GoRoute(
                path: 'card',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CardScreen()),
              ),
              GoRoute(
                path: 'rating',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: RattingScreen()),
              ),
              GoRoute(
                path: 'toast',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ToastScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
