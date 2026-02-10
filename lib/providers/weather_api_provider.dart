import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/weather_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'weather_api_provider.dart';
import 'package:geolocator/geolocator.dart';

final syncProvider = Provider((ref) {

  Future<void> performSync() async {
    try {
      // 1. Get Current Position
      Position position = await _determinePosition();

      // 2. Pass real lat/lon to the provider
      final data = await ref.read(
          weatherProvider((lat: position.latitude, lon: position.longitude)).future
      );

      // 3. Logic based on weather condition
      _handleWeatherLogic(data.current.description);

    } catch (e) {
      print("Error during sync: $e");
    }
  }

  return performSync; // Return the function so it can be called elsewhere
});

// Helper: Determine the current position with permission handling
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return Future.error('Location services are disabled.');

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return Future.error('Permissions denied');
  }

  return await Geolocator.getCurrentPosition();
}


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
  final String apiKey = 'YOUR_OPENWEATHER_API_KEY';
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

void _handleWeatherLogic(String description) {
  final condition = description.toLowerCase();

  if (condition.contains('rain')) {
    print("☔ Action: It is rainy. Remember to take an umbrella!");
  }
  else if (condition.contains('cloud')) {
    print("☁️ Action: It is cloudy. Perfect for a walk.");
  }
  else if (condition.contains('clear')) {
    print("☀️ Action: The sky is clear. Don't forget sunscreen!");
  }
  else if (condition.contains('snow')) {
    print("❄️ Action: It's snowing! Drive carefully.");
  }
  else {
    print("🌡️ Current weather status: $condition");
  }
}


