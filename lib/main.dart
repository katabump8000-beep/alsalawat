import 'package:flutter/material.dart';

import 'constants.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DafatriApp());
}

class DafatriApp extends StatelessWidget {
  const DafatriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'NotoSansArabic',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff6554c0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff10111a),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xff171824)),
      ),
      // كل التطبيق من اليمين لليسار (يشمل الحوارات والرسائل).
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const LoginScreen(),
    );
  }
}
