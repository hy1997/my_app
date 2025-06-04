import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'category_management_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;

  const SettingsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String _message = '';
  Map<String, dynamic>? _combinedBudgetInfo;
  String? _boundUsername;
  int? _boundUserId;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _apiService.setUserId(widget.userId);
    _checkBindingStatus();
  }

  Future<void> _checkBindingStatus() async {
    print('_checkBindingStatus called');
    try {
      final response = await _apiService.getBoundUsers(widget.userId);
      print('Check binding status response: $response');
      if (response['success'] == true && response['data'] != null) {
        final boundUsers = response['data'] as List<dynamic>;
        if (boundUsers.isNotEmpty) {
          final boundUser = boundUsers.first;
          if (boundUser['username'] != null && boundUser['boundUserId'] != null) {
            setState(() {
              _boundUsername = boundUser['username'] as String;
              _boundUserId = boundUser['boundUserId'] as int;
              _message = '';
            });
          } else {
            setState(() {
              _boundUsername = null;
              _boundUserId = null;
              _message = '获取绑定用户名或用户ID失败';
            });
          }
        } else {
          setState(() {
            _boundUsername = null;
            _boundUserId = null;
            _message = '';
          });
        }
      } else {
        setState(() {
          _boundUsername = null;
          _boundUserId = null;
          _message = response['message'] ?? '检查绑定状态失败';
        });
      }
    } catch (e) {
      print('Error checking binding status: $e');
      setState(() {
        _boundUsername = null;
        _boundUserId = null;
        _message = '检查绑定状态异常: ${e.toString()}';
      });
    }
  }

  Future<void> _removeBinding() async {
    if (widget.userId == null || _boundUserId == null) {
      setState(() {
        _message = '用户ID或绑定用户ID未获取，无法移除绑定';
      });
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除绑定确认'),
        content: Text('确定要移除与 $_boundUsername 的绑定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _message = '移除绑定中...';
      });
      final response = await _apiService.removeBinding(widget.userId, _boundUserId!);
      setState(() {
        _message = response;
        if (response.contains('成功')) {
          _boundUsername = null;
          _boundUserId = null;
        }
      });
    }
  }

  Future<void> bindUser() async {
    if (widget.userId == null) {
      setState(() {
        _message = '用户ID未获取，无法绑定';
      });
      return;
    }
    if (_usernameController.text.isEmpty) {
      setState(() {
        _message = '请输入要绑定的用户名';
      });
      return;
    }
    setState(() {
      _message = '绑定中...';
    });

    final response = await _apiService.bindUser(widget.userId, _usernameController.text);
    _usernameController.clear();
    setState(() {
      _message = response;
    });
    _checkBindingStatus();
  }

  Future<void> fetchCombinedBudget() async {
    final response = await _apiService.getCombinedBudget();
    setState(() {
      _combinedBudgetInfo = response;
      if (_combinedBudgetInfo?['error'] != null) {
        _message = _combinedBudgetInfo!['error'];
      } else {
        _message = '';
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('退出确认'),
        content: Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Use AuthProvider to clear the login state
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      // Navigation is handled by the Consumer in main.dart
      
      // **** 移除导航到登录页并清除堆栈 ****
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()), // 跳转到登录页
        (Route<dynamic> route) => false, // 移除所有之前的路由
      );

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.category),
            title: Text('分类管理'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryManagementScreen(userId: widget.userId),
                ),
              );
            },
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('用户绑定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                if (_boundUsername == null || _boundUsername!.isEmpty) ...[
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(labelText: '输入要绑定的用户名'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: bindUser,
                    child: Text('绑定用户'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('已绑定用户: $_boundUsername', style: TextStyle(fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _removeBinding,
                        tooltip: '移除绑定',
                      ),
                    ],
                  ),
                ],
                if (_message.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(_message, style: TextStyle(color: _message.contains('失败') ? Colors.red : Colors.green)),
                ],
              ],
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('查看组合预算 (测试)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: fetchCombinedBudget,
                  child: Text('获取组合预算'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
                if (_combinedBudgetInfo != null) ...[
                  SizedBox(height: 16),
                  Text('本月总预算: ¥${_combinedBudgetInfo!['monthlyBudget'] ?? 'N/A'}'),
                  Text('每日总预算: ¥${_combinedBudgetInfo!['dailyBudget'] ?? 'N/A'}'),
                  Text('固定支出总额: ¥${_combinedBudgetInfo!['fixedExpenses'] ?? 'N/A'}'),
                ],
              ],
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
} 