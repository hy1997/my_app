import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class BudgetSettingsScreen extends StatefulWidget {
  final int? userId;
  const BudgetSettingsScreen({Key? key, this.userId}) : super(key: key);
  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  DateTime selectedDay = DateTime.now();
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  final dailyBudgetController = TextEditingController();
  final monthlyBudgetController = TextEditingController();
  final dailyBudgetForDateController = TextEditingController();
  DateTime selectedCustomDay = DateTime.now();
  List<Map<String, dynamic>> fixedExpenses = [];
  bool loading = false;
  bool setForWholeMonth = false;

  @override
  void initState() {
    super.initState();
    _fetchBudget();
  }

  Future<void> _fetchBudget() async {
    setState(() { loading = true; });
    try {
      final userId = widget.userId ?? 1; // TODO: 替换为实际登录用户ID
      final data = await ApiService().getBudgetSettings(userId);
      if (data != null) {
        if (data['dailyBudget'] != null) dailyBudgetController.text = data['dailyBudget'].toString();
        if (data['monthlyBudget'] != null) monthlyBudgetController.text = data['monthlyBudget'].toString();
        if (data['fixedExpenses'] != null && data['fixedExpenses'] is List) {
          fixedExpenses = List<Map<String, dynamic>>.from(data['fixedExpenses']);
        }
        // 可扩展：支持后端返回的日期/月
      }
    } catch (e) {
      // ignore error
    }
    setState(() { loading = false; });
  }

  @override
  void dispose() {
    dailyBudgetController.dispose();
    monthlyBudgetController.dispose();
    dailyBudgetForDateController.dispose();
    super.dispose();
  }

  void _pickDay() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDay = picked;
      });
    }
  }

  void _pickMonth() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(selectedMonth + '-01'),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      selectableDayPredicate: (date) => date.day == 1,
    );
    if (picked != null) {
      setState(() {
        selectedMonth = DateFormat('yyyy-MM').format(picked);
      });
    }
  }

  void _addFixedExpense() async {
    String name = '';
    String amount = '';
    String repeatType = '每天';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('添加固定支出'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: '名称'),
                onChanged: (v) => name = v,
              ),
              TextField(
                decoration: InputDecoration(labelText: '金额'),
                keyboardType: TextInputType.number,
                onChanged: (v) => amount = v,
              ),
              DropdownButton<String>(
                value: repeatType,
                items: ['每天', '每月'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => repeatType = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (name.isNotEmpty && amount.isNotEmpty) {
                  setState(() {
                    fixedExpenses.add({
                      'name': name,
                      'amount': double.tryParse(amount) ?? 0,
                      'repeatType': repeatType,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDailyBudget() async {
    final userId = widget.userId ?? 1;
    await ApiService().setDailyBudget(userId, double.tryParse(dailyBudgetController.text) ?? 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('每日预算保存成功')));
  }

  Future<void> _saveMonthlyBudget() async {
    final userId = widget.userId ?? 1;
    await ApiService().setMonthlyBudgetForMonth(
      userId,
      selectedMonth,
      double.tryParse(monthlyBudgetController.text) ?? 0,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${selectedMonth}月预算保存成功')));
  }

  Future<void> _saveDailyBudgetForDateOrMonth() async {
    final userId = widget.userId ?? 1;
    final value = double.tryParse(dailyBudgetForDateController.text) ?? 0;
    if (setForWholeMonth) {
      // 只设置当前选择日期所在月的每天预算
      final year = selectedCustomDay.year;
      final month = selectedCustomDay.month;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        await ApiService().setDailyBudgetForDate(
          userId,
          DateFormat('yyyy-MM-dd').format(date),
          value,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${year}年${month}月每天预算已批量设置')));
    } else {
      // 只设置当前选中日期
      await ApiService().setDailyBudgetForDate(
        userId,
        DateFormat('yyyy-MM-dd').format(selectedCustomDay),
        value,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('指定日期预算保存成功')));
    }
  }

  void _saveSettings() async {
    final userId = widget.userId ?? 1; // TODO: 替换为实际登录用户ID
    final settings = {
      'userId': userId,
      'dailyBudget': double.tryParse(dailyBudgetController.text) ?? 0,
      'dailyBudgetDate': DateFormat('yyyy-MM-dd').format(selectedDay),
      'monthlyBudget': double.tryParse(monthlyBudgetController.text) ?? 0,
      'monthlyBudgetMonth': selectedMonth,
      'fixedExpenses': fixedExpenses,
    };
    await ApiService().updateBudgetSettings(settings);
    // 保存后重新获取数据并清空输入框
    await _fetchBudget();
    dailyBudgetController.clear();
    monthlyBudgetController.clear();
    setState(() {
      selectedDay = DateTime.now();
      selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
      fixedExpenses = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存成功')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('预算设置')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Row(
                    children: [
                      Text('每日预算', style: TextStyle(fontSize: 18)),
                      Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedCustomDay,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedCustomDay = picked;
                            });
                          }
                        },
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedCustomDay)),
                      ),
                    ],
                  ),
                  TextField(
                    controller: dailyBudgetForDateController,
                    decoration: InputDecoration(prefixText: '¥ '),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 8),
                  CheckboxListTile(
                    value: setForWholeMonth,
                    onChanged: (v) {
                      setState(() {
                        setForWholeMonth = v ?? true;
                      });
                    },
                    title: Text('设置为本月每天预算'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saveDailyBudgetForDateOrMonth,
                    child: Text('保存每日预算'),
                  ),
                  Divider(),
                  Row(
                    children: [
                      Text('本月预算', style: TextStyle(fontSize: 18)),
                      Spacer(),
                      TextButton(
                        onPressed: _pickMonth,
                        child: Text(selectedMonth),
                      ),
                    ],
                  ),
                  TextField(
                    controller: monthlyBudgetController,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saveMonthlyBudget,
                    child: Text('保存本月预算'),
                  ),
                ],
              ),
            ),
    );
  }
} 