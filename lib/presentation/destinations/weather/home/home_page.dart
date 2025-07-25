import 'package:auto_route/annotations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/presentation/base/widgets/theme/theme_picker/theme_picker.dart';
import 'package:flutter_template/presentation/destinations/weather/home/home_screen.dart';
import 'package:flutter_template/presentation/destinations/weather/home/widgets/home_page_body/home_page_drawer.dart';
import 'package:flutter_template/generated/codegen_loader.g.dart';
import 'package:flutter_template/foundation/security/admin_security.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class HomePage extends ConsumerStatefulWidget {
  final HomeScreen homeScreen;

  const HomePage({
    super.key,
    this.homeScreen = const HomeScreen(),
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Clear admin authentication whenever home page is loaded
    _logoutAdmin();
  }
  
  Future<void> _logoutAdmin() async {
    // Using AdminSecurity class to logout
    await AdminSecurity().logout();
    
    // Double-check by directly setting the flag as well
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAdminAuthenticated', false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("homePageTitle".tr()),
        actions: [
          IconButton(
            onPressed: () {
              String locale = context.locale.toString();
              if (locale == "hi_IN") {
                context.setLocale(const Locale("te", "IN"));
              } else if (locale=="en_US"){
                context.setLocale(const Locale("hi", "IN"));
              } else {
                context.setLocale(const Locale("en", "US"));
              }
            },
            icon: const Icon(Icons.language),
          ),
          IconButton(
            onPressed: () {
              // final viewModel = ref.watch(homeViewModelProvider.notifier);
              // viewModel.onIntent(const SearchHomeScreenIntent());
            },
            icon: const Icon(Icons.search),
          ),
          const ThemePicker(),
        ],
      ),
      drawer: myDrawer(context, ref),
      body: Container(),
    );
  }
}

// import 'package:auto_route/annotations.dart';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_template/presentation/base/page/base_page.dart';
// import 'package:flutter_template/presentation/base/widgets/theme/theme_picker/theme_picker.dart';
// import 'package:flutter_template/presentation/destinations/weather/home/home_screen.dart';
// import 'package:flutter_template/presentation/destinations/weather/home/home_screen_intent.dart';
// import 'package:flutter_template/presentation/destinations/weather/home/home_screen_state.dart';
// import 'package:flutter_template/presentation/destinations/weather/home/home_view_model.dart';
// import 'package:flutter_template/presentation/destinations/weather/home/widgets/home_page_body/home_page_drawer.dart';
// import 'package:flutter_template/generated/codegen_loader.g.dart';
// import 'widgets/home_page_body/home_page_body.dart';

// @RoutePage()
// class HomePage extends ConsumerWidget {
//   final HomeScreen homeScreen;

//   const HomePage({
//     super.key,
//     this.homeScreen = const HomeScreen(),
//   });


//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     // return BasePage<HomeScreen, HomeScreenState, HomeViewModel>(
//     //   viewModelProvider: homeViewModelProvider,
//     //   screen: homeScreen,
//     //   drawer: myDrawer(context,ref),
//     //   appBarActions: () => [
//     //     IconButton(
//     //       onPressed: () {
//     //         String locale = context.locale.toString();
//     //         if (locale == "hi_IN") {
//     //           context.setLocale(const Locale("en", "US"));
//     //         } else {
//     //           context.setLocale(const Locale("hi", "IN"));
//     //         }
//     //       },
//     //       icon: const Icon(Icons.language),
//     //     ),
//     //     IconButton(
//     //       onPressed: () {
//     //         final viewModel = ref.watch(homeViewModelProvider.notifier);
//     //         viewModel.onIntent(const SearchHomeScreenIntent());
//     //       },
//     //       icon: const Icon(Icons.search),
//     //     ),
//     //     const ThemePicker(),
//     //   ],
//     //   body: const HomePageBody(),
//     // );
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("homePageTitle".tr()
//         ),
//         actions: [
//         IconButton(
//         onPressed: () {
//       String locale = context.locale.toString();
//       if (locale == "hi_IN") {
//         context.setLocale(const Locale("te", "IN"));
//       } else if (locale=="en_US"){
//         context.setLocale(const Locale("hi", "IN"));
//       }else{
//         context.setLocale(const Locale("en", "US"));
//       }
//     },
//     icon: const Icon(Icons.language),
//     ),
//     IconButton(
//     onPressed: () {
//     // final viewModel = ref.watch(homeViewModelProvider.notifier);
//     // viewModel.onIntent(const SearchHomeScreenIntent());
//     },
//     icon: const Icon(Icons.search),
//     ),
//     const ThemePicker(),
//     ],
//       ),
//       drawer: myDrawer(context, ref),
//       body: Container(),
//     );
//   }
// }
