import 'package:dio/dio.dart';
import '../config/api_config.dart';

class HomeService {
  late final Dio _dio;

  HomeService() {
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

  Future<Map<String, dynamic>> getHomeData(int userId) async {
    try {
      final response = await _dio.get('/home', queryParameters: {'userId': userId});
      return response.data;
    } catch (e) {
      throw Exception('获取首页数据失败: ${e.toString()}');
    }
  }
} 