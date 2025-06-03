import 'package:dio/dio.dart';
import '../config/api_config.dart';

class BillService {
  late final Dio _dio;

  BillService() {
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
  }

  Future<List<dynamic>> getBills(int userId) async {
    try {
      final response = await _dio.get(ApiConfig.bills, queryParameters: {'userId': userId});
      return response.data;
    } catch (e) {
      throw Exception('获取账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> createBill(Map<String, dynamic> bill) async {
    try {
      final response = await _dio.post(ApiConfig.bills, data: bill);
      return response.data;
    } catch (e) {
      throw Exception('创建账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateBill(int billId, Map<String, dynamic> bill) async {
    try {
      final response = await _dio.put('${ApiConfig.bills}/$billId', data: bill);
      return response.data;
    } catch (e) {
      throw Exception('更新账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> deleteBill(int billId) async {
    try {
      final response = await _dio.delete('${ApiConfig.bills}/$billId');
      return response.data;
    } catch (e) {
      throw Exception('删除账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> searchBills(int userId, Map<String, dynamic> params) async {
    try {
      Map<String, dynamic> queryParams = {'userId': userId};
      queryParams.addAll(params);
      final response = await _dio.get(ApiConfig.billsSearch, queryParameters: queryParams);
      return response.data;
    } catch (e) {
      throw Exception('搜索账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getDailyBills(int userId, String date) async {
    try {
      final response = await _dio.get(ApiConfig.billsDaily, queryParameters: {
        'userId': userId,
        'date': date,
      });
      return response.data;
    } catch (e) {
      throw Exception('获取日账单失败: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getMonthlyFixedBills(int userId, String startDate, String endDate) async {
    try {
      final response = await _dio.get(ApiConfig.billsFixedMonthly, queryParameters: {
        'userId': userId,
        'startDate': startDate,
        'endDate': endDate,
      });
      return response.data;
    } catch (e) {
      throw Exception('获取月度固定账单失败: ${e.toString()}');
    }
  }
} 