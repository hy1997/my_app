import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'add_expense_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> expense;

  const ExpenseDetailScreen({
    Key? key,
    required this.userId,
    required this.expense,
  }) : super(key: key);

  @override
  _ExpenseDetailScreenState createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _apiService = ApiService();
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final categoryName = expense['categoryName'] ?? '未分类';
    final categoryIcon = expense['categoryIcon'] ?? '📊';
    final amount = expense['amount']?.toString() ?? '0';
    final note = expense['note'] ?? '';
    
    DateTime? dateTime;
    String formattedDate = '未知日期';
    String formattedTime = '';
    
    if (expense['time'] != null) {
      try {
        dateTime = DateTime.parse(expense['time']);
        formattedDate = DateFormat('yyyy-MM-dd').format(dateTime);
        formattedTime = DateFormat('HH:mm').format(dateTime);
      } catch (e) {
        print('解析日期失败: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('支出详情'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分类和金额
            Center(
              child: Column(
                children: [
                  Text(categoryIcon, style: TextStyle(fontSize: 48)),
                  SizedBox(height: 8),
                  Text(categoryName, style: TextStyle(fontSize: 20)),
                  SizedBox(height: 16),
                  Text(
                    '¥$amount',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            
            // 日期和时间
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text('日期'),
              subtitle: Text('$formattedDate ${formattedTime.isNotEmpty ? "· $formattedTime" : ""}'),
            ),
            
            // 备注
            if (note.isNotEmpty)
              ListTile(
                leading: Icon(Icons.note),
                title: Text('备注'),
                subtitle: Text(note),
              ),
            
            Spacer(),
            
            // 删除按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isDeleting ? null : () => _confirmDelete(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isDeleting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('删除此支出', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context) async {
    final result = await Navigator.pushNamed(
      context,
      '/add-expense',
      arguments: {
        'userId': widget.userId,
        'expenseToEdit': widget.expense,
      },
    );
    
    if (result == true) {
      Navigator.pop(context, true); // 返回上一页并刷新
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除这笔支出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => _deleteExpense(context),
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(BuildContext context) async {
    Navigator.pop(context); // 关闭对话框
    
    setState(() => _isDeleting = true);
    
    try {
      await _apiService.deleteBill(widget.expense['id'], widget.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除成功')),
      );
      Navigator.pop(context, true); // 返回上一页并刷新
    } catch (e) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }
} 