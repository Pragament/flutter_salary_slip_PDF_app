

import 'package:flutter_template/services/base/id_generator.dart';
import 'package:hive_flutter/adapters.dart';

import '../models.dart';

class OrganizationRepository {
  final Box<Organization> _box;

  OrganizationRepository(this._box);

  // Get all organizations
  List<Organization> getAll() {
    return _box.values.toList();
  }

  // Add a new organization
  void addOrganization(Organization organization) {
    var groupsBox =  Hive.box<Group>('groups');
    var branchesBox=  Hive.box<Branch>('branches');
    var empBox= Hive.box<Employee>("employees");

    Group defaultGroup = Group('General Team',HiveList(empBox,objects: null),{},generateId());
    groupsBox.add(defaultGroup);


    Branch defaultBranch = Branch('Main Office',HiveList(branchesBox,objects: null),{},generateId());
    defaultBranch.groups = HiveList(groupsBox);
    defaultBranch.groups!.add(defaultGroup);
    branchesBox.add(defaultBranch);
    organization.branches = HiveList(branchesBox);
    organization.branches!.add(defaultBranch);
    _box.put(organization.id, organization);
  }

  // Update an existing organization
  void updateOrganization(Organization organization) {
    if (_box.containsKey(organization.id)) {
      _box.put(organization.id, organization);
    }
  }

  // Delete an organization
  void deleteOrganization(String id) {
    _box.delete(id);
  }

  // Find an organization by its ID
  Organization? getOrganizationById(String id) {
    return _box.get(id);
  }
}
