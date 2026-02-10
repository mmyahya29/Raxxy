class WeatherBase {
  final int id;
  final double temp;
  final String description;
  final String icon;
  final DateTime date;

  WeatherBase({
    required this.id,
    required this.temp,
    required this.description,
    required this.icon,
    required this.date,
  });

  factory WeatherBase.fromJson(Map<String, dynamic> json) {
    return WeatherBase(
      id: json['weather'][0]['id'],
      temp: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'],
      icon: json['weather'][0]['icon'],
      date: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
    );
  }
}

// A container to hold both results
class FullWeatherData {
  final WeatherBase current;
  final List<WeatherBase> forecast;

  FullWeatherData({required this.current, required this.forecast});
}