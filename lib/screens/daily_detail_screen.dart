import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';

class DailyDetailScreen extends StatefulWidget {
  final int? userId;
  const DailyDetailScreen({Key? key, this.userId}) : super(key: key);
  @override
  State<DailyDetailScreen> createState() => _DailyDetailScreenState();
}

class _DailyDetailScreenState extends State<DailyDetailScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _bills = {};
  Map<DateTime, double> _budgets = {};
  double _monthTotal = 0;
  double _monthBudget = 0;

  @override
  void initState() {
    super.initState();
    _fetchMonthData(_focusedDay);
  }

  Future<void> _fetchMonthData(DateTime month) async {
    final userId = widget.userId ?? 1;
    final data = await ApiService().getDailyDetail(userId, month.year, month.month);
    setState(() {
      _bills = {};
      _budgets = {};
      _monthTotal = data['monthTotal'] ?? 0;
      _monthBudget = data['monthBudget'] ?? 0;
      for (var day in data['days'] ?? []) {
        final date = DateTime(month.year, month.month, day['day']);
        _bills[date] = List<Map<String, dynamic>>.from(day['bills'] ?? []);
        _budgets[date] = day['budget']?.toDouble() ?? 0;
      }
    });
  }

  List<Map<String, dynamic>> _getBillsForDay(DateTime day) {
    return _bills[DateTime(day.year, day.month, day.day)] ?? [];
  }

  double _getBudgetForDay(DateTime day) {
    return _budgets[DateTime(day.year, day.month, day.day)] ?? 0;
  }

  double _getTotalForDay(DateTime day) {
    return _getBillsForDay(day).fold(0.0, (sum, b) => sum + (b['amount'] ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay ?? _focusedDay;
    final bills = _getBillsForDay(selected);
    final budget = _getBudgetForDay(selected);
    final total = _getTotalForDay(selected);
    final over = total - budget;
    return Scaffold(
      appBar: AppBar(title: Text('每日消费明细')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchMonthData(focusedDay);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final total = _getTotalForDay(day);
                final budget = _getBudgetForDay(day);
                final isOver = total > budget && budget > 0;
                return Column(
                  children: [
                    Text('${day.day}'),
                    if (budget > 0)
                      Text('¥${total.toInt()}', style: TextStyle(fontSize: 12, color: isOver ? Colors.red : Colors.black)),
                    if (budget > 0)
                      Text('¥${budget.toInt()}', style: TextStyle(fontSize: 10, color: Colors.blue)),
                  ],
                );
              },
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选中日期：${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}'),
                Text('当日预算：¥${budget.toInt()}'),
                Text('实际消费：¥${total.toInt()}'),
                if (over > 0) Text('超支：¥${over.toInt()}', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: bills.isEmpty
                ? Center(child: Text('无消费记录'))
                : ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, idx) {
                      final b = bills[idx];
                      return ListTile(
                        title: Text('${b['category'] ?? '未知'}  ¥${b['amount']}'),
                        subtitle: Text(b['remark'] ?? ''),
                      );
                    },
                  ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本月合计：¥${_monthTotal.toInt()}'),
                Text('本月预算：¥${_monthBudget.toInt()}'),
                Text('剩余预算：¥${(_monthBudget - _monthTotal).toInt()}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 