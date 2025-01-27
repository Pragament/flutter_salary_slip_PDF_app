import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final  Branch? currentBranch=ref.watch(currentBranchProvider);
  final Group?  currentGroup=ref.watch(currentGroupProvider);


  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        // Drawer Header with title
        DrawerHeader(
          child: Center(
            child: Text(
              'Business Management',
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
          title: Text('Home'),
          onTap: () async {
            context.go('/');
          },
        ),

        // Current Organization
        ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(currentOrg?.name ?? "No Business"),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      context.push('/switch-organization',extra: {
                        "title":"Switch Organization",
                        "items":ref.watch(organizationProvider),
                        "onSwitch":(dynamic org){
                          ref.read(currentOrganizationProvider.notifier).setOrganization(org);
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
                  Text(currentBranch?.name??"No Branch"),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      context.push('/switch-branch',extra: {
                        "title":"Switch Branch",
                        "items":ref.watch(branchProvider),
                        "onSwitch":(dynamic br){
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
                  Text(currentGroup?.name??"No Group"),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      context.push('/switch-group',extra: {
                        "title":"Switch Group",
                        "items":ref.watch(groupProvider),
                        "onSwitch":(dynamic  grp){
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
          title: Text('Manage Organizations'),
          onTap: () {
            context.push('/manage-organizations');
          },
        ),
        ListTile(
          title: Text('Manage Branches'),
          onTap: () {
            context.push('/manage-branches');
          },
        ),
        ListTile(
          title: Text('Manage Groups'),
          onTap: () {
            context.push('/manage-groups');
          },
        ),
        ListTile(
          title: Text('Manage Employees'),
          onTap: () {
            context.push('/manage-employees');
          },
        ),
      ],
    ),
  );
}

