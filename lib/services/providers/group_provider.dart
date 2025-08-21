

// Provider to access all groups within a branch
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/providers/cur_branch_provider.dart';
import 'package:hive_flutter/adapters.dart';

import '../base/database/hive_manager/Repos/group_repo.dart';
import '../base/database/hive_manager/models.dart';
import 'cur_org_provider.dart';

final groupProvider = StateNotifierProvider<GroupNotifier, List<Group>?>((ref) {
  final currentOrganization = ref.watch(currentOrganizationProvider);
  final currentBranch = ref.watch(currentBranchProvider);
  return GroupNotifier(ref.read(groupRepositoryProvider),currentOrganization,currentBranch);
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final box = Hive.box<Organization>('organizations');
  return GroupRepository(box);
});

// StateNotifier to manage groups
class GroupNotifier extends StateNotifier<List<Group>?> {
  final GroupRepository _groupRepository;
  final Organization? organization;
  final Branch? branch;

  GroupNotifier(this._groupRepository,this.organization,this.branch) : super([]){
    init();
  }

  // Initialize the list of groups for a specific branch
  void init()  {
    if(organization != null && branch != null) {
      state = _groupRepository.getAll(organization!.id, branch!.id);
    }else{
      state=[];
    }
  }

  // Add a new group to a branch
  void addGroup(String organizationId, String branchId, Group group) {
    _groupRepository.addGroup(organizationId, branchId, group);
    state = _groupRepository.getAll(organizationId, branchId);
  }

  // Update an existing group
  void updateGroup(String organizationId, String branchId, Group group) {
    _groupRepository.updateGroup(organizationId, branchId, group);
    state = _groupRepository.getAll(organizationId, branchId);
  }

  // Delete a group from a branch
  void deleteGroup(String organizationId, String branchId, String groupId) {
    _groupRepository.deleteGroup(organizationId, branchId, groupId);
    state = _groupRepository.getAll(organizationId, branchId);
  }
}
