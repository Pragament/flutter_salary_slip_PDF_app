import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';

class AttendanceRepository {
  final Box<Organization> _box;
  final Uuid _uuid = Uuid();

  AttendanceRepository(this._box);

  // Get all attendance logs for a specific group
  Future<List<AttendanceLog>> getAttendanceLogs(
      String orgId, String branchId, String groupId) async {
    try {
      final org = _box.values.firstWhere((org) => org.id == orgId);
      final branch =
          org.branches?.firstWhere((branch) => branch.id == branchId);
      final group = branch?.groups?.firstWhere((group) => group.id == groupId);

      if (group == null) return [];

      final attendanceBox =
          await Hive.openBox<AttendanceLog>('attendance_logs');

      final logs = attendanceBox.values
          .where((log) =>
              log.organizationId == orgId &&
              log.branchId == branchId &&
              log.groupId == groupId)
          .toList();

      return logs;
    } catch (e) {
      print('Error getting attendance logs: $e');
      return [];
    }
  }

  // Get recent attendance logs (last 7 days)
  Future<List<AttendanceLog>> getRecentAttendanceLogs(
      String orgId, String branchId, String groupId) async {
    try {
      final logs = await getAttendanceLogs(orgId, branchId, groupId);

      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));

      return logs
          .where((log) => log.punchInTime.isAfter(sevenDaysAgo))
          .toList();
    } catch (e) {
      print('Error getting recent attendance logs: $e');
      return [];
    }
  }

  // Get attendance logs for a specific employee
  Future<List<AttendanceLog>> getEmployeeAttendanceLogs(
      String orgId, String branchId, String groupId, String employeeId) async {
    try {
      final logs = await getAttendanceLogs(orgId, branchId, groupId);

      return logs.where((log) => log.employeeId == employeeId).toList();
    } catch (e) {
      print('Error getting employee attendance logs: $e');
      return [];
    }
  }

  // Get attendance logs for a specific month
  Future<List<AttendanceLog>> getAttendanceLogsByMonth(String orgId,
      String branchId, String groupId, int year, int month) async {
    try {
      final logs = await getAttendanceLogs(orgId, branchId, groupId);

      return logs
          .where((log) =>
              log.punchInTime.year == year && log.punchInTime.month == month)
          .toList();
    } catch (e) {
      print('Error getting attendance logs by month: $e');
      return [];
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
    try {
      final attendanceBox =
          await Hive.openBox<AttendanceLog>('attendance_logs');

      String? savedImagePath;
      if (imagePath != null) {
        // Copy image to a permanent location
        savedImagePath = await _saveAttendanceImage(imagePath, 'punch_in');
      }

      final newLog = AttendanceLog(
        id: _uuid.v4(),
        employeeId: employeeId,
        punchInTime: DateTime.now(),
        punchInImagePath: savedImagePath,
        notes: notes,
        organizationId: orgId,
        branchId: branchId,
        groupId: groupId,
        punchInFaceVerified: faceVerified,
      );

      await attendanceBox.put(newLog.id, newLog);

      return newLog;
    } catch (e) {
      print('Error punching in: $e');
      rethrow;
    }
  }

  // Punch out
  Future<AttendanceLog> punchOut(
    String logId,
    String? imagePath,
    String? notes, {
    bool? faceVerified,
  }) async {
    try {
      final attendanceBox =
          await Hive.openBox<AttendanceLog>('attendance_logs');

      final existingLog = attendanceBox.get(logId);
      if (existingLog == null) {
        throw Exception('Attendance log not found');
      }

      String? savedImagePath;
      if (imagePath != null) {
        // Copy image to a permanent location
        savedImagePath = await _saveAttendanceImage(imagePath, 'punch_out');
      }

      // Combine notes if both exist
      String? combinedNotes = existingLog.notes;
      if (notes != null) {
        if (combinedNotes != null) {
          combinedNotes = '$combinedNotes\n$notes';
        } else {
          combinedNotes = notes;
        }
      }

      final updatedLog = existingLog.copyWith(
        punchOutTime: DateTime.now(),
        punchOutImagePath: savedImagePath,
        notes: combinedNotes,
        punchOutFaceVerified: faceVerified,
      );

      await attendanceBox.put(logId, updatedLog);

      return updatedLog;
    } catch (e) {
      print('Error punching out: $e');
      rethrow;
    }
  }

  // Get the latest attendance log for an employee
  Future<AttendanceLog?> getLatestAttendanceLog(
      String orgId, String branchId, String groupId, String employeeId) async {
    try {
      final logs =
          await getEmployeeAttendanceLogs(orgId, branchId, groupId, employeeId);

      if (logs.isEmpty) return null;

      // Sort by punch in time (newest first)
      logs.sort((a, b) => b.punchInTime.compareTo(a.punchInTime));

      return logs.first;
    } catch (e) {
      print('Error getting latest attendance log: $e');
      return null;
    }
  }

  // Delete an attendance log
  Future<void> deleteAttendanceLog(String logId) async {
    try {
      final attendanceBox =
          await Hive.openBox<AttendanceLog>('attendance_logs');

      final log = attendanceBox.get(logId);
      if (log != null) {
        // Delete associated images
        if (log.punchInImagePath != null) {
          try {
            await File(log.punchInImagePath!).delete();
          } catch (e) {
            print('Error deleting punch in image: $e');
          }
        }

        if (log.punchOutImagePath != null) {
          try {
            await File(log.punchOutImagePath!).delete();
          } catch (e) {
            print('Error deleting punch out image: $e');
          }
        }

        // Delete the log
        await attendanceBox.delete(logId);
      }
    } catch (e) {
      print('Error deleting attendance log: $e');
      rethrow;
    }
  }

  // Helper method to save attendance images
  Future<String> _saveAttendanceImage(String sourcePath, String type) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final attendanceImagesDir =
          Directory(path.join(directory.path, 'attendance_images'));

      if (!await attendanceImagesDir.exists()) {
        await attendanceImagesDir.create(recursive: true);
      }

      final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = path.join(attendanceImagesDir.path, fileName);

      // Copy the file
      await File(sourcePath).copy(destinationPath);

      return destinationPath;
    } catch (e) {
      print('Error saving attendance image: $e');
      rethrow;
    }
  }
}

// Provider for attendance repository
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final box = Hive.box<Organization>('organizations');
  return AttendanceRepository(box);
});
