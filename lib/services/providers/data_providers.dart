// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:hive_flutter/adapters.dart';
// import '../base/database/hive_manager/models.dart';
// import 'current_business_provider.dart';
//
// // Business Box Provider
// final businessBoxProvider = Provider((ref) => Hive.box('businessBox'));
//
// // Organizations Provider with CRUD operations
// final organizationsProvider = StateNotifierProvider<OrganizationsNotifier, List<Organization>>((ref) {
//   final box = ref.watch(businessBoxProvider);
//   return OrganizationsNotifier(box);
// });
//
// class OrganizationsNotifier extends StateNotifier<List<Organization>> {
//   final Box box;
//
//   OrganizationsNotifier(this.box) : super((box.get('organizations') as List<dynamic>?)?.cast<Organization>() ?? []);
//
//   void createOrganization(Organization organization) {
//     state = [...state, organization];
//     save();
//   }
//
//   void updateOrganization(int index, Organization updatedOrganization) {
//     state[index] = updatedOrganization;
//     save();
//   }
//
//   void deleteOrganization(int index) {
//     state.removeAt(index);
//     save();
//   }
//
//   void save() {
//     box.put('organizations', state);
//   }
// }
//
// // Branches Provider with CRUD operations
// final branchesProvider = StateNotifierProvider<BranchesNotifier, List<Branch>>((ref) {
//   final currentOrganization = ref.watch(currentOrganizationProvider);
//   return BranchesNotifier(currentOrganization);
// });
//
// class BranchesNotifier extends StateNotifier<List<Branch>> {
//   final Organization? organization;
//
//   BranchesNotifier(this.organization) : super(organization?.branches ?? []);
//
//   void createBranch(Branch branch) {
//     state = [...state, branch];
//     save();
//   }
//
//   void updateBranch(int index, Branch updatedBranch) {
//     state[index] = updatedBranch;
//     save();
//   }
//
//   void deleteBranch(int index) {
//     state.removeAt(index);
//     save();
//   }
//
//   void save() {
//     if (organization != null) {
//       organization!.branches = state;
//       Hive.box('businessBox').put('organizations', organization);
//     }
//   }
// }
//
// // Groups Provider with CRUD operations
// final groupsProvider = StateNotifierProvider<GroupsNotifier, List<Group>>((ref) {
//   final currentBranch = ref.watch(currentBranchProvider);
//   return GroupsNotifier(currentBranch);
// });
//
// class GroupsNotifier extends StateNotifier<List<Group>> {
//   final Branch? branch;
//
//   GroupsNotifier(this.branch) : super(branch?.groups ?? []);
//
//   void createGroup(Group group) {
//     state = [...state, group];
//     save();
//   }
//
//   void updateGroup(int index, Group updatedGroup) {
//     state[index] = updatedGroup;
//     save();
//   }
//
//   void deleteGroup(int index) {
//     state.removeAt(index);
//     save();
//   }
//
//   void save() {
//     if (branch != null) {
//       branch!.groups = state;
//       Hive.box('businessBox').put('organizations', branch);
//     }
//   }
// }
