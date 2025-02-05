import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/navigation/base/app_router.dart';  // Your GoRouter setup
import 'package:flutter_template/presentation/base/widgets/theme/theme_listener.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:get_it/get_it.dart';

import '../navigation/base/router.dart';
import 'base/theme/theme_data/template_app_theme_data.dart';
import 'base/widgets/snackbar/snackbar.dart';

class TemplateApp extends StatelessWidget {
  TemplateApp({super.key});

  //final AppRouter _appRouter = GetIt.I.get();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: ThemeStateListener(
        builder: (themeState) => DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final lightTheme = (themeState.isDynamic && lightDynamic != null)
                ? buildTheme(lightDynamic.harmonized())
                : material3LightTheme;
            final darkTheme = (themeState.isDynamic && darkDynamic != null)
                ? buildTheme(darkDynamic.harmonized())
                : material3DarkTheme;
            return MaterialApp.router(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              routerConfig: router,  // Set routerConfig directly here
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeState.themeMode,
             // scaffoldMessengerKey: scaffoldMessengerKey,  // Use if you have a scaffold messenger key
            );
          },
        ),
      ),
    );
  }
}
