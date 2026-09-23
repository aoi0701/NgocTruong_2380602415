import 'package:flutter/material.dart';
import 'AlarmScreen.dart';
import 'StopwatchScreen.dart';

class TimeToolsScreen extends StatelessWidget {
  const TimeToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thời gian & Báo thức'),
          backgroundColor: Colors.orange,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.alarm), text: 'Báo thức'),
              Tab(icon: Icon(Icons.timer), text: 'Bấm giờ'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AlarmScreen(),
            StopwatchScreen(),
          ],
        ),
      ),
    );
  }
}
