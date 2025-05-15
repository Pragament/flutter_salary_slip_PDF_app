import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/base/database/hive_manager/models.dart';
import 'package:flutter_template/services/base/id_generator.dart';
import 'package:hive/hive.dart';



class AttendanceRepository {
  static const String _boxName = 'attendance_logs';
  
  // Initialize Hive box
  Future<Box<AttendanceLog>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<AttendanceLog>(_boxName);
    }
    return Hive.box<AttendanceLog>(_boxName);
  }
  
  // Get all attendance logs for an organization
  Future<List<AttendanceLog>> getAttendanceLogs(
    String orgId, 
    String branchId, 
    String groupId
  ) async {
    final box = await _getBox();
    
    return box.values
        .where((log) => 
            log.organizationId == orgId &&
            log.branchId == branchId &&
            log.groupId == groupId)
        .toList();
  }
  
  // Get attendance logs for a specific employee
  Future<List<AttendanceLog>> getEmployeeAttendanceLogs(
    String orgId, 
    String branchId, 
    String groupId, 
    String employeeId
  ) async {
    final box = await _getBox();
    
    return box.values
        .where((log) => 
            log.organizationId == orgId &&
            log.branchId == branchId &&
            log.groupId == groupId &&
            log.employeeId == employeeId)
        .toList();
  }
  
  // Get attendance logs for a specific month
  Future<List<AttendanceLog>> getAttendanceLogsByMonth(
    String orgId, 
    String branchId, 
    String groupId,
    int year,
    int month
  ) async {
    final box = await _getBox();
    
    return box.values
        .where((log) => 
            log.organizationId == orgId &&
            log.branchId == branchId &&
            log.groupId == groupId &&
            log.punchInTime.year == year &&
            log.punchInTime.month == month)
        .toList();
  }
  
  // Get recent attendance logs (last 7 days)
  Future<List<AttendanceLog>> getRecentAttendanceLogs(
    String orgId, 
    String branchId, 
    String groupId
  ) async {
    final box = await _getBox();
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    return box.values
        .where((log) => 
            log.organizationId == orgId &&
            log.branchId == branchId &&
            log.groupId == groupId &&
            log.punchInTime.isAfter(sevenDaysAgo))
        .toList();
  }
  
  // Create a new punch-in record
  Future<AttendanceLog> punchIn(
    String orgId,
    String branchId,
    String groupId,
    String employeeId,
    String? imagePath,
    String? notes
  ) async {
    final box = await _getBox();
    
    final newLog = AttendanceLog(
      id: generateId(),
      employeeId: employeeId,
      punchInTime: DateTime.now(),
      punchInImagePath: imagePath,
      notes: notes,
      organizationId: orgId,
      branchId: branchId,
      groupId: groupId,
    );
    
    await box.put(newLog.id, newLog);
    return newLog;
  }
  
  // Update with punch-out
  Future<AttendanceLog> punchOut(
    String logId,
    String? imagePath,
    String? notes
  ) async {
    final box = await _getBox();
    final log = box.get(logId);
    
    if (log == null) {
      throw Exception('Attendance log not found');
    }
    
    final updatedLog = log.copyWith(
      punchOutTime: DateTime.now(),
      punchOutImagePath: imagePath,
      notes: notes ?? log.notes,
    );
    
    await box.put(logId, updatedLog);
    return updatedLog;
  }
  
  // Get the latest attendance log for an employee
  Future<AttendanceLog?> getLatestAttendanceLog(
    String orgId,
    String branchId,
    String groupId,
    String employeeId
  ) async {
    final box = await _getBox();
    
    final logs = box.values
        .where((log) => 
            log.organizationId == orgId &&
            log.branchId == branchId &&
            log.groupId == groupId &&
            log.employeeId == employeeId)
        .toList();
    
    if (logs.isEmpty) return null;
    
    // Sort logs by punch-in time (newest first)
    logs.sort((a, b) => b.punchInTime.compareTo(a.punchInTime));
    
    return logs.first;
  }
  
  // Delete an attendance log
  Future<void> deleteAttendanceLog(String logId) async {
    final box = await _getBox();
    await box.delete(logId);
  }
}

// Provider for the attendance repository
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});