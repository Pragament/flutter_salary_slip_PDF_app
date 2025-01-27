import 'package:flutter_template/presentation/destinations/crud_pages/crud_branches.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/crud_groups.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/crud_orgs.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/dialogs/crud_business.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/dialogs/crud_emp_page.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/dialogs/crud_page.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/crud_emps.dart';
import 'package:flutter_template/presentation/destinations/weather/home/home_page.dart';
import 'package:flutter_template/presentation/destinations/weather/home/widgets/list/items_list.dart';
import 'package:go_router/go_router.dart';


final router = GoRouter(
  routes: [
    // Root/Home route
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),

    // Manage Organizations route
    GoRoute(
      path: '/manage-organizations',
      builder: (context, state) => ManageOrganizationsScreen(),
    ),

    // Manage Branches route
    GoRoute(
      path: '/manage-branches',
      builder: (context, state) => ManageBranchesScreen(),
    ),

    // Manage Groups route
    GoRoute(
      path: '/manage-groups',
      builder: (context, state) => ManageGroupsScreen(),
    ),

    // Manage Employees route
    GoRoute(
      path: '/manage-employees',
      builder: (context, state) => ManageEmployeesScreen(),
    ),

    // Switch Organization route
    GoRoute(
      path: '/switch-organization',
        builder: (context, state) {
          Map<String,dynamic> args=state.extra as Map<String,dynamic>;
          return ItemsList(title: args["title"], items: args["items"], onSwitch: args["onSwitch"]);
        }     ),

    // Switch Branch route
    GoRoute(
      path: '/switch-branch',
        builder: (context, state) {
          Map<String,dynamic> args=state.extra as Map<String,dynamic>;
          return ItemsList(title: args["title"], items: args["items"], onSwitch: args["onSwitch"]);
        }     ),

    // Switch Group route
    GoRoute(
      path: '/switch-group',
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return ItemsList(title: args["title"], items: args["items"], onSwitch: args["onSwitch"]);
      }
    ),

    GoRoute(
      path: '/create-edit-page',
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return CreateEditPage(title: args["title"], onSubmit: args["onSave"],initialName: args["initialName"],initialDynamicFields: args["initialDynamicFields"],);
} ,
    ),
    GoRoute(
      path: '/create-edit-org',
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return ManageBusinessPage(title: args["title"],
            initialImg: args["initialImg"],
            initialPhone: args["initialPhone"],
            initialEmail: args["initialEmail"],initialDynamicFields: args["initialDynamicFields"],
            initialAddress: args["initialAddress"],
            initialCompanyName:args["initialName"] ,
            onSubmit: args["onSave"]);
      } ,
    ),
    GoRoute(
      path: '/create-edit-emp',
      builder: (context, state) {
        Map<String,dynamic> args=state.extra as Map<String,dynamic>;
        return CreateEditEmployeePage(title: args["title"],
            onSubmit: args["onSave"],
          initialDynamicFields: args["initialDynamicFields"],
          initialName: args["initialName"],
          initialEmail: args["initialEmail"],
          initialPhone: args["initialPhone"],
        );
        } ,
    ),
  ],
);