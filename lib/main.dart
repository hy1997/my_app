import 'package:flutter/material.dart';
import './screens/login_screen.dart';
import './screens/register_screen.dart';
import './screens/main_tab_screen.dart';
import './screens/add_expense_screen.dart';
import './screens/category_screen.dart';
import './screens/expense_detail_screen.dart';
import './screens/budget_settings_screen.dart';
import './screens/statistics_screen.dart';
import './screens/daily_detail_screen.dart';
import './screens/search_screen.dart';
import './screens/settings_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import './providers/auth_provider.dart';
import './providers/user_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账 App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          print('Consumer builder called, isAuthenticated: ${authProvider.isAuthenticated}');
          if (authProvider.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (authProvider.isAuthenticated) {
            return MainTabScreen(); // 用户已认证，跳转到主页
          } else {
            return LoginScreen(); // 用户未认证，跳转到登录页
          }
        },
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => MainTabScreen(userId: args?['userId'], username: args?['username']),
          );
        } else if (settings.name == '/add-expense') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => AddExpenseScreen(
              userId: args['userId'],
              expenseToEdit: args['expenseToEdit'],
            ),
          );
        } else if (settings.name == '/expense-detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ExpenseDetailScreen(
              userId: args['userId'],
              expense: args['expense'],
            ),
          );
        } else if (settings.name == '/category') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => CategoryScreen(userId: args['userId']),
          );
        } else if (settings.name == '/settings') {
          // Get userId from AuthProvider
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.userId; // Use the userId from AuthProvider
          if (userId != null) {
            return MaterialPageRoute(
              builder: (context) => SettingsScreen(userId: userId),
            );
          } else {
            // If userId is not available (should not happen if isAuthenticated is true), redirect to login
            return MaterialPageRoute(builder: (context) => LoginScreen());
          }
        }
        return null;
      },
      routes: {
        '/register': (context) => RegisterScreen(),
      },
    );
  }
} 