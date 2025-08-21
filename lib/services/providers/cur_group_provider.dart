

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/providers/cur_org_provider.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../base/database/hive_manager/models.dart';
import 'cur_branch_provider.dart';

final currentGroupProvider = StateNotifierProvider< CurrentGroupNotifier,Group?>((ref) {
  final Organization? organization = ref.watch(currentOrganizationProvider);
  final Branch? branchy = ref.watch(currentBranchProvider);
  final box =  Hive.box<Organization>('organizations');

  final sharedPrefs=GetIt.instance<SharedPreferences>();
  String currentGroupId= sharedPrefs.getString("defaultGroup")??"";

  Group? group;
  if (organization?.branches != null && organization!.branches!.isNotEmpty) {
    Branch? branch = organization.branches!.firstWhere(
          (b) => b.id == branchy?.id,
      orElse: () => Branch("No Branch", HiveList(box), {}, ""), // Fallback if no branch matches
    );

    group = branch.groups?.firstWhere(
          (g) => g.id == currentGroupId,
      orElse: () => Group("No Group", HiveList(box), {}, "id"), // Fallback if no group matches
    );
  } else {
    group = null; // Handle null case if no branches are found
  }
  return CurrentGroupNotifier(box, group);
});

class CurrentGroupNotifier extends StateNotifier<Group?> {
  final Box box;

  CurrentGroupNotifier(this.box, Group? initialGroup) : super(initialGroup);

  void setGroup(Group group) {
    state = group;
    final sharedPrefs=GetIt.instance<SharedPreferences>();
    sharedPrefs.setString("defaultGroup", group.id);
    //box.put('currentGroup', group);
  }

  void resetGroup(Group? group,Group? deleted,Branch? curBranch) {
    final sharedPrefs=GetIt.instance<SharedPreferences>();
    String currentGroupId= sharedPrefs.getString("defaultGroup")??"";
    if(deleted!=null){
      if (currentGroupId == deleted.id) {
        // Check if groups are available in the current branch
        String? newId = curBranch?.groups?.isNotEmpty == true ? curBranch?.groups?.first.id : null;

        // Safely set the new default group or a fallback value
        sharedPrefs.setString("defaultGroup", newId ?? "null");

        // Retrieve the default group ID from Hive with a fallback value
        Box box = Hive.box<Organization>("organizations");
        state = box.get("defaultGroupId");
      }

    }else{
      if(currentGroupId==group?.id){
        state = group;
      }
    }
  }
}
