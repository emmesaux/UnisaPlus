import 'package:flutter/material.dart';
import '../models/aula.dart';
import '../models/campus_map_data.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dettaglio_aula_sheet.dart';

/// Schermo con la planimetria dell'edificio e le aule interattive e cliccabili.
/// Riprende fedelmente l'esperienza di EasyMap con le mappe di piano e la
/// disponibilità delle aule in tempo reale.
class EdificioMapScreen extends StatefulWidget {
  const EdificioMapScreen({
    super.key,
    required this.building,
    this.api,
    this.initialFloorIndex = 0,
  });

  final CampusBuildingData building;
  final ApiService? api;
  final int initialFloorIndex;

  @override
  State<EdificioMapScreen> createState() => _EdificioMapScreenState();
}

class _EdificioMapScreenState extends State<EdificioMapScreen> {
  late int _selectedFloorIndex;
  final TransformationController _transCtrl = TransformationController();
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, AulaConOrario> _liveAule = {};
  bool _isLoadingLive = false;
  String _filtroAula = '';

  // Dimensioni standard delle planimetrie EasyRoom (A4 landscape)
  static const double _mapWidth = 1653.0;
  static const double _mapHeight = 1169.0;

  @override
  void initState() {
    super.initState();
    _selectedFloorIndex = widget.initialFloorIndex.clamp(
      0,
      widget.building.floors.isEmpty ? 0 : widget.building.floors.length - 1,
    );
    _caricaAuleLive();
  }

  @override
  void dispose() {
    _transCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _caricaAuleLive() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _isLoadingLive = true);
    try {
      final auleList = await api.getAuleLibere();
      final map = <String, AulaConOrario>{};
      for (final ed in auleList) {
        for (final a in ed.aule) {
          map[a.id] = a;
          map[a.nome.toLowerCase().trim()] = a;
        }
      }
      if (mounted) {
        setState(() {
          _liveAule = map;
          _isLoadingLive = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLive = false);
      }
    }
  }

  AulaConOrario _trovaAula(CampusRoomPin pin) {
    // Cerca prima per id esatto
    if (_liveAule.containsKey(pin.id)) {
      return _liveAule[pin.id]!;
    }
    // Poi per nome
    final nomeLower = pin.name.toLowerCase().trim();
    if (_liveAule.containsKey(nomeLower)) {
      return _liveAule[nomeLower]!;
    }
    // Altrimenti genera modello aula sintetico con disponibilità base
    return AulaConOrario(
      id: pin.id,
      nome: pin.name,
      capacity: pin.capacity.isNotEmpty ? pin.capacity : null,
      coordX: pin.coordX,
      coordY: pin.coordY,
      lezioni: const [],
    );
  }

  void _apriDettaglioAula(CampusRoomPin pin) {
    final aula = _trovaAula(pin);
    DettaglioAulaSheet.mostra(
      context,
      nomeEdificio: widget.building.name,
      aula: aula,
    );
  }

  void _resetZoom() {
    _transCtrl.value = Matrix4.identity();
  }

  void _zoomIn() {
    final current = _transCtrl.value.getMaxScaleOnAxis();
    final newScale = (current * 1.3).clamp(0.5, 4.0);
    _transCtrl.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
  }

  void _zoomOut() {
    final current = _transCtrl.value.getMaxScaleOnAxis();
    final newScale = (current / 1.3).clamp(0.5, 4.0);
    _transCtrl.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final floors = widget.building.floors;
    final currentFloor = floors.isNotEmpty && _selectedFloorIndex < floors.length
        ? floors[_selectedFloorIndex]
        : null;

    final roomsOnFloor = currentFloor?.rooms ?? [];
    final roomsFiltered = roomsOnFloor.where((r) {
      if (_filtroAula.isEmpty) return true;
      final q = _filtroAula.toLowerCase();
      return r.name.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.building.name, style: const TextStyle(fontSize: 16)),
            Text(
              widget.building.address.isNotEmpty
                  ? widget.building.address
                  : 'Mappa edificio e aule',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoadingLive)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Aggiorna orari aule',
              onPressed: _caricaAuleLive,
            ),
        ],
      ),
      body: Column(
        children: [
          // Selettore Piani (se più di 1 piano)
          if (floors.length > 1)
            Container(
              height: 48,
              color: scheme.surface,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: floors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final floor = floors[idx];
                  final isSelected = idx == _selectedFloorIndex;
                  return ChoiceChip(
                    label: Text(
                      '${floor.floorLabel} (${floor.rooms.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedFloorIndex = idx;
                          _resetZoom();
                        });
                      }
                    },
                  );
                },
              ),
            ),

          // Area Planimetria Interattiva
          Expanded(
            child: currentFloor == null || !currentFloor.hasMapImage
                ? _buildNessunaMappa(scheme, roomsFiltered)
                : Stack(
                    children: [
                      // Canvas con la mappa e i pin cliccabili
                      InteractiveViewer(
                        transformationController: _transCtrl,
                        minScale: 0.2,
                        maxScale: 4.5,
                        boundaryMargin: const EdgeInsets.all(300),
                        child: Center(
                          child: SizedBox(
                            width: _mapWidth,
                            height: _mapHeight,
                            child: Stack(
                              children: [
                                // Immagine reale della planimetria EasyRoom
                                Positioned.fill(
                                  child: Image.network(
                                    currentFloor.fullImageUrl,
                                    fit: BoxFit.fill,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: scheme.surfaceContainerHighest,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Caricamento planimetria EasyRoom...',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, err, stack) {
                                      return Container(
                                        color: scheme.surfaceContainerHighest,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.map_outlined,
                                                size: 64,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Planimetria temporaneamente non disponibile dal server.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // Pin cliccabili di ciascuna aula
                                for (final pin in currentFloor.rooms)
                                  if (pin.hasCoordinates)
                                    _buildRoomPin(pin, scheme),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Controlli Zoom galleggianti
                      Positioned(
                        right: 16,
                        bottom: 96,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'zoom_in_edificio',
                              onPressed: _zoomIn,
                              tooltip: 'Ingrandisci',
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom_out_edificio',
                              onPressed: _zoomOut,
                              tooltip: 'Rimpicciolisci',
                              child: const Icon(Icons.remove),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom_reset_edificio',
                              onPressed: _resetZoom,
                              tooltip: 'Reimposta vista',
                              child: const Icon(Icons.center_focus_strong),
                            ),
                          ],
                        ),
                      ),

                      // Legenda floating in alto a sinistra
                      Positioned(
                        left: 16,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: scheme.outlineVariant),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _DotLegenda(color: Color(0xFF2E7D5B), label: 'Libera'),
                              SizedBox(width: 10),
                              _DotLegenda(color: AppColors.corallo, label: 'In corso'),
                            ],
                          ),
                        ),
                      ),

                      // Barra inferiore espandibile con lista rapida aule del piano
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildElencoRapidoAule(
                          scheme,
                          roomsFiltered,
                          currentFloor.floorLabel,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomPin(CampusRoomPin pin, ColorScheme scheme) {
    final aula = _trovaAula(pin);
    final now = DateTime.now();
    final bool isLibera = aula.liberaOra(now);
    final Color badgeColor =
        isLibera ? const Color(0xFF2E7D5B) : AppColors.corallo;

    // Coordinate esatte (pixel su canvas 1653x1169)
    final double left = pin.coordX! - 42;
    final double top = pin.coordY! - 18;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _apriDettaglioAula(pin),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                pin.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElencoRapidoAule(
    ColorScheme scheme,
    List<CampusRoomPin> rooms,
    String floorName,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(Icons.meeting_room_outlined, color: scheme.primary),
        title: Text(
          'Aule $floorName (${rooms.length})',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Tocca per orario, capienza e fasce libere',
          style: TextStyle(fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Filtra aula per nome o codice...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon: _filtroAula.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filtroAula = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _filtroAula = v.trim()),
            ),
          ),
          SizedBox(
            height: 180,
            child: rooms.isEmpty
                ? const Center(
                    child: Text('Nessuna aula trovata con questo filtro.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    itemCount: rooms.length,
                    itemBuilder: (context, idx) {
                      final r = rooms[idx];
                      final aula = _trovaAula(r);
                      final isLibera = aula.liberaOra(DateTime.now());
                      final color = isLibera
                          ? const Color(0xFF2E7D5B)
                          : AppColors.corallo;

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 5,
                          backgroundColor: color,
                        ),
                        title: Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          r.capacity.isNotEmpty
                              ? 'Capienza: ${r.capacity} posti'
                              : r.code,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLibera ? 'LIBERA' : 'IN CORSO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                        onTap: () => _apriDettaglioAula(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNessunaMappa(ColorScheme scheme, List<CampusRoomPin> rooms) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Nessuna planimetria grafica disponibile per questo piano.',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Puoi consultare le aule dell\'edificio direttamente dall\'elenco:',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (ctx, idx) {
                  final r = rooms[idx];
                  return Card(
                    child: ListTile(
                      title: Text(r.name),
                      subtitle: Text(r.code),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _apriDettaglioAula(r),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotLegenda extends StatelessWidget {
  const _DotLegenda({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
