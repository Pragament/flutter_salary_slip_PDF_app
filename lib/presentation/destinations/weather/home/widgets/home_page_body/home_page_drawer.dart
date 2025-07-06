import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/foundation/security/admin_security.dart';
import 'package:flutter_template/services/providers/branch_provider.dart';
import 'package:flutter_template/services/providers/group_provider.dart';
import 'package:flutter_template/services/providers/org_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';

import '../../../../../../services/base/database/hive_manager/models.dart';
import '../../../../../../services/providers/cur_branch_provider.dart';
import '../../../../../../services/providers/cur_group_provider.dart';
import '../../../../../../services/providers/cur_org_provider.dart';

Drawer myDrawer(BuildContext context, WidgetRef ref) {
  final Organization? currentOrg = ref.watch(currentOrganizationProvider);
  final Branch? currentBranch = ref.watch(currentBranchProvider);
  final Group? currentGroup = ref.watch(currentGroupProvider);

  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        // Drawer Header with title
        DrawerHeader(
          child: Center(
            child: Text(
              'manageBuss'.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          decoration: BoxDecoration(color: Colors.blue),
        ),

        // Home Navigation
        ListTile(
          title: Text('homePageTitle'.tr()),
          onTap: () async {
            context.go('/');
          },
        ),

        // Current Organization
        ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currentOrg?.name ?? "noOrg".tr()),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  context.push('/switch-organization', extra: {
                    "title": "switchOrg".tr(),
                    "items": ref.watch(organizationProvider),
                    "onSwitch": (dynamic org) {
                      ref
                          .read(currentOrganizationProvider.notifier)
                          .setOrganization(org);
                    }
                  });
                },
              ),
            ],
          ),
        ),
        ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currentBranch?.name ?? "noBranch".tr()),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  context.push('/switch-branch', extra: {
                    "title": "switchBr".tr(),
                    "items": ref.watch(branchProvider),
                    "onSwitch": (dynamic br) {
                      ref.read(currentBranchProvider.notifier).setBranch(br);
                    }
                  });
                },
              ),
            ],
          ),
        ),
        ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currentGroup?.name ?? "noGrp".tr()),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () {
                  context.push('/switch-group', extra: {
                    "title": "switchGrp".tr(),
                    "items": ref.watch(groupProvider),
                    "onSwitch": (dynamic grp) {
                      ref.read(currentGroupProvider.notifier).setGroup(grp);
                    }
                  });
                },
              ),
            ],
          ),
        ),

        // Divider to separate sections
        Divider(),

        // Management Sections (Organizations, Branches, Groups)
        ListTile(
          title: Text('manageOrgs'.tr()),
          onTap: () {
            context.push('/manage-organizations');
          },
        ),
        ListTile(
          title: Text('manageBr'.tr()),
          onTap: () {
            context.push('/manage-branches');
          },
        ),
        ListTile(
          title: Text('manageGrp'.tr()),
          onTap: () {
            context.push('/manage-groups');
          },
        ),
        ListTile(
          title: Text('manageEmp'.tr()),
          onTap: () {
            context.push('/manage-employees');
          },
        ),
         ListTile(
          leading: Icon(Icons.password),
          title: Text('changepassword'),
          onTap: () {
            context.push('/change_password');
          },
        ),
        ListTile(
          leading: const Icon(Icons.people_alt),
          title: const Text('Attendance'),
          onTap: () {
            // Close the drawer if it's open
            Navigator.of(context).pop();
            // Navigate to the attendance screen
            context.go('/attendance');
          },
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: Text('Logout Admin'.tr()),
          onTap: () async {
            await AdminSecurity().logout();
            Navigator.pop(context); 
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Admin logged out'.tr())),
            );
          },
        ),
      ],
    ),
  );
}