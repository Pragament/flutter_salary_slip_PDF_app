import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Employee extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String phone;
  @HiveField(3)
  final String email;
  @HiveField(4)
  final Map<String, Map<String, String>> dynamicFields;
  @HiveField(5)
  final List<double>? faceFeatures; // Face recognition features
  @HiveField(6)
  final String? profileImagePath; // Path to reference image

  Employee(
    this.name,
    this.phone,
    this.email,
    this.dynamicFields,
    this.id, {
    this.faceFeatures,
    this.profileImagePath,
  });

  // Copy method to update employee with face features
  Employee copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    Map<String, Map<String, String>>? dynamicFields,
    List<double>? faceFeatures,
    String? profileImagePath,
  }) {
    return Employee(
      name ?? this.name,
      phone ?? this.phone,
      email ?? this.email,
      dynamicFields ?? this.dynamicFields,
      id ?? this.id,
      faceFeatures: faceFeatures ?? this.faceFeatures,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }

  // Check if employee has face recognition trained
  bool get hasFaceRecognition =>
      faceFeatures != null && faceFeatures!.isNotEmpty;

  @override
  String toString() {
    return 'Employee{id: $id, name: $name, phone: $phone, email: $email, hasFaceFeatures: $hasFaceRecognition}';
  }
}

@HiveType(typeId: 1)
class Group extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  List<Employee>? employees;
  @HiveField(3)
  final Map<String, Map<String, String>> dynamicFields;

  Group(this.name, this.employees, this.dynamicFields, this.id);
}

@HiveType(typeId: 2)
class Branch extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  List<Group>? groups;
  @HiveField(3)
  final Map<String, Map<String, String>> dynamicFields;

  Branch(this.name, this.groups, this.dynamicFields, this.id);
}

@HiveType(typeId: 3)
class Organization extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String phone;
  @HiveField(3)
  final String mail;
  @HiveField(4)
  final String address;
  @HiveField(5)
  List<Branch>? branches;
  @HiveField(6)
  final Map<String, Map<String, String>> dynamicFields;
  @HiveField(7)
  final Uint8List? img;

  Organization(this.name, this.branches, this.dynamicFields, this.id,
      this.phone, this.mail, this.address, this.img);
}

@HiveType(typeId: 4)
class AttendanceLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String employeeId;

  @HiveField(2)
  final DateTime punchInTime;

  @HiveField(3)
  final DateTime? punchOutTime;

  @HiveField(4)
  final String? punchInImagePath;

  @HiveField(5)
  final String? punchOutImagePath;

  @HiveField(6)
  final String? notes;

  @HiveField(7)
  final String organizationId;

  @HiveField(8)
  final String branchId;

  @HiveField(9)
  final String groupId;

  @HiveField(10)
  final bool? punchInFaceVerified;

  @HiveField(11)
  final bool? punchOutFaceVerified;

  AttendanceLog({
    required this.id,
    required this.employeeId,
    required this.punchInTime,
    this.punchOutTime,
    this.punchInImagePath,
    this.punchOutImagePath,
    this.notes,
    required this.organizationId,
    required this.branchId,
    required this.groupId,
    this.punchInFaceVerified,
    this.punchOutFaceVerified,
  });

  // Calculate duration between punch in and punch out
  Duration? get duration {
    if (punchOutTime == null) return null;
    return punchOutTime!.difference(punchInTime);
  }

  // Clone with updated values
  AttendanceLog copyWith({
    String? id,
    String? employeeId,
    DateTime? punchInTime,
    DateTime? punchOutTime,
    String? punchInImagePath,
    String? punchOutImagePath,
    String? notes,
    String? organizationId,
    String? branchId,
    String? groupId,
    bool? punchInFaceVerified,
    bool? punchOutFaceVerified,
  }) {
    return AttendanceLog(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      punchInTime: punchInTime ?? this.punchInTime,
      punchOutTime: punchOutTime ?? this.punchOutTime,
      punchInImagePath: punchInImagePath ?? this.punchInImagePath,
      punchOutImagePath: punchOutImagePath ?? this.punchOutImagePath,
      notes: notes ?? this.notes,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      groupId: groupId ?? this.groupId,
      punchInFaceVerified: punchInFaceVerified ?? this.punchInFaceVerified,
      punchOutFaceVerified: punchOutFaceVerified ?? this.punchOutFaceVerified,
    );
  }
}
