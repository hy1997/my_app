import 'package:flutter/foundation.dart';

class UserProvider with ChangeNotifier {
  int? _userId;
  
  int? get userId => _userId;
  
  void setUserId(int? id) {
    _userId = id;
    notifyListeners();
  }
} 