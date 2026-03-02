class AppText {
  static Map<String, Map<String, String>> data = {
    "vi": {
      "home": "Trang chủ",
      "chart": "Đồ thị",
      "weather": "Thời tiết",
      "online": "Thiết bị trực tuyến",
      "offline": "Arduino mất kết nối!",
      "temperature": "Nhiệt độ",
      "humidity": "Độ ẩm",
      "waterLevel": "Mực nước",
      "manual": "CHẾ ĐỘ TAY",
      "auto": "CHẾ ĐỘ TỰ ĐỘNG",
      "pump": "BƠM NƯỚC",
      "motor": "QUẠT / MOTOR",
      "on": "BẬT",
      "off": "TẮT",
    },
    "en": {
      "home": "Home",
      "chart": "Chart",
      "weather": "Weather",
      "online": "Device Online",
      "offline": "Arduino disconnected!",
      "temperature": "Temperature",
      "humidity": "Humidity",
      "waterLevel": "Water Level",
      "manual": "MANUAL MODE",
      "auto": "AUTO MODE",
      "pump": "WATER PUMP",
      "motor": "FAN / MOTOR",
      "on": "ON",
      "off": "OFF",
    },
    "ja": {
      "home": "ホーム",
      "chart": "グラフ",
      "weather": "天気",
      "online": "デバイス接続中",
      "offline": "Arduino 切断",
      "temperature": "温度",
      "humidity": "湿度",
      "waterLevel": "水位",
      "manual": "手動モード",
      "auto": "自動モード",
      "pump": "水ポンプ",
      "motor": "ファン / モーター",
      "on": "オン",
      "off": "オフ",
    },
  };

  static String get(String key, String langCode) {
    return data[langCode]?[key] ?? key;
  }
}