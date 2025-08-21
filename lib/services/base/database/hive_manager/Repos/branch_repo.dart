

import 'package:flutter_template/services/base/id_generator.dart';
import 'package:hive_flutter/adapters.dart';

import '../models.dart';

class BranchRepository {
  final Box<Organization> _box;

  BranchRepository(this._box);

  // Get all branches in an organization
  List<Branch> getAll(String organizationId) {
    var organization = _box.get(organizationId);
    return organization?.branches ?? [];
  }

  // Add a branch to an organization
  void addBranch(String organizationId, Branch branch) {
    var groupsBox =  Hive.box<Group>('groups');
    var branchesBox=  Hive.box<Branch>('branches');
    var empBox= Hive.box<Employee>("employees");
    Group group = Group('General Team',HiveList(empBox,objects: null),{},generateId());
    groupsBox.add(group);
   // Branch defaultBranch = Branch('Main Office',HiveList(branchesBox,objects: null),{},defaultBranchId);
    branch.groups = HiveList(groupsBox);
    branch.groups!.add(group);
    branchesBox.add(branch);
    var organization = _box.get(organizationId);
    if (organization != null) {
      organization.branches?.add(branch);
      organization.save(); // Save the organization with the new branch
    }
  }

  // Update an existing branch within an organization
  void updateBranch(String organizationId, Branch branch) {
    var branchesBox=  Hive.box<Branch>('branches');
    final id=branchesBox.keys.firstWhere((key)=>branchesBox.get(key)?.id == branch.id);
    branchesBox.put(id,branch);
    var organization = _box.get(organizationId);
    if (organization != null) {
      var branchIndex = organization.branches?.indexWhere((b) => b.id == branch.id);
      if (branchIndex != -1) {
        organization.branches?[branchIndex??0] = branch;
        organization.save(); // Save the updated organization
      }
    }
  }

  // Delete a branch from an organization
  void deleteBranch(String organizationId, String branchId) {
    var branchBox =  Hive.box<Branch>('branches');
    final id=branchBox.keys.firstWhere((key)=>branchBox.get(key)?.id == branchId);
    var organization = _box.get(organizationId);
    if (organization != null) {
      organization.branches?.removeWhere((b) => b.id == branchId);
      organization.save(); // Save the organization after deleting the branch
    }
    branchBox.delete(id);
  }

  // Find a branch by its ID
  Branch? getBranchById(String organizationId, String branchId) {
    var organization = _box.get(organizationId);
    return organization?.branches?.firstWhere((b) => b.id == branchId);
  }
}
