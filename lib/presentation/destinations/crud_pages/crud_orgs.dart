import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/providers/cur_org_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/providers/org_provider.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/base/id_generator.dart';
import 'dialogs/crud_page.dart';

class ManageOrganizationsScreen extends ConsumerStatefulWidget {
  const ManageOrganizationsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManageOrganizationsScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends ConsumerState<ManageOrganizationsScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final organizations = ref.watch(organizationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Organizations"),
      ),
      body: ListView.builder(
        itemCount: organizations.length,
        itemBuilder: (context, index) {
          final organization = organizations[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              color: Colors.grey.shade100,
              elevation: 3,
              child: ListTile(
                title: Text(organization.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                        onPressed: () => context.push("/create-edit-org", extra: {
                          "title":  "Edit Organization",
                          "initialPhone": organization.phone,
                          "initialEmail": organization.mail,
                          "initialAddress": organization.address,
                                  'initialName': organization.name,
                                  'initialDynamicFields': organization.dynamicFields,
                              "onSave": (name,add,em,ph, fields,img) {
                                final updatedOrg = Organization(name,
                                    organization.branches, fields, organization.id,
                                ph,em,add,img
                                );
                                ref
                                    .read(organizationProvider.notifier)
                                    .updateOrganization(updatedOrg);
                                ref
                                    .read(currentOrganizationProvider.notifier)
                                    .resetOrganization(updatedOrg,null);

                              },
                            })
                      //     _openCreateEditDialog(
                      //   context,
                      //   organization: organization,
                      //   onSave: (name, fields) {
                      //     final updatedOrg =
                      //     Organization(name, organization.branches, fields, organization.id);
                      //     ref.read(organizationProvider.notifier).updateOrganization(updatedOrg);
                      //   },
                      // ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        ref
                          .read(organizationProvider.notifier)
                          .deleteOrganization(organization.id);
                        ref
                            .read(currentOrganizationProvider.notifier)
                            .resetOrganization(null,organization);
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
        onPressed: () => context.push("/create-edit-org",extra: {
    "title":  "Create Organization",
          "initialName": null,
          "initialEmail":null,
          "initialAddress":null,
          "initialDynamicFields": null,
    "onSave": (name,add,em,ph, fields,img) {
        final newOrg = Organization(name,null , fields, generateId(),
        ph,em,add,img
        );
        ref.read(organizationProvider.notifier).addOrganization(newOrg);
      }})
        //     _openCreateEditDialog(
        //   context,
        //   onSave: (name, fields) {
        //     final newOrg = Organization(name, null, fields, generateId());
        //     ref.read(organizationProvider.notifier).addOrganization(newOrg);
        //   },
        // ),
        ,child: Icon(Icons.add),
      ),
    );
  }

  // void _openCreateEditDialog(BuildContext context,
  //     {Organization? organization,
  //       required void Function(String name, Map<String, String> fields) onSave}) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return CreateEditPage(
  //         title: organization == null ? "Create Organization" : "Edit Organization",
  //         initialName: organization?.name,
  //         initialDynamicFields: organization?.dynamicFields,
  //         onSubmit: onSave,
  //       );
  //     },
  //   );
  // }
}

