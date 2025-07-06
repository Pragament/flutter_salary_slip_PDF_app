import 'package:flutter/material.dart';
import 'package:flutter_template/presentation/base/intent/intent_handler_callback.dart';
import 'package:flutter_template/presentation/destinations/weather/home/home_screen_intent.dart';


class HomePageBodyContent extends StatelessWidget {
  final IntentHandlerCallback<HomeScreenIntent> intentHandler;

  const HomePageBodyContent({
    super.key,
    required this.intentHandler,
  });

  @override
  Widget build(BuildContext context)  {
      return Container();
    }
  }
