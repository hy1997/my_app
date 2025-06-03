import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'budget_settings_screen.dart';
import 'daily_detail_screen.dart';

class MainTabScreen extends StatefulWidget {
  final int? userId;
  final String? username;
  
  const MainTabScreen({Key? key, this.userId, this.username}) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  int? userId;
  String? username;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<StatisticsScreenState> _statisticsKey = GlobalKey<StatisticsScreenState>();
  
  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    username = widget.username;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      if (args is Map) {
        userId = args['userId'];
        username = args['username'];
      } else if (args is int) {
        userId = args;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: _homeKey, userId: userId, username: username),
      StatisticsScreen(key: _statisticsKey, userId: userId),
      BudgetSettingsScreen(userId: userId),
     ];
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: '预算'),
         ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 0) {
              _homeKey.currentState?.refreshHomeData();
            } else if (index == 1) {
              _statisticsKey.currentState?.refreshData();
            }
          });
        },
      ),
    );
  }
} 