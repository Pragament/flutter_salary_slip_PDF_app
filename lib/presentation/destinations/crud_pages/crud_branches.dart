import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/providers/cur_branch_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/providers/branch_provider.dart';
import '../../../../services/providers/cur_org_provider.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/base/id_generator.dart';
import 'dialogs/crud_page.dart';


class ManageBranchesScreen extends ConsumerStatefulWidget {
  const ManageBranchesScreen({super.key});

  @override
  ConsumerState<ManageBranchesScreen> createState() => _ManageBranchesScreenState();
}

class _ManageBranchesScreenState extends ConsumerState<ManageBranchesScreen> {
  @override
  Widget build(BuildContext context) {
    final currentOrganization = ref.watch(currentOrganizationProvider);
    if (currentOrganization == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Manage Branches")),
        body: Center(child: Text("No organization selected.")),
      );
    }

    final branches = ref.watch(branchProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Branches - ${currentOrganization.name}"),
      ),
      body: branches.isEmpty?Center(child: Text("No Branches")):ListView.builder(
        itemCount: branches.length,
        itemBuilder: (context, index) {
          final branch = branches[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 3,
              color: Colors.grey.shade100,
              child: ListTile(
                title: Text(branch.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => context.push("/create-edit-page", extra: {
                        "title": "Edit Branch",
                        "initialName": branch.name,
                        "initialDynamicFields": branch.dynamicFields,
                        "onSave": (name, fields) {
                          final updatedBranch =
                              Branch(name, branch.groups, fields, branch.id);
                          ref
                              .read(branchProvider.notifier)
                              .updateBranch(currentOrganization.id, updatedBranch);
                          ref
                              .read(currentBranchProvider.notifier)
                              .resetBranch(updatedBranch,null,null);
                        },
                      })
                      //     _openCreateEditDialog(
                      //   context,
                      //   organizationId: currentOrganization.id,
                      //   branch: branch,
                      //   onSave: (name, fields) {
                      //     final updatedBranch = Branch(name, branch.groups, fields, branch.id);
                      //     ref
                      //         .read(branchProvider.notifier)
                      //         .updateBranch(currentOrganization.id, updatedBranch);
                      //   },
                      // )
                      ,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        ref
                          .read(branchProvider.notifier)
                          .deleteBranch(currentOrganization.id, branch.id);
                        ref
                            .read(currentBranchProvider.notifier)
                            .resetBranch(null,branch,currentOrganization);
                        },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>context.push("/create-edit-page",extra: {
          "title":"Create Branch",  "initialName": null,
          "initialDynamicFields": null,"onSave":(name, fields) {
        final newBranch = Branch(name, null, fields, generateId());
        ref.read(branchProvider.notifier).addBranch(currentOrganization.id, newBranch);
      },
        })
        //     _openCreateEditDialog(
        //   context,
        //   organizationId: currentOrganization.id,
        //   onSave: (name, fields) {
        //     final newBranch = Branch(name, null, fields, generateId());
        //     ref.read(branchProvider.notifier).addBranch(currentOrganization.id, newBranch);
        //   },
        // )
        ,

        child: Icon(Icons.add),
      ),
    );
  }

  // void _openCreateEditDialog(BuildContext context,
  //     {required String organizationId,
  //       Branch? branch,
  //       required void Function(String name, Map<String, String> fields) onSave}) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return CreateEditPage(
  //         title: branch == null ? "Create Branch" : "Edit Branch",
  //         initialName: branch?.name,
  //         initialDynamicFields: branch?.dynamicFields,
  //         onSubmit: onSave,
  //       );
  //     },
  //   );
  // }
}
