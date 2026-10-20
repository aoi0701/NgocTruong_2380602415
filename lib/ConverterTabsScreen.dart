import 'package:flutter/material.dart';
import 'TemperatureConverterScreen.dart';
import 'UnitConverterScreen.dart';

class ConverterTabsScreen extends StatelessWidget {
  const ConverterTabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Công cụ chuyển đổi'),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.thermostat), text: 'Nhiệt độ'),
              Tab(icon: Icon(Icons.straighten), text: 'Đơn vị đo'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TemperatureConverterScreen(showAppBar: false),
            UnitConverterScreen(showAppBar: false),
          ],
        ),
      ),
    );
  }
}
