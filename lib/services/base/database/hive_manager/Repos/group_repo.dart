

import 'package:hive_flutter/adapters.dart';

import '../models.dart';

class GroupRepository {
  final Box<Organization> _box;

  GroupRepository(this._box);

  // Get all groups in a branch of an organization
  List<Group> getAll(String organizationId, String branchId) {
    var organization = _box.get(organizationId);
    var branch = organization?.branches?.firstWhere((b) => b.id == branchId);
    return branch?.groups ?? [];
  }

  // Add a group to a branch
  void addGroup(String organizationId, String branchId, Group group) {
    var organization = _box.get(organizationId);
    var empBox= Hive.box<Employee>("employees");
    var groupsBox =  Hive.box<Group>('groups');
    group.employees=HiveList(empBox);
    //var branchesBox=  Hive.box<Branch>('branches');
   // Group group = Group('General Team',HiveList(groupsBox,objects: null),{},generateId());
    groupsBox.add(group);
    // Branch defaultBranch = Branch('Main Office',HiveList(branchesBox,objects: null),{},defaultBranchId);
    //branch.groups = HiveList(groupsBox);
    //branch.groups!.add(group);
    //branchesBox.add(branch);
    if (organization != null) {
      var branch = organization.branches?.firstWhere((b) => b.id == branchId);
      branch?.groups?.add(group);
      organization.save(); // Save the organization after adding the group
    }
  }

  // Update an existing group in a branch
  void updateGroup(String organizationId, String branchId, Group group) {
    var groupsBox =  Hive.box<Group>('groups');
    final id=groupsBox.keys.firstWhere((key)=>groupsBox.get(key)?.id == group.id);
    groupsBox.put(id,group);
    var organization = _box.get(organizationId);
    if (organization != null) {
      var branch = organization.branches?.firstWhere((b) => b.id == branchId);
      var groupIndex = branch?.groups?.indexWhere((g) => g.id == group.id);
      if (groupIndex != -1) {
        branch!.groups?[groupIndex??0] = group;
        organization.save(); // Save the updated organization
      }
    }
  }

  // Delete a group from a branch
  void deleteGroup(String organizationId, String branchId, String groupId) {
    var groupsBox =  Hive.box<Group>('groups');
    final id=groupsBox.keys.firstWhere((key)=>groupsBox.get(key)?.id == groupId);
    var organization = _box.get(organizationId);
    if (organization != null) {
      var branch = organization.branches?.firstWhere((b) => b.id == branchId);
      branch?.groups?.removeWhere((g) => g.id == groupId);
      organization.save(); // Save the organization after deleting the group
    }
    groupsBox.delete(id);
  }

  // Find a group by its ID
  Group? getGroupById(String organizationId, String branchId, String groupId) {
    var organization = _box.get(organizationId);
    var branch = organization?.branches?.firstWhere((b) => b.id == branchId,);
    return branch?.groups?.firstWhere((g) => g.id == groupId,);
  }
}
