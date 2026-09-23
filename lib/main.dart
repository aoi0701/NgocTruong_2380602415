import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'HomeScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ứng dụng chuyển đổi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),);
  }
}