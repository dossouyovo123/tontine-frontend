import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Core/Tontine_store.dart';

// ============================================================
// MODÈLE LOCAL (mappage de la réponse API)
// ============================================================

enum StatutComplement { enAttente, approuve, refuse, motoAttribuee }

class DemandeComplement {
  final int    apiId;          // ID réel en base
  final String id;             // référence CMP001
  final String nomMembre;
  final int    membreApiId;    // ID du membre pour les appels API
  final String telephone;
  final int    semaineCotisees;
  final double montantCotiseTotalCFA;
  final double montantMotoEstime;
  final String? descriptionMoto;
  final DateTime dateDemande;
  StatutComplement statut;
  DateTime? dateAttributionMoto;
  String? notesAdmin;

  DemandeComplement({
    required this.apiId,
    required this.id,
    required this.nomMembre,
    required this.membreApiId,
    this.telephone = '',
    required this.semaineCotisees,
    required this.montantCotiseTotalCFA,
    required this.montantMotoEstime,
    this.descriptionMoto,
    required this.dateDemande,
    this.statut = StatutComplement.enAttente,
    this.dateAttributionMoto,
    this.notesAdmin,
  });

  // ── Depuis la réponse JSON Laravel ────────────────────────
  factory DemandeComplement.fromJson(Map<String, dynamic> j) {
    StatutComplement statut;
    switch (j['statut'] as String? ?? 'en_attente') {
      case 'approuve':       statut = StatutComplement.approuve;      break;
      case 'refuse':         statut = StatutComplement.refuse;        break;
      case 'moto_attribuee': statut = StatutComplement.motoAttribuee; break;
      default:               statut = StatutComplement.enAttente;
    }

    final membre = j['membre'] as Map<String, dynamic>? ?? {};

    return DemandeComplement(
      apiId:                int.tryParse(j['id'].toString()) ?? 0,
      id:                   j['reference'] ?? 'CMP???',
      nomMembre:            membre['nom'] ?? j['nom_membre'] ?? '—',
      membreApiId:          int.tryParse((membre['id'] ?? j['membre_id']).toString()) ?? 0,
      telephone:            membre['telephone'] ?? '',
      semaineCotisees:      j['semaines_cotisees_snapshot'] ?? 0,
      montantCotiseTotalCFA: (j['montant_cotise_total'] as num?)?.toDouble() ?? 0,
      montantMotoEstime:    (j['montant_moto_estime']  as num?)?.toDouble() ?? 0,
      descriptionMoto:      j['description_moto'],
      dateDemande:          DateTime.tryParse(j['date_demande'] ?? '') ?? DateTime.now(),
      statut:               statut,
      dateAttributionMoto:  j['date_attribution_moto'] != null
          ? DateTime.tryParse(j['date_attribution_moto'])
          : null,
      notesAdmin: j['notes_admin'],
    );
  }

  bool get estEligible => semaineCotisees >= kSeuilEligibilite;
  double get montantComplement => montantMotoEstime - montantCotiseTotalCFA;

  String get statutLabel {
    switch (statut) {
      case StatutComplement.enAttente:     return 'En attente';
      case StatutComplement.approuve:      return 'Approuvé';
      case StatutComplement.refuse:        return 'Refusé';
      case StatutComplement.motoAttribuee: return ' Attribuée';
    }
  }

  Color get statutColor {
    switch (statut) {
      case StatutComplement.enAttente:     return Colors.orange;
      case StatutComplement.approuve:      return Colors.blue;
      case StatutComplement.refuse:        return Colors.red;
      case StatutComplement.motoAttribuee: return Colors.green;
    }
  }

  IconData get statutIcon {
    switch (statut) {
      case StatutComplement.enAttente:     return Icons.hourglass_top_rounded;
      case StatutComplement.approuve:      return Icons.thumb_up_alt_rounded;
      case StatutComplement.refuse:        return Icons.cancel_rounded;
      case StatutComplement.motoAttribuee: return Icons.two_wheeler_rounded;
    }
  }

  String get statutApi {
    switch (statut) {
      case StatutComplement.enAttente:     return 'en_attente';
      case StatutComplement.approuve:      return 'approuve';
      case StatutComplement.refuse:        return 'refuse';
      case StatutComplement.motoAttribuee: return 'moto_attribuee';
    }
  }
}

// ============================================================
// PAGE COMPLÉMENTS — intégrée à l'API
// ============================================================

class ComplementsPage extends StatefulWidget {
  const ComplementsPage({super.key});

  @override
  State<ComplementsPage> createState() => _ComplementsPageState();
}

class _ComplementsPageState extends State<ComplementsPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  String _searchQuery = '';
  StatutComplement? _filterStatut;
  bool _isGeneratingPdf = false;

  List<DemandeComplement> _demandes = [];
  bool _isLoading = true;
  String? _error;

  static const Color _primary    = Color(0xFF1565C0);
  static const Color _accent     = Color(0xFF0288D1);
  static const Color _motoOrange = Color(0xFFE65100);
  static const Color _bg         = Color(0xFFF0F4F8);
  static const Color _whatsapp   = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _charger();
    // Charge aussi les membres dans le store si pas encore fait
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TontineStore().membres.isEmpty) TontineStore().chargerMembres();
    });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  // ── Chargement depuis l'API ───────────────────────────────
  Future<void> _charger() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await ApiService().getComplements();
      final data = (res['data'] as List?) ?? (res['complements'] as List?) ?? [];
      setState(() => _demandes = data.map((j) => DemandeComplement.fromJson(j)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  List<DemandeComplement> get _filtrees => _demandes.where((d) =>
  d.nomMembre.toLowerCase().contains(_searchQuery.toLowerCase()) &&
      (_filterStatut == null || d.statut == _filterStatut)
  ).toList();

  int get _nbAttente  => _demandes.where((d) => d.statut == StatutComplement.enAttente).length;
  int get _nbApprouve => _demandes.where((d) => d.statut == StatutComplement.approuve).length;
  int get _nbAttribue => _demandes.where((d) => d.statut == StatutComplement.motoAttribuee).length;

  // ── Changer statut via API ────────────────────────────────
  Future<void> _changerStatut(DemandeComplement d, StatutComplement nouveau) async {
    Navigator.pop(context);
    try {
      Map<String, dynamic> res;
      switch (nouveau) {
        case StatutComplement.approuve:
          res = await ApiService().approuverComplement(d.apiId);
          break;
        case StatutComplement.refuse:
          res = await ApiService().refuserComplement(d.apiId);
          break;
        case StatutComplement.motoAttribuee:
          res = await ApiService().attribuerMoto(d.apiId);
          break;
        default:
          return;
      }
      // Met à jour localement
      setState(() {
        d.statut = nouveau;
        if (nouveau == StatutComplement.motoAttribuee) {
          d.dateAttributionMoto = DateTime.now();
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Statut mis à jour : ${d.statutLabel}'),
        backgroundColor: d.statutColor, behavior: SnackBarBehavior.floating,
      ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Nouvelle demande via API ──────────────────────────────
  Future<void> _soumettreDemande({
    required int membreId,
    required double montantMoto,
    required String? descriptionMoto,
  }) async {
    try {
      final res = await ApiService().creerComplement(
        membreId: membreId,
        montantMoto: montantMoto.toInt(),
        description: descriptionMoto,
      );
      final nouvelle = DemandeComplement.fromJson(res);
      setState(() => _demandes.insert(0, nouvelle));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Demande ${nouvelle.id} enregistrée'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
      ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.firstError ?? e.message),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [_buildHeader(inner)],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : Column(children: [
          _buildSearch(),
          _buildChips(),
          Expanded(child: _buildListe()),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _motoOrange,
        onPressed: _showNouvelleSheet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouvelle demande',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildErrorState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.wifi_off, size: 60, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _charger,
        icon: const Icon(Icons.refresh),
        label: const Text('Réessayer'),
      ),
    ]),
  );
  Widget _buildHeader(bool inner) => SliverAppBar(
    expandedHeight: 220,
    pinned: true,
    backgroundColor: _primary,

    // 👈 bouton retour
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),

    // 🔥 TOUT SUR LA MÊME LIGNE
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.two_wheeler_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        const Text(
          'Compléments Motos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
      ],
    ),

    actions: [
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.white),
        onPressed: _charger,
      ),
    ],

    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF0288D1)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
            // 👆 IMPORTANT: on descend pour éviter conflit avec la top bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text(
                  'Attribution par cotisations (52 semaines)',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),

                const SizedBox(height: 3),

                Row(children: [
                  _pill(_nbAttente.toString(), 'En attente',
                      Colors.orange.shade100, Colors.orange.shade800),
                  const SizedBox(width: 10),
                  _pill(_nbApprouve.toString(), 'Approuvés',
                      Colors.blue.shade100, Colors.blue.shade800),
                  const SizedBox(width: 10),
                  _pill(_nbAttribue.toString(), 'Attribués',
                      Colors.green.shade100, Colors.green.shade800),
                ]),

                const SizedBox(height: 16),
                _buildProgress(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _pill(String v, String l, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Text(v, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(width: 6),
      Text(l, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildProgress() {
    final store = TontineStore();
    final sem   = store.semaineCourante;
    final pct   = sem / 52.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Semaine $sem / 52',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        Text('${(pct * 100).toStringAsFixed(0)}% de l\'année',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: pct, minHeight: 8,
          backgroundColor: Colors.white.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade300),
        ),
      ),
    ]);
  }

  // ── SEARCH + CHIPS ────────────────────────────────────────
  Widget _buildSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Rechercher une demande...',
        prefixIcon: const Icon(Icons.search, color: _primary),
        filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _buildChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(children: [
      _chip('Tous',        null,                           Colors.blueGrey),
      _chip('En attente',  StatutComplement.enAttente,     Colors.orange),
      _chip('Approuvés',   StatutComplement.approuve,      Colors.blue),
      _chip('Attribués',   StatutComplement.motoAttribuee, Colors.green),
      _chip('Refusés',     StatutComplement.refuse,        Colors.red),
    ]),
  );

  Widget _chip(String label, StatutComplement? s, Color color) {
    final sel = _filterStatut == s;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label), selected: sel,
        onSelected: (_) => setState(() => _filterStatut = s),
        selectedColor: color.withOpacity(0.15), backgroundColor: Colors.white,
        labelStyle: TextStyle(color: sel ? color : Colors.black54,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12),
        side: BorderSide(color: sel ? color : Colors.grey.shade200),
      ),
    );
  }

  // ── LISTE ─────────────────────────────────────────────────
  Widget _buildListe() {
    final list = _filtrees;
    if (list.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.two_wheeler_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Aucune demande', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildCard(list[i]),
      ),
    );
  }

  // ── CARTE ─────────────────────────────────────────────────
  Widget _buildCard(DemandeComplement d) {
    final fmt      = NumberFormat('#,###', 'fr_FR');
    final progress = (d.semaineCotisees / 52.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _showDetail(d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: d.statutColor.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(
              color: d.statutColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Identité
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_primary, _accent],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(d.nomMembre[0],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.nomMembre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(children: [
                  Icon(Icons.tag, size: 10, color: Colors.grey.shade400),
                  Text(d.id, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(width: 8),
                  if (d.telephone.isNotEmpty) ...[
                    Icon(Icons.phone, size: 10, color: Colors.grey.shade400),
                    const SizedBox(width: 2),
                    Text(d.telephone, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ]),
              ])),
              // Badge statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: d.statutColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(d.statutIcon, color: d.statutColor, size: 13),
                  const SizedBox(width: 4),
                  Text(d.statutLabel,
                      style: TextStyle(color: d.statutColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            // Moto
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.two_wheeler_rounded, color: _motoOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  d.descriptionMoto ?? 'Moto non précisée',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontStyle: d.descriptionMoto == null ? FontStyle.italic : FontStyle.normal,
                    fontSize: 13,
                  ),
                )),
                Text('${fmt.format(d.montantMotoEstime)} CFA',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _motoOrange, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 12),
            // Semaines + éligibilité
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${d.semaineCotisees} semaines cotisées',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600)),
              Row(children: [
                Icon(d.estEligible ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    color: d.estEligible ? Colors.green : Colors.orange, size: 14),
                const SizedBox(width: 4),
                Text(d.estEligible ? 'Éligible' : 'Non éligible (< $kSeuilEligibilite sem.)',
                    style: TextStyle(
                        color: d.estEligible ? Colors.green : Colors.orange,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress, minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                    d.estEligible ? Colors.green : Colors.orange),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Demande du ${DateFormat('dd/MM/yyyy').format(d.dateDemande)} • '
                  'Cotisé : ${fmt.format(d.montantCotiseTotalCFA)} CFA',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            ),
            const SizedBox(height: 12),
            // Boutons PDF + WhatsApp
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _isGeneratingPdf ? null : () => _lancerExport(d),
                icon: const Icon(Icons.picture_as_pdf_rounded, color: _motoOrange, size: 15),
                label: Text(_isGeneratingPdf ? '...' : 'PDF',
                    style: const TextStyle(color: _motoOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _motoOrange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: _isGeneratingPdf ? null : () => _exporterWhatsApp(d),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 15),
                label: const Text('WhatsApp',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _whatsapp,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  // ============================================================
  // DÉTAIL
  // ============================================================
  void _showDetail(DemandeComplement d) {
    final fmt  = NumberFormat('#,###', 'fr_FR');
    final dfmt = DateFormat('dd/MM/yyyy');

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            // Header coloré
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [d.statutColor.withOpacity(0.8), d.statutColor],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10)))),
                Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(d.nomMembre[0], style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.nomMembre, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(d.id, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (d.telephone.isNotEmpty)
                      Row(children: [
                        const Icon(Icons.phone, color: Colors.white60, size: 12),
                        const SizedBox(width: 4),
                        Text(d.telephone,
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(d.statutIcon, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(d.statutLabel, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ),
                ]),
              ]),
            ),
            // Corps scrollable
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _dRow(Icons.two_wheeler_rounded, _motoOrange,
                    'Moto souhaitée', d.descriptionMoto ?? 'Non précisée'),
                _dRow(Icons.payments_outlined, Colors.green,
                    'Montant estimé moto', '${fmt.format(d.montantMotoEstime)} CFA'),
                _dRow(Icons.savings_rounded, Colors.blue,
                    'Total cotisé', '${fmt.format(d.montantCotiseTotalCFA)} CFA'),
                _dRow(Icons.money_off_rounded, Colors.red,
                    'Complément nécessaire', '${fmt.format(d.montantComplement)} CFA'),
                _dRow(Icons.calendar_today_rounded, Colors.blueGrey,
                    'Date de demande', dfmt.format(d.dateDemande)),
                _dRow(Icons.bar_chart_rounded,
                    d.estEligible ? Colors.green : Colors.orange,
                    'Semaines cotisées', '${d.semaineCotisees} / 52 semaines'),
                if (d.dateAttributionMoto != null)
                  _dRow(Icons.check_circle_rounded, Colors.green,
                      'Date d\'attribution', dfmt.format(d.dateAttributionMoto!)),
                if (d.notesAdmin != null && d.notesAdmin!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.notes_rounded, color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.notesAdmin!,
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 13))),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                // Boutons PDF + WhatsApp
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _isGeneratingPdf ? null
                        : () { Navigator.pop(context); _lancerExport(d); },
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: _motoOrange, size: 16),
                    label: Text(_isGeneratingPdf ? 'Génération...' : 'Télécharger PDF',
                        style: const TextStyle(color: _motoOrange, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _motoOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _isGeneratingPdf ? null
                        : () { Navigator.pop(context); _exporterWhatsApp(d); },
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    label: const Text('WhatsApp',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _whatsapp,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )),
                ]),
                const SizedBox(height: 16),
                // Actions selon statut
                if (d.statut == StatutComplement.enAttente) ...[
                  _actionBtn('APPROUVER', Icons.thumb_up_alt_rounded, Colors.blue,
                          () => _changerStatut(d, StatutComplement.approuve)),
                  const SizedBox(height: 10),
                  _actionBtn('REFUSER', Icons.cancel_rounded, Colors.red,
                          () => _changerStatut(d, StatutComplement.refuse)),
                ],
                if (d.statut == StatutComplement.approuve)
                  _actionBtn('MARQUER MOTO ATTRIBUÉE', Icons.two_wheeler_rounded, Colors.green,
                          () => _changerStatut(d, StatutComplement.motoAttribuee)),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ============================================================
  // NOUVELLE DEMANDE — utilise les membres du TontineStore
  // ============================================================
  void _showNouvelleSheet() {
    Membre? selMembre;
    final montantCtrl  = TextEditingController();
    final descCtrl     = TextEditingController();
    bool isSaving      = false;

    // Membres actifs éligibles du store (remplis via /membres)
    final store         = TontineStore();
    final membresActifs = store.membres
        .where((m) => m.isActive && !m.aAbandonne)
        .toList();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (ctx, setSheet) {
        final elig = selMembre != null && selMembre!.semainesCotisees >= kSeuilEligibilite;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10)))),
                Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _motoOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.two_wheeler_rounded, color: _motoOrange)),
                  const SizedBox(width: 12),
                  const Text('Nouvelle demande complément',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 20),

                // Sélection membre
                _sheetLabel('Membre bénéficiaire'),
                GestureDetector(
                  onTap: () => _selectMembreDuStore(ctx, setSheet, membresActifs, (m) => selMembre = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(children: [
                      Icon(Icons.person, color: selMembre == null ? Colors.grey : _primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        selMembre?.nom ?? 'Sélectionner un membre',
                        style: TextStyle(
                          color: selMembre == null ? Colors.grey : Colors.black,
                          fontWeight: selMembre == null ? FontWeight.normal : FontWeight.bold,
                        ),
                      )),
                      const Icon(Icons.arrow_drop_down),
                    ]),
                  ),
                ),

                // Carte éligibilité
                if (selMembre != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: elig ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: elig ? Colors.green.shade200 : Colors.orange.shade200),
                    ),
                    child: Row(children: [
                      Icon(elig ? Icons.verified_rounded : Icons.warning_amber_rounded,
                          color: elig ? Colors.green.shade700 : Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(elig ? 'Membre éligible ✓' : 'Pas encore éligible',
                            style: TextStyle(
                                color: elig ? Colors.green.shade800 : Colors.orange.shade800,
                                fontWeight: FontWeight.bold)),
                        Text(
                          '${selMembre!.semainesCotisees} semaines cotisées — '
                              '${NumberFormat('#,###', 'fr_FR').format(selMembre!.totalCotiseCfa)} CFA versés',
                          style: TextStyle(
                              color: elig ? Colors.green.shade700 : Colors.orange.shade700,
                              fontSize: 12),
                        ),
                        if (!elig)
                          Text('Il faut au moins $kSeuilEligibilite semaines.',
                              style: TextStyle(
                                  color: Colors.orange.shade600,
                                  fontSize: 11, fontStyle: FontStyle.italic)),
                      ])),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),
                _sheetLabel('Description de la moto'),
                TextField(controller: descCtrl,
                    decoration: _sheetDeco(Icons.two_wheeler_rounded, 'Ex: Yamaha YBR 125 - Noire')),
                const SizedBox(height: 14),
                _sheetLabel('Montant de la moto (CFA)'),
                TextField(controller: montantCtrl, keyboardType: TextInputType.number,
                    decoration: _sheetDeco(Icons.payments_outlined, 'Ex: 750000')),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (selMembre != null && elig && !isSaving) ? () async {
                      final montant = double.tryParse(montantCtrl.text.trim()) ?? 0;
                      if (montant <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Entrez un montant valide'),
                          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
                        ));
                        return;
                      }
                      setSheet(() => isSaving = true);
                      Navigator.pop(context);
                      await _soumettreDemande(
                        membreId: selMembre!.id,
                        montantMoto: montant,
                        descriptionMoto: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      );
                    } : null,
                    icon: isSaving
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, color: Colors.white),
                    label: const Text('ENREGISTRER LA DEMANDE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: elig && selMembre != null ? _motoOrange : Colors.grey.shade400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            )),
          ),
        );
      }),
    );
  }

  // Picker membre depuis le TontineStore (données API réelles)
  void _selectMembreDuStore(
      BuildContext sheetCtx,
      StateSetter setSheet,
      List<Membre> membres,
      Function(Membre) onSelect) {
    String filter = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (ctx, ss) {
        final filtered = membres
            .where((m) => m.nom.toLowerCase().contains(filter.toLowerCase()))
            .toList();
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const Padding(padding: EdgeInsets.all(16),
                child: Text('Choisir le membre',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true, onChanged: (v) => ss(() => filter = v),
                decoration: InputDecoration(hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: filtered.isEmpty
                ? Center(child: Text('Aucun membre actif',
                style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx2, i) {
                final m    = filtered[i];
                final elig = m.semainesCotisees >= kSeuilEligibilite;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: elig ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Text(m.nom[0], style: TextStyle(
                        color: elig ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.bold)),
                  ),
                  title: Text(m.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${m.semainesCotisees} sem. — ${m.telephone} — '
                        '${elig ? "✓ Éligible" : "✗ Non éligible"}',
                    style: TextStyle(
                        color: elig ? Colors.green.shade600 : Colors.orange.shade600,
                        fontSize: 11),
                  ),
                  onTap: () {
                    setSheet(() => onSelect(m));
                    Navigator.pop(context);
                  },
                );
              },
            )),
          ]),
        );
      }),
    );
  }

  // ============================================================
  // GÉNÉRATION PDF (inchangée — logique locale)
  // ============================================================
  Future<File> _genererPDF(DemandeComplement d) async {
    final doc  = pw.Document();
    final fmt  = NumberFormat('#,###', 'fr_FR');
    final dfmt = DateFormat('dd/MM/yyyy');
    final now  = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.orange800, width: 2))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('MaTontine - Compléments Motos',
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange800)),
            pw.Text('Généré le $now',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
                color: PdfColors.orange800, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text('FICHE DEMANDE',
                style: pw.TextStyle(color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
        ]),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
      ),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        // Identité
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColors.blue200)),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(width: 56, height: 56,
                decoration: pw.BoxDecoration(color: PdfColors.blue800, shape: pw.BoxShape.circle),
                child: pw.Center(child: pw.Text(d.nomMembre[0],
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 24,
                        fontWeight: pw.FontWeight.bold)))),
            pw.SizedBox(width: 16),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(d.nomMembre,
                    style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(color: _pdfStatutColor(d.statut),
                      borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(d.statutLabel,
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ]),
              pw.SizedBox(height: 8),
              _pdfInfoRow('Référence', d.id),
              if (d.telephone.isNotEmpty) _pdfInfoRow('Téléphone', d.telephone),
              _pdfInfoRow('Date de demande', dfmt.format(d.dateDemande)),
              if (d.dateAttributionMoto != null)
                _pdfInfoRow('Date attribution', dfmt.format(d.dateAttributionMoto!)),
            ])),
          ]),
        ),
        pw.SizedBox(height: 16),
        // Résumé financier
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
              color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RÉSUMÉ FINANCIER', style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              _pdfBox('${d.semaineCotisees} sem.', 'Semaines\ncotisées', PdfColors.blue800),
              pw.SizedBox(width: 6),
              _pdfBox('${fmt.format(d.montantCotiseTotalCFA)} CFA', 'Total\ncotisé', PdfColors.teal700),
              pw.SizedBox(width: 6),
              _pdfBox('${fmt.format(d.montantMotoEstime)} CFA', 'Prix\nmoto', PdfColors.orange700),
              pw.SizedBox(width: 6),
              _pdfBox('${fmt.format(d.montantComplement)} CFA', 'Complément\nnécessaire', PdfColors.red700),
            ]),
          ]),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
              color: PdfColors.orange800, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text('DÉTAIL DE LA DEMANDE', style: pw.TextStyle(
              color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            _pdfTableHeader(['Champ', 'Valeur'], PdfColors.orange100),
            _pdfTableRow('Moto souhaitée', d.descriptionMoto ?? 'Non précisée', false),
            _pdfTableRow('Prix moto estimé', '${fmt.format(d.montantMotoEstime)} CFA', true),
            _pdfTableRow('Total cotisé', '${fmt.format(d.montantCotiseTotalCFA)} CFA', false),
            _pdfTableRow('Complément à verser', '${fmt.format(d.montantComplement)} CFA', true),
            _pdfTableRow('Semaines cotisées', '${d.semaineCotisees} / 52', false),
            _pdfTableRow('Éligibilité',
                d.estEligible ? 'Éligible (≥ $kSeuilEligibilite semaines)'
                    : 'Non éligible (< $kSeuilEligibilite semaines)', true),
            if (d.notesAdmin != null && d.notesAdmin!.isNotEmpty)
              _pdfTableRow('Notes admin', d.notesAdmin!, false),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.orange50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.orange200)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('MONTANT COMPLÉMENT À VERSER', style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
            pw.Text('${fmt.format(d.montantComplement)} CFA', style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
          ]),
        ),
        pw.SizedBox(height: 30),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _pdfSignature('Signature du membre', d.nomMembre),
          _pdfSignature('Signature du responsable', 'Responsable Tontine'),
        ]),
      ],
    ));

    final dir   = await getTemporaryDirectory();
    final fname = 'Complement_${d.nomMembre.replaceAll(' ', '_')}_${d.id}_'
        '${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';
    final file  = File('${dir.path}/$fname');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  PdfColor _pdfStatutColor(StatutComplement s) {
    switch (s) {
      case StatutComplement.enAttente:     return PdfColors.orange700;
      case StatutComplement.approuve:      return PdfColors.blue700;
      case StatutComplement.refuse:        return PdfColors.red700;
      case StatutComplement.motoAttribuee: return PdfColors.green700;
    }
  }

  pw.Widget _pdfInfoRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(children: [
      pw.Text('$label : ', style: pw.TextStyle(
          fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
    ]),
  );

  pw.Widget _pdfBox(String val, String label, PdfColor color) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(val, style: pw.TextStyle(
            color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.white, fontSize: 7)),
      ]),
    ),
  );

  pw.TableRow _pdfTableHeader(List<String> headers, PdfColor bg) => pw.TableRow(
    decoration: pw.BoxDecoration(color: bg),
    children: headers.map((h) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    )).toList(),
  );

  pw.TableRow _pdfTableRow(String label, String value, bool alt) => pw.TableRow(
    decoration: pw.BoxDecoration(color: alt ? PdfColors.grey50 : PdfColors.white),
    children: [
      pw.Padding(padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
      pw.Padding(padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
    ],
  );

  pw.Widget _pdfSignature(String titre, String nom) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(titre, style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 40),
      pw.Container(width: 150, height: 1, color: PdfColors.grey400),
      pw.Text(nom, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ],
  );

  // ── Export PDF local ──────────────────────────────────────
  Future<void> _lancerExport(DemandeComplement d) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final file = await _genererPDF(d);
      await Printing.sharePdf(
          bytes: await file.readAsBytes(), filename: file.path.split('/').last);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur PDF : $e'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ── Export WhatsApp ───────────────────────────────────────
  Future<void> _exporterWhatsApp(DemandeComplement d) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final file = await _genererPDF(d);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Bonjour ${d.nomMembre},\n\nVeuillez trouver ci-joint votre '
            'fiche de demande de complément moto (${d.id}).\nMerci',
        subject: 'Complément Moto - ${d.nomMembre}',
      );
      if (d.telephone.isNotEmpty) {
        final raw    = d.telephone.replaceAll(RegExp(r'[^0-9]'), '');
        final intl   = raw.startsWith('0') ? '229${raw.substring(1)}' : raw;
        final waUrl  = Uri.parse('https://wa.me/$intl');
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur WhatsApp : $e'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ── Helpers widgets ───────────────────────────────────────
  Widget _dRow(IconData icon, Color color, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ])),
    ]),
  );

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
  );

  Widget _sheetLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(text, style: const TextStyle(
        fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 12)),
  );

  InputDecoration _sheetDeco(IconData icon, String hint) => InputDecoration(
    prefixIcon: Icon(icon, color: _primary, size: 20),
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2)),
  );
}