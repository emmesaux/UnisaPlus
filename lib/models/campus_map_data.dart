import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CampusRoomPin {
  final String id;
  final String name;
  final String code;
  final String capacity;
  final double? coordX;
  final double? coordY;
  final String type;

  const CampusRoomPin({
    required this.id,
    required this.name,
    required this.code,
    required this.capacity,
    this.coordX,
    this.coordY,
    required this.type,
  });

  bool get hasCoordinates => coordX != null && coordY != null;

  factory CampusRoomPin.fromJson(Map<String, dynamic> json) {
    return CampusRoomPin(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      capacity: json['capacity']?.toString() ?? '',
      coordX: (json['coordX'] as num?)?.toDouble(),
      coordY: (json['coordY'] as num?)?.toDouble(),
      type: json['type']?.toString() ?? '',
    );
  }
}

class CampusFloorData {
  final String floorLabel;
  final String mapImage;
  final List<CampusRoomPin> rooms;

  const CampusFloorData({
    required this.floorLabel,
    required this.mapImage,
    required this.rooms,
  });

  bool get hasMapImage => mapImage.isNotEmpty;

  /// URL reale su EasyRoom del file mappa
  String get fullImageUrl =>
      'https://easycourse.unisa.it/EasyRoom/$mapImage';

  factory CampusFloorData.fromJson(Map<String, dynamic> json) {
    final list = (json['rooms'] as List<dynamic>? ?? [])
        .map((r) => CampusRoomPin.fromJson(r as Map<String, dynamic>))
        .toList();
    return CampusFloorData(
      floorLabel: json['floor_label']?.toString() ?? 'Piano',
      mapImage: json['map_image']?.toString() ?? '',
      rooms: list,
    );
  }
}

class CampusBuildingData {
  final String name;
  final String areaCode;
  final String campus;
  final String address;
  final List<CampusFloorData> floors;

  const CampusBuildingData({
    required this.name,
    required this.areaCode,
    required this.campus,
    required this.address,
    required this.floors,
  });

  int get totalRooms =>
      floors.fold(0, (sum, f) => sum + f.rooms.length);

  factory CampusBuildingData.fromJson(Map<String, dynamic> json) {
    final floorList = (json['floors'] as List<dynamic>? ?? [])
        .map((f) => CampusFloorData.fromJson(f as Map<String, dynamic>))
        .toList();
    return CampusBuildingData(
      name: json['name']?.toString() ?? '',
      areaCode: json['area_code']?.toString() ?? '',
      campus: json['campus']?.toString() ?? 'fisciano',
      address: json['address']?.toString() ?? '',
      floors: floorList,
    );
  }
}

class CampusMapRepository {
  CampusMapRepository._();
  static final CampusMapRepository instance = CampusMapRepository._();

  Map<String, CampusBuildingData>? _cache;

  Future<Map<String, CampusBuildingData>> getBuildings() async {
    if (_cache != null) return _cache!;
    try {
      final raw =
          await rootBundle.loadString('assets/campus_easyrooms.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <String, CampusBuildingData>{};
      for (final entry in decoded.entries) {
        map[entry.key] = CampusBuildingData.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
      _cache = map;
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Cerca l'edificio corrispondente a un codice (es. "Edificio F", "Edificio B", "Campus Baronissi")
  Future<CampusBuildingData?> findBuilding(String query) async {
    final all = await getBuildings();
    final q = query.toLowerCase().trim();
    for (final entry in all.entries) {
      final k = entry.key.toLowerCase();
      if (k == q || k.contains(q) || q.contains(k)) {
        return entry.value;
      }
    }
    return null;
  }
}

