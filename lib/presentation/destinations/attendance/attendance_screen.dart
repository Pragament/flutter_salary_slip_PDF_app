import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/providers/attendance_provider.dart';
import '../../../services/providers/emp_provider.dart';
import '../../../services/providers/cur_group_provider.dart';
import '../../../services/providers/cur_branch_provider.dart';
import '../../../services/providers/cur_org_provider.dart';
import '../camera/camera_screen.dart';
import 'attendance_history_screen.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? selectedEmployeeId;
  bool isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final currentOrg = ref.read(currentOrganizationProvider);
      final currentBranch = ref.read(currentBranchProvider);
      final currentGroup = ref.read(currentGroupProvider);
      
      if (currentOrg != null && currentBranch != null && currentGroup != null) {
        await ref.read(attendanceProvider.notifier).loadRecentAttendanceLogs(
          currentOrg.id,
          currentBranch.id,
          currentGroup.id
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load attendance data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  void _showSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    _showSnackBar(message, isSuccess: false);
  }
  
  Future<void> _handlePunchIn() async {
    if (selectedEmployeeId == null) {
      _showErrorSnackBar('Please select an employee');
      return;
    }
    
    final currentOrg = ref.read(currentOrganizationProvider);
    final currentBranch = ref.read(currentBranchProvider);
    final currentGroup = ref.read(currentGroupProvider);
    
    if (currentOrg == null || currentBranch == null || currentGroup == null) {
      _showErrorSnackBar('Organization, branch, or group not selected');
      return;
    }
    
    try {
      // First check if the employee already has an active session
      final latestLog = await ref.read(attendanceProvider.notifier).getLatestAttendanceLog(
        currentOrg.id, 
        currentBranch.id, 
        currentGroup.id, 
        selectedEmployeeId!
      );
      
      if (latestLog != null && latestLog.punchOutTime == null) {
        _showErrorSnackBar('This employee is already punched in');
        return;
      }
      
      // Open camera for selfie
      final imagePath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(
            title: 'Punch In Selfie',
          ),
        ),
      );
      
      if (imagePath == null) {
        // User canceled
        return;
      }
      
      setState(() {
        isLoading = true;
      });
      
      // Create punch-in record
      await ref.read(attendanceProvider.notifier).punchIn(
        currentOrg.id,
        currentBranch.id,
        currentGroup.id,
        selectedEmployeeId!,
        imagePath,
        null // no notes
      );
      
      _showSnackBar('Successfully punched in');
      
      // Refresh logs
      await ref.read(attendanceProvider.notifier).loadRecentAttendanceLogs(
        currentOrg.id,
        currentBranch.id,
        currentGroup.id
      );
    } catch (e) {
      _showErrorSnackBar('Failed to punch in: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  Future<void> _handlePunchOut() async {
    if (selectedEmployeeId == null) {
      _showErrorSnackBar('Please select an employee');
      return;
    }
    
    final currentOrg = ref.read(currentOrganizationProvider);
    final currentBranch = ref.read(currentBranchProvider);
    final currentGroup = ref.read(currentGroupProvider);
    
    if (currentOrg == null || currentBranch == null || currentGroup == null) {
      _showErrorSnackBar('Organization, branch, or group not selected');
      return;
    }
    
    try {
      // Get the latest attendance log for this employee
      final latestLog = await ref.read(attendanceProvider.notifier).getLatestAttendanceLog(
        currentOrg.id, 
        currentBranch.id, 
        currentGroup.id, 
        selectedEmployeeId!
      );
      
      if (latestLog == null || latestLog.punchOutTime != null) {
        _showErrorSnackBar('No active attendance session found for this employee');
        return;
      }
      
      // Open camera for selfie
      final imagePath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(
            title: 'Punch Out Selfie',
          ),
        ),
      );
      
      if (imagePath == null) {
        // User canceled
        return;
      }
      
      setState(() {
        isLoading = true;
      });
      
      // Update punch-out record
      await ref.read(attendanceProvider.notifier).punchOut(
        latestLog.id,
        imagePath,
        null // no notes
      );
      
      _showSnackBar('Successfully punched out');
      
      // Refresh logs
      await ref.read(attendanceProvider.notifier).loadRecentAttendanceLogs(
        currentOrg.id,
        currentBranch.id,
        currentGroup.id
      );
    } catch (e) {
      _showErrorSnackBar('Failed to punch out: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  void _viewAttendanceHistory() {
    // Use GoRouter instead of MaterialPageRoute
    context.go('/attendance/history');
  }
  
  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final employees = ref.watch(employeeProvider);
    final attendanceLogs = ref.watch(attendanceProvider);
    
    if (currentGroup == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("attendance".tr()),
          // Add leading back button
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(child: Text("noGrpSelected".tr())),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text("attendance".tr()),
        // Add leading back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _viewAttendanceHistory,
            tooltip: 'View History',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Employee selector
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select Employee",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        isExpanded: true,
                        hint: const Text('Select an employee'),
                        value: selectedEmployeeId,
                        items: employees?.map((employee) {
                          return DropdownMenuItem<String>(
                            value: employee.id,
                            child: Text(employee.name),
                          );
                        }).toList() ?? [],
                        onChanged: (value) {
                          setState(() {
                            selectedEmployeeId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                // Recent attendance
                Expanded(
                  child: attendanceLogs == null || attendanceLogs.isEmpty
                      ? Center(child: Text("noAttendanceRecords".tr()))
                      : _buildRecentAttendanceList(attendanceLogs, employees),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'punch_in',
            onPressed: _handlePunchIn,
            backgroundColor: Colors.green,
            child: const Icon(Icons.login),
            tooltip: 'Punch In',
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'punch_out',
            onPressed: _handlePunchOut,
            backgroundColor: Colors.red,
            child: const Icon(Icons.logout),
            tooltip: 'Punch Out',
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentAttendanceList(List<AttendanceLog> logs, List<Employee>? employees) {
    // Filter logs for selected employee if needed
    final filteredLogs = selectedEmployeeId != null
        ? logs.where((log) => log.employeeId == selectedEmployeeId).toList()
        : logs;
    
    // Sort by most recent first
    filteredLogs.sort((a, b) => b.punchInTime.compareTo(a.punchInTime));
    
    // Limit to recent logs only
    final recentLogs = filteredLogs.take(10).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Recent Attendance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: recentLogs.isEmpty
              ? Center(child: Text('No recent attendance records'))
              : ListView.builder(
                  itemCount: recentLogs.length,
                  itemBuilder: (context, index) {
                    return _buildAttendanceCard(recentLogs[index], employees);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildAttendanceCard(AttendanceLog log, List<Employee>? employees) {
    // Find employee
    final employee = employees?.firstWhere(
      (e) => e.id == log.employeeId,
      orElse: () => Employee('Unknown', '', '', {}, log.employeeId),
    );
    
    final bool isActive = log.punchOutTime == null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee?.name ?? 'Unknown Employee',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(log.punchInTime),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'In:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(DateFormat('h:mm a').format(log.punchInTime)),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                    thickness: 1,
                    width: 24,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Out:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log.punchOutTime != null
                              ? DateFormat('h:mm a').format(log.punchOutTime!)
                              : '-- : --',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (log.punchInImagePath != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(log.punchInImagePath!),
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: log.punchOutImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(log.punchOutImagePath!),
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}