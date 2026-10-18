import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

enum CategoriaServizio {
  tutti('Tutti', Icons.apps_outlined),
  biblioteche('Biblioteche', Icons.menu_book_outlined),
  adisurc('ADISURC', Icons.restaurant_outlined),
  cus('CUS Sport', Icons.sports_tennis_outlined),
  didattica('Didattica', Icons.school_outlined),
  supporto('Supporto', Icons.support_agent_outlined);

  const CategoriaServizio(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ServizioUtileItem {
  final String titolo;
  final String descrizione;
  final String url;
  final CategoriaServizio categoria;
  final IconData icona;
  final String? badge;
  final Color? coloreBadge;

  const ServizioUtileItem({
    required this.titolo,
    required this.descrizione,
    required this.url,
    required this.categoria,
    required this.icona,
    this.badge,
    this.coloreBadge,
  });
}

const List<ServizioUtileItem> kServiziUtili = [
  // --- BIBLIOTECHE ---
  ServizioUtileItem(
    titolo: 'Biblioteche di Ateneo UNISA',
    descrizione:
        'Polo bibliotecario di Ateneo (Caianiello, Scienze, Polo Biomedico): orari, servizi, sale lettura, prestiti e consultazione online.',
    url: 'https://www.biblioteche.unisa.it/',
    categoria: CategoriaServizio.biblioteche,
    icona: Icons.local_library_outlined,
    badge: 'Portale Ufficiale',
    coloreBadge: Color(0xFF1B5259),
  ),

  // --- ADISURC ---
  ServizioUtileItem(
    titolo: 'Portale Ufficiale ADISURC',
    descrizione:
        'Azienda per il Diritto allo Studio Universitario della Regione Campania. Servizi, bandi, mense e modulistica.',
    url: 'https://www.adisurcampania.it/',
    categoria: CategoriaServizio.adisurc,
    icona: Icons.public_outlined,
    badge: 'Sito Istituzionale',
    coloreBadge: Color(0xFFE8A33D),
  ),
  ServizioUtileItem(
    titolo: 'Borse di Studio e Sussidi ADISURC',
    descrizione:
        'Bandi annuali per borse di studio universitarie, integrazioni, graduatorie e accredito rimborsi.',
    url: 'https://www.adisurcampania.it/',
    categoria: CategoriaServizio.adisurc,
    icona: Icons.euro_outlined,
    badge: 'Bandi & Graduatorie',
    coloreBadge: Color(0xFF2E7D5B),
  ),
  ServizioUtileItem(
    titolo: 'Alloggi e Residenze Universitarie',
    descrizione:
        'Posti alloggio nelle residenze di Fisciano e Baronissi per studenti in sede, fuori sede e internazionali.',
    url: 'https://www.adisurcampania.it/',
    categoria: CategoriaServizio.adisurc,
    icona: Icons.home_work_outlined,
    badge: 'Residenze Campus',
    coloreBadge: Color(0xFF1B5259),
  ),
  ServizioUtileItem(
    titolo: 'Servizio Ristorazione & Mense',
    descrizione:
        'Tariffe pasti in base alla fascia ISEE, orari di apertura e servizi ristorazione per gli studenti.',
    url: 'https://www.adisurcampania.it/',
    categoria: CategoriaServizio.adisurc,
    icona: Icons.restaurant_menu_outlined,
    badge: 'Tariffe & Mense',
  ),

  // --- CUS SALERNO (SPORT) ---
  ServizioUtileItem(
    titolo: 'CUS Salerno — Sito Ufficiale',
    descrizione:
        'Centro Universitario Sportivo di Salerno: attività sportive, orari corsi, tornei e news.',
    url: 'https://www.cussalerno.it/',
    categoria: CategoriaServizio.cus,
    icona: Icons.fitness_center_outlined,
    badge: 'Sito Ufficiale CUS',
    coloreBadge: Color(0xFFE8A33D),
  ),
  ServizioUtileItem(
    titolo: 'Tesseramento & Abbonamenti CUS',
    descrizione:
        'Iscrizione, quota tesseramento studenti UNISA, abbonamenti per sala pesi, fitness e piscina.',
    url: 'https://www.cussalerno.it/tesseramento/',
    categoria: CategoriaServizio.cus,
    icona: Icons.card_membership_outlined,
    badge: 'Tariffe Studenti',
    coloreBadge: Color(0xFF2E7D5B),
  ),
  ServizioUtileItem(
    titolo: 'Impianti Sportivi Fisciano (PalaCUS)',
    descrizione:
        'Palestra, piscina coperta, campi da tennis, padel, calcio a 5/8 e pista di atletica leggera.',
    url: 'https://www.cussalerno.it/impianti/',
    categoria: CategoriaServizio.cus,
    icona: Icons.stadium_outlined,
    badge: 'Campus Fisciano',
    coloreBadge: Color(0xFF1B5259),
  ),

  // --- DIDATTICA & PORTALI UNISA ---
  ServizioUtileItem(
    titolo: 'Portale Esse3 Web UNISA',
    descrizione:
        'Segreteria online per immatricolazioni, certificati, piano di studi e carriera completa.',
    url: 'https://esse3web.unisa.it/',
    categoria: CategoriaServizio.didattica,
    icona: Icons.laptop_chromebook_outlined,
    badge: 'Segreteria Online',
    coloreBadge: Color(0xFF012158),
  ),
  ServizioUtileItem(
    titolo: 'Webmail Studenti (@studenti.unisa.it)',
    descrizione:
        'Accesso alla casella di posta istituzionale su piattaforma Google Workspace for Education.',
    url: 'https://mail.google.com/a/studenti.unisa.it',
    categoria: CategoriaServizio.didattica,
    icona: Icons.mark_email_read_outlined,
    badge: 'Email Istituzionale',
  ),
  ServizioUtileItem(
    titolo: 'Didattica Online & E-Learning',
    descrizione:
        'Linee guida, aule virtuali, canali Teams e accesso ai materiali didattici dei corsi di studio.',
    url: 'https://web.unisa.it/didatticaonline/',
    categoria: CategoriaServizio.didattica,
    icona: Icons.school_outlined,
    badge: 'Didattica Online',
    coloreBadge: Color(0xFF1B5259),
  ),
  ServizioUtileItem(
    titolo: 'Centro Linguistico di Ateneo (CLA)',
    descrizione:
        'Corsi di lingue straniere, test di piazzamento, idoneità linguistiche e certificazioni (B1, B2, C1).',
    url: 'https://www.cla.unisa.it/',
    categoria: CategoriaServizio.didattica,
    icona: Icons.translate_outlined,
    badge: 'Certificazioni Lingua',
  ),
  ServizioUtileItem(
    titolo: 'Tirocini & Ufficio Placement',
    descrizione:
        'Gestione tirocini curriculari ed extracurriculari, convenzioni aziendali e offerte di lavoro.',
    url: 'https://placement.unisa.it/',
    categoria: CategoriaServizio.didattica,
    icona: Icons.work_outline,
    badge: 'Stage & Lavoro',
  ),

  // --- SUPPORTO & ATENEO ---
  ServizioUtileItem(
    titolo: 'Ufficio Diritto allo Studio e Disabilità/DSA',
    descrizione:
        'Servizi dedicati agli studenti con disabilità o disturbi specifici dell’apprendimento (DSA) e tutor alla pari.',
    url: 'https://www.disabilidsa.unisa.it/',
    categoria: CategoriaServizio.supporto,
    icona: Icons.accessibility_new_outlined,
    badge: 'Inclusione & DSA',
    coloreBadge: Color(0xFF2E7D5B),
  ),
  ServizioUtileItem(
    titolo: 'Centro di Orientamento e Tutorato (CAOT)',
    descrizione:
        'Orientamento universitario per future matricole, passaggio di corso e supporto durante la carriera.',
    url: 'https://www.orientamento.unisa.it/',
    categoria: CategoriaServizio.supporto,
    icona: Icons.compass_calibration_outlined,
    badge: 'Orientamento',
  ),
  ServizioUtileItem(
    titolo: 'URP — Ufficio Relazioni con il Pubblico e Contatti',
    descrizione:
        'Informazioni generali, contatti ufficiali dei presidi, centralino di Ateneo e segnalazioni.',
    url: 'https://web.unisa.it/ateneo/contatti',
    categoria: CategoriaServizio.supporto,
    icona: Icons.info_outline,
    badge: 'Contatti Ateneo',
  ),
];

class ServiziUtiliScreen extends StatefulWidget {
  const ServiziUtiliScreen({super.key});

  @override
  State<ServiziUtiliScreen> createState() => _ServiziUtiliScreenState();
}

class _ServiziUtiliScreenState extends State<ServiziUtiliScreen> {
  CategoriaServizio _categoriaSelezionata = CategoriaServizio.tutti;
  String _ricerca = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServizioUtileItem> get _serviziFiltrati {
    return kServiziUtili.where((item) {
      final corrispondeCat =
          _categoriaSelezionata == CategoriaServizio.tutti ||
          item.categoria == _categoriaSelezionata;
      if (!corrispondeCat) return false;

      if (_ricerca.isEmpty) return true;
      final q = _ricerca.toLowerCase();
      return item.titolo.toLowerCase().contains(q) ||
          item.descrizione.toLowerCase().contains(q) ||
          (item.badge?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _apriUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire il link: $url'),
            backgroundColor: AppColors.arancio,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtrati = _serviziFiltrati;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servizi e collegamenti utili'),
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca servizio, biblioteca, ADISURC, CUS...',
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

          // Chips categorie
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: CategoriaServizio.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = CategoriaServizio.values[idx];
                final sel = cat == _categoriaSelezionata;
                return FilterChip(
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: sel ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  label: Text(cat.label),
                  selected: sel,
                  onSelected: (_) => setState(() => _categoriaSelezionata = cat),
                  showCheckmark: false,
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Lista servizi
          Expanded(
            child: filtrati.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nessun servizio trovato',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prova a cambiare termine di ricerca o categoria.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    itemCount: filtrati.length,
                    itemBuilder: (context, index) {
                      final item = filtrati[index];
                      return _ServizioCard(
                        item: item,
                        onTap: () => _apriUrl(context, item.url),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServizioCard extends StatelessWidget {
  const _ServizioCard({required this.item, required this.onTap});

  final ServizioUtileItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      color: (item.coloreBadge ?? scheme.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icona,
                      color: item.coloreBadge ?? scheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.badge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (item.coloreBadge ?? scheme.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.badge!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: item.coloreBadge ?? scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          item.titolo,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: scheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.descrizione,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 13,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.url.replaceFirst('https://', '').replaceFirst(RegExp(r'/+$'), ''),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

