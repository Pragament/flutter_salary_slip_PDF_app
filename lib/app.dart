import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/domain/di/domain_module.dart';
import 'package:flutter_template/foundation/logger/logger.dart';
import 'package:flutter_template/interactor/di/interactor_module.dart';
import 'package:flutter_template/navigation/di/navigation_module.dart';
import 'package:flutter_template/presentation/di/presentation_module.dart';
import 'package:flutter_template/presentation/intl/translations/translation_loader.dart';
import 'package:flutter_template/presentation/template_app.dart';
import 'package:flutter_template/repository/di/repository_module.dart';
import 'package:flutter_template/services/base/database/hive_manager/models.dart';
import 'package:flutter_template/services/base/database/hive_manager/Repos/org_repo.dart';
import 'package:flutter_template/services/base/id_generator.dart';
import 'package:flutter_template/services/di/service_module.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';

void startApp() async {
  await initialiseApp();

  // Add fonts license
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale("en", "US"), Locale("hi", "IN")],
      path: "assets/translations",
      fallbackLocale: const Locale("en", "US"),
      assetLoader: const CodegenLoader(),
      child: TemplateApp(),
    ),
  );
}

@visibleForTesting
Future initialiseApp({bool test = false}) async {
  final bindings = WidgetsFlutterBinding.ensureInitialized();

  bindings.deferFirstFrame();

  _initialiseGetIt();

  await Future.wait([
    _initSharedPreferences(),
    _initHive(),
    EasyLocalization.ensureInitialized(),
  ]);

  EasyLocalization.logger.printer = customEasyLogger;

  if (!kIsWeb && Platform.isAndroid) {
    try {
      FlutterDisplayMode.setHighRefreshRate();
    } on PlatformException catch (exception) {
      log.e(exception);
    }
  }

  bindings.allowFirstFrame();
}

Future _initSharedPreferences() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  GetIt.instance.registerSingleton(sharedPreferences);
}
Future _initHive() async {
  await Hive.initFlutter();
  Hive.registerAdapter(EmployeeAdapter());
  Hive.registerAdapter(GroupAdapter());
  Hive.registerAdapter(BranchAdapter());
  Hive.registerAdapter(OrganizationAdapter());

// Open the boxes
  var groupsBox = await Hive.openBox<Group>('groups');
  var branchesBox= await Hive.openBox<Branch>('branches');
  var empBox=await Hive.openBox<Employee>("employees");
  final sharedPrefs=GetIt.instance<SharedPreferences>();
  //var businessBox = await Hive.openBox('businessBox');

  var organizationsBox= await Hive.openBox<Organization>('organizations');


  if (organizationsBox.isEmpty) {
    print("Initializing default hierarchy because the organizationBox is empty");

    String defaultGroupId=generateId();
    Group defaultGroup = Group('General Team',HiveList(empBox,objects: null),{},"defaultGroupId");
    groupsBox.add(defaultGroup);

    sharedPrefs.setString("defaultGroup", "defaultGroupId");

    // Create and save Branch
    String defaultBranchId=generateId();
    Branch defaultBranch = Branch('Main Office',HiveList(branchesBox,objects: null),{},"defaultBranchId");
    defaultBranch.groups = HiveList(groupsBox);
    defaultBranch.groups!.add(defaultGroup);
    branchesBox.add(defaultBranch);

    sharedPrefs.setString("defaultBranch", "defaultBranchId");

    // Create and save Organization
    String defaultOrgId=generateId();
    Organization defaultOrg = Organization('My Business',HiveList(organizationsBox,objects: null),{},"defaultOrgId","","","",null);
    defaultOrg.branches = HiveList(branchesBox);
    defaultOrg.branches!.add(defaultBranch);

    sharedPrefs.setString("defaultOrg", "defaultOrgId");

   // final defaultOrg2=Organization('My Business',HiveList(businessBox,objects: null),{},generateId());
   //  defaultOrg2.branches = HiveList(branchesBox);
   //  defaultOrg2.branches!.add(defaultBranch);

    organizationsBox.put(defaultOrg.id, defaultOrg);
    //businessBox.put('currentOrganization', defaultOrg);
    // businessBox.put('currentBranch', defaultBranch);
    // businessBox.put('currentGroup', defaultGroup);


    print("Default hierarchy initialized");

    //print("Main : "+businessBox.get("currentOrganization").toString());

  }
}



void _initialiseGetIt() {
  log.d("Initializing dependencies...");
  GetIt.instance
    ..serviceModule()
    ..repositoryModule()
    ..domainModule()
    ..interactorModule()
    ..presentationModule();
    //..navigationModule();
}
