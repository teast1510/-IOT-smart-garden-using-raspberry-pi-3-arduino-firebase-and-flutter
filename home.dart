import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_text.dart';

class HomePage extends StatefulWidget {
  final Function(String)? onChangeLanguage;

  const HomePage({super.key, this.onChangeLanguage});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final db = FirebaseDatabase.instance.ref();

  int mode = 0;
  int pump = 0;
  int motor = 0;
  double temperature = 0;
  double humidity = 0;
  int waterLevel = 0;

  bool isOnline = false;
  DateTime? lastUpdate;
  Timer? _statusTimer;

  bool _isLoading = false;
  String _loadingMessage = "Đang cập nhật...";

  @override
  void initState() {
    super.initState();
    listenData();

    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (lastUpdate != null && mounted) {
        final diff = DateTime.now().difference(lastUpdate!).inSeconds;
        if (diff > 15) {
          setState(() => isOnline = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void listenData() {
    db.child("smartgarden/device1/latest").onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null || !mounted) return;

      setState(() {
        temperature = (data["temperature"] ?? 0).toDouble();
        humidity = (data["humidity"] ?? 0).toDouble();
        waterLevel = (data["waterLevel"] ?? 0).toInt();
        pump = (data["pumpState"] ?? 0).toInt();
        motor = (data["motorState"] ?? 0).toInt();
        mode = (data["mode"] ?? 0).toInt();

        lastUpdate = DateTime.now();
        isOnline = true;
      });
    });
  }

  void sendCommand(String path, int value) {
    db.child("smartgarden/device1/control/$path").set(value);
  }

  Future<void> _sendWithLoading(String path, int value, String message) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });

    sendCommand(path, value);

    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật chậm hoặc lỗi mạng.")),
        );
      }
    });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
    }
    timeoutTimer.cancel();
  }

  Widget sensorCard(String title, String value, IconData icon, Color statusColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: statusColor),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    final bool canChangeMode = isOnline && !_isLoading;
    final bool canControlDevices = isOnline && !_isLoading && mode == 1;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 240, 242),
      appBar: AppBar(
        title: const Text("Smart Garden"),
        centerTitle: true,
        actions: [
          IconButton(icon: const Text("🇻🇳", style: TextStyle(fontSize: 20)), onPressed: () => widget.onChangeLanguage?.call("vi")),
          IconButton(icon: const Text("🇬🇧", style: TextStyle(fontSize: 20)), onPressed: () => widget.onChangeLanguage?.call("en")),
          IconButton(icon: const Text("🇯🇵", style: TextStyle(fontSize: 20)), onPressed: () => widget.onChangeLanguage?.call("ja")),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: isOnline ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isOnline ? Icons.cloud_done : Icons.cloud_off, color: isOnline ? Colors.green : Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? AppText.get("online", lang) : AppText.get("offline", lang),
                        style: TextStyle(color: isOnline ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          sensorCard(AppText.get("temperature", lang), "$temperature °C", Icons.thermostat, Colors.red),
                          sensorCard(AppText.get("humidity", lang), "$humidity %", Icons.water_drop, Colors.blue),
                        ],
                      ),
                      Row(
                        children: [
                          sensorCard(AppText.get("waterLevel", lang), "$waterLevel ml", Icons.waves, Colors.cyan),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.settings, color: mode == 1 ? Colors.orange : Colors.green, size: 32),
                        title: Text(
                          mode == 1 ? AppText.get("manual", lang) : AppText.get("auto", lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Switch(
                          value: mode == 1,
                          activeColor: Colors.orange,
                          onChanged: canChangeMode ? (v) => _sendWithLoading("mode", v ? 1 : 0, "Đang chuyển chế độ...") : null,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.water, color: pump == 1 ? Colors.blue : Colors.grey, size: 32),
                        title: Text(
                          "${AppText.get("pump", lang)}: ${pump == 1 ? AppText.get("on", lang) : AppText.get("off", lang)}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: Switch(
                          value: pump == 1,
                          activeColor: Colors.blue,
                          onChanged: canControlDevices ? (v) => _sendWithLoading("pump", v ? 1 : 0, "Đang cập nhật bơm...") : null,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.air, color: motor == 1 ? Colors.teal : Colors.grey, size: 32),
                        title: Text(
                          "${AppText.get("motor", lang)}: ${motor == 1 ? AppText.get("on", lang) : AppText.get("off", lang)}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: Switch(
                          value: motor == 1,
                          activeColor: Colors.teal,
                          onChanged: canControlDevices ? (v) => _sendWithLoading("motor", v ? 1 : 0, "Đang cập nhật quạt...") : null,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white.withOpacity(0.95),
              child: const Center(
                child: Text(
                  "© Copyright by protocolhexad",
                  style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(_loadingMessage, style: const TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}