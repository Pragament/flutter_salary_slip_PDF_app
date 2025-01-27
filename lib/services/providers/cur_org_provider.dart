import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../base/database/hive_manager/models.dart';

// Create a FutureProvider to load the currentOrganization from Hive
// final currentOrganizationFutureProvider = FutureProvider<Organization?>((ref) async {
//   final box = await Hive.openBox('businessBox');
//   return box.get('currentOrganization');
// });

final currentOrganizationProvider = StateNotifierProvider<CurrentOrganizationNotifier, Organization?>((ref) {
  final box =  Hive.box<Organization>('organizations');
  final sharedPrefs=GetIt.instance<SharedPreferences>();
  String currentOrgId= sharedPrefs.getString("defaultOrg")??"";
  Organization? defaultOrg= box.get(currentOrgId);
  return CurrentOrganizationNotifier(ref,defaultOrg);
});

class CurrentOrganizationNotifier extends StateNotifier<Organization?> {
  CurrentOrganizationNotifier(this.ref,Organization? defaultOrg) : super(defaultOrg);

  final Ref ref;

  // Method to set the organization and save it to Hive
  void setOrganization(Organization organization) async {
    //final box = await Hive.openBox('businessBox');
    state = organization;
    final sharedPrefs=GetIt.instance<SharedPreferences>();
    sharedPrefs.setString("defaultOrg", organization.id);
    sharedPrefs.setString("defaultBranch", organization.branches!.first.id);
    sharedPrefs.setString("defaultGroup", organization.branches!.first.groups!.first.id);
    //box.put('currentOrganization', organization);
  }

  // Method to reset the organization and remove it from Hive
  void resetOrganization(Organization? organization,Organization? deleted)  {
    final sharedPrefs=GetIt.instance<SharedPreferences>();
    String? currentOrgId= sharedPrefs.getString("defaultOrg");
    if(deleted!=null){
      if(currentOrgId==deleted.id){
      sharedPrefs.setString("defaultOrg", "defaultOrgId");
      sharedPrefs.setString("defaultBranch", "defaultBranchId");
      sharedPrefs.setString("defaultGroup", "defaultGroupId");
      Box box=Hive.box<Organization>("organizations");
      state=box.get("defaultOrgId");}
    }else{
    if(currentOrgId==organization?.id){
      state = organization;
    }
    }
  }
}
