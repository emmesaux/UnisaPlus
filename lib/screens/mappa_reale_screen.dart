import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/campus_map_data.dart';
import '../models/edificio_geo.dart';
import '../services/api_service.dart';
import '../widgets/app_segmented.dart';
import 'edificio_map_screen.dart';
import 'mensa_menu_screen.dart';
import 'mappa_campus_screen.dart' show CategoriaPunto;

/// I tre poli con mappa reale.
enum PoloMappa { fisciano, baronissi, ruggi }

/// Portale ufficiale delle biblioteche di Ateneo (orari, servizi e
/// prenotazione posti/sale studio).
const String _urlBibliotecheUnisa = 'https://www.biblioteche.unisa.it/';

/// Mappa reale (tile OpenStreetMap) dei poli UNISA: ogni edificio è evidenziato
/// con il suo footprint reale ed è cliccabile per aprire le aule/planimetrie
/// (come EasyMap). Mense e biblioteche portano a menù e prenotazione.
class MappaRealeScreen extends StatefulWidget {
  const MappaRealeScreen({super.key, this.api});
  final ApiService? api;

  @override
  State<MappaRealeScreen> createState() => _MappaRealeScreenState();
}

class _MappaRealeScreenState extends State<MappaRealeScreen> {
  final MapController _map = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final LayerHitNotifier<EdificioGeo> _hitNotifier = ValueNotifier(null);

  PoloMappa _polo = PoloMappa.fisciano;
  Map<String, CampusBuildingData> _datiEasyRoom = {};
  List<EdificioGeo> _edifici = const [];
  String _query = '';
  CategoriaPunto _categoria = CategoriaPunto.tutti;

  static const _centri = {
    PoloMappa.fisciano: (LatLng(40.77205, 14.79090), 16.3),
    PoloMappa.baronissi: (LatLng(40.75590, 14.78110), 17.2),
    PoloMappa.ruggi: (LatLng(40.648909, 14.828711), 17.2),
  };

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    final risultati = await Future.wait([
      CampusMapRepository.instance.getBuildings(),
      EdificiGeoRepository.instance.getAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _datiEasyRoom = risultati[0] as Map<String, CampusBuildingData>;
      _edifici = risultati[1] as List<EdificioGeo>;
    });
  }

  String get _poloKey => _polo.name;

  /// Edifici del polo selezionato, filtrati per categoria.
  List<EdificioGeo> get _edificiPolo {
    return _edifici.where((e) {
      if (e.polo != _poloKey) return false;
      if (_categoria != CategoriaPunto.tutti &&
          e.categoria != _categoria.name) {
        return false;
      }
      return true;
    }).toList();
  }

  List<EdificioGeo> get _risultati {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _edifici
        .where((e) =>
            e.polo == _poloKey &&
            (e.codice.toLowerCase().contains(q) ||
                e.nome.toLowerCase().contains(q)))
        .take(8)
        .toList();
  }

  void _vaiAlPolo(PoloMappa polo) {
    setState(() => _polo = polo);
    final (centro, zoom) = _centri[polo]!;
    _map.move(centro, zoom);
  }

  void _zoom(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(12.0, 19.0));
  }

  void _selezionaRisultato(EdificioGeo ed) {
    FocusScope.of(context).unfocus();
    setState(() {
      _query = '';
      _searchCtrl.clear();
    });
    _map.move(ed.centro, 18.5);
    _apri(ed);
  }

  CampusBuildingData? _buildingDi(EdificioGeo ed) =>
      ed.easyRoomKey.isEmpty ? null : _datiEasyRoom[ed.easyRoomKey];

  void _apri(EdificioGeo ed) {
    final building = _buildingDi(ed);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration:
                          BoxDecoration(color: ed.colore, shape: BoxShape.circle),
                      child: Icon(ed.icona, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ed.codice.length <= 3
                                ? 'Edificio ${ed.codice}'
                                : ed.codice,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          if (ed.nome != ed.codice)
                            Text(
                              ed.nome,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13, color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (ed.isMensa)
                  _AzioneSheet(
                    icona: Icons.restaurant_menu,
                    label: 'Vedi il menù (pranzo e cena)',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            MensaMenuScreen(titolo: 'Menù · ${ed.codice}'),
                      ));
                    },
                  )
                else if (ed.isBiblioteca)
                  _AzioneSheet(
                    icona: Icons.event_seat_outlined,
                    label: 'Prenota il posto / Biblioteche UNISA',
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await launchUrl(Uri.parse(_urlBibliotecheUnisa),
                          mode: LaunchMode.externalApplication);
                    },
                  )
                else if (building != null)
                  _AzioneSheet(
                    icona: Icons.meeting_room_outlined,
                    label: 'Vedi le aule (${building.totalRooms})',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EdificioMapScreen(
                            building: building, api: widget.api),
                      ));
                    },
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Planimetrie delle aule non ancora disponibili per questo edificio.',
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (centro, zoom) = _centri[_polo]!;
    final edifici = _edificiPolo;
    return Scaffold(
      appBar: AppBar(title: const Text('Mappa dei Campus')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: AppSegmented<PoloMappa>(
              value: _polo,
              onChanged: _vaiAlPolo,
              segments: const [
                AppSegment(value: PoloMappa.fisciano, label: 'Fisciano', icon: Icons.school),
                AppSegment(value: PoloMappa.baronissi, label: 'Baronissi', icon: Icons.local_hospital_outlined),
                AppSegment(value: PoloMappa.ruggi, label: 'Ruggi', icon: Icons.medical_services_outlined),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cerca edificio, aula, biblioteca…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _query = '';
                            _searchCtrl.clear();
                          });
                        },
                      ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              children: [
                for (final cat in CategoriaPunto.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(cat.label),
                      avatar: Icon(cat.icon, size: 16),
                      selected: _categoria == cat,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _categoria = cat),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    final hit = _hitNotifier.value;
                    if (hit != null && hit.hitValues.isNotEmpty) {
                      _apri(hit.hitValues.first);
                    }
                  },
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: centro,
                      initialZoom: zoom,
                      minZoom: 12,
                      maxZoom: 19,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'it.unisaplus.app',
                        maxZoom: 19,
                        tileBuilder: dark ? darkModeTileBuilder : null,
                      ),
                      // Footprint evidenziati e cliccabili.
                      PolygonLayer<EdificioGeo>(
                        hitNotifier: _hitNotifier,
                        polygons: [
                          for (final ed in edifici)
                            Polygon<EdificioGeo>(
                              points: ed.poligono,
                              hitValue: ed,
                              color: ed.colore.withValues(alpha: 0.42),
                              borderColor: ed.colore,
                              borderStrokeWidth: 2,
                            ),
                        ],
                      ),
                      // Etichette al centro di ogni edificio (anch'esse toccabili).
                      MarkerLayer(
                        markers: [
                          for (final ed in edifici)
                            Marker(
                              point: ed.centro,
                              width: 70,
                              height: 24,
                              alignment: Alignment.center,
                              child: _Etichetta(
                                  edificio: ed, onTap: () => _apri(ed)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pulsanti zoom / ricentra in basso a destra.
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: Column(
                    children: [
                      _MapBtn(icon: Icons.add, tooltip: 'Ingrandisci', onTap: () => _zoom(1)),
                      const SizedBox(height: 10),
                      _MapBtn(icon: Icons.remove, tooltip: 'Rimpicciolisci', onTap: () => _zoom(-1)),
                      const SizedBox(height: 10),
                      _MapBtn(
                        icon: Icons.center_focus_strong,
                        tooltip: 'Ricentra sul campus',
                        onTap: () => _vaiAlPolo(_polo),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  left: 6,
                  bottom: 4,
                  child: Container(
                    color: scheme.surface.withValues(alpha: 0.7),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('© OpenStreetMap',
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                  ),
                ),

                if (_query.trim().isEmpty)
                  const Positioned(
                    left: 16,
                    top: 10,
                    child: _PillInfo(testo: 'Tocca un edificio per le aule'),
                  ),

                if (_risultati.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 8,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(14),
                      color: scheme.surface,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final ed in _risultati)
                              ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: ed.colore,
                                  child: Icon(ed.icona,
                                      size: 16, color: Colors.white),
                                ),
                                title: Text(
                                  ed.codice.length <= 3
                                      ? 'Edificio ${ed.codice}'
                                      : ed.codice,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Text(ed.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)),
                                onTap: () => _selezionaRisultato(ed),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etichetta compatta col codice dell'edificio, posata al centro del footprint.
class _Etichetta extends StatelessWidget {
  const _Etichetta({required this.edificio, required this.onTap});
  final EdificioGeo edificio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: edificio.colore,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.3),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Text(
          edificio.codice,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

/// Pulsante azione a larghezza piena nella scheda edificio.
class _AzioneSheet extends StatelessWidget {
  const _AzioneSheet(
      {required this.icona, required this.label, required this.onTap});
  final IconData icona;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icona),
        label: Text(label),
      ),
    );
  }
}

/// Pulsante circolare per i controlli mappa (zoom / ricentra).
class _MapBtn extends StatelessWidget {
  const _MapBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 3,
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            child: Icon(icon, color: scheme.primary, size: 24),
          ),
        ),
      ),
    );
  }
}

class _PillInfo extends StatelessWidget {
  const _PillInfo({required this.testo});
  final String testo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 14, color: scheme.primary),
          const SizedBox(width: 5),
          Text(testo,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
        ],
      ),
    );
  }
}
