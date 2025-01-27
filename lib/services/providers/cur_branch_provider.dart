

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

  //print(branch?.first);

  //final branch=box.get("currentBranch")??organization?.branches?.isNotEmpty == true ? organization?.branches?.first : null;
  //print("Provider : ${branch?.name}");
  return CurrentBranchNotifier(box,branch);
});

class CurrentBranchNotifier extends StateNotifier<Branch?> {
  final Box box;

  CurrentBranchNotifier(this.box, Branch? initialBranch) : super(initialBranch);

  void setBranch(Branch branch) {
    state = branch;
    final sharedPrefs=GetIt.instance<SharedPreferences>();
    sharedPrefs.setString("defaultBranch", branch.id);
    sharedPrefs.setString("defaultGroup", branch.groups!.first.id);

    //box.put('currentBranch', branch);
  }

  void resetBranch(Branch? branch,Branch? deleted,Organization? curOrg) {
    final sharedPrefs=GetIt.instance<SharedPreferences>();
    String? currentBranchId= sharedPrefs.getString("defaultBranch");
    if(deleted!=null){
      if(currentBranchId==deleted.id){
        String? newId=curOrg?.branches?.first.id;
        sharedPrefs.setString("defaultBranch", newId.toString());
        sharedPrefs.setString("defaultGroup", curOrg?.branches?.first.groups?.first.id??"null");
        Box box=Hive.box<Organization>("organizations");
        state=box.get("defaultBranchId");}
    }else{
      if(currentBranchId==branch?.id){
        state = branch;
      }
    }
  }
}
