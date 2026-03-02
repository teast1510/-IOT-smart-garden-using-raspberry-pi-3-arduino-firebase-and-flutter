import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'firebase_options.dart';
import 'home.dart';
import 'app_text.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SmartGardenApp());
}

class SmartGardenApp extends StatefulWidget {
  const SmartGardenApp({super.key});

  @override
  State<SmartGardenApp> createState() => _SmartGardenAppState();
}

class _SmartGardenAppState extends State<SmartGardenApp> {
  Locale _locale = const Locale('vi');

  void changeLanguage(String code) {
    setState(() {
      _locale = Locale(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
        Locale('ja'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: MainNavigation(onChangeLanguage: changeLanguage),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final Function(String) onChangeLanguage;

  const MainNavigation({super.key, required this.onChangeLanguage});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onChangeLanguage: widget.onChangeLanguage),
      const HistoryChartPage(),
      const WeatherPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: AppText.get("home", lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.show_chart),
            label: AppText.get("chart", lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.wb_sunny_outlined),
            label: AppText.get("weather", lang),
          ),
        ],
      ),
    );
  }
}

class HistoryChartPage extends StatelessWidget {
  const HistoryChartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instance.ref("smartgarden/device1/history");
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(AppText.get("chart", lang))),
      body: StreamBuilder(
        stream: db.limitToLast(20).onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final sortedKeys = data.keys.toList()..sort();

          List<FlSpot> spots = [];
          for (int i = 0; i < sortedKeys.length; i++) {
            final val = data[sortedKeys[i]]['temperature'] ?? 0;
            spots.add(FlSpot(i.toDouble(), val.toDouble()));
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  AppText.get("temperature", lang),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                                final timestamp = sortedKeys[value.toInt()].toString();
                                return Text(
                                  timestamp.substring(timestamp.length - 8, timestamp.length - 3),
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.red,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Map<String, dynamic>? current;
  List<dynamic>? forecast;
  bool loading = true;
  String error = '';

  final String key = '0a4afaf104013452a0b315e0a7e50231';
  final String city = 'Da Nang,VN';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final curRes = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$key&units=metric&lang=vi',
      ));
      if (curRes.statusCode == 200) {
        current = jsonDecode(curRes.body);
      } else {
        throw 'Lỗi thời tiết hiện tại';
      }

      final foreRes = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$key&units=metric&lang=vi',
      ));
      if (foreRes.statusCode == 200) {
        final data = jsonDecode(foreRes.body);
        final list = data['list'] as List;
        final daily = <dynamic>[];
        String? last;
        for (var item in list) {
          final dt = item['dt_txt'].split(' ')[0];
          if (last != dt) {
            daily.add(item);
            last = dt;
            if (daily.length == 3) break;
          }
        }
        forecast = daily;
      } else {
        throw 'Lỗi dự báo';
      }
    } catch (e) {
      error = e.toString();
    }

    setState(() => loading = false);
  }

  IconData icon(String desc) {
    desc = desc.toLowerCase();
    if (desc.contains('mưa')) return Icons.grain;
    if (desc.contains('mây')) return Icons.cloud;
    if (desc.contains('nắng') || desc.contains('quang')) return Icons.wb_sunny;
    return Icons.cloud_queue;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppText.get("weather", lang)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: load,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(child: Text(error, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (current != null) ...[
                          Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(icon(current!['weather'][0]['description']), size: 100, color: Colors.blue[700]),
                                      const SizedBox(width: 24),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${current!['main']['temp'].toStringAsFixed(1)}°C',
                                            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            current!['weather'][0]['description'],
                                            style: TextStyle(fontSize: 24, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Column(
                                        children: [
                                          Icon(Icons.water_drop, color: Colors.blue),
                                          Text('${current!['main']['humidity']}%'),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          Icon(Icons.air, color: Colors.teal),
                                          Text('${current!['wind']['speed']} m/s'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        if (forecast != null && forecast!.isNotEmpty) ...[
                          Text(
                            'Dự báo 3 ngày',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[800]),
                          ),
                          const SizedBox(height: 16),
                          ...forecast!.map((day) {
                            final d = DateTime.fromMillisecondsSinceEpoch(day['dt'] * 1000);
                            final desc = day['weather'][0]['description'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: Icon(icon(desc), size: 48, color: Colors.blue[600]),
                                title: Text(
                                  '${d.day}/${d.month} - $desc',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                                ),
                                subtitle: Text(
                                  'Min ${day['main']['temp_min'].toStringAsFixed(1)}°C - Max ${day['main']['temp_max'].toStringAsFixed(1)}°C',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}