import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  int? _userId;
  String? _token;
  bool _isLoading = false;

  int? get userId => _userId;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _userId != null;

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('userId');
      _token = prefs.getString('token');
    } catch (e) {
      print('加载认证状态失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(int userId, String? token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', userId);
      await prefs.setString('token', token ?? '');

      _userId = userId;
      _token = token;
    } catch (e) {
      print('保存认证状态失败: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('token');

      _userId = null;
      _token = null;
    } catch (e) {
      print('清除认证状态失败: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 