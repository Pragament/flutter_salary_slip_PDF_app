
// Provider to access all organizations
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';

import '../base/database/hive_manager/Repos/org_repo.dart';
import '../base/database/hive_manager/models.dart';

final organizationProvider = StateNotifierProvider<OrganizationNotifier, List<Organization>>((ref) {
  return OrganizationNotifier(ref.read(organizationRepositoryProvider));
});

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  final box = Hive.box<Organization>('organizations');
  return OrganizationRepository(box);
});

// StateNotifier to manage organizations
class OrganizationNotifier extends StateNotifier<List<Organization>> {
  final OrganizationRepository _organizationRepository;

  OrganizationNotifier(this._organizationRepository) : super([]){
    init();
  }

  // Initialize the list of organizations
  void init()  {
    state = _organizationRepository.getAll();
  }

  // Add a new organization
  void addOrganization(Organization organization) {
    _organizationRepository.addOrganization(organization);
    state = _organizationRepository.getAll();
  }

  // Update an existing organization
  void updateOrganization(Organization organization) {
    _organizationRepository.updateOrganization(organization);
    state = _organizationRepository.getAll();
  }

  // Delete an organization
  void deleteOrganization(String id) {
    _organizationRepository.deleteOrganization(id);
    state = _organizationRepository.getAll();
  }
}
