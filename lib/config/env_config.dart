class EnvConfig {
  static const bool isDevelopment = bool.fromEnvironment('FLUTTER_ENV', defaultValue: true);
  
  static String get apiBaseUrl {
    if (isDevelopment) {
      return 'http://113.44.83.69/api';
    } else {
      return 'https://api.yourdomain.com/api';  // 生产环境 API 地址
    }
  }
  
  static const int apiTimeout = 15;
  static const int apiRetryCount = 3;
  static const Duration apiRetryDelay = Duration(seconds: 100);
  
  static const String appName = '记账 App';
  static const String appVersion = '1.0.0';
  
  // 缓存配置
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_info';
  static const Duration tokenExpiration = Duration(days: 7);
  
  // 其他配置
  static const int defaultPageSize = 20;
  static const Duration animationDuration = Duration(milliseconds: 300);
} 