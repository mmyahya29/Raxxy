import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/weather_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'weather_api_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';




// 1. The Repository Provider
final weatherRepositoryProvider = Provider((ref) => WeatherRepository());

// 2. The FutureProvider to get weather data
// We use .family to pass in lat/lon as a record
final weatherProvider = FutureProvider.family<FullWeatherData, ({double lat, double lon})>(
      (ref, coords) async {
    final repository = ref.watch(weatherRepositoryProvider);
    return repository.fetchWeather(coords.lat, coords.lon);
  },
);

class WeatherRepository {
  final String apiKey = dotenv.env['WEATHER_API_KEY'] ?? '';
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<FullWeatherData> fetchWeather(double lat, double lon) async {
    final currentUri = Uri.parse('$baseUrl/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey');
    final forecastUri = Uri.parse('$baseUrl/forecast?lat=$lat&lon=$lon&units=metric&appid=$apiKey');

    // Run both requests in parallel
    final responses = await Future.wait([
      http.get(currentUri),
      http.get(forecastUri),
    ]);

    if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
      final currentJson = jsonDecode(responses[0].body);
      final forecastJson = jsonDecode(responses[1].body);

      // Parse current
      final current = WeatherBase.fromJson(currentJson);

      // Parse forecast list (OpenWeather returns a 'list' key for forecasts)
      final List forecastList = forecastJson['list'];
      final forecast = forecastList.map((item) => WeatherBase.fromJson(item)).toList();

      return FullWeatherData(current: current, forecast: forecast);
    } else {
      throw Exception('Failed to fetch weather data from OpenWeather');
    }
  }
}



