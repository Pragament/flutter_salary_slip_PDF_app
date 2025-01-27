

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../base/database/hive_manager/models.dart';
import 'cur_org_provider.dart';

final currentBranchProvider = StateNotifierProvider< CurrentBranchNotifier,Branch?>((ref) {
  final Organization? organization = ref.watch(currentOrganizationProvider);
  print("Provider : ${organization?.name}");
  final box =  Hive.box<Organization>('organizations');
 // print("Provider : ${box.get("currentOrganization")?.name}");
  //final branch = organization?.branches?.isNotEmpty == true ? organization?.branches?.first : null;

  final sharedPrefs=GetIt.instance<SharedPreferences>();
  String currentBranchId= sharedPrefs.getString("defaultBranch")??"";

  Branch? branch;
  if (organization?.branches != null && organization!.branches!.isNotEmpty) {
    branch = organization!.branches!.firstWhere(
          (b) => b.id == currentBranchId,
      orElse: () => organization.branches!.first, // Provide a fallback branch if needed
    );
  } else {
    branch = null; // Handle null case explicitly
  }

  return CurrentBranchNotifier(box,branch);
});

class CurrentBranchNotifier extends StateNotifier<Branch?> {
  final Box box;

  CurrentBranchNotifier(this.box, Branch? initialBranch) : super(initialBranch);

  void setBranch(Branch branch) {
    state = branch;
    final sharedPrefs = GetIt.instance<SharedPreferences>();
    sharedPrefs.setString("defaultBranch", branch.id);
    if (branch.groups != null && branch.groups!.isNotEmpty) {
      sharedPrefs.setString("defaultGroup", branch.groups!.first.id);
    } else {
      sharedPrefs.setString(
          "defaultGroup", "defaultGroupId"); // Use a fallback value
    }


    //box.put('currentBranch', branch);
  }

  void resetBranch(Branch? branch, Branch? deleted, Organization? curOrg) {
    final sharedPrefs = GetIt.instance<SharedPreferences>();
    String? currentBranchId = sharedPrefs.getString("defaultBranch");
    if (deleted != null) {
      if (currentBranchId == deleted.id) {
        String? newId = curOrg?.branches?.isNotEmpty == true ? curOrg?.branches
            ?.first.id : null;
        sharedPrefs.setString("defaultBranch", newId ?? "null");

        String? defaultGroupId = curOrg?.branches?.isNotEmpty == true &&
            curOrg?.branches?.first.groups?.isNotEmpty == true
            ? curOrg?.branches?.first.groups?.first.id
            : null;
        sharedPrefs.setString("defaultGroup", defaultGroupId??"null");

        Box box = Hive.box<Organization>("organizations");
        state = box.get("defaultBranchId");// Ensure 'state' has a fallback value

      } else {
        if (currentBranchId == branch?.id) {
          state = branch;
        }
      }
    }
  }
}
