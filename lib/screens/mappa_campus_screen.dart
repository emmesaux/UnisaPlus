import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/campus_map_data.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'edificio_map_screen.dart';

enum TipoCampus {
  fisciano('Campus di Fisciano', 'Sede Principale', Icons.domain),
  baronissi('Campus di Baronissi', 'Polo Biomedico', Icons.local_hospital_outlined);

  const TipoCampus(this.titolo, this.sottotitolo, this.icona);
  final String titolo;
  final String sottotitolo;
  final IconData icona;
}

enum CategoriaPunto {
  tutti('Tutti', Icons.apps_outlined),
  didattica('Didattica', Icons.school_outlined),
  biblioteca('Biblioteche', Icons.menu_book_outlined),
  ristoro('Mense', Icons.restaurant_outlined),
  sport('CUS & Sport', Icons.sports_tennis_outlined),
  trasporti('Trasporti', Icons.directions_bus_outlined),
  residenze('Residenze', Icons.home_work_outlined),
  servizi('Servizi', Icons.storefront_outlined);

  const CategoriaPunto(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Modello geometrico per i blocchi degli edifici sulla mappa schematica 2D.
class EdificioSchematico {
  final String id;
  final String codice;
  final String nome;
  final String dipartimento;
  final String descrizione;
  final TipoCampus campus;
  final CategoriaPunto categoria;
  final Color colore;
  final IconData icona;
  final Rect rettangolo;
  final double latitudine;
  final double longitudine;
  final List<String> areeEasyRoom;

  const EdificioSchematico({
    required this.id,
    required this.codice,
    required this.nome,
    required this.dipartimento,
    required this.descrizione,
    required this.campus,
    required this.categoria,
    required this.colore,
    required this.icona,
    required this.rettangolo,
    required this.latitudine,
    required this.longitudine,
    this.areeEasyRoom = const [],
  });

  bool get haPlanimetrie => areeEasyRoom.isNotEmpty;
}

/// Coordinate e sagome geometriche schematiche degli edifici (Fisciano e Baronissi).
/// Rispecchiano le reali posizioni relative e la disposizione dei campus UNISA.
const List<EdificioSchematico> kEdificiSchematici = [
  // ================= FISCIANO (Canvas 1000 x 900) =================
  // OVEST: Terminal Bus
  EdificioSchematico(
    id: 'fisc_terminal',
    codice: 'Terminal Bus',
    nome: 'Terminal Bus Fisciano',
    dipartimento: 'Ingresso Ovest · Capolinea e fermate autobus',
    descrizione:
        'Principale nodo di arrivo e partenza autobus da e per Salerno, Napoli, Avellino, Caserta e Benevento.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.trasporti,
    colore: Color(0xFF012158),
    icona: Icons.directions_bus,
    rettangolo: Rect.fromLTWH(40, 200, 110, 160),
    latitudine: 40.7752,
    longitudine: 14.7878,
  ),

  // Piazza del Sapere & Servizi
  EdificioSchematico(
    id: 'fisc_piazza',
    codice: 'Centro Servizi',
    nome: 'Piazza del Sapere & Servizi',
    dipartimento: 'Cuore del Campus · Servizi agli studenti',
    descrizione:
        'Ufficio Postale, Sportello Bancomat, Farmacia Universitaria, Libreria e Centro Stampa.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.servizi,
    colore: Color(0xFF012158),
    icona: Icons.local_convenience_store_outlined,
    rettangolo: Rect.fromLTWH(180, 260, 100, 90),
    latitudine: 40.7728,
    longitudine: 14.7910,
  ),

  // Edificio A1 - Rettorato
  EdificioSchematico(
    id: 'fisc_a1',
    codice: 'Edificio A1',
    nome: 'Edificio A1 — Rettorato',
    dipartimento: 'Rettorato, Uffici Centrali e Segreterie',
    descrizione:
        'Sede del Rettorato, Sala del Senato Accademico, Uffici di Presidenza e Segreterie Studenti.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFF012158),
    icona: Icons.account_balance,
    rettangolo: Rect.fromLTWH(180, 370, 100, 90),
    latitudine: 40.7735,
    longitudine: 14.7895,
    areeEasyRoom: ['Edificio A1 - Rettorato'],
  ),

  // Edificio A2 - Aula Magna e Teatro
  EdificioSchematico(
    id: 'fisc_a2',
    codice: 'Edificio A2',
    nome: 'Edificio A2 — Aula Magna e Teatro',
    dipartimento: 'Cerimonie, Convegni e Teatro di Ateneo',
    descrizione:
        'Grande aula cerimoniale dell\'Ateneo per inaugurazione anno accademico, lauree magistrali e convegni.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFFE8A33D),
    icona: Icons.theater_comedy_outlined,
    rettangolo: Rect.fromLTWH(180, 480, 100, 90),
    latitudine: 40.7739,
    longitudine: 14.7901,
    areeEasyRoom: ['Edificio A2 - Aula Magna e Teatro'],
  ),

  // Biblioteca Centrale Caianiello
  EdificioSchematico(
    id: 'fisc_biblio_umanistica',
    codice: 'Biblio Caianiello',
    nome: 'Biblioteca "E.R. Caianiello"',
    dipartimento: 'Polo Umanistico · Sale studio e consultazione',
    descrizione:
        'Sale lettura con centinaia di posti studio, consultazione volumi e periodici, emeroteca e sale tesi.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.biblioteca,
    colore: Color(0xFF1B5259),
    icona: Icons.local_library_outlined,
    rettangolo: Rect.fromLTWH(180, 590, 100, 80),
    latitudine: 40.7734,
    longitudine: 14.7892,
  ),

  // NORD-OVEST: Edificio B (B, B1, B2)
  EdificioSchematico(
    id: 'fisc_b',
    codice: 'Edificio B',
    nome: 'Edificio B — Scienze Umane e Lettere',
    dipartimento: 'DISUFF, Lettere, Filosofia e Formazione',
    descrizione:
        'Dipartimento di Scienze Umane, Filosofiche e della Formazione. Aule didattiche, laboratori multimediali e studi docenti.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFF1B5259),
    icona: Icons.menu_book,
    rettangolo: Rect.fromLTWH(320, 100, 130, 140),
    latitudine: 40.7745,
    longitudine: 14.7890,
    areeEasyRoom: ['Edificio B', 'Edificio B1', 'Edificio B2'],
  ),

  // NORD: Edificio C (C, C1, C2)
  EdificioSchematico(
    id: 'fisc_c',
    codice: 'Edificio C',
    nome: 'Edificio C — Economia e Scienze Politiche',
    dipartimento: 'DISES, DISPC · Economia e Comunicazione',
    descrizione:
        'Dipartimenti di Scienze Economiche e Statistiche e Scienze Politiche e della Comunicazione.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFF1B5259),
    icona: Icons.insights_outlined,
    rettangolo: Rect.fromLTWH(480, 100, 130, 140),
    latitudine: 40.7742,
    longitudine: 14.7912,
    areeEasyRoom: ['Edificio C', 'Edificio C1', 'Edificio C2'],
  ),

  // NORD-EST: Edificio D (D, D1, D2, D3)
  EdificioSchematico(
    id: 'fisc_d',
    codice: 'Edificio D',
    nome: 'Edificio D — Giurisprudenza',
    dipartimento: 'Scuola di Giurisprudenza · Scienze Giuridiche',
    descrizione:
        'Dipartimento di Scienze Giuridiche. Aule didattiche D1-D3, Aula Magna di Giurisprudenza e studi docenti.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFF012158),
    icona: Icons.gavel,
    rettangolo: Rect.fromLTWH(640, 100, 130, 140),
    latitudine: 40.7731,
    longitudine: 14.7924,
    areeEasyRoom: ['Edificio D', 'Edificio D1', 'Edificio D2', 'Edificio D3'],
  ),

  // CENTRO: Mensa Centrale ADISURC
  EdificioSchematico(
    id: 'fisc_mensa_centrale',
    codice: 'Mensa Centrale',
    nome: 'Mensa Centrale ADISURC',
    dipartimento: 'Ristorazione principale Ateneo',
    descrizione:
        'Due linee self-service, pizzeria forno a legna, pasti caldi, linea celiachia/vegetariano e bar annesso.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.ristoro,
    colore: Color(0xFFE8A33D),
    icona: Icons.restaurant,
    rettangolo: Rect.fromLTWH(420, 330, 120, 90),
    latitudine: 40.7725,
    longitudine: 14.7905,
  ),

  // EST: Edificio E (E, E1, E2)
  EdificioSchematico(
    id: 'fisc_e',
    codice: 'Edificio E',
    nome: 'Edificio E — Farmacia e Chimica',
    dipartimento: 'DIFARMA · Farmacia e Chimica Farmaceutica',
    descrizione:
        'Dipartimento di Farmacia. Aule E1-E3, laboratori di tecnologia farmaceutica, chimica e biologia sperimentale.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFF2E7D5B),
    icona: Icons.biotech,
    rettangolo: Rect.fromLTWH(640, 310, 130, 130),
    latitudine: 40.7715,
    longitudine: 14.7928,
    areeEasyRoom: ['Edificio E', 'Edificio E1', 'Edificio E2'],
  ),

  // SUD-EST: Edificio F (F, F1, F2, F3, F4)
  EdificioSchematico(
    id: 'fisc_f',
    codice: 'Edificio F',
    nome: 'Edificio F — Ingegneria e Scienze',
    dipartimento: 'DIIn, DIPMAT · Ingegneria, Informatica, Fisica',
    descrizione:
        'Polo tecnologico e scientifico: aule didattiche F1-F4, laboratori informatici avanzati e dipartimenti.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFFA3021F),
    icona: Icons.precision_manufacturing_outlined,
    rettangolo: Rect.fromLTWH(640, 500, 140, 170),
    latitudine: 40.7702,
    longitudine: 14.7918,
    areeEasyRoom: [
      'Edificio F',
      'Edificio F1',
      'Edificio F2',
      'Edificio F3',
      'Edificio F4',
      'Edificio I1',
      'Edificio L2',
    ],
  ),

  // SUD-EST: Biblioteca Scienze & Mensa F
  EdificioSchematico(
    id: 'fisc_biblio_scienze',
    codice: 'Biblio Scienze',
    nome: 'Biblioteca Scienze e Tecnologie',
    dipartimento: 'Edificio F2 · Polo Scientifico',
    descrizione:
        'Sale studio specializzate per Ingegneria, Scienze e Farmacia con postazioni cablate.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.biblioteca,
    colore: Color(0xFF012158),
    icona: Icons.menu_book,
    rettangolo: Rect.fromLTWH(490, 520, 110, 70),
    latitudine: 40.7705,
    longitudine: 14.7920,
  ),
  EdificioSchematico(
    id: 'fisc_mensa_f',
    codice: 'Mensa F',
    nome: 'Mensa & Ristoro Edificio F',
    dipartimento: 'Punto ristoro rapido Ingegneria',
    descrizione:
        'Primi espressi, insalate, panini e bar a servizio degli studenti del polo tecnologico.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.ristoro,
    colore: Color(0xFFE8A33D),
    icona: Icons.lunch_dining_outlined,
    rettangolo: Rect.fromLTWH(490, 610, 110, 60),
    latitudine: 40.7698,
    longitudine: 14.7915,
  ),

  // NORD-EST: CUS Salerno
  EdificioSchematico(
    id: 'fisc_cus',
    codice: 'PalaCUS',
    nome: 'CUS Salerno — Sport & Piscina',
    dipartimento: 'Centro Universitario Sportivo',
    descrizione:
        'Palazzetto dello sport, sala pesi/fitness, piscina coperta semi-olimpionica, campi tennis e pista atletica.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.sport,
    colore: Color(0xFF2E7D5B),
    icona: Icons.fitness_center,
    rettangolo: Rect.fromLTWH(820, 100, 140, 160),
    latitudine: 40.7758,
    longitudine: 14.7942,
  ),

  // SUD: Residenze ADISURC
  EdificioSchematico(
    id: 'fisc_residenze',
    codice: 'Residenze',
    nome: 'Residenze Universitarie ADISURC',
    dipartimento: 'Alloggi studenti e sale studio interne',
    descrizione:
        'Alloggi per studenti fuori sede ed Erasmus, con sale studio, lavanderie e aree comuni.',
    campus: TipoCampus.fisciano,
    categoria: CategoriaPunto.residenze,
    colore: Color(0xFF1B5259),
    icona: Icons.apartment_outlined,
    rettangolo: Rect.fromLTWH(640, 720, 140, 100),
    latitudine: 40.7685,
    longitudine: 14.7935,
  ),

  // ================= BARONISSI (Canvas 800 x 700) =================
  // Fermata Bus Baronissi
  EdificioSchematico(
    id: 'bar_bus',
    codice: 'Fermata Bus',
    nome: 'Fermata Bus & Navetta Baronissi',
    dipartimento: 'Ingresso Campus Baronissi',
    descrizione:
        'Fermata delle linee Busitalia e della navetta universitaria che collega continuamente Fisciano con Baronissi.',
    campus: TipoCampus.baronissi,
    categoria: CategoriaPunto.trasporti,
    colore: Color(0xFF012158),
    icona: Icons.directions_bus,
    rettangolo: Rect.fromLTWH(40, 240, 110, 130),
    latitudine: 40.7510,
    longitudine: 14.7728,
  ),

  // Polo Didattico Medicina e Chirurgia
  EdificioSchematico(
    id: 'bar_medicina',
    codice: 'Polo Didattico',
    nome: 'Polo Didattico di Medicina e Chirurgia',
    dipartimento: 'Scuola Medica Salernitana · Medicina e Odontoiatria',
    descrizione:
        'Aule didattiche, aule multimediali, Aula Magna e laboratori per le Professioni Sanitarie e Medicina.',
    campus: TipoCampus.baronissi,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFFA3021F),
    icona: Icons.local_hospital,
    rettangolo: Rect.fromLTWH(200, 160, 240, 180),
    latitudine: 40.7518,
    longitudine: 14.7735,
    areeEasyRoom: ['Campus Baronissi'],
  ),

  // Laboratori Ricerca Biomedica
  EdificioSchematico(
    id: 'bar_lab',
    codice: 'Lab Biomedici',
    nome: 'Laboratori di Ricerca Biomedica',
    dipartimento: 'Genetica molecolare, biochimica e simulazione',
    descrizione:
        'Laboratori avanzati per la ricerca biomedica sperimentale e simulazione clinica.',
    campus: TipoCampus.baronissi,
    categoria: CategoriaPunto.didattica,
    colore: Color(0xFFA3021F),
    icona: Icons.biotech,
    rettangolo: Rect.fromLTWH(200, 390, 160, 130),
    latitudine: 40.7522,
    longitudine: 14.7740,
  ),

  // Biblioteca Polo Biomedico
  EdificioSchematico(
    id: 'bar_biblio',
    codice: 'Biblio Biomedica',
    nome: 'Biblioteca del Polo Biomedico',
    dipartimento: 'Sale lettura e banche dati scientifiche',
    descrizione:
        'Sale studio, volumi di anatomia e medicina interna, banche dati PubMed e Scopus.',
    campus: TipoCampus.baronissi,
    categoria: CategoriaPunto.biblioteca,
    colore: Color(0xFF1B5259),
    icona: Icons.local_library_outlined,
    rettangolo: Rect.fromLTWH(390, 390, 150, 130),
    latitudine: 40.7515,
    longitudine: 14.7732,
  ),

  // Mensa Baronissi
  EdificioSchematico(
    id: 'bar_mensa',
    codice: 'Mensa',
    nome: 'Mensa ADISURC Baronissi',
    dipartimento: 'Ristorazione polo biomedico',
    descrizione:
        'Servizio ristorazione self-service ADISURC dedicato a studenti e docenti del polo di Baronissi.',
    campus: TipoCampus.baronissi,
    categoria: CategoriaPunto.ristoro,
    colore: Color(0xFFE8A33D),
    icona: Icons.restaurant,
    rettangolo: Rect.fromLTWH(480, 180, 120, 110),
    latitudine: 40.7512,
    longitudine: 14.7745,
  ),

  // CUS Baronissi
  EdificioSchematico(
    id: 'bar_cus',
    codice: 'CUS Baronissi',
    nome: 'Impianti Sportivi CUS Baronissi',
    dipartimento: 'Palestra fitness e campi polivalenti',
    descrizione:
        'Palestra pesi, sala fitness e campi all\'aperto a disposizione degli studenti.',
    campus: TipoCampus.baronissi,
    categoria: CategoriaPunto.sport,
    colore: Color(0xFF2E7D5B),
    icona: Icons.fitness_center,
    rettangolo: Rect.fromLTWH(630, 180, 130, 150),
    latitudine: 40.7525,
    longitudine: 14.7725,
  ),

  // Residenze Baronissi
  EdificioSchematico(
    id: 'bar_residenze',
    codice: 'Residenze',
    nome: 'Residenze Universitarie Baronissi',
    dipartimento: 'Alloggi ADISURC Medicina',
    descrizione:
        'Posti alloggio per studenti del Polo Sanitario e delle Scuole di Specializzazione.',
    campus: TipoCampus.baronissi,
    categoria: CategoriaPunto.residenze,
    colore: Color(0xFF1B5259),
    icona: Icons.apartment_outlined,
    rettangolo: Rect.fromLTWH(570, 390, 150, 130),
    latitudine: 40.7508,
    longitudine: 14.7748,
  ),
];

class MappaCampusScreen extends StatefulWidget {
  const MappaCampusScreen({super.key, this.api});
  final ApiService? api;

  @override
  State<MappaCampusScreen> createState() => _MappaCampusScreenState();
}

class _MappaCampusScreenState extends State<MappaCampusScreen> {
  TipoCampus _campusSelezionato = TipoCampus.fisciano;
  CategoriaPunto _categoriaSelezionata = CategoriaPunto.tutti;
  bool _mostraMappaInterattiva = true;
  String _ricerca = '';
  final TextEditingController _searchController = TextEditingController();
  final TransformationController _transCtrl = TransformationController();

  EdificioSchematico? _edificioSelezionato;
  Map<String, CampusBuildingData> _datiEdificiEasyRoom = {};

  // Fit-to-viewport: dimensione dell'area disponibile e campus gia' centrato,
  // per mostrare SEMPRE l'intera mappa all'apertura (prima appariva tagliata).
  Size? _viewport;
  TipoCampus? _fittedCampus;
  Size? _fittedViewport;

  @override
  void initState() {
    super.initState();
    _caricaDatiEasyRoom();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transCtrl.dispose();
    super.dispose();
  }

  Future<void> _caricaDatiEasyRoom() async {
    try {
      final dati = await CampusMapRepository.instance.getBuildings();
      if (mounted) {
        setState(() => _datiEdificiEasyRoom = dati);
      }
    } catch (_) {}
  }

  List<EdificioSchematico> get _edificiFiltrati {
    return kEdificiSchematici.where((e) {
      if (e.campus != _campusSelezionato) return false;
      if (_categoriaSelezionata != CategoriaPunto.tutti &&
          e.categoria != _categoriaSelezionata) {
        return false;
      }
      if (_ricerca.isEmpty) return true;
      final q = _ricerca.toLowerCase();
      return e.nome.toLowerCase().contains(q) ||
          e.codice.toLowerCase().contains(q) ||
          e.dipartimento.toLowerCase().contains(q) ||
          e.descrizione.toLowerCase().contains(q);
    }).toList();
  }

  void _apriPlanimetriaEdificio(EdificioSchematico edificio) {
    if (!edificio.haPlanimetrie) {
      _apriNavigatore(edificio);
      return;
    }

    final aree = edificio.areeEasyRoom;
    if (aree.length == 1) {
      final buildingData = _datiEdificiEasyRoom[aree.first];
      if (buildingData != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EdificioMapScreen(
              building: buildingData,
              api: widget.api,
            ),
          ),
        );
        return;
      }
    }

    // Se ci sono più blocchi (es. Edificio F ha F, F1, F2, F3, F4)
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Scegli il blocco di ${edificio.codice}',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Questo edificio comprende diversi corpi didattici e laboratori:',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              for (final area in aree) ...[
                Builder(
                  builder: (ctx) {
                    final data = _datiEdificiEasyRoom[area];
                    final numPiani = data?.floors.length ?? 1;
                    final numAule = data?.totalRooms ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              edificio.colore.withValues(alpha: 0.15),
                          child: Icon(edificio.icona,
                              color: edificio.colore, size: 20),
                        ),
                        title: Text(
                          area,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '$numPiani planimetrie · $numAule aule censite',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (data != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EdificioMapScreen(
                                  building: data,
                                  api: widget.api,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _apriNavigatore(EdificioSchematico edificio) async {
    final lat = edificio.latitudine;
    final lng = edificio.longitudine;
    final label = Uri.encodeComponent(edificio.nome);
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    final webUri = Uri.parse(googleMapsUrl);

    try {
      final launched = await launchUrl(
        geoUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  double get _canvasWidth =>
      _campusSelezionato == TipoCampus.fisciano ? 1000.0 : 800.0;
  double get _canvasHeight =>
      _campusSelezionato == TipoCampus.fisciano ? 900.0 : 700.0;

  /// Inquadra l'intera mappa nell'area disponibile (una sola volta per campus
  /// o quando cambia la dimensione del riquadro). Senza questo la mappa veniva
  /// renderizzata a grandezza naturale (1000x900) e appariva tagliata.
  void _fitToViewport(Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) return;
    final gia = _fittedCampus == _campusSelezionato &&
        _fittedViewport == viewport;
    if (gia) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transCtrl.value = _matriceFit(viewport);
      _fittedCampus = _campusSelezionato;
      _fittedViewport = viewport;
    });
  }

  Matrix4 _matriceFit(Size viewport) {
    final cw = _canvasWidth;
    final ch = _canvasHeight;
    final scale =
        (viewport.width / cw < viewport.height / ch
                ? viewport.width / cw
                : viewport.height / ch) *
            0.94;
    final dx = (viewport.width - cw * scale) / 2;
    final dy = (viewport.height - ch * scale) / 2;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _resetZoom() {
    final vp = _viewport;
    if (vp == null) {
      _transCtrl.value = Matrix4.identity();
      return;
    }
    _transCtrl.value = _matriceFit(vp);
  }

  void _scalaAttornoAlCentro(double fattore) {
    final vp = _viewport;
    if (vp == null) return;
    final corrente = _transCtrl.value.clone();
    final scalaCorrente = corrente.getMaxScaleOnAxis();
    final nuova = (scalaCorrente * fattore).clamp(0.2, 3.5);
    final fattoreReale = nuova / scalaCorrente;
    if (fattoreReale == 1.0) return;
    final fx = vp.width / 2;
    final fy = vp.height / 2;
    final attorno = Matrix4.identity()
      ..translateByDouble(fx, fy, 0, 1)
      ..scaleByDouble(fattoreReale, fattoreReale, 1, 1)
      ..translateByDouble(-fx, -fy, 0, 1);
    _transCtrl.value = attorno.multiplied(corrente);
  }

  void _zoomIn() => _scalaAttornoAlCentro(1.3);

  void _zoomOut() => _scalaAttornoAlCentro(1 / 1.3);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final edifici = _edificiFiltrati;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappa dei Campus'),
        actions: [
          IconButton(
            icon: Icon(
              _mostraMappaInterattiva
                  ? Icons.view_list_outlined
                  : Icons.map_outlined,
            ),
            tooltip: _mostraMappaInterattiva
                ? 'Passa all\'elenco'
                : 'Passa alla mappa interattiva',
            onPressed: () {
              setState(() => _mostraMappaInterattiva = !_mostraMappaInterattiva);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selettore Campus: Fisciano / Baronissi
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SegmentedButton<TipoCampus>(
              segments: const [
                ButtonSegment(
                  value: TipoCampus.fisciano,
                  label: Text('Campus di Fisciano'),
                  icon: Icon(Icons.school, size: 18),
                ),
                ButtonSegment(
                  value: TipoCampus.baronissi,
                  label: Text('Campus di Baronissi'),
                  icon: Icon(Icons.local_hospital, size: 18),
                ),
              ],
              selected: {_campusSelezionato},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) {
                  setState(() {
                    _campusSelezionato = set.first;
                    _edificioSelezionato = null;
                    _resetZoom();
                  });
                }
              },
            ),
          ),

          // Barra di ricerca aule / edifici
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _campusSelezionato == TipoCampus.fisciano
                    ? 'Cerca edificio, aula, DIIn, biblioteca, mensa...'
                    : 'Cerca aule medicina, laboratori, mensa...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _ricerca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _ricerca = '');
                        },
                      )
                    : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onChanged: (v) => setState(() => _ricerca = v.trim()),
            ),
          ),

          // Filtri categorie orizzontali
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              itemCount: CategoriaPunto.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = CategoriaPunto.values[idx];
                final sel = cat == _categoriaSelezionata;
                return FilterChip(
                  avatar: Icon(
                    cat.icon,
                    size: 14,
                    color: sel ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  label: Text(cat.label, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (_) => setState(() => _categoriaSelezionata = cat),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // Visualizzazione: Mappa Interattiva 2D oppure Elenco Schede
          Expanded(
            child: _mostraMappaInterattiva
                ? _buildMappaInterattiva(scheme, edifici)
                : _buildElencoSchede(scheme, edifici),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MAPPA INTERATTIVA 2D (SCHEMA EDIFICI NON DETTAGLIATI STILE EASYMAP)
  // =========================================================================
  Widget _buildMappaInterattiva(
    ColorScheme scheme,
    List<EdificioSchematico> edifici,
  ) {
    final isFisciano = _campusSelezionato == TipoCampus.fisciano;
    final double canvasWidth = isFisciano ? 1000.0 : 800.0;
    final double canvasHeight = isFisciano ? 900.0 : 700.0;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _viewport = viewport;
        // Inquadra l'intera mappa al primo render / al cambio campus.
        _fitToViewport(viewport);

        return Stack(
          children: [
            // Canvas interattivo (pinch-to-zoom, pan). constrained:false lascia
            // il canvas alla sua dimensione naturale: ci pensa il fit a mostrarlo
            // tutto, cosi' nessun edificio resta fuori schermo.
            ClipRect(
              child: InteractiveViewer(
                transformationController: _transCtrl,
                constrained: false,
                minScale: 0.2,
                maxScale: 3.5,
                boundaryMargin: EdgeInsets.symmetric(
                  horizontal: viewport.width * 0.5,
                  vertical: viewport.height * 0.5,
                ),
                child: SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: Stack(
                    children: [
                      // Sfondo, parchi e viali del campus (CustomPainter).
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CampusSfondoPainter(
                            isFisciano: isFisciano,
                            scheme: scheme,
                            isDark: isDark,
                          ),
                        ),
                      ),

                      // Blocchi degli edifici.
                      for (final ed in edifici) _buildEdificioBlock(ed, scheme),
                    ],
                  ),
                ),
              ),
            ),

            // Badge informativo in alto a destra.
            Positioned(
              top: 10,
              right: 16,
              child: _buildPillInfo(
                scheme,
                Icons.touch_app_outlined,
                'Tocca un edificio',
              ),
            ),

            // Controlli Zoom galleggianti.
            Positioned(
              right: 16,
              bottom: _edificioSelezionato != null ? 200 : 20,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in_campus',
                    onPressed: _zoomIn,
                    tooltip: 'Ingrandisci',
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out_campus',
                    onPressed: _zoomOut,
                    tooltip: 'Rimpicciolisci',
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_reset_campus',
                    onPressed: _resetZoom,
                    tooltip: 'Inquadra tutta la mappa',
                    child: const Icon(Icons.fit_screen_outlined),
                  ),
                ],
              ),
            ),

            // Scheda informativa dell'edificio selezionato (in basso).
            if (_edificioSelezionato != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildSchedaEdificioSelezionato(
                  scheme,
                  _edificioSelezionato!,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPillInfo(ColorScheme scheme, IconData icona, String testo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icona, size: 14, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            testo,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Numero di aule censite nell'edificio (somma dei blocchi EasyRoom).
  int _conteggioAule(EdificioSchematico ed) {
    var tot = 0;
    for (final area in ed.areeEasyRoom) {
      tot += _datiEdificiEasyRoom[area]?.totalRooms ?? 0;
    }
    return tot;
  }

  Widget _buildEdificioBlock(EdificioSchematico ed, ColorScheme scheme) {
    final bool isSelected = _edificioSelezionato?.id == ed.id;
    final r = ed.rettangolo;
    final int nAule = ed.haPlanimetrie ? _conteggioAule(ed) : 0;

    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: GestureDetector(
        onTap: () {
          setState(() => _edificioSelezionato = ed);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? ed.colore : ed.colore.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.amberAccent : Colors.white,
              width: isSelected ? 3.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? ed.colore.withValues(alpha: 0.5)
                    : Colors.black26,
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(ed.icona, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(
                ed.codice,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (ed.haPlanimetrie) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_outlined,
                          size: 9, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        nAule > 0 ? '$nAule aule' : 'PIANTE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchedaEdificioSelezionato(
    ColorScheme scheme,
    EdificioSchematico ed,
  ) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ed.colore, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ed.colore.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(ed.icona, color: ed.colore, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ed.nome,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ed.dipartimento,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _edificioSelezionato = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ed.descrizione,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (ed.haPlanimetrie) ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ed.colore,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: const Text(
                        'Mappa edificio ed aule',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _apriPlanimetriaEdificio(ed),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('GPS', style: TextStyle(fontSize: 12)),
                  onPressed: () => _apriNavigatore(ed),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ELENCO SCHEDE EDIFICI (VISTA LISTA ALTERNATIVA)
  // =========================================================================
  Widget _buildElencoSchede(
    ColorScheme scheme,
    List<EdificioSchematico> edifici,
  ) {
    if (edifici.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined,
                  size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'Nessun edificio trovato',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Prova a cambiare ricerca o filtro.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: edifici.length,
      itemBuilder: (context, index) {
        final ed = edifici[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ed.colore.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(ed.icona, color: ed.colore, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: ed.colore.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ed.codice,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ed.colore,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ed.nome,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            ed.dipartimento,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ed.descrizione,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 12),
                Divider(color: scheme.outlineVariant, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (ed.haPlanimetrie) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ed.colore,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        icon: const Icon(Icons.layers_outlined, size: 15),
                        label: const Text(
                          'Mappa ed Aule',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _apriPlanimetriaEdificio(ed),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      icon: const Icon(Icons.navigation_outlined, size: 15),
                      label: const Text(
                        'Navigatore',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _apriNavigatore(ed),
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
}

/// Disegna lo sfondo del campus con le aree verdi, i viali pedonali e le piazze.
class _CampusSfondoPainter extends CustomPainter {
  final bool isFisciano;
  final ColorScheme scheme;
  final bool isDark;

  _CampusSfondoPainter({
    required this.isFisciano,
    required this.scheme,
    this.isDark = false,
  });

  // Palette dello sfondo, adattata a tema chiaro/scuro.
  Color get _bgTop => isDark ? const Color(0xFF12161D) : const Color(0xFFF6F4EC);
  Color get _bgBottom =>
      isDark ? const Color(0xFF181D26) : const Color(0xFFEDE9DC);
  Color get _green =>
      isDark ? const Color(0xFF1C2B24) : const Color(0xFFDCEBCF);
  Color get _greenBorder =>
      isDark ? const Color(0xFF28402F) : const Color(0xFFC6DcB4);
  Color get _road =>
      isDark ? const Color(0xFF2A303B) : const Color(0xFFE3DCC6);
  Color get _roadSub =>
      isDark ? const Color(0xFF232833) : const Color(0xFFEBE5D2);
  Color get _roadLine =>
      isDark ? const Color(0xFF3A414E) : const Color(0xFFFCFAF2);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Sfondo generale del campus con lieve gradiente verticale.
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bgTop, _bgBottom],
      ).createShader(full);
    canvas.drawRect(full, bgPaint);

    // Cornice morbida attorno alla mappa.
    final cornice = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(full.deflate(3), const Radius.circular(18)),
      cornice,
    );

    // 2. Aree verdi e giardini (con bordo tenue).
    final greenPaint = Paint()..color = _green;
    final greenStroke = Paint()
      ..color = _greenBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    void parco(Rect r) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(24));
      canvas.drawRRect(rr, greenPaint);
      canvas.drawRRect(rr, greenStroke);
    }

    if (isFisciano) {
      parco(const Rect.fromLTWH(20, 20, 260, 160)); // ovest
      parco(const Rect.fromLTWH(310, 260, 290, 220)); // Piazza del Sapere
      parco(const Rect.fromLTWH(20, 700, 580, 160)); // sud
    } else {
      parco(const Rect.fromLTWH(20, 20, 760, 120));
      parco(const Rect.fromLTWH(20, 540, 760, 140));
    }

    // 3. Viali pedonali e strade del campus (asfalto + linea di mezzeria).
    final roadPaint = Paint()
      ..color = _road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    final roadSubPaint = Paint()
      ..color = _roadSub
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final linePaint = Paint()
      ..color = _roadLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    void viale(Offset a, Offset b, Paint base, {bool mezzeria = false}) {
      canvas.drawLine(a, b, base);
      if (mezzeria) _dashedLine(canvas, a, b, linePaint);
    }

    if (isFisciano) {
      viale(const Offset(50, 250), const Offset(950, 250), roadPaint,
          mezzeria: true);
      viale(const Offset(50, 480), const Offset(950, 480), roadPaint,
          mezzeria: true);
      viale(const Offset(300, 50), const Offset(300, 850), roadSubPaint);
      viale(const Offset(620, 50), const Offset(620, 850), roadSubPaint);
      viale(const Offset(790, 50), const Offset(790, 850), roadSubPaint);
    } else {
      viale(const Offset(50, 350), const Offset(750, 350), roadPaint,
          mezzeria: true);
      viale(const Offset(170, 120), const Offset(170, 560), roadSubPaint);
      viale(const Offset(460, 120), const Offset(460, 560), roadSubPaint);
    }

    // 4. Bussola in alto a destra.
    _disegnaBussola(canvas, Offset(size.width - 54, 54));
  }

  /// Linea tratteggiata (mezzeria dei viali principali).
  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 16.0;
    const gap = 14.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * (d + dash).clamp(0, total);
      canvas.drawLine(start, end, paint);
      d += dash + gap;
    }
  }

  /// Rosa dei venti stilizzata con la N.
  void _disegnaBussola(Canvas canvas, Offset c) {
    final anello = Paint()
      ..color = (isDark ? Colors.white : AppColors.mare).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, 22, anello);

    final ago = Paint()..color = AppColors.corallo;
    final path = Path()
      ..moveTo(c.dx, c.dy - 18)
      ..lineTo(c.dx - 6, c.dy)
      ..lineTo(c.dx + 6, c.dy)
      ..close();
    canvas.drawPath(path, ago);
    final agoSud = Paint()
      ..color = (isDark ? Colors.white54 : AppColors.nebbia);
    final path2 = Path()
      ..moveTo(c.dx, c.dy + 18)
      ..lineTo(c.dx - 6, c.dy)
      ..lineTo(c.dx + 6, c.dy)
      ..close();
    canvas.drawPath(path2, agoSud);

    final tp = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.mare,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - 36));
  }

  @override
  bool shouldRepaint(covariant _CampusSfondoPainter oldDelegate) =>
      oldDelegate.isFisciano != isFisciano || oldDelegate.isDark != isDark;
}
