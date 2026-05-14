import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'screens/main_screen.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ✨ [핵심] 앱이 켜지기 전에 카카오맵 구멍(View)을 미리 무조건 뚫어둡니다!
  ui_web.platformViewRegistry.registerViewFactory('kakao-map-view', (int viewId) {
    final div = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'; 

    // ✨ 구멍(div)을 파자마자, JS 함수에게 직접 던져줍니다!
    Future.delayed(const Duration(milliseconds: 100), () {
      js.context.callMethod('initKakaoMap', [div]);
    });

    return div;
  });

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI 맛집 추천',
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: const MainScreen(),
    );
  }
}