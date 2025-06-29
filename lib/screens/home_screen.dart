import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'add_expense_screen.dart';
import 'category_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final int? userId;
  final String? username;
  
  const HomeScreen({Key? key, this.userId, this.username}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  Future<Map<String, dynamic>>? _homeData;
  int? userId;
  String? username;
  DateTime _selectedDay = DateTime.now();
  Map<String, dynamic>? _selectedDaySummary;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  
  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    username = widget.username;
    refreshHomeData();
  }
  
  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      userId = widget.userId;
      refreshHomeData();
    }
    if (oldWidget.username != widget.username) {
      username = widget.username;
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreUserIdAndLoadData();
  }

  Future<void> _restoreUserIdAndLoadData() async {
    print('_restoreUserIdAndLoadData called');
    if (userId == null) {
      final prefs = await SharedPreferences.getInstance();
      final localUserId = prefs.getInt('userId');
      final localUsername = prefs.getString('username');
      if (localUserId != null) {
        print('从本地存储恢复用户ID: $localUserId, 用户名: $localUsername');
        setState(() {
          userId = localUserId;
          username = localUsername;
        });
        _apiService.setUserId(userId!);
        refreshHomeData();
        return;
      }
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['userId'] != null) {
        print('从路由参数恢复用户ID: ${args['userId']}, 用户名: ${args['username']}');
        setState(() {
          userId = args['userId'] as int?;
          username = args['username'] as String?;
        });
        if (userId != null) {
           _apiService.setUserId(userId!);
        }
        refreshHomeData();
        return;
      }
      print('未能恢复用户ID');
    } else {
      print('用户ID已存在: $userId');
      _apiService.setUserId(userId!);
      refreshHomeData();
    }
  }
  
  Future<void> refreshHomeData() async {
    print('refreshHomeData called with userId: $userId');
    if (userId != null) {
      setState(() {
        _homeData = _fetchHomeData(userId!);
      });
    } else {
      print('refreshHomeData called but userId is null');
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDay = date;
      _homeData = _fetchHomeData(userId!);
    });
  }

  Future<Map<String, dynamic>> _fetchHomeData(int userId) async {
    try {
      final now = _selectedDay;
      final today = DateFormat('yyyy-MM-dd').format(now);
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
      final startDate = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
      final endDate = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);
      final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final monthStr = DateFormat('yyyy-MM').format(now);

      print('日期范围调试: startDate=$startDate, yesterday=$yesterday, today=$today'); // Debug print

      // Variables to store individual bound user data
      List<Map<String, dynamic>> boundUsersData = [];

      print('开始获取预算设置...');
      final budgetSettings = await _apiService.getBudgetSettings(userId);
      print('获取预算设置响应: $budgetSettings');

      print('开始获取本月预算...');
      final monthlyBudgetResp = await _apiService.getMonthlyBudget(userId, monthStr);
      print('获取本月预算响应: $monthlyBudgetResp');
      final monthlyBudget = monthlyBudgetResp['budget'] ?? 0.0;

      print('开始获取今日预算...');
      final dailyBudgetData = await _apiService.getDailyBudget(userId, today);
      print('获取今日预算响应: $dailyBudgetData');
      final dailyBudget = dailyBudgetData['budget'] ?? 0.0;

      print('API: 获取今日账单 (我的)...'); // Debug print
      final dailyBillsResponse = await _apiService.getDailyBills(userId, today);
      print('API: 获取今日账单 (我的) 响应: ${dailyBillsResponse}'); // Debug print raw response

      // These are the user's own daily bills and totals
      final todayBills = dailyBillsResponse != null && dailyBillsResponse['bills'] is List
          ? dailyBillsResponse['bills'] as List<dynamic>
          : [];
       print('我的今日账单数量: ${todayBills.length}'); // Debug print

      final todayTotal = dailyBillsResponse != null ? (dailyBillsResponse['total'] ?? 0.0) as double : 0.0; // Ensure double
      final todayFixedTotal = dailyBillsResponse != null ? (dailyBillsResponse['fixedTotal'] ?? 0.0) as double : 0.0; // Ensure double
      final todayGrandTotal = dailyBillsResponse != null ? (dailyBillsResponse['grandTotal'] ?? 0.0) as double : 0.0; // Ensure double

      // Initialize allTodayBills with current user's daily bills
      List<Map<String, dynamic>> allTodayBills = []; // Initialize as empty, add non-fixed bills below
      print('初始化 allTodayBills 数量: ${allTodayBills.length}'); // Debug print

      // Add current user's non-fixed daily bills to allTodayBills
      if (dailyBillsResponse != null && dailyBillsResponse['bills'] is List) {
          final todayBillsList = dailyBillsResponse['bills'] as List<dynamic>;
          for (var bill in todayBillsList) {
              if (bill is Map<String, dynamic> && (bill['isFixed'] != true)) { // ONLY add non-fixed bills
                  bill['username'] = username; // Add username for potential display
                  allTodayBills.add(bill);
              }
          }
      }
      print('添加我的非固定今日账单至 allTodayBills, 当前数量: ${allTodayBills.length}'); // Debug print

      List<Map<String, dynamic>> allMonthFixedBills = []; // Initialize here to collect all fixed bills
      // Add current user's fixed bills for today to allMonthFixedBills
      if (dailyBillsResponse != null && dailyBillsResponse['bills'] is List) {
          final todayBillsList = dailyBillsResponse['bills'] as List<dynamic>;
          for (var bill in todayBillsList) {
              if (bill is Map<String, dynamic> && (bill['isFixed'] == true)) {
                  bill['username'] = username; // Add username for potential display
                  allMonthFixedBills.add(bill);
              }
          }
      }

      print('API: 获取本月所有账单...');
      final monthlyBillsExcludingTodayResponse = await _apiService.searchBills(userId, {
        'startTime': startDate,
        'endTime': yesterday,
      });
      print('API: 获取本月所有账单响应: ${monthlyBillsExcludingTodayResponse}'); // Debug print raw response

      // Access data['results'] and data['total'] from the response
      final monthlyBillsData = monthlyBillsExcludingTodayResponse != null ? monthlyBillsExcludingTodayResponse : {};
      final allMonthlyBillsExcludingToday = monthlyBillsData['results'] is List ? monthlyBillsData['results'] as List<dynamic> : [];
      // We can also get the total directly from the response if needed:
      final monthlyTotalExcludingToday = monthlyBillsData['total'] ?? 0.0; // Get total from data

      // Add current user's monthly fixed bills (excluding today) to allMonthFixedBills
      for (var bill in allMonthlyBillsExcludingToday) {
          if (bill is Map<String, dynamic> && (bill['isFixed'] == true)) {
              bill['username'] = username; // Add username for potential display
              allMonthFixedBills.add(bill);
          }
      }

      print('获取到本月所有账单数量: ${allMonthlyBillsExcludingToday.length}');

      double monthTotalExcludingToday = 0.0;
      double monthFixedTotalExcludingToday = 0.0; // Fixed bills excluding today

      for (var bill in allMonthlyBillsExcludingToday) {
        // Ensure amount is treated as double
        final amount = bill['amount'] is num ? bill['amount'].toDouble() : double.tryParse(bill['amount'].toString()) ?? 0.0;
        final isFixed = bill['isFixed'] == true;

        if (!isFixed) {
          monthTotalExcludingToday += amount;
        } else {
          monthFixedTotalExcludingToday += amount;
        }
         print('处理本月（不含今天）账单: ID=${bill['id']}, Amount=$amount, isFixed=$isFixed, Current non-fixed total=$monthTotalExcludingToday, Current fixed total=$monthFixedTotalExcludingToday'); // Debug print bill processing
      }
      print('计算出的本月（不含今天）非固定总额: $monthTotalExcludingToday');
      print('计算出的本月（不含今天）固定总额: $monthFixedTotalExcludingToday');

      final calculatedUsedMonth = monthTotalExcludingToday + monthFixedTotalExcludingToday; // This is MY calculated monthly used based on MY search results EXCLUDING today
      print('计算出的我的本月已用 (不含今天): $calculatedUsedMonth');

      // My total used for the month (including today, fixed and non-fixed)
      final myTotalMonthlyUsed = monthTotalExcludingToday + monthFixedTotalExcludingToday + todayTotal + todayFixedTotal;
      // My total fixed for the month (including today)
      final myTotalMonthFixed = monthFixedTotalExcludingToday + todayFixedTotal;

      print('计算出的我的本月总已用 (含今天): $myTotalMonthlyUsed');

      // Initialize total used amounts with current user's data
      double totalTotalMonthlyUsed = myTotalMonthlyUsed; // Total used for month (mine + bound, including fixed)
      double totalTotalDailyUsed = todayTotal.toDouble(); // Total non-fixed used for today (mine + bound)

      // Get bound users' data
      final boundUsersResponse = await _apiService.getBoundUsers(userId);
      // Check if boundUsersResponse and its data are valid before accessing
      final boundUsers = (boundUsersResponse != null && boundUsersResponse['data'] is List<dynamic>)
          ? boundUsersResponse['data'] as List<dynamic>
          : null;
      
      double totalMonthlyBudget = monthlyBudget;
      double totalDailyBudget = dailyBudget;
      double totalMonthFixed = 0.0; // Declare totalMonthFixed here

      // Add bound users' data only if boundUsers is not null and not empty
      if (boundUsers != null && boundUsers.isNotEmpty) {
          for (var boundUser in boundUsers) {
            final boundUserId = boundUser['boundUserId'];
            final boundUsername = boundUser['username'] ?? '绑定用户';

            // Get bound user's budgets
            double boundUserDailyBudget = 0.0;
            double boundUserMonthlyBudget = 0.0;
            try {
              final boundUserDailyBudgetResp = await _apiService.getDailyBudget(boundUserId, today);
              if (boundUserDailyBudgetResp != null) {
                 boundUserDailyBudget = boundUserDailyBudgetResp['budget'] ?? 0.0;
                 totalDailyBudget += boundUserDailyBudget;
              }
              final boundUserMonthlyBudgetResp = await _apiService.getMonthlyBudget(boundUserId, monthStr);
              if (boundUserMonthlyBudgetResp != null) {
                 boundUserMonthlyBudget = boundUserMonthlyBudgetResp['budget'] ?? 0.0;
                 totalMonthlyBudget += boundUserMonthlyBudget;
              }
            } catch (e) {
               print('获取绑定用户 $boundUsername 预算失败: $e');
            }

            // Get bound user's daily bills and calculate usedToday
            double boundUserUsedToday = 0.0;
            double boundUserTodayFixedTotal = 0.0; // Declare variable here
            try {
              print('API: 获取绑定用户 ${boundUser['username'] ?? '绑定人'} 今日账单...'); // Debug print
              final boundUserDailyBillsResp = await _apiService.getDailyBills(boundUserId, today);
              print('API: 获取绑定用户 ${boundUser['username'] ?? '绑定人'} 今日账单响应: ${boundUserDailyBillsResp}'); // Debug print raw response

              if (boundUserDailyBillsResp != null && boundUserDailyBillsResp['bills'] is List) {
                boundUserUsedToday = (boundUserDailyBillsResp['total'] ?? 0.0) as double; // Ensure double
                boundUserTodayFixedTotal = (boundUserDailyBillsResp['fixedTotal'] ?? 0.0) as double; // Assign value here

                // Add to allTodayBills for combined display
                 for (var bill in boundUserDailyBillsResp['bills']) { // Directly iterate over the bills list from the response
                   if (bill is Map<String, dynamic> && (bill['isFixed'] != true)) { // ONLY add non-fixed bills for bound users
                      bill['username'] = boundUsername;
                       allTodayBills.add(bill);
                   }
                 }
                print('添加绑定用户 ${boundUser['username'] ?? '绑定人'} 今日非固定账单至 allTodayBills, 当前数量: ${allTodayBills.length}'); // Debug print

              }
            } catch (e) {
              print('获取绑定用户 $boundUsername 日账单失败: $e');
            }

            // Get bound user's monthly bills (excluding today) and calculate usedMonth and usedMonthFixed
            double boundUserMonthTotalExcludingToday = 0.0;
            double boundUserMonthFixedTotalExcludingToday = 0.0;
            try {
              final boundUserMonthlyBillsExcludingTodayResp = await _apiService.searchBills(boundUserId, {
                'startDate': startDate,
                'endDate': yesterday,
              });
               if (boundUserMonthlyBillsExcludingTodayResp != null && boundUserMonthlyBillsExcludingTodayResp['data'] != null && boundUserMonthlyBillsExcludingTodayResp['data']['results'] is List) {
                final bills = boundUserMonthlyBillsExcludingTodayResp['data']['results'] as List<dynamic>;
                for (var bill in bills) {
                  // Ensure amount is treated as double
                  final amount = bill['amount'] is num ? bill['amount'].toDouble() : double.tryParse(bill['amount'].toString()) ?? 0.0;
                  final isFixed = bill['isFixed'] == true;
                  if (isFixed) {
                    boundUserMonthFixedTotalExcludingToday += amount;
                  } else {
                    boundUserMonthTotalExcludingToday += amount;
                  }
                   print('处理绑定用户 ${boundUser['username'] ?? '绑定人'} 月账单 (不含今天): ID=${bill['id']}, Amount=$amount, isFixed=$isFixed'); // Debug print bound user bill processing
                }
              }
            } catch (e) {
               print('获取绑定用户 $boundUsername 月账单 (不含今天) 失败: $e');
            }

            // Bound user's total used for the month (including today, fixed and non-fixed)
            final boundUserTotalMonthlyUsed = boundUserMonthTotalExcludingToday + boundUserMonthFixedTotalExcludingToday + boundUserUsedToday + boundUserTodayFixedTotal; // Use the variable
            // Bound user's total fixed for the month (including today)
            final boundUserTotalMonthFixed = boundUserMonthFixedTotalExcludingToday + boundUserTodayFixedTotal; // Use the variable

            // Add to total used amounts
             totalTotalDailyUsed += boundUserUsedToday; // Total non-fixed daily used

            // Store bound user's data
            boundUsersData.add({
              'userId': boundUserId,
              'username': boundUsername,
              'dailyBudget': boundUserDailyBudget,
              'usedToday': boundUserUsedToday,
              'monthlyBudget': boundUserMonthlyBudget,
              'totalMonthlyUsed': boundUserTotalMonthlyUsed, // Total monthly used for this bound user
              'totalMonthFixed': boundUserTotalMonthFixed, // Total monthly fixed for this bound user
            });
          }
      }

      // totalMonthFixed should be the sum of all users' fixed bills this month
      // Recalculate totalMonthFixed based on allMonthFixedBills (which now includes bound users' fixed bills)
      for (var bill in allMonthFixedBills) {
        if (bill['amount'] != null) {
          final amount = bill['amount'] is num ? bill['amount'].toDouble() : double.tryParse(bill['amount'].toString()) ?? 0.0;
          totalMonthFixed += amount;
        }
      }

      // Now return the correct individual and total used amounts
      final result = {
        'usedToday': todayTotal.toDouble(), // My today used (from getDailyBills)
        'usedTodayFixed': todayFixedTotal.toDouble(),
        'usedTodayGrand': todayGrandTotal.toDouble(), // Use todayGrandTotal directly (already double)
        'usedMonth': totalTotalMonthlyUsed, // Total used for the month (mine + bound)
        'usedMonthFixed': totalMonthFixed + myTotalMonthFixed, // Total fixed for the month (mine + bound)
        'budget': budgetSettings,
        'monthlyBudget': totalMonthlyBudget,
        'allDailyBills': allTodayBills,
        'dailyBudget': totalDailyBudget,
        'user': {'username': username ?? '用户'},
        'allMonthFixedBills': allMonthFixedBills,
        'totalMonthlyBudget': totalMonthlyBudget,
        'totalDailyBudget': totalDailyBudget,
        'totalMonthFixed': totalMonthFixed + myTotalMonthFixed, // Total fixed for all users (mine + bound)
        'myTotalMonthlyUsed': myTotalMonthlyUsed, // My total monthly used (incl. fixed)
        'myTotalMonthFixed': myTotalMonthFixed, // My total monthly fixed
        'totalTotalMonthlyUsed': totalTotalMonthlyUsed, // Total monthly used for all users (mine + bound)
        'totalTotalDailyUsed': totalTotalDailyUsed, // Total non-fixed daily used for all users
        'todayGrandTotal': todayGrandTotal, // My today's grand total
        'boundUsers': boundUsersData,
        'myMonthlyBudget': monthlyBudget, // My monthly budget
        'myDailyBudget': dailyBudget, // My daily budget
        'myUsedToday': todayTotal, // My non-fixed used today
        'myFixedToday': todayFixedTotal, // My fixed used today
        'myGrandTotalToday': todayGrandTotal, // My grand total used today
      };
      print('boundUsersData: $boundUsersData'); // Debug print
      print('totalTotalMonthlyUsed calculated: $totalTotalMonthlyUsed'); // Debug print
      return result;
    } catch (e) {
      print('获取首页数据失败: $e');
      rethrow;
      return {
        'dailyBudget': 0.0,
        'monthlyBudget': 0.0,
        'todayBills': [],
        'monthFixedBills': [],
        'allTodayBills': [],
        'allMonthFixedBills': [],
        'totalMonthlyBudget': 0.0,
        'totalDailyBudget': 0.0,
        'totalMonthFixed': 0.0,
        'myTotalMonthlyUsed': 0.0,
        'todayGrandTotal': 0.0,
        'username': username,
        'boundUsers': [],
        'myMonthlyBudget': 0.0,
        'myDailyBudget': 0.0,
        'myUsedToday': 0.0,
        'myFixedToday': 0.0,
        'myGrandTotalToday': 0.0,
        'totalTotalMonthlyUsed': 0.0,
        'totalTotalDailyUsed': 0.0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: userId == null
          ? const Center(child: Text('未获取到用户ID'))
          : RefreshIndicator(
              key: _refreshKey,
              onRefresh: refreshHomeData,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _homeData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('加载中...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    print('HomeScreen FutureBuilder 错误: ${snapshot.error}');
                    String errorMessage = '加载失败';
                    if (snapshot.error is Exception) {
                      errorMessage = '加载失败: ${snapshot.error.toString().replaceFirst('Exception: ', '')}';
                    } else if (snapshot.error != null) {
                       errorMessage = '加载失败: ${snapshot.error.toString()}';
                    }

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(errorMessage),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: refreshHomeData,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: Text('暂无数据'));
                  }

                  final data = snapshot.data!;
                  // Retrieve individual and total budget/used data
                  final myDailyBudget = (data['myDailyBudget'] ?? 0.0) as double; // My daily budget
                  final myMonthlyBudget = (data['myMonthlyBudget'] ?? 0.0) as double; // My monthly budget
                  final myTotalMonthlyUsed = (data['myTotalMonthlyUsed'] ?? 0.0) as double; // My total monthly used (incl. fixed)
                  final myTotalMonthFixed = (data['myTotalMonthFixed'] ?? 0.0) as double; // My total monthly fixed
                  final myGrandTotalToday = (data['myGrandTotalToday'] ?? 0.0) as double; // My grand total today
                  final myUsedTodayNonFixed = (data['myUsedToday'] ?? 0.0) as double; // My non-fixed used today

                  final totalDailyBudget = (data['totalDailyBudget'] ?? 0.0) as double; // Total daily budget
                  final totalMonthlyBudget = (data['totalMonthlyBudget'] ?? 0.0) as double; // Total monthly budget
                  final totalTotalMonthlyUsed = (data['totalTotalMonthlyUsed'] ?? 0.0) as double; // Total monthly used (mine + bound)
                  final totalTotalDailyUsed = (data['totalTotalDailyUsed'] ?? 0.0) as double; // Total non-fixed daily used
                  final totalMonthFixed = (data['totalMonthFixed'] ?? 0.0) as double; // Total fixed for all users

                  final boundUsersData = data['boundUsers'] as List<dynamic>? ?? [];

                  final allDailyBills = data['allDailyBills'] as List<dynamic>? ?? []; // All daily bills (mine + bound)
                  final allMonthFixedBills = data['allMonthFixedBills'] as List<dynamic>? ?? []; // All monthly fixed bills (mine + bound)
                  final usedTodayGrand = (data['todayGrandTotal'] ?? 0.0) as double; // Use the correct key for my today's grand total

                  print('Combined Daily Bills count: ${allDailyBills.length}');
                  print('Combined Monthly Fixed Bills count: ${allMonthFixedBills.length}');
                  print('Current User ID in build: $userId');

                  final dailyPercent = totalDailyBudget > 0 ? (totalTotalDailyUsed / totalDailyBudget).clamp(0.0, 1.0) : 0.0;
                  final monthPercent = totalMonthlyBudget > 0 ? (totalTotalMonthlyUsed / totalMonthlyBudget).clamp(0.0, 1.0) : 0.0;
                  final displayUsername = data['user']?['username'] ?? username ?? '用户';

                  return ListView(
                    children: [
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                const Text('记账', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                    Text('用户名：$displayUsername', style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                  IconButton(
                                      icon: const Icon(Icons.settings),
                                    onPressed: () {
                                        Navigator.pushNamed(context, '/settings');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                          const Text('本月预算', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 12),
                                          Text('总预算: ¥${myMonthlyBudget.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: Colors.black87)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // 显示所有用户本月总已用金额 (含固定支出)
                                      Text('总已用 (本月至今): ¥${totalTotalMonthlyUsed.toStringAsFixed(2)}', // 显示所有用户本月总已用 (含固定支出)
                                          style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 10.0,
                                        child: LinearProgressIndicator(
                                      value: (myMonthlyBudget > 0 ? (myTotalMonthlyUsed / myMonthlyBudget).clamp(0.0, 1.0) : 0.0).toDouble(), // 使用我的总月度已用和我的月度预算计算进度条
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>((myMonthlyBudget > 0 ? (myTotalMonthlyUsed / myMonthlyBudget) : 0.0) >= 1 ? Colors.red : Colors.green), // 根据我的总月度已用和预算确定颜色
                                    ),
                                      ),
                                       const SizedBox(height: 4),
                                      Text(
                                        '''(含固定支出: ¥${myTotalMonthFixed.toStringAsFixed(2)} ）''' , // 显示我的和所有绑定人的总固定支出
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                      // Display combined monthly fixed bills
                                      if (allMonthFixedBills.isNotEmpty) ...[
                                        const Divider(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('固定支出明细', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: NeverScrollableScrollPhysics(),
                                          itemCount: allMonthFixedBills.length,
                                          itemBuilder: (context, index) {
                                            final bill = allMonthFixedBills[index];
                                            bool isCurrentUserBill = bill['userId'] == userId;
                                            return _buildFixedBillItem(bill, isCurrentUserBill);
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                          const Text('今日预算', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // 显示我的今日总预算
                                    Text('我的总预算: ¥${myDailyBudget.toStringAsFixed(2)}', 
                                        style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    // 显示绑定人今日总预算
                                    if (boundUsersData.isNotEmpty) // Check if there are bound users
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          for (var boundUser in boundUsersData) // Iterate through bound users
                                            Text(
                                              '${boundUser['username'] ?? '绑定人'}总预算: ¥${(boundUser['dailyBudget'] ?? 0.0).toStringAsFixed(2)}', // 显示绑定人今日总预算
                                              style: const TextStyle(fontSize: 14, color: Colors.black87)
                                            ),
                                        ],
                                      ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 8.0,
                                      child: LinearProgressIndicator(
                                    value: dailyPercent.toDouble(), // 使用总计已用和总计预算计算进度条 (保持总计)
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(dailyPercent >= 1 ? Colors.red : Colors.blue),
                                  ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      color: Colors.blue.withOpacity(0.05), // Subtle blue background for my data
                                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                      child: Text('我的: 已用 ¥${myUsedTodayNonFixed.toStringAsFixed(2)}   剩余 ¥${(myDailyBudget - myUsedTodayNonFixed).toStringAsFixed(2)}', // 显示我的今日预算信息
                                        style: TextStyle(color: (myTotalMonthlyUsed / myDailyBudget) >= 1 ? Colors.red : Colors.black)),
                                    ),
                                    // 显示绑定人今日预算信息
                                    if (boundUsersData.isNotEmpty) // Check if there are bound users
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          for (var boundUser in boundUsersData) // Iterate through bound users
                                            Container(
                                              color: Colors.grey.withOpacity(0.05), // Subtle grey background for bound user data
                                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                              margin: const EdgeInsets.only(bottom: 4.0), // Add some space between bound users
                                              child: Text(
                                                '${boundUser['username'] ?? '绑定人'}: 已用 ¥${(boundUser['usedToday'] ?? 0.0).toStringAsFixed(2)}   剩余 ¥${(((boundUser['dailyBudget'] ?? 0.0) as double) - ((boundUser['usedToday'] ?? 0.0) as double)).toStringAsFixed(2)}', // 确保类型转换正确且括号匹配
                                                style: TextStyle(
                                                  color: (((boundUser['usedToday'] ?? 0.0) as double) / ((boundUser['dailyBudget'] ?? 0.0) == 0.0 ? 1.0 : ((boundUser['dailyBudget'] ?? 0.0) as double))) >= 1 ? Colors.red : Colors.black // 避免除以零，确保类型转换和括号匹配
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  const Text('今日支出', style: TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Text(DateFormat('yyyy-MM-dd').format(_selectedDay)),
                                    IconButton(
                                        icon: const Icon(Icons.calendar_today, size: 20),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedDay,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                          locale: const Locale('zh', 'CN'),
                                        );
                                        if (picked != null && picked != _selectedDay) {
                                          _onDateChanged(picked);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                              const SizedBox(height: 8),
                            Card(
                              child: Column(
                                children: [
                                  if (allDailyBills.isEmpty)
                                    const ListTile(title: Text('暂无支出'))
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: allDailyBills.length,
                                      itemBuilder: (context, index) {
                                        final bill = allDailyBills[index];
                                        bool isCurrentUserBill = bill['userId'] == userId;
                                        return _buildDailyBillItem(bill, isCurrentUserBill);
                                      },
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text('合计: ¥${totalTotalDailyUsed.toStringAsFixed(2)}', // 显示所有用户当日非固定支出总和
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddExpenseScreen(userId: userId!),
                                  ),
                                );
                                if (result == true) {
                                    refreshHomeData();
                                }
                              },
                                icon: const Icon(Icons.add),
                                label: const Text('添加支出'),
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDailyBillItem(dynamic bill, bool isCurrentUserBill) {
    print('Building Daily Bill Item: ID=${bill['id']}, UserID=${bill['userId']}, Note=${bill['note'] ?? ''}, isCurrentUserBill=$isCurrentUserBill');
    final category = bill['categoryName'] ?? bill['categoryId']?.toString() ?? '未分类';
    final icon = bill['categoryIcon'] ?? '🧾';
    final time = bill['time'] != null 
        ? DateFormat('HH:mm').format(DateTime.parse(bill['time']))
        : '';
    final amount = bill['amount']?.toString() ?? '0';
    final note = bill['note'] ?? '';
    final usernamePrefix = bill['username'] != null && bill['username'] != username 
        ? '${bill['username']}: '
        : '';

    return Column(
      children: [
        ListTile(
          tileColor: isCurrentUserBill ? null : Colors.grey.withOpacity(0.05), // Subtle grey background for bound user bills
          leading: Text(icon, style: TextStyle(fontSize: 24)),
          title: Text('$usernamePrefix$category'),
          subtitle: Text('$time ${note.isNotEmpty ? "• $note" : ""}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('¥$amount', style: TextStyle(fontWeight: FontWeight.bold)),
              if (isCurrentUserBill) ...[
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddExpenseScreen(
                          userId: userId!,
                          expenseToEdit: bill,
                        ),
                      ),
                    );
                    if (result == true) {
                      refreshHomeData();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('删除确认'),
                        content: Text('确定要删除这条支出吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('删除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _apiService.deleteBill(bill['id'], userId!); 
                      refreshHomeData();
                    }
                  },
                ),
              ],
            ],
          ),
          onTap: isCurrentUserBill ? () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddExpenseScreen(
                  userId: userId!,
                  expenseToEdit: bill,
                ),
              ),
            );
            if (result == true) {
              refreshHomeData();
            }
          } : null,
        ),
        Divider(height: 1),
      ],
    );
  }

  Widget _buildFixedBillItem(dynamic bill, bool isCurrentUserBill) {
    print('Building Fixed Bill Item: ID=${bill['id']}, UserID=${bill['userId']}, Category=${bill['categoryName'] ?? ''}, isCurrentUserBill=$isCurrentUserBill');
    final category = bill['categoryName'] ?? bill['categoryId']?.toString() ?? '未分类';
    final icon = bill['categoryIcon'] ?? '🧾';
    final time = bill['time'] != null 
        ? DateFormat('HH:mm').format(DateTime.parse(bill['time']))
        : '';
    final amount = bill['amount']?.toString() ?? '0';
    final note = bill['note'] ?? '';
    final usernamePrefix = bill['username'] != null && bill['username'] != username 
        ? '${bill['username']}: '
        : '';
    
    return Column(
      children: [
        ListTile(
          tileColor: isCurrentUserBill ? null : Colors.grey.withOpacity(0.05), // Subtle grey background for bound user bills
          leading: Text(icon, style: TextStyle(fontSize: 24)),
          title: Row(
            children: [
              Text('$usernamePrefix$category'),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('固定', style: TextStyle(fontSize: 12, color: Colors.blue)),
              ),
            ],
          ),
          subtitle: Text('$time ${note.isNotEmpty ? "• $note" : ""}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('¥$amount', style: TextStyle(fontWeight: FontWeight.bold)),
               if (isCurrentUserBill) ...[
                 IconButton(
                   icon: Icon(Icons.edit, color: Colors.blue),
                   onPressed: () async {
                     final result = await Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => AddExpenseScreen(
                           userId: userId!,
                           expenseToEdit: bill,
                         ),
                       ),
                     );
                     if (result == true) {
                       refreshHomeData();
                     }
                   },
                 ),
                 IconButton(
                   icon: Icon(Icons.delete, color: Colors.red),
                   onPressed: () async {
                     final confirm = await showDialog<bool>(
                       context: context,
                       builder: (context) => AlertDialog(
                         title: Text('删除确认'),
                         content: Text('确定要删除这条支出吗？'),
                         actions: [
                           TextButton(
                             onPressed: () => Navigator.pop(context, false),
                             child: Text('取消'),
                           ),
                           TextButton(
                             onPressed: () => Navigator.pop(context, true),
                             child: Text('删除', style: TextStyle(color: Colors.red)),
                           ),
                         ],
                       ),
                     );
                     if (confirm == true) {
                        await _apiService.deleteBill(bill['id'], userId!); 
                       refreshHomeData();
                     }
                   },
                 ),
               ],
            ],
          ),
           onTap: isCurrentUserBill ? () async {
             final result = await Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (context) => AddExpenseScreen(
                   userId: userId!,
                   expenseToEdit: bill,
                 ),
               ),
             );
             if (result == true) {
               refreshHomeData();
             }
           } : null,
        ),
        Divider(height: 1),
      ],
    );
  }

  void _navigateToAddExpenseScreen(int? billId, Map<String, dynamic>? expenseToEdit) async {
    if (userId == null) {
        print('User ID is null, cannot navigate to AddExpenseScreen');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('用户ID未设置，无法添加或编辑账单')),
        );
        return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          userId: userId!,
          expenseToEdit: expenseToEdit,
        ),
      ),
    );
    
    if (result == true) {
      print('Received true result from AddExpenseScreen, refreshing data...');
      refreshHomeData();
    } else {
        print('Received result from AddExpenseScreen: $result');
    }
  }

  void _confirmDelete(int billId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除确认'),
        content: Text('确定要删除这条支出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _apiService.deleteBill(billId, userId!);
      refreshHomeData();
    }
  }
} 