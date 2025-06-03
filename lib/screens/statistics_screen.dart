import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bookkeeping_app/screens/add_expense_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';

class StatisticsScreen extends StatefulWidget {
  final int? userId;
  const StatisticsScreen({Key? key, this.userId}) : super(key: key);
  @override
  State<StatisticsScreen> createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  List<Map<String, dynamic>> _calendarDays = [];
  DateTime? _selectedDay;
  Map<String, dynamic>? _selectedDayStat;
  Map<String, dynamic>? _selectedDaySummary;
  List<dynamic> _selectedDayBills = [];
  bool _isLoading = false;
  bool _isCalendarLoading = false;
  bool _isBillsLoading = false;

  double _calculateDailyTotal() {
    double total = 0.0;
    for (var bill in _selectedDayBills) {
      total += (bill['amount'] as num? ?? 0.0).toDouble();
    }
    return total;
  }

  double _calculateNonFixedDailyTotal() {
    double total = 0.0;
    for (var bill in _selectedDayBills) {
      if (bill['isFixed'] != true) {
        total += (bill['amount'] as num? ?? 0.0).toDouble();
      }
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    
    // 确保页面初始化时加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshData();
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用恢复前台时刷新数据
    if (state == AppLifecycleState.resumed) {
      refreshData();
    }
  }

  // 每次页面显示时都刷新数据
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    refreshData();
  }

  Future<void> _fetchCalendarData() async {
    final year = _focusedDay.year;
    final month = _focusedDay.month;
    
    try {
      setState(() {
        _isCalendarLoading = true;
      });
      
      print('获取日历数据: ${year}-${month}');
      final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
      if (currentUserId == null) {
        print('未登录用户');
        return;
      }
      final resp = await ApiService().getDailyStatistics(currentUserId, year, month);
      if (resp != null && resp['success'] == true && resp['data'] != null) {
        // 确保我们仍在同一个月
        if (_focusedDay.year == year && _focusedDay.month == month) {
          final days = List<Map<String, dynamic>>.from(resp['data']['days'] ?? []);
          
          setState(() {
            _calendarDays = days;
            print('获取到日历数据: ${_calendarDays.length} 天 (${year}-${month})');
          });
        }
      } else {
        print('获取日历数据失败: 响应格式错误');
        if (_focusedDay.year == year && _focusedDay.month == month) {
          setState(() {
            _calendarDays = [];
          });
        }
      }
    } catch (e) {
      print('获取日历数据错误: $e');
      if (_focusedDay.year == year && _focusedDay.month == month) {
        setState(() {
          _calendarDays = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取${year}年${month}月数据失败'),
            duration: Duration(seconds: 2),
          )
        );
      }
    } finally {
      if (_focusedDay.year == year && _focusedDay.month == month) {
        setState(() {
          _isCalendarLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDayBills(DateTime day) async {
    if (day == null) return;

    setState(() {
      _isBillsLoading = true;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(day);

    try {
      print('统计页: 开始获取日账单, 日期: $dateStr');
      final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
      if (currentUserId == null) {
        print('未登录用户');
        return;
      }
      final resp = await ApiService().getDailyBills(currentUserId, dateStr);
      print('统计页: 获取日账单响应数据: $resp');

      // 检查响应格式
      if (resp != null && resp.containsKey('bills') && resp['bills'] is List) {
        final bills = resp['bills'] ?? [];
        print('统计页: 获取到 ${bills.length} 条日账单');
        print('统计页: 日账单数据详情: $bills');

        setState(() {
          _selectedDayBills = bills;
        });
      } else {
        // 处理响应格式不符合预期的情况
        setState(() {
          _selectedDayBills = [];
        });
        print('统计页: 获取日账单失败或格式错误: ${resp?['message'] ?? '未知错误'}');
        print('统计页: 获取日账单失败或格式错误: 原始响应: $resp');
      }
    } catch (e) {
      print('统计页: 获取日账单失败: $e');
      setState(() {
        _selectedDayBills = [];
      });
    } finally {
      setState(() {
        _isBillsLoading = false;
        print('统计页: 日账单加载结束');
      });
    }
  }

  Future<void> _fetchDaySummary(DateTime day) async {
    if (day == null) return;
    
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    
    try {
      print('获取日汇总数据: $dateStr');
      final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
      if (currentUserId == null) {
        print('未登录用户');
        return;
      }
      final resp = await ApiService().getDayStatistics(currentUserId, dateStr);
      print('日汇总响应数据: $resp');
      
      // Increased robustness in checking the response structure
      if (resp != null && resp['success'] == true && resp.containsKey('data') && resp['data'] is Map<String, dynamic>) {
        final summary = resp['data'];
        print('设置日汇总数据: $summary');
        
        setState(() {
          _selectedDaySummary = {
            'budget': summary['budget'] ?? 0.0,
            'spent': summary['spent'] ?? 0.0,
            'remain': summary['remain'] ?? 0.0,
            'fixedSpent': summary['fixedSpent'] ?? 0.0
          };
        });
      } else {
        print('获取日汇总失败或格式错误: ${resp?['message'] ?? '未知错误'}');
        setState(() {
          _selectedDaySummary = {
            'budget': 0.0,
            'spent': 0.0,
            'remain': 0.0,
            'fixedSpent': 0.0
          };
        });
      }
    } catch (e) {
      print('获取日汇总失败: $e');
      setState(() {
        _selectedDaySummary = {
          'budget': 0.0,
          'spent': 0.0,
          'remain': 0.0,
          'fixedSpent': 0.0
        };
      });
    }
  }

  // 优化刷新数据流程，确保每次都获取最新数据
  Future<void> refreshData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取日历数据
      await _fetchCalendarData();

      // 如果有选定的日期，获取该日的数据
      if (_selectedDay != null) {
        await Future.wait([
          _fetchDayBills(_selectedDay!),
          _fetchDaySummary(_selectedDay!),
        ]);
        
        setState(() {
          _selectedDayStat = _calendarDays.firstWhere(
            (d) => d['date'] == DateFormat('yyyy-MM-dd').format(_selectedDay!),
            orElse: () => {},
          );
        });
      }
    } catch (e) {
      print('刷新数据失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刷新数据失败'),
          duration: Duration(seconds: 2),
        )
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('统计分析'),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: refreshData,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('日历视图（预算/支出/余额）'),
                  const SizedBox(height: 8),
                  _isCalendarLoading 
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ))
                      : _buildCalendar(),
                  if (_selectedDay != null)
                    _buildDayExpenseDetails(),
                  if (_selectedDay == null)
                    Card(
                      elevation: 2,
                      margin: EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: EdgeInsets.all(24.0),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.touch_app, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              '请点击日历中的日期查看支出明细',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建日历组件
  Widget _buildCalendar() {
    return TableCalendar(
                    locale: 'zh_CN',
                    focusedDay: _focusedDay,
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2100),
                    calendarFormat: CalendarFormat.month,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      rowHeight: 110,
      daysOfWeekHeight: 20,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronIcon: Icon(_isLoading ? Icons.hourglass_empty : Icons.chevron_left),
        rightChevronIcon: Icon(_isLoading ? Icons.hourglass_empty : Icons.chevron_right),
      ),
      availableGestures: AvailableGestures.horizontalSwipe,
      onPageChanged: (focusedDay) {
        // 当月份变化时调用
        setState(() {
          _focusedDay = focusedDay;
          // 清除选定的日期
          if (_selectedDay != null && _selectedDay!.month != focusedDay.month) {
            _selectedDay = null;
            _selectedDayStat = null;
            _selectedDaySummary = null;
            _selectedDayBills = [];
          }
        });
        // 获取新月份的数据
        _fetchCalendarData();
      },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
          
                        _selectedDayStat = _calendarDays.firstWhere(
                          (d) => d['date'] == DateFormat('yyyy-MM-dd').format(selectedDay),
                          orElse: () => {},
                        );
                      });
        
        // 获取选定日期的数据
                      _fetchDayBills(selectedDay);
                      _fetchDaySummary(selectedDay);
                    },
                    calendarBuilders: CalendarBuilders(
        defaultBuilder: _buildCalendarDay,
      ),
    );
  }

  // 构建日历单元格
  Widget _buildCalendarDay(BuildContext context, DateTime day, DateTime focusedDay) {
    final String dayStr = DateFormat('yyyy-MM-dd').format(day);
                        final stat = _calendarDays.firstWhere(
      (d) => d['date'] == dayStr,
                          orElse: () => {},
                        );
    
    return Container(
      margin: EdgeInsets.all(1),
      padding: EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: stat.isNotEmpty ? 
          ((stat['remain'] ?? 0) < 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.05)) 
          : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
          Text('${day.day}', style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold,
            color: day.month == _focusedDay.month ? Colors.black : Colors.grey,
          )),
          if (stat.isNotEmpty) ...[
            const SizedBox(height: 1),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '预:${stat['budget'] != null ? '￥${stat['budget']}' : '-'}',
                style: TextStyle(fontSize: 7, color: Colors.blue),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 1),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '支:${stat['spent'] != null ? '￥${stat['spent']}' : '-'}',
                style: TextStyle(fontSize: 7, color: Colors.red),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 1),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: (stat['remain'] ?? 0) < 0 
                  ? Colors.red.withOpacity(0.1) 
                  : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
                                    ),
              child: Text(
                '余:${stat['remain'] != null ? '￥${stat['remain']}' : '-'}',
                style: TextStyle(
                  fontSize: 7, 
                  fontWeight: FontWeight.bold,
                  color: (stat['remain'] ?? 0) < 0 ? Colors.red : Colors.green
                                ),
                                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
                              ),
                          ],
        ],
                    ),
    );
  }

  // 构建支出明细卡片
  Widget _buildDayExpenseDetails() {
    print('统计页: 构建日支出明细卡片, 账单数量: ${_selectedDayBills.length}');
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 添加日期和加载指示器
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${DateFormat('yyyy-MM-dd').format(_selectedDay!)} 支出明细', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  )
                ),
                if (_isBillsLoading)
                  SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  ),
              ],
            ),
            SizedBox(height: 12),
            
            // 添加预算、支出、余额汇总卡片
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem(
                      '今日预算',
                      '¥${_selectedDaySummary?['budget']?.toStringAsFixed(2) ?? '0.00'}',
                      Colors.blue
                    ),
                    _summaryItem(
                      '今日支出',
                      '¥${_selectedDaySummary?['spent']?.toStringAsFixed(2) ?? '0.00'}',
                      Colors.red
                    ),
                    _summaryItem(
                      '余额',
                      '¥${_selectedDaySummary?['remain']?.toStringAsFixed(2) ?? '0.00'}',
                      (_selectedDaySummary?['remain'] ?? 0) < 0 ? Colors.red : Colors.green
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // 支出明细列表
            if (!_isBillsLoading && _selectedDayBills.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text('暂无支出记录')),
              ),
            if (!_isBillsLoading)
              ..._selectedDayBills
                .where((bill) { // 过滤固定支出
                  // Check if isFixed exists and is explicitly true
                  final isFixed = bill['isFixed'];
                  final shouldInclude = !(isFixed is bool && isFixed == true);
                  print('统计页: 过滤账单 ID=${bill['id']}, isFixed=$isFixed, shouldInclude=$shouldInclude');
                  return shouldInclude;
                })
                .map((bill) => ListTile(
                  contentPadding: EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                  leading: Text(bill['categoryIcon'] ?? '🧾', style: TextStyle(fontSize: 24)),
                  title: Text(bill['categoryName'] ?? bill['categoryId']?.toString() ?? '未分类'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('¥${bill['amount']}', style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddExpenseScreen(
                                userId: widget.userId!,
                                expenseToEdit: bill,
                              ),
                            ),
                          );
                          if (result == true) {
                            refreshData();
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
                            await ApiService().deleteBill(bill['id'], widget.userId!);
                            refreshData();
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddExpenseScreen(
                          userId: widget.userId!,
                          expenseToEdit: bill,
                        ),
                      ),
                    );
                    if (result == true) {
                      refreshData();
                    }
                  },
                )).toList(),
            if (!_isBillsLoading && _selectedDayBills.where((bill) => bill['isFixed'] != true).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0, right: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('合计: ¥${_calculateNonFixedDailyTotal().toStringAsFixed(2)}', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red
                      )
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
              ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
            ),
          ),
        ],
    );
  }
} 