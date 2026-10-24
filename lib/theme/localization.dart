class AppLocalizations {
  static String currentLang = 'en'; // 'en' or 'ms'

  static bool get isMs => currentLang == 'ms';

  static void setLocale(String lang) {
    currentLang = lang;
  }

  static String get(String key) {
    final en = _strings['en'] ?? {};
    final ms = _strings['ms'] ?? {};
    if (currentLang == 'ms') {
      return ms[key] ?? en[key] ?? key;
    }
    return en[key] ?? key;
  }

  static final Map<String, Map<String, String>> _strings = {
    'en': {
      'app_title': 'DashMate Deck',
      'apps': 'Apps',
      'car_screen': 'Car Screen',
      'settings': 'Settings',
      'browse': 'Browse',
      'parking': 'Parking',
      'calendar': 'Calendar',
      'lyrics': 'Lyrics',
      'prayer': 'Waktu Solat',
      'custom_page': 'Custom Card',
      'car_card': 'Split-Screen Car Card',
      'floating_menu': 'Floating Menu',
      'language': 'Language',
      'english': 'English',
      'malay': 'Bahasa Melayu',
      'weather_radar': 'Weather & Radar',
      'air_quality': 'Air Quality',
      'parked_at': 'Parked Spot',
      'save_spot': 'Save Current Spot',
      'clear_spot': 'Clear Spot',
      'navigate_car': 'Navigate to Car',
      'level': 'Level / Floor',
      'bay': 'Bay Number',
      'notes': 'Notes / Pillar',
      'parked_since': 'Parked Since',
      'quick_links': 'Quick Links',
      'youtube': 'YouTube',
      'rtm_klik': 'RTM Klik',
      'google': 'Google',
      'search_url': 'Enter URL or Search...',
      'upcoming_events': 'Upcoming Events (7 Days)',
      'no_events': 'No events scheduled for this week',
      'cal_permission': 'Calendar access granted',
      'cal_grant': 'Sync System Calendar',
      'good': 'Good',
      'moderate': 'Moderate',
      'sensitive': 'Sensitive',
      'unhealthy': 'Unhealthy',
    },
    'ms': {
      'app_title': 'DashMate Dek',
      'apps': 'Aplikasi',
      'car_screen': 'Skrin Kenderaan',
      'settings': 'Tetapan',
      'browse': 'Pelayar Web',
      'parking': 'Parkir',
      'calendar': 'Kalendar',
      'lyrics': 'Lirik Lagu',
      'prayer': 'Waktu Solat',
      'custom_page': 'Kad Khas',
      'car_card': 'Kad Skrin Pisah Auto',
      'floating_menu': 'Menu Terapung',
      'language': 'Bahasa',
      'english': 'English',
      'malay': 'Bahasa Melayu',
      'weather_radar': 'Cuaca & Radar',
      'air_quality': 'Kualiti Udara',
      'parked_at': 'Lokasi Parkir',
      'save_spot': 'Simpan Lokasi Semasa',
      'clear_spot': 'Kosongkan Lokasi',
      'navigate_car': 'Pandu Arah ke Kereta',
      'level': 'Aras / Tingkat',
      'bay': 'Nombor Petak (Bay)',
      'notes': 'Catatan / Tiang',
      'parked_since': 'Diparkir Sejak',
      'quick_links': 'Pautan Pantas',
      'youtube': 'YouTube',
      'rtm_klik': 'RTM Klik',
      'google': 'Google',
      'search_url': 'Masukkan URL atau Carian...',
      'upcoming_events': 'Acara Mendatang (7 Hari)',
      'no_events': 'Tiada acara dijadualkan minggu ini',
      'cal_permission': 'Akses kalendar dibenarkan',
      'cal_grant': 'Segerakkan Kalendar Telefon',
      'good': 'Baik',
      'moderate': 'Sederhana',
      'sensitive': 'Sensitif',
      'unhealthy': 'Tidak Sihat',
    }
  };
}
