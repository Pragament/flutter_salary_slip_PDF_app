import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../base/database/hive_manager/Repos/attendance_repo.dart';
import '../base/database/hive_manager/models.dart';

// Notifier for attendance logs
class AttendanceNotifier extends StateNotifier<List<AttendanceLog>?> {
  final AttendanceRepository _repository;

  AttendanceNotifier(this._repository) : super(null);

  // Load attendance logs
  Future<void> loadAttendanceLogs(
      String orgId, String branchId, String groupId) async {
    try {
      final logs =
          await _repository.getAttendanceLogs(orgId, branchId, groupId);
      state = logs;
    } catch (e) {
      print('Error loading attendance logs: $e');
      // Keep existing state if there's an error
      if (state == null) state = [];
    }
  }

  // Load recent attendance logs (last 7 days)
  Future<void> loadRecentAttendanceLogs(
      String orgId, String branchId, String groupId) async {
    try {
      final logs =
          await _repository.getRecentAttendanceLogs(orgId, branchId, groupId);
      state = logs;
    } catch (e) {
      print('Error loading recent attendance logs: $e');
      // Keep existing state if there's an error
      if (state == null) state = [];
    }
  }

  // Load attendance logs for a specific employee
  Future<void> loadEmployeeAttendanceLogs(
      String orgId, String branchId, String groupId, String employeeId) async {
    try {
      final logs = await _repository.getEmployeeAttendanceLogs(
          orgId, branchId, groupId, employeeId);
      state = logs;
    } catch (e) {
      print('Error loading employee attendance logs: $e');
      if (state == null) state = [];
    }
  }

  // Load attendance logs for a specific month
  Future<void> loadAttendanceLogsByMonth(String orgId, String branchId,
      String groupId, int year, int month) async {
    try {
      final logs = await _repository.getAttendanceLogsByMonth(
          orgId, branchId, groupId, year, month);
      state = logs;
    } catch (e) {
      print('Error loading attendance logs by month: $e');
      if (state == null) state = [];
    }
  }

  // Punch in
  Future<AttendanceLog> punchIn(
    String orgId,
    String branchId,
    String groupId,
    String employeeId,
    String? imagePath,
    String? notes, {
    bool? faceVerified,
  }) async {
    final newLog = await _repository.punchIn(
        orgId, branchId, groupId, employeeId, imagePath, notes,
        faceVerified: faceVerified);

    // Update state with the new log
    if (state != null) {
      state = [...state!, newLog];
    } else {
      state = [newLog];
    }

    return newLog;
  }

  // Punch out
  Future<AttendanceLog> punchOut(
    String logId,
    String? imagePath,
    String? notes, {
    bool? faceVerified,
  }) async {
    final updatedLog = await _repository.punchOut(logId, imagePath, notes,
        faceVerified: faceVerified);

    // Update the log in the state
    if (state != null) {
      state = state!.map((log) => log.id == logId ? updatedLog : log).toList();
    }

    return updatedLog;
  }

  // Get the latest attendance log for an employee
  Future<AttendanceLog?> getLatestAttendanceLog(
      String orgId, String branchId, String groupId, String employeeId) async {
    return await _repository.getLatestAttendanceLog(
        orgId, branchId, groupId, employeeId);
  }

  // Delete an attendance log
  Future<void> deleteAttendanceLog(String logId) async {
    await _repository.deleteAttendanceLog(logId);

    // Remove the log from the state
    if (state != null) {
      state = state!.where((log) => log.id != logId).toList();
    }
  }
}

// Provider for attendance logs
final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, List<AttendanceLog>?>((ref) {
  final repository = ref.watch(attendanceRepositoryProvider);
  return AttendanceNotifier(repository);
});

// Provider for currently selected employee filter
final selectedEmployeeFilterProvider = StateProvider<String?>((ref) => null);

// Provider for selected month filter
final selectedMonthFilterProvider =
    StateProvider<DateTime>((ref) => DateTime.now());
