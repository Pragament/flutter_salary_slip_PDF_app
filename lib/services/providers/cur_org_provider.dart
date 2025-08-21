import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../base/database/hive_manager/models.dart';

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
    state = organization;

    final sharedPrefs = GetIt.instance<SharedPreferences>();

    // Safely set defaultOrg
    sharedPrefs.setString("defaultOrg", organization.id);

    // Safely set defaultBranch and defaultGroup with null and empty checks
    String? defaultBranchId = organization.branches?.isNotEmpty == true
        ? organization.branches!.first.id
        : null;
    sharedPrefs.setString("defaultBranch", defaultBranchId ?? "defaultBranchId");

    String? defaultGroupId = organization.branches?.isNotEmpty == true &&
        organization.branches!.first.groups?.isNotEmpty == true
        ? organization.branches!.first.groups!.first.id
        : null;
    sharedPrefs.setString("defaultGroup", defaultGroupId ?? "defaultGroupId");
  }

// Method to reset the organization and remove it from Hive
  void resetOrganization(Organization? organization, Organization? deleted) {
    final sharedPrefs = GetIt.instance<SharedPreferences>();
    String? currentOrgId = sharedPrefs.getString("defaultOrg");

    if (deleted != null) {
      if (currentOrgId == deleted.id) {
        // Reset default organization, branch, and group IDs
        sharedPrefs.setString("defaultOrg", "defaultOrgId");
        sharedPrefs.setString("defaultBranch", "defaultBranchId");
        sharedPrefs.setString("defaultGroup", "defaultGroupId");

        // Get default organization from Hive with a fallback
        Box box = Hive.box<Organization>("organizations");
        state = box.get("defaultOrgId");
      }
    } else {
      if (currentOrgId == organization?.id) {
        // Restore the organization state
        state = organization;
      }
    }
  }

}
