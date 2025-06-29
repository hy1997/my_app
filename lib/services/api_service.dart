import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:convert';
import '../config/api_config.dart';
import '../models/category.dart';
import 'package:intl/intl.dart';

class ApiService {
  late final Dio _dio;
  int? _userId;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(seconds: ApiConfig.connectTimeout),
      receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
      sendTimeout: Duration(seconds: ApiConfig.sendTimeout),
      validateStatus: (status) => status! < ApiConfig.serverError,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Connection': 'keep-alive',
      },
    ));

    // 添加重试拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('Request URL: ${options.uri}');
        print('Request Method: ${options.method}');
        print('Request Headers: ${options.headers}');
        print('Request Data: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('Response Status: ${response.statusCode}');
        print('Response Headers: ${response.headers}');
        // Special handling for login response for detailed inspection
        if (response.requestOptions.path.contains(ApiConfig.login)) {
          print('Login Response Data (Raw): ${response.data}');
        } else {
          print('Response Data: ${response.data}');
        }
        
        if (response.data is String) {
          if (response.data.isNotEmpty) {
            try {
              response.data = json.decode(response.data);
            } catch (e) {
              print('Error decoding response: $e');
            }
          } else {
            print('Response data is empty string. Skipping JSON decode.');
          }
        }
        
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print('Error Type: ${e.type}');
        print('Error Message: ${e.message}');
        print('Error Response: ${e.response?.data}');
        print('Error Status Code: ${e.response?.statusCode}');
        print('Error Request: ${e.requestOptions.uri}');
        
        // 如果是连接错误，尝试重试
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          
          // 最多重试3次
          int retryCount = 0;
          while (retryCount < 3) {
            try {
              print('Retrying... Attempt ${retryCount + 1}');
              final response = await _dio.request(
                e.requestOptions.path,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
                options: Options(
                  method: e.requestOptions.method,
                  headers: e.requestOptions.headers,
                ),
              );
              return handler.resolve(response);
            } catch (retryError) {
              retryCount++;
              if (retryCount == 3) {
          return handler.reject(DioException(
            requestOptions: e.requestOptions,
                  error: '网络连接失败，请检查网络设置',
          ));
              }
              // 等待一段时间后重试
              await Future.delayed(Duration(seconds: 1));
            }
          }
        }
        
        if (e.error is SocketException) {
          print('Socket Error: ${e.error}');
          return handler.reject(DioException(
            requestOptions: e.requestOptions,
            error: '网络连接失败，请检查网络设置',
          ));
        }
        
        if (e.response?.statusCode == ApiConfig.unauthorized) {
          return handler.reject(DioException(
            requestOptions: e.requestOptions,
            error: '登录已过期，请重新登录',
          ));
        }
        
        // 处理其他错误
        String errorMessage = '网络错误，请稍后重试';
        if (e.response?.data != null) {
          try {
            if (e.response?.data is String) {
              final data = json.decode(e.response?.data as String);
              errorMessage = data['message'] ?? errorMessage;
            } else if (e.response?.data is Map) {
              errorMessage = e.response?.data['message'] ?? errorMessage;
            }
          } catch (e) {
            print('Error parsing error message: $e');
          }
        }
        
        return handler.reject(DioException(
          requestOptions: e.requestOptions,
          error: errorMessage,
        ));
      },
    ));
  }

  void setUserId(int id) {
    _userId = id;
    print('ApiService userId set to: $_userId');
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(ApiConfig.login, data: {
          'username': username,
          'password': password,
      });
      
      if (response.statusCode == ApiConfig.success) {
        // Check if response data is a Map
        if (response.data is! Map<String, dynamic>) {
            print('Login response data is not a Map.');
             throw DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: '登录成功，但响应数据格式错误',
            );
        }

        // Check if response contains 'user' field and it is a Map
        if (!response.data.containsKey('user') || response.data['user'] is! Map<String, dynamic>) {
            print("Login response missing 'user' field or it is not a Map.");
             throw DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: response.data?['message'] ?? '登录成功，但缺少用户数据字段',
            );
        }

        // Validate the response structure for required data (user id)
        if (response.data['user'] == null || response.data['user']['id'] == null) {
            print('Login response data missing required user id.');
             throw DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: response.data?['message'] ?? '登录成功，但响应数据不完整 (缺少用户ID)',
            );
        }
        setUserId(response.data['user']['id']);
        return response.data;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: response.data?['message'] ?? '登录失败',
        );
      }
    } catch (e) {
      if (e is DioException) {
        rethrow;
      }
      throw DioException(
        requestOptions: RequestOptions(path: ApiConfig.login),
        error: '登录失败，请稍后重试',
      );
    }
  }

  Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'username': username,
          'password': password,
        },
      );
      
      print('注册响应数据: ${response.data}'); // 添加日志输出
      
      if (response.statusCode == ApiConfig.success) {
        final userData = response.data;
        // 注册成功后初始化默认分类
        if (userData['success'] == true && userData['data'] != null) {
          final userId = userData['data']['id'];
          print('获取到用户ID: $userId'); // 添加日志输出
          if (userId != null) {
            try {
              // 尝试初始化默认分类，最多重试3次
              int retryCount = 0;
              Map<String, dynamic>? result;
              
              while (retryCount < 3 && result == null) {
                try {
                  print('尝试初始化默认分类，第${retryCount + 1}次');
                  result = await initDefaultCategories(userId);
                  print('初始化默认分类成功: $result'); 
                } catch (e) {
                  print('初始化默认分类失败，重试 ${retryCount + 1}/3: $e');
                  retryCount++;
                  // 等待短暂时间后重试
                  await Future.delayed(Duration(milliseconds: 500));
                  
                  // 如果是最后一次尝试，则手动创建一些基本默认分类
                  if (retryCount == 3) {
                    print('默认分类初始化API调用失败，手动创建基础默认分类');
                    await _createBasicDefaultCategories(userId);
                  }
                }
              }
            } catch (e) {
              print('初始化默认分类过程中发生错误: $e');
              // 尝试手动创建基础默认分类
              try {
                await _createBasicDefaultCategories(userId);
              } catch (err) {
                print('手动创建基础默认分类也失败: $err');
              }
            }
          } else {
            print('用户ID为空，无法初始化默认分类'); 
          }
        } else {
          print('注册响应数据格式不正确，无法初始化默认分类: $userData'); 
        }
        return userData;
      } else {
        throw Exception(response.data['message'] ?? '注册失败');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? '注册失败');
      }
      throw Exception(e.message ?? '网络错误，请稍后重试');
    } catch (e) {
      throw Exception('注册失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getBudgetSettings(int userId) async {
    try {
      print('API: 获取预算设置...');
      final response = await _dio.get(ApiConfig.budgetSettings, queryParameters: {'userId': userId});
      print('API: 获取预算设置响应: ${response.data}');
      
      if (response.data is Map<String, dynamic> && response.data['success'] == true && response.data['data'] != null) {
         return response.data['data'] as Map<String, dynamic>;
      }

      // 如果响应格式不正确或失败，返回默认结构
      print('API: 获取预算设置失败或格式错误');
      return {
        'dailyBudget': 0.0,
        'monthlyBudget': 0.0,
        'fixedExpenses': [],
      };
    } catch (e) {
      print('API: 获取预算设置异常: $e');
      // 异常时也返回默认结构
      return {
        'dailyBudget': 0.0,
        'monthlyBudget': 0.0,
        'fixedExpenses': [],
      };
    }
  }

  Future<bool> updateBudgetSettings(Map<String, dynamic> settings) async {
    try {
      final response = await _dio.post(ApiConfig.budgetSettings, data: settings);
      return response.statusCode == ApiConfig.success;
    } catch (e) {
      throw Exception('更新预算设置失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> setMonthlyBudget(int userId, double budget) async {
    try {
      final response = await _dio.post(ApiConfig.monthlyBudget, data: {
        'userId': userId,
        'budget': budget,
      });
      return response.data;
    } catch (e) {
      throw Exception('设置月度预算失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> setDailyBudget(int userId, double budget) async {
    try {
      final response = await _dio.post(ApiConfig.dailyBudgetDefault, data: {
        'userId': userId,
        'budget': budget,
      });
      return response.data;
    } catch (e) {
      throw Exception('设置每日预算失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> setDailyBudgetForDate(int userId, String date, double budget, bool setForWholeMonth ) async {
    try {
      final response = await _dio.post(ApiConfig.dailyBudget, data: {
        'userId': userId,
        'date': date,
        'budget': budget,
        'setForWholeMonth':setForWholeMonth,
       });
      return response.data;
    } catch (e) {
      throw Exception('设置指定日期预算失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getDailyBudget(int userId, String date) async {
    try {
       print('API: 获取今日预算...');
      final response = await _dio.get(ApiConfig.dailyBudget, queryParameters: {
        'userId': userId,
        'date': date,
      });
       print('API: 获取今日预算响应: ${response.data}');

      if (response.data is Map<String, dynamic> && response.data['success'] == true && response.data['data'] != null) {
         return response.data['data'] as Map<String, dynamic>;
      }

       // 如果响应格式不正确或失败，返回默认结构
      print('API: 获取今日预算失败或格式错误');
       return {
        'budget': 0.0,
      };
    } catch (e) {
      print('API: 获取日期预算异常: $e');
      // 异常时也返回默认结构
      return {
         'budget': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> setBudgetNotification(int userId, int threshold, bool enabled) async {
    try {
      final response = await _dio.post(ApiConfig.budgetNotification, data: {
        'userId': userId,
        'threshold': threshold,
        'enabled': enabled,
      });
      return response.data;
    } catch (e) {
      throw Exception('设置预算提醒失败: ${e.toString()}');
    }
  }

  Future<List<Category>> getCategories(int userId) async {
    try {
      print('开始获取分类列表，用户ID: $userId');
      final response = await _dio.get(ApiConfig.categories, queryParameters: {'userId': userId});
      
      print('获取分类列表响应: ${response.data}');
      
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> results = data['data']['results'];
          final categories = results.map((json) => Category.fromJson(json)).toList();
          print('解析到分类列表: ${categories.length} 个');
          return categories;
        }
      }
      print('获取分类列表失败: ${response.statusCode}');
      return [];
    } catch (e) {
      print('获取分类列表异常: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addCategory(int userId, Map<String, dynamic> category) async {
    try {
      final response = await _dio.post(ApiConfig.categories, data: {
        'userId': userId,
        ...category,
      });
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      throw Exception('添加分类失败：响应数据格式错误');
    } catch (e) {
      print('添加分类失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategory(int categoryId, Map<String, dynamic> category) async {
    try {
      final response = await _dio.put(ApiConfig.categories + '/$categoryId', data: category);
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      throw Exception('更新分类失败：响应数据格式错误');
    } catch (e) {
      print('更新分类失败: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    try {
      await _dio.delete(ApiConfig.categories + '/$categoryId');
    } catch (e) {
      print('删除分类失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initDefaultCategories(int userId) async {
    try {
      final response = await _dio.post(ApiConfig.categoriesInit, data: {'userId': userId});
      print('初始化默认分类响应: ${response.data}'); // 添加日志
      
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      throw Exception('初始化默认分类失败：响应数据格式错误');
    } catch (e) {
      print('初始化默认分类失败: $e');
      if (e is DioException && e.response?.data != null) {
        print('错误响应数据: ${e.response?.data}');
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getBills(int userId) async {
    try {
      final response = await _dio.get(ApiConfig.bills, queryParameters: {'userId': userId});
      return response.data;
    } catch (e) {
      throw Exception('获取账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> createBill(Map<String, dynamic> bill, int userId) async {
    try {
      // Remove userId from bill data and add as query parameter
      final response = await _dio.post(
        ApiConfig.bills,
        data: bill, // Send bill data in the request body
        queryParameters: {'userId': userId}, // Send userId as a query parameter
      );
      return response.data;
    } catch (e) {
      throw Exception('创建账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateBill(int billId, Map<String, dynamic> bill, int userId) async {
    try {
      // Remove _userId dependency and add userId parameter
      // This method will now be called with the userId from the UI layer
      // Ensure userId is included in the bill data for the backend to verify ownership
      // Remove userId from bill data and add as query parameter
      final response = await _dio.put(
        ApiConfig.bills + '/$billId',
        data: bill, // Send updated bill data in the request body
        queryParameters: {'userId': userId}, // Send userId as a query parameter
      );
      return response.data;
    } catch (e) {
      throw Exception('更新账单失败: ${e.toString()}');
    }
  }

  Future<void> deleteBill(int billId, int userId) async {
    try {
      print('API: 删除账单...');
      final response = await _dio.delete(
        '${ApiConfig.bills}/$billId',
        queryParameters: {'userId': userId},
      );
      print('API: 删除账单响应: ${response.data}');
      
      if (response.statusCode != ApiConfig.success) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: (response.data is Map<String, dynamic> && response.data.containsKey('message')) ? response.data['message'] : '删除失败',
        );
      }
    } catch (e) {
      print('删除账单失败: $e');
      if (e is DioException) {
        rethrow;
      }
      throw DioException(
        requestOptions: RequestOptions(path: '${ApiConfig.bills}/$billId'),
        error: '删除失败，请稍后重试',
      );
    }
  }

  Future<Map<String, dynamic>> searchBills(int userId, Map<String, dynamic> params) async {
    try {
      Map<String, dynamic> queryParams = {'userId': userId};
      queryParams.addAll(params);
      print('API: Searching bills with params: $queryParams'); // Add log
      final response = await _dio.get(ApiConfig.billsSearch, queryParameters: queryParams);
      print('API: Search bills response status: ${response.statusCode}'); // Add log
      print('API: Search bills response data: ${response.data}'); // Add log

      // Check if response data is a Map and has the expected structure
      if (response.data is Map<String, dynamic> && 
          response.data.containsKey('success') && response.data['success'] == true &&
          response.data.containsKey('data') && response.data['data'] is Map<String, dynamic> &&
          response.data['data'].containsKey('results') && response.data['data']['results'] is List) {

        print('API: Successfully received and validated search bills data.'); // Add log
        return response.data['data']; // Return the 'data' part which contains 'results' and 'total'
      } else if (response.data is Map<String, dynamic> && 
                 response.data.containsKey('success') && response.data['success'] == false) {
          // Handle backend error message if success is false
          final errorMessage = response.data['message'] ?? '搜索账单失败';
           print('API: Search bills backend reported failure: $errorMessage');
           // Depending on desired behavior, you might want to throw here
           // throw Exception(errorMessage);
           // Or return an empty result
           return {'results': [], 'total': 0}; // Return empty result on backend failure
      }
      else {
        // Handle unexpected response format or empty response string
        print('API: Unexpected search bills response format or empty data.'); // Add log
        // Return an empty result to prevent TypeError in UI
        return {'results': [], 'total': 0};
      }

    } catch (e) {
      print('API: Search bills exception: $e'); // Add log
      // Throw a more specific exception or return an empty result on error
      throw Exception('搜索账单失败: ${e.toString()}');
       // Or return empty result on exception
       // return {'results': [], 'total': 0};
    }
  }

  Future<Map<String, dynamic>> getDailyBills(int userId, String date) async {
    try {
      print('API: 获取日账单...');
      final response = await _dio.get(ApiConfig.billsDaily, queryParameters: {
        'userId': userId,
        'date': date,
      });
      print('API: 获取日账单响应状态: ${response.statusCode}'); // Add log
      print('API: 获取日账单响应数据: ${response.data}'); // Add log

       // Check if response data is a Map and has the expected structure
       if (response.data is Map<String, dynamic> && 
          response.data.containsKey('success') && response.data['success'] == true &&
          response.data.containsKey('data') && response.data['data'] is Map<String, dynamic> &&
          response.data['data'].containsKey('bills') && response.data['data']['bills'] is List) {

          print('API: Successfully received and validated daily bills data.'); // Add log
          return response.data['data']; // Return the 'data' part
       } else if (response.data is Map<String, dynamic> && 
                 response.data.containsKey('success') && response.data['success'] == false) {
          // Handle backend error message if success is false
          final errorMessage = response.data['message'] ?? '获取日账单失败';
           print('API: Daily bills backend reported failure: $errorMessage');
           // Return empty result on backend failure
           return {'date': date, 'bills': [], 'total': 0.0, 'fixedTotal': 0.0, 'grandTotal': 0.0};
       }
       else {
         // Handle unexpected response format or empty response string
         print('API: Unexpected daily bills response format or empty data.'); // Add log
         // Return an empty result to prevent TypeError in UI
         return {'date': date, 'bills': [], 'total': 0.0, 'fixedTotal': 0.0, 'grandTotal': 0.0};
       }

    } catch (e) {
      print('API: 获取日账单异常: $e'); // Add log
      // Throw a more specific exception or return an empty result on error
       throw Exception('获取日账单失败: ${e.toString()}');
       // Or return empty result on exception
       // return {'date': date, 'bills': [], 'total': 0.0, 'fixedTotal': 0.0, 'grandTotal': 0.0};
    }
  }

  Future<Map<String, dynamic>> getStatistics(int userId) async {
    try {
      final response = await _dio.get(ApiConfig.statistics, queryParameters: {'userId': userId});
      return response.data;
    } catch (e) {
      throw Exception('获取统计数据失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getDailyDetail(int userId, int year, int month) async {
    try {
      final response = await _dio.get(ApiConfig.dailyDetail, queryParameters: {
        'userId': userId,
        'year': year,
        'month': month,
      });
      return response.data;
    } catch (e) {
      throw Exception('获取每日明细失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getMonthlyFixedBills(int userId, String startDate, String endDate) async {
    final response = await _dio.get(ApiConfig.billsFixedMonthly, queryParameters: {
      'userId': userId,
      'startDate': startDate,
      'endDate': endDate,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> setMonthlyBudgetForMonth(int userId, String month, double budget) async {
    try {
      final response = await _dio.post(ApiConfig.monthlyBudget, data: {
        'userId': userId,
        'month': month,
        'budget': budget,
      });
      return response.data;
    } catch (e) {
      throw Exception('设置指定月份月度预算失败: \\${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getMonthlyBudget(int userId, String month) async {
    try {
      print('API: 获取月度预算...');
      final response = await _dio.get(ApiConfig.monthlyBudget, queryParameters: {
        'userId': userId,
        'month': month,
      });
       print('API: 获取月度预算响应: ${response.data}');

      if (response.data is Map<String, dynamic> && response.data['success'] == true && response.data['data'] != null) {
         return response.data['data'] as Map<String, dynamic>;
      }

       // 如果响应格式不正确或失败，返回默认结构
      print('API: 获取月度预算失败或格式错误');
       return {
        'budget': 0.0,
      };
    } catch (e) {
      print('API: 获取本月预算异常: $e');
      // 异常时也返回默认结构
      return {
         'budget': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> getDailyStatistics(int userId, int year, int month) async {
    final yityresp = await _dio.get(ApiConfig.statisticsDaily, queryParameters: {
      'userId': userId,
      'year': year,
      'month': month,
    });
    return yityresp.data;
  }

  Future<Map<String, dynamic>> getDayStatistics(int userId, String date) async {
    final resp = await _dio.get(ApiConfig.statisticsDay, queryParameters: {
      'userId': userId,
      'date': date,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> category) async {
    try {
      final response = await _dio.post(
        ApiConfig.categories,
        data: category,
      );
      return response.data;
    } catch (e) {
      print('创建分类失败: $e');
      rethrow;
    }
  }

  // 手动创建基础默认分类（当API调用失败时的备用方案）
  Future<void> _createBasicDefaultCategories(int userId) async {
    print('开始手动创建基础默认分类');
    
    final defaultCategories = [
      {'name': '餐饮', 'icon': '🍔', 'description': '日常饮食支出', 'isFixed': false},
      {'name': '交通', 'icon': '🚕', 'description': '交通出行支出', 'isFixed': false},
      {'name': '购物', 'icon': '🛒', 'description': '购物消费支出', 'isFixed': false},
      {'name': '住房', 'icon': '🏠', 'description': '房租水电等', 'isFixed': true},
      {'name': '娱乐', 'icon': '🎮', 'description': '休闲娱乐支出', 'isFixed': false},
    ];
    
    for (var category in defaultCategories) {
      try {
        print('创建默认分类: ${category['name']}');
        final categoryData = {
          'userId': userId,
          'name': category['name'],
          'icon': category['icon'],
          'description': category['description'],
          'isFixed': category['isFixed'],
          'type': 'expense',
          'orderIndex': defaultCategories.indexOf(category),
        };
        
        await addCategory(userId, categoryData);
      } catch (e) {
        print('创建默认分类 ${category['name']} 失败: $e');
        // 继续尝试创建其他分类
        continue;
      }
    }
  }

  Future<String> bindUser(int userId, String username) async {
    try {
      final response = await _dio.post('${ApiConfig.baseUrl}/user-binding/bind', data: {
        'userId': userId,
        'username': username,
      });
      if (response.data is Map<String, dynamic> && response.data['success'] == true) {
        return '绑定成功';
      } else if (response.data is Map<String, dynamic> && response.data['message'] != null) {
         return response.data['message'];
      }
      else {
        return response.data?.toString() ?? '绑定失败: 未知响应';
      }
    } on DioException catch (e) {
      String errorMessage = '绑定失败: ' + (e.response?.data?['message'] ?? e.message ?? e.toString());
      print('绑定用户 DioException: $errorMessage');
      return errorMessage;
    } catch (e) {
      String errorMessage = '绑定失败: ${e.toString()}';
      print('绑定用户未知异常: $errorMessage');
      return errorMessage;
    }
  }

  Future<Map<String, dynamic>> getCombinedBudget() async {
    if (_userId == null) {
       throw Exception('User ID is not set in ApiService');
    }
    try {
      final now = DateTime.now();
      final month = DateFormat('yyyy-MM').format(now);
      final response = await _dio.get('${ApiConfig.baseUrl}/api/budget/combined', queryParameters: {
        'userId': _userId!,
        'month': month,
      });
      return response.data['data'];
    } catch (e) {
      throw Exception('获取组合预算失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getBoundUsers(int userId) async {
    try {
      final response = await _dio.get('/user-binding/bound-users', queryParameters: {
        'userId': userId,
      });

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
         print('获取绑定用户响应数据: $responseData'); // 添加详细日志
        if (responseData['success'] == true) {
          // Return the data field which should be a list of maps with boundUserId and username
          return responseData; // The data field contains the list
        } else {
          final errorMessage = responseData['message'] ?? '获取绑定用户失败: 未知错误';
           print('获取绑定用户失败: $errorMessage');
          throw Exception(errorMessage);
        }
      } else {
        final errorMessage = '获取绑定用户失败: 响应数据格式错误或为空';
         print('$errorMessage. 原始数据: ${response.data}');
        throw Exception(errorMessage);
      }

    } on DioException catch (e) {
       print('获取绑定用户 DioException: ${e.message}');
       if (e.response?.data != null && e.response?.data is Map<String, dynamic>){
          final errorResponseData = e.response?.data as Map<String, dynamic>;
          final errorMessage = errorResponseData['message'] ?? e.message;
           print('获取绑定用户失败 (DioException): $errorMessage');
          throw Exception(errorMessage); // Throw exception with backend message
       } else {
           print('获取绑定用户失败 (DioException): ${e.toString()}');
          throw Exception('获取绑定用户失败: ${e.message ?? e.toString()}');
       }
    } catch (e) {
      print('获取绑定用户未知异常: ${e.toString()}');
      throw Exception('获取绑定用户失败: ${e.toString()}');
    }
  }

  // Add method to remove binding
  Future<String> removeBinding(int userId, int boundUserId) async {
    try {
      final response = await _dio.delete('${ApiConfig.baseUrl}/user-binding/remove', queryParameters: {
        'userId': userId,
        'boundUserId': boundUserId,
      });
      if (response.data is Map<String, dynamic> && response.data['success'] == true) {
        return '移除绑定成功';
      } else if (response.data is Map<String, dynamic> && response.data['message'] != null) {
         return response.data['message'];
      }
      else {
        return response.data?.toString() ?? '移除绑定失败: 未知响应';
      }
    } on DioException catch (e) {
      String errorMessage = '移除绑定失败: ' + (e.response?.data?['message'] ?? e.message ?? e.toString());
      print('移除绑定 DioException: $errorMessage');
      return errorMessage;
    } catch (e) {
      String errorMessage = '移除绑定失败: ${e.toString()}';
      print('移除绑定未知异常: $errorMessage');
      return errorMessage;
    }
  }
}