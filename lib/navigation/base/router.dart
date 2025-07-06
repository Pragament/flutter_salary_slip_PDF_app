import 'package:flutter_template/presentation/destinations/attendance/attendance_screen.dart';
import 'package:flutter_template/presentation/destinations/attendance/attendance_history_screen.dart';
import 'package:flutter_template/presentation/auth/admin_lock_screen.dart';
import 'package:flutter_template/foundation/security/admin_security.dart';
import 'package:flutter_template/presentation/destinations/change_password/setnewpasswordscreen.dart';
import 'package:flutter_template/presentation/destinations/change_password/verifypasswordscreen.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/crud_branches.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/crud_groups.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/crud_orgs.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/dialogs/crud_business.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/dialogs/crud_emp_page.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/dialogs/crud_page.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/crud_emps.dart';
import 'package:flutter_template/presentation/destinations/weather/home/home_page.dart';
import 'package:flutter_template/presentation/destinations/weather/home/widgets/list/items_list.dart';
import 'package:flutter_template/screens/create_edit_employee_screen.dart';
import 'package:flutter_template/presentation/settings/admin_settings_screen.dart';
import 'package:go_router/go_router.dart';

// Auth check redirector function
Future<String?> _checkAuth(String targetPath) async {
  final isAdmin = await AdminSecurity().isAdmin();
  if (!isAdmin) {
    // Clear any previous authentication to ensure fresh login
    await AdminSecurity().logout();
    // Redirect to auth screen with the target path as extra data
    return '/admin-auth';
  }
  return null; 
}

final router = GoRouter(
  routes: [
    // Root/Home route
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),

    // Admin Authentication Screen
    GoRoute(
      path: '/admin-auth',
      builder: (context, state) {
        // Get the redirect path from extra data
        final String redirectPath = state.extra as String? ?? '/';
        return AdminLockScreen(redirectPath: redirectPath);
      },
    ),

    // Manage Organizations route - protected with auth check
    GoRoute(
      path: '/manage-organizations',
      redirect: (context, state) async {
        return await _checkAuth('/manage-organizations');
      },
      builder: (context, state) => ManageOrganizationsScreen(),
    ),

    // Manage Branches route - protected with auth check
    GoRoute(
      path: '/manage-branches',
      redirect: (context, state) async {
        return await _checkAuth('/manage-branches');
      },
      builder: (context, state) => ManageBranchesScreen(),
    ),

    // Manage Groups route - protected with auth check
    GoRoute(
      path: '/manage-groups',
      redirect: (context, state) async {
        return await _checkAuth('/manage-groups');
      },
      builder: (context, state) => ManageGroupsScreen(),
    ),

    // Manage Employees route - protected with auth check
    GoRoute(
      path: '/manage-employees',
      redirect: (context, state) async {
        return await _checkAuth('/manage-employees');
      },
      builder: (context, state) => ManageEmployeesScreen(),
    ),

    // Switch Organization route
    GoRoute(
      path: '/switch-organization',
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return ItemsList(title: args["title"], items: args["items"], onSwitch: args["onSwitch"]);
      }
    ),

    // Switch Branch route
    GoRoute(
      path: '/switch-branch',
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return ItemsList(title: args["title"], items: args["items"], onSwitch: args["onSwitch"]);
      }
    ),

    // Switch Group route
    GoRoute(
      path: '/switch-group',
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return ItemsList(title: args["title"], items: args["items"], onSwitch: args["onSwitch"]);
      }
    ),

    // Create/Edit Page route - protected with auth check
    GoRoute(
      path: '/create-edit-page',
      redirect: (context, state) async {
        return await _checkAuth('/create-edit-page');
      },
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return CreateEditPage(
          title: args["title"], 
          onSubmit: args["onSave"],
          initialName: args["initialName"],
          initialDynamicFields: args["initialDynamicFields"],
        );
      },
    ),
    
    // Create/Edit Organization route - protected with auth check
    GoRoute(
      path: '/create-edit-org',
      redirect: (context, state) async {
        return await _checkAuth('/create-edit-org');
      },
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return ManageBusinessPage(
          title: args["title"],
          initialImg: args["initialImg"],
          initialPhone: args["initialPhone"],
          initialEmail: args["initialEmail"],
          initialDynamicFields: args["initialDynamicFields"],
          initialAddress: args["initialAddress"],
          initialCompanyName: args["initialName"],
          onSubmit: args["onSave"],
        );
      },
    ),
    
    // Create/Edit Employee route - protected with auth check
    GoRoute(
      path: '/create-edit-emp',
      redirect: (context, state) async {
        return await _checkAuth('/create-edit-emp');
      },
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
        return CreateEditEmployeeScreen(
          title: extra['title'] as String,
          initialName: extra['initialName'] as String?,
          initialPhone: extra['initialPhone'] as String?,
          initialEmail: extra['initialEmail'] as String?,
          initialDynamicFields: extra['initialDynamicFields'] as Map<String, Map<String, String>>?,
          onSave: extra['onSave'] as Function(String, String, String, Map<String, Map<String, String>>),
        );
      },
    ),
    
    // Employee Attendance route
    GoRoute(
      path: '/attendance',
      builder: (context, state) => const AttendanceScreen(),
    ),
    
    // Attendance History route
    GoRoute(
      path: '/attendance/history',
      builder: (context, state) => const AttendanceHistoryScreen(),
    ),
    
    // Admin Attendance route - protected with auth check
    GoRoute(
      path: '/admin/attendance',
      redirect: (context, state) async {
        return await _checkAuth('/admin/attendance');
      },
      builder: (context, state) => const AttendanceHistoryScreen(),
    ),
    
    // Admin Settings route - protected with auth check
    GoRoute(
      path: '/admin/settings',
      redirect: (context, state) async {
        return await _checkAuth('/admin/settings');
      },
      builder: (context, state) => const AdminSettingsScreen(),
    ),

    //change password home screen
    GoRoute(
      path: '/change_password',
      builder: (context, state) =>  VerifyPasswordScreen(),
      ),
     GoRoute(
      path: '/set-new-password',
      builder: (context, state) => const SetNewPasswordScreen(),
    ),
   
  ],
);