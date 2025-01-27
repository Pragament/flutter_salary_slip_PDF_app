import 'dart:typed_data';

import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Employee extends HiveObject{
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String phone;
  @HiveField(3)
  final String email;
  @HiveField(4)
  final Map<String, String> dynamicFields;

  Employee(this.name, this.phone, this.email, this.dynamicFields, this.id);
}

@HiveType(typeId: 1)
class Group extends HiveObject{
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  List<Employee>? employees;
  @HiveField(3)
  final Map<String, String> dynamicFields;

  Group(this.name, this.employees, this.dynamicFields, this.id);
}

@HiveType(typeId: 2)
class Branch extends HiveObject{
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  List<Group>? groups;
  @HiveField(3)
  final Map<String, String> dynamicFields;

  Branch(this.name, this.groups, this.dynamicFields, this.id);
}

@HiveType(typeId: 3)
class Organization extends HiveObject{

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
  final Map<String, String> dynamicFields;
  @HiveField(7)
  final Uint8List? img;


  Organization(this.name, this.branches, this.dynamicFields, this.id, this.phone, this.mail, this.address, this.img);
}

