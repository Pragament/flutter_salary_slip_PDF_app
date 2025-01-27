

// Provider to access all branches for a specific organization
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';

import '../base/database/hive_manager/Repos/branch_repo.dart';
import '../base/database/hive_manager/models.dart';
import 'cur_org_provider.dart';

final branchProvider = StateNotifierProvider<BranchNotifier, List<Branch>>((ref) {
  final currentOrganization = ref.watch(currentOrganizationProvider);
  return BranchNotifier(ref.read(branchRepositoryProvider),currentOrganization);
});

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  final box = Hive.box<Organization>('organizations');
  return BranchRepository(box);
});

// StateNotifier to manage branches
class BranchNotifier extends StateNotifier<List<Branch>> {
  final BranchRepository _branchRepository;
  final Organization? organization;

  BranchNotifier(this._branchRepository,this.organization) : super([]){
    init();
  }

  // Initialize the list of branches for a specific organization
  void init()  {
    state = _branchRepository.getAll(organization!.id);
  }

  // Add a new branch to an organization
  void addBranch(String organizationId, Branch branch) {
    _branchRepository.addBranch(organizationId, branch);
    state = _branchRepository.getAll(organizationId);
  }

  // Update an existing branch
  void updateBranch(String organizationId, Branch branch) {
    _branchRepository.updateBranch(organizationId, branch);
    state = _branchRepository.getAll(organizationId);
  }

  // Delete a branch
  void deleteBranch(String organizationId, String branchId) {
    _branchRepository.deleteBranch(organizationId, branchId);
    state = _branchRepository.getAll(organizationId);
  }
}
