import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/providers/cur_group_provider.dart';
import 'package:flutter_template/services/providers/cur_org_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/providers/group_provider.dart';
import '../../../../services/providers/cur_branch_provider.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/base/id_generator.dart';


class ManageGroupsScreen extends ConsumerStatefulWidget {
  const ManageGroupsScreen({super.key});

  @override
  ConsumerState<ManageGroupsScreen> createState() => _ManageBranchesScreenState();
}

class _ManageBranchesScreenState extends ConsumerState<ManageGroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final currentOrg= ref.watch(currentOrganizationProvider);
    if (currentBranch == null) {
      return Scaffold(
        appBar: AppBar(title: Text("manageGrp".tr())),
        body: Center(child: Text("noBrSelected".tr())),
      );
    }

    final groups = ref.watch(groupProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("${"manageGrp".tr()} - ${currentBranch.name}"),
      ),
      body: (groups==null || groups.isEmpty )?Center(child: Text("noGrp".tr())):ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 3,
              color: Colors.grey.shade100,
              child: ListTile(
                title: Text(group.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => context.push("/create-edit-page",extra: {
                        "title":"editGrp".tr(),
                          "onSave": (name, fields) {
                            final updatedGroup = Group(name, group.employees, fields, group.id);
                            ref
                                .read(groupProvider.notifier)
                                .updateGroup(currentOrg!.id,currentBranch.id, updatedGroup);
                            ref
                                .read(currentGroupProvider.notifier)
                                .resetGroup(updatedGroup,null,null);
                          },
                                "initialName": group.name,
                                "initialDynamicFields": group.dynamicFields,
                      })
                      //     _openCreateEditDialog(
                      //   context,
                      //   branchId: currentBranch.id,
                      //   group: group,
                      //   onSave: (name, fields) {
                      //     final updatedGroup = Group(name, group.employees, fields, group.id);
                      //     ref
                      //         .read(groupProvider.notifier)
                      //         .updateGroup(currentOrg!.id,currentBranch.id, updatedGroup);
                      //   },
                      // ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        ref
                          .read(groupProvider.notifier)
                          .deleteGroup(currentOrg!.id,currentBranch.id, group.id);
                        ref
                            .read(currentGroupProvider.notifier)
                            .resetGroup(null,group,currentBranch);
                      }
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push("/create-edit-page",extra: {
          "title":"createGrp".tr(),
          "initialName": null,
          "initialDynamicFields": null,
          "onSave": (name, fields) {
        final newGroup = Group(name, null, fields, generateId());
        ref.read(groupProvider.notifier).addGroup(currentOrg!.id,currentBranch.id, newGroup);
      },
        })
        //     _openCreateEditDialog(
        //   context,
        //   branchId: currentBranch.id,
        //   onSave: (name, fields) {
        //     final newGroup = Group(name, null, fields, generateId());
        //     ref.read(groupProvider.notifier).addGroup(currentOrg!.id,currentBranch.id, newGroup);
        //   },
        // )
        ,
        child: Icon(Icons.add),
      ),
    );
  }
  // void _openCreateEditDialog(BuildContext context,
  //     {required String branchId,
  //       Group? group,
  //       required void Function(String name, Map<String, String> fields) onSave}) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return CreateEditPage(
  //         title: group == null ? "Create Group" : "Edit Group",
  //         initialName: group?.name,
  //         initialDynamicFields: group?.dynamicFields,
  //         onSubmit: onSave,
  //       );
  //     },
  //   );
  // }
}
