import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;  // 添加密码显示/隐藏状态变量

  @override
  void initState() {
    super.initState();
    // 清空输入框内容
    _usernameController.clear();
    _passwordController.clear();
  }

  @override
  void dispose() {
    // 在 Widget 销毁时释放控制器资源
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '记账 App',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9!@#$%^&*(),.?":{}|<>]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9!@#$%^&*(),.?":{}|<>]{6,20}$').hasMatch(value)) {
                      return '密码只能包含字母、数字和特殊符号，长度6-20位';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text('没有账号？立即注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await _apiService.login(
          _usernameController.text,
          _passwordController.text,
        );
        
        if (response['success'] == true) {
          // 登录成功
          final user = response['user'];
          if (user != null && user['id'] != null) {
            int userId;
            if (user['id'] is int) {
              userId = user['id'];
            } else if (user['id'] is num) {
              userId = (user['id'] as num).toInt();
            } else if (user['id'] is String) {
              userId = int.parse(user['id']);
            } else {
              throw Exception('无法解析用户ID');
            }
            // Assuming the backend will return a token in the response, e.g., response['token']
            final String? token = response['token']; // Get token from response (may be null currently)

            // Get AuthProvider instance
            final authProvider = Provider.of<AuthProvider>(context, listen: false);

            // Use AuthProvider to handle login state and persistence
            await authProvider.login(userId, token);

            // 初始化该用户的默认分类
            try {
              await _apiService.initDefaultCategories(userId);
            } catch (e) {
              print('初始化默认分类失败：$e');
              // 继续执行，不影响登录
            }
            // 导航到主页
            Navigator.pushReplacementNamed(
              context,
              '/home',
              arguments: {
                'userId': userId,
                'username': user['username'] ?? '用户',
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('登录成功，但未获取到用户信息')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? '登录失败')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
} 