import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'tool_registry.dart';

class WeatherTool extends AiTool {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  String get name => 'get_weather';

  @override
  String get description =>
      '查询指定城市的实时天气信息，包含温度、湿度、天气状况和风速。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'city': {
            'type': 'string',
            'description': '城市名称，使用中文，如 "北京"、"上海"、"杭州"',
          },
        },
        'required': ['city'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final city = args['city']?.toString() ?? '';
    if (city.isEmpty) return '错误: 请提供城市名称';

    if (AppConfig.weatherApiKey.isEmpty) {
      return '天气服务未配置 API Key。请在设置中填入 OpenWeatherMap API Key。';
    }

    try {
      final response = await _dio.get(
        '${AppConfig.weatherApiBaseUrl}/weather',
        queryParameters: {
          'q': city,
          'appid': AppConfig.weatherApiKey,
          'units': 'metric',
          'lang': 'zh_cn',
        },
      );

      final data = response.data;
      final temp = data['main']['temp'];
      final feelsLike = data['main']['feels_like'];
      final humidity = data['main']['humidity'];
      final description = data['weather'][0]['description'];
      final windSpeed = data['wind']['speed'];
      final cityName = data['name'];

      return '$cityName 天气: $description\n'
          '温度: $temp°C (体感 $feelsLike°C)\n'
          '湿度: $humidity%\n'
          '风速: ${windSpeed}m/s';
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return '天气查询失败: API Key 无效，请在设置中检查。';
      }
      if (e.response?.statusCode == 404) {
        return '天气查询失败: 找不到城市 "$city"，请确认城市名称。';
      }
      return '天气查询失败: 网络错误 ${e.message}';
    } catch (e) {
      return '天气查询失败: $e';
    }
  }
}
