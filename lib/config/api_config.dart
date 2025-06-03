class ApiConfig {
  // API 基础配置
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
      defaultValue: 'http://113.44.83.69/api'
  );
  
  // API 超时配置
  static const int connectTimeout = 150;
  static const int receiveTimeout = 150;
  static const int sendTimeout = 150  ;

  // API 路径配置
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  
  // 首页相关
  static const String home = '/home';
  
  // 分类相关
  static const String categories = '/categories';
  static const String categoriesInit = '/categories/init';
  
  // 账单相关
  static const String bills = '/bills';
  static const String billsSearch = '/bills/search';
  static const String billsDaily = '/bills/daily';
  static const String billsFixedMonthly = '/bills/fixed/monthly';
  
  // 预算相关
  static const String budget = '/budget';
  static const String budgetSettings = '/budget/settings';
  static const String monthlyBudget = '/budget/monthly';
  static const String dailyBudget = '/budget/daily';
  static const String dailyBudgetDefault = '/budget/daily/default';
  static const String budgetNotification = '/budget/notification';
  
  // 统计相关
  static const String statistics = '/statistics';
  static const String statisticsDaily = '/statistics/daily';
  static const String statisticsDay = '/statistics/day';
  static const String dailyDetail = '/daily-detail';
  
  // API 响应状态码
  static const int success = 200;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int serverError = 500;
} 