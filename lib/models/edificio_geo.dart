import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// Edificio dell'ateneo con il suo footprint reale (poligono OSM), usato per
/// evidenziare e rendere cliccabile ogni blocco sulla mappa reale.
class EdificioGeo {
  EdificioGeo({
    required this.codice,
    required this.nome,
    required this.categoria,
    required this.easyRoomKey,
    required this.polo,
    required this.poligono,
  }) : centro = _centroide(poligono);

  /// Etichetta breve (es. "F1", "C2", "Mensa").
  final String codice;

  /// Nome completo OSM.
  final String nome;

  /// Categoria: didattica, biblioteca, ristoro, sport, trasporti, residenze,
  /// servizi.
  final String categoria;

  /// Chiave del blocco in `campus_easyrooms.json` per aprire la planimetria
  /// (vuota se non ci sono planimetrie).
  final String easyRoomKey;

  /// 'fisciano' | 'baronissi' | 'ruggi'.
  final String polo;

  /// Vertici del footprint.
  final List<LatLng> poligono;

  /// Centro geometrico (per posizionare l'etichetta).
  final LatLng centro;

  bool get isMensa => categoria == 'ristoro';
  bool get isBiblioteca => categoria == 'biblioteca';
  bool get haPlanimetrie => easyRoomKey.isNotEmpty;

  /// Colore dell'edificio: per i blocchi didattici segue la lettera (come la
  /// mappa storica), altrimenti la categoria.
  Color get colore {
    final l = codice.isNotEmpty ? codice[0].toUpperCase() : '';
    const perLettera = {
      'A': Color(0xFFE8A33D),
      'B': Color(0xFF1B5259),
      'C': Color(0xFF1B5259),
      'D': Color(0xFF012158),
      'E': Color(0xFF2E7D5B),
      'F': Color(0xFFA3021F),
    };
    if (categoria == 'didattica' && perLettera.containsKey(l)) {
      return perLettera[l]!;
    }
    switch (categoria) {
      case 'biblioteca':
        return const Color(0xFF012158);
      case 'ristoro':
        return const Color(0xFFE8A33D);
      case 'sport':
        return const Color(0xFF2E7D5B);
      case 'trasporti':
        return const Color(0xFF012158);
      case 'residenze':
        return const Color(0xFF1B5259);
      case 'servizi':
        return const Color(0xFF7B5EA7);
      default:
        return AppColors.mare;
    }
  }

  IconData get icona {
    switch (categoria) {
      case 'biblioteca':
        return Icons.local_library_outlined;
      case 'ristoro':
        return Icons.restaurant;
      case 'sport':
        return Icons.fitness_center;
      case 'trasporti':
        return Icons.directions_bus;
      case 'residenze':
        return Icons.apartment_outlined;
      case 'servizi':
        return Icons.storefront_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  factory EdificioGeo.fromJson(Map<String, dynamic> j) {
    final pts = (j['poly'] as List)
        .map((p) => LatLng(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ))
        .toList();
    return EdificioGeo(
      codice: j['codice']?.toString() ?? '',
      nome: j['nome']?.toString() ?? '',
      categoria: j['cat']?.toString() ?? 'didattica',
      easyRoomKey: j['easyroom']?.toString() ?? '',
      polo: j['polo']?.toString() ?? 'fisciano',
      poligono: pts,
    );
  }

  static LatLng _centroide(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(40.772, 14.790);
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }
}

/// Carica (una sola volta) i footprint degli edifici dall'asset.
class EdificiGeoRepository {
  EdificiGeoRepository._();
  static final EdificiGeoRepository instance = EdificiGeoRepository._();

  List<EdificioGeo>? _cache;

  Future<List<EdificioGeo>> getAll() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/campus_edifici_geo.json');
      final list = (jsonDecode(raw) as List)
          .map((e) => EdificioGeo.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache = list;
      return list;
    } catch (_) {
      return const [];
    }
  }
}
