import 'dart:io';
import 'package:csv/csv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/providers/attendance_provider.dart';
import '../../../services/providers/emp_provider.dart';
import '../../../services/providers/cur_group_provider.dart';
import '../../../services/providers/cur_branch_provider.dart';
import '../../../services/providers/cur_org_provider.dart';
import '../../../foundation/security/admin_security.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  String? selectedEmployeeId;
  DateTime selectedMonth = DateTime.now();
  bool isLoading = false;
  bool isAdminMode = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await AdminSecurity().isAdmin();
    setState(() {
      isAdminMode = isAdmin;
    });
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
        await ref.read(attendanceProvider.notifier).loadAttendanceLogsByMonth(
            currentOrg.id,
            currentBranch.id,
            currentGroup.id,
            selectedMonth.year,
            selectedMonth.month);
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

  Future<void> _filterByMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        // This hides the day selection
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });

      await _refreshData();
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentOrg = ref.read(currentOrganizationProvider);
      final currentBranch = ref.read(currentBranchProvider);
      final currentGroup = ref.read(currentGroupProvider);

      if (currentOrg == null || currentBranch == null || currentGroup == null) {
        return;
      }

      if (selectedEmployeeId != null) {
        await ref.read(attendanceProvider.notifier).loadEmployeeAttendanceLogs(
            currentOrg.id,
            currentBranch.id,
            currentGroup.id,
            selectedEmployeeId!);
      } else {
        await ref.read(attendanceProvider.notifier).loadAttendanceLogsByMonth(
            currentOrg.id,
            currentBranch.id,
            currentGroup.id,
            selectedMonth.year,
            selectedMonth.month);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to refresh data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAttendanceLog(String logId) async {
    if (!isAdminMode) {
      _showErrorSnackBar('Admin access required');
      return;
    }

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
            'Are you sure you want to delete this attendance record? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isLoading = true;
      });

      try {
        await ref.read(attendanceProvider.notifier).deleteAttendanceLog(logId);
        _showSnackBar('Attendance record deleted');
        await _refreshData();
      } catch (e) {
        _showErrorSnackBar('Failed to delete record: $e');
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _exportAttendanceCSV() async {
    final attendanceLogs = ref.read(attendanceProvider);
    final employees = ref.read(employeeProvider);

    if (attendanceLogs == null || attendanceLogs.isEmpty) {
      _showSnackBar('No attendance records to export', isSuccess: false);
      return;
    }

    // Request permission for Android
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnackBar('Storage permission denied', isSuccess: false);
        return;
      }
    }

    final rows = <List<String>>[];

    // Add headers
    rows.add([
      'Employee Name',
      'Date',
      'In Time',
      'Out Time',
      'Duration',
      'Punch In Image',
      'Punch Out Image',
      'Notes'
    ]);

    for (final log in attendanceLogs) {
      final emp = employees?.firstWhere(
        (e) => e.id == log.employeeId,
        orElse: () => Employee('Unknown', '', '', {}, log.employeeId),
      );

      final name = emp?.name ?? 'Unknown';
      final date = DateFormat('yyyy-MM-dd').format(log.punchInTime);
      final inTime = DateFormat('h:mm a').format(log.punchInTime);
      final outTime = log.punchOutTime != null
          ? DateFormat('h:mm a').format(log.punchOutTime!)
          : '--';
      final duration = log.punchOutTime != null
          ? '${log.punchOutTime!.difference(log.punchInTime).inHours}h ${log.punchOutTime!.difference(log.punchInTime).inMinutes % 60}m'
          : '--';

      rows.add([
        name,
        date,
        inTime,
        outTime,
        duration,
        log.punchInImagePath ?? '',
        log.punchOutImagePath ?? '',
        log.notes ?? '',
      ]);
    }

    // Convert to CSV
    final csvData = const ListToCsvConverter().convert(rows);

    // Save file
    final directory =
        await getExternalStorageDirectory(); // safer than Downloads
    final downloadsDir = Directory('/storage/emulated/0/Download');
    final path =
        '${downloadsDir.path}/attendance_export_${DateTime.now().millisecondsSinceEpoch}.csv';

    final file = File(path);
    await file.writeAsString(csvData);

    _showSnackBar('CSV exported to Downloads folder');
  }

  void _viewAttendanceImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final employees = ref.watch(employeeProvider);
    final attendanceLogs = ref.watch(attendanceProvider);

    if (currentGroup == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("attendanceHistory".tr()),
          // Add leading back button
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/attendance'),
          ),
        ),
        body: Center(child: Text("noGrpSelected".tr())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("attendanceHistory".tr()),
        // Add leading back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/attendance'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Employee',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedEmployeeId,
                              hint: const Text('All Employees'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Employees'),
                                ),
                                ...?employees?.map((employee) {
                                  return DropdownMenuItem<String>(
                                    value: employee.id,
                                    child: Text(employee.name),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedEmployeeId = value;
                                });
                                _refreshData();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _filterByMonth,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                                DateFormat('MMM yyyy').format(selectedMonth)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () {
                                _exportAttendanceCSV();
                              },
                              child: Text('Export as csv',style: TextStyle(color: Colors.red),)),
                        ],
                      )
                    ],
                  ),
                ),

                // Records
                Expanded(
                  child: attendanceLogs == null || attendanceLogs.isEmpty
                      ? Center(child: Text("noAttendanceRecords".tr()))
                      : _buildAttendanceList(attendanceLogs, employees),
                ),
              ],
            ),
    );
  }

  Widget _buildAttendanceList(
      List<AttendanceLog> logs, List<Employee>? employees) {
    // Filter logs for selected employee if needed
    final filteredLogs = selectedEmployeeId != null
        ? logs.where((log) => log.employeeId == selectedEmployeeId).toList()
        : logs;

    // Sort by most recent first
    filteredLogs.sort((a, b) => b.punchInTime.compareTo(a.punchInTime));

    return ListView.builder(
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        return _buildAttendanceCard(filteredLogs[index], employees);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceLog log, List<Employee>? employees) {
    // Find employee
    final employee = employees?.firstWhere(
      (e) => e.id == log.employeeId,
      orElse: () => Employee('Unknown', '', '', {}, log.employeeId),
    );

    final bool isActive = log.punchOutTime == null;

    // Calculate duration if punched out
    String duration = '';
    if (log.punchOutTime != null) {
      final diff = log.punchOutTime!.difference(log.punchInTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      duration = '$hours h $minutes m';
    }

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
                        DateFormat('EEEE, MMMM d, yyyy')
                            .format(log.punchInTime),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                if (isAdminMode)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteAttendanceLog(log.id),
                    tooltip: 'Delete',
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
                  if (duration.isNotEmpty) ...[
                    const VerticalDivider(
                      thickness: 1,
                      width: 24,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duration:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(duration),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (log.punchInImagePath != null ||
                log.punchOutImagePath != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (log.punchInImagePath != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Punch In Photo'),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _viewAttendanceImage(
                                context, log.punchInImagePath!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(log.punchInImagePath!),
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (log.punchOutImagePath != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Punch Out Photo'),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _viewAttendanceImage(
                                context, log.punchOutImagePath!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(log.punchOutImagePath!),
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(log.notes!),
            ],
          ],
        ),
      ),
    );
  }
}