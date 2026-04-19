import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Core/Tontine_store.dart';

class CotisationsPage extends StatefulWidget {
  const CotisationsPage({super.key});
  @override
  State<CotisationsPage> createState() => _CotisationsPageState();
}

class _CotisationsPageState extends State<CotisationsPage> {
  String _filterStatut = 'Tous';
  String _searchQuery  = '';
  bool   _isLoading    = false;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _bg      = Color(0xFFF0F4F8);
  static const Color _violet  = Color(0xFF6A1B9A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final store = TontineStore();
    if (store.membres.isEmpty) await store.chargerMembres();
    if (mounted) setState(() => _isLoading = true);
    await store.chargerCotisationsSemaine();
    if (mounted) setState(() => _isLoading = false);
  }

  DateTime get _prochainSamedi {
    final now = DateTime.now();
    final d   = (DateTime.saturday - now.weekday + 7) % 7;
    return d == 0 ? now.add(const Duration(days: 7)) : now.add(Duration(days: d));
  }
  bool get _estSamediAujourdhui => DateTime.now().weekday == DateTime.saturday;

  List<Membre> get _membres =>
      TontineStore().membres.where((m) => !m.aAbandonne && m.isActive).toList();

  List<Membre> get _filtered => _membres.where((m) {
    final st = TontineStore().calculerStatut(m.id);
    return (_filterStatut == 'Tous' || st == _filterStatut) &&
        m.nom.toLowerCase().contains(_searchQuery.toLowerCase());
  }).toList();

  int get _nbPayes  => _membres.where((m) => TontineStore().calculerStatut(m.id) == 'Payé').length;
  int get _nbRetard => _membres.where((m) => TontineStore().calculerStatut(m.id) == 'En retard').length;
  int get _nbImpaye => _membres.where((m) => TontineStore().calculerStatut(m.id) == 'Impayé').length;

  // ── Encaisser (page principale) ───────────────────────────
  Future<void> _encaisser(Membre membre) async {
    final store   = TontineStore();
    final sem     = store.semaineCourante;
    final dateStr = DateFormat('dd/MM/yyyy').format(store.dateDuSamedi(sem));
    final fmt     = NumberFormat('#,###', 'fr_FR');
    if (store.aPayeSemaine(membre.id, sem)) { _showDejaPayeDialog(membre); return; }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.monetization_on_rounded, color: Colors.green),
          SizedBox(width: 10), Text("Confirmer l'encaissement"),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(membre.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200)),
            child: Column(children: [
              _confirmRow('Semaine', 'N° $sem'),
              _confirmRow('Date samedi', dateStr),
              _confirmRow('Montant', '${fmt.format(kMontantHebdo)} CFA', valueColor: Colors.green),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      await ApiService().encaisser(membreId: membre.id, numSemaine: sem);
      store.encaisserLocal(membre.id, sem);
      _showSnack('${membre.nom} — Sem.$sem encaissée ✓', Colors.green);
    } on ApiException catch (e) {
      _showSnack(e.firstError ?? e.message, Colors.red);
    } finally { setState(() => _isLoading = false); }
  }

  // ── Annuler (page principale) ─────────────────────────────
  Future<void> _annuler(Membre membre) async {
    final store = TontineStore();
    final sem   = store.semaineCourante;
    final cotId = store.getCotisationId(membre.id, sem);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.undo_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 10), const Text('Annuler ?'),
        ]),
        content: Text('Retirer l\'encaissement sem.$sem de ${membre.nom} ?\n\n'
            'La semaine restera visible dans l\'historique comme impayée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NON')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OUI, ANNULER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      if (cotId != null) await ApiService().annulerCotisation(cotId);
      store.annulerLocal(membre.id, sem);
      _showSnack('Sem.$sem marquée impayée pour ${membre.nom}', Colors.orange);
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    } finally { setState(() => _isLoading = false); }
  }

  // ── WhatsApp ──────────────────────────────────────────────
  Future<void> _ouvrirWhatsApp(
      String telephone, String nomMembre, int semaine, bool paye) async {
    final fmt    = NumberFormat('#,###', 'fr_FR');
    final raw    = telephone.replaceAll(RegExp(r'[^0-9]'), '');
    final numero = raw.startsWith('0') ? '229${raw.substring(1)}' : raw;
    final statut = paye
        ? ' Votre cotisation sem.$semaine (${fmt.format(kMontantHebdo)} CFA) est bien enregistrée.'
        : ' Votre cotisation sem.$semaine (${fmt.format(kMontantHebdo)} CFA) n\'est pas encore encaissée.';
    final message = Uri.encodeComponent('Bonjour $nomMembre,\n\n$statut\n\nMerci — MaTontine ');
    final waUrl = Uri.parse('https://wa.me/$numero?text=$message');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showSnack('Impossible d\'ouvrir WhatsApp', Colors.red);
    }
  }

  // ══════════════════════════════════════════════════════════
  // HISTORIQUE COMPLET
  // ══════════════════════════════════════════════════════════
  void _showHistorique(Membre membre) {
    final store        = TontineStore();
    final semCourante  = store.semaineCourante;
    final fmt          = NumberFormat('#,###', 'fr_FR');
    final anneeEnCours = DateTime.now().year;
    final debutAnnee   = DateFormat('dd/MM/yyyy').format(store.premierSamediJanvier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        List<Map<String, dynamic>>? historique;
        bool loading = true;

        return StatefulBuilder(
          builder: (ctx2, setModal) {
            if (loading && historique == null) {
              Future.microtask(() async {
                try {
                  final data = await ApiService().getCotisationsMembre(membre.id);
                  final rawCotisations = (data['cotisations'] as List?)
                      ?.cast<Map<String, dynamic>>() ?? [];

                  final list = rawCotisations.map((c) {
                    final s        = c['num_semaine'] as int;
                    final payeDb   = c['paye'] == true || c['statut'] == 'paye';
                    final payeLocal = store.aPayeSemaine(membre.id, s);
                    final payeFinal = payeLocal || payeDb;

                    return {
                      'semaine':       s,
                      'date_samedi':   c['date_samedi'] as String?
                          ?? DateFormat('dd/MM/yyyy').format(store.dateDuSamedi(s)),
                      'paye':          payeFinal,
                      'statut':        payeFinal ? 'paye' : 'impaye',
                      'montant':       payeFinal ? (c['montant'] as int? ?? kMontantHebdo) : 0,
                      'cotisation_id': c['id'] as int?,
                    };
                  }).toList();

                  list.sort((a, b) => (b['semaine'] as int).compareTo(a['semaine'] as int));

                  if (ctx2.mounted) {
                    setModal(() { historique = list; loading = false; });
                  }
                } catch (_) {
                  if (ctx2.mounted) setModal(() { historique = []; loading = false; });
                }
              });
            }

            final nbPayees  = historique?.where((h) => h['paye'] == true).length ?? 0;
            final nbImpayes = (historique?.length ?? 0) - nbPayees;
            final payeCourante = store.aPayeSemaine(membre.id, semCourante);

            return DraggableScrollableSheet(
              initialChildSize: 0.82, minChildSize: 0.4, maxChildSize: 0.95,
              builder: (_, ctrl) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10)))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(membre.nom,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if (loading)
                          const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      ]),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade100)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.calendar_month_rounded, size: 13, color: Colors.blue.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Historique $anneeEnCours  •  Début : $debutAnnee',
                            style: TextStyle(color: Colors.blue.shade700,
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      if (!loading)
                        Row(children: [
                          Expanded(child: _resumeBox(
                              '$nbPayees', 'Payées',
                              '${fmt.format(nbPayees * kMontantHebdo)} CFA',
                              Colors.green)),
                          const SizedBox(width: 10),
                          Expanded(child: _resumeBox(
                              '$nbImpayes', 'Impayées',
                              '${fmt.format(nbImpayes * kMontantHebdo)} CFA attendus',
                              Colors.red)),
                        ]),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: loading
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text('Chargement de l\'historique $anneeEnCours...',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ]))
                        : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: historique!.length,
                      itemBuilder: (_, i) {
                        final h           = historique![i];
                        final sem         = h['semaine'] as int;
                        final paye        = h['paye'] == true;
                        final cotId       = h['cotisation_id'] as int?;
                        final estCourante = sem == semCourante;
                        final dateStr     = h['date_samedi'] as String? ?? '';

                        final bgColor = estCourante
                            ? (paye ? Colors.green.shade50 : Colors.orange.shade50)
                            : paye ? const Color(0xFFF8FFF8) : Colors.red.shade50;

                        final borderColor = paye
                            ? Colors.green.shade200
                            : estCourante ? Colors.orange.shade300 : Colors.red.shade200;

                        final circleColor = paye
                            ? Colors.green
                            : estCourante ? Colors.orange.shade400 : Colors.red.shade400;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor,
                                width: estCourante ? 1.5 : 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Column(children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                      color: circleColor, shape: BoxShape.circle),
                                  child: Center(child: Text('$sem',
                                      style: const TextStyle(color: Colors.white,
                                          fontWeight: FontWeight.bold, fontSize: 13))),
                                ),
                                if (estCourante) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: Text('EN COURS',
                                        style: TextStyle(fontSize: 6,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade800)),
                                  ),
                                ],
                              ]),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      estCourante ? 'Semaine $sem (en cours)' : 'Semaine $sem',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13,
                                          color: estCourante
                                              ? Colors.orange.shade800 : Colors.black87),
                                    ),
                                    Row(children: [
                                      Icon(Icons.event, size: 11, color: Colors.grey.shade400),
                                      const SizedBox(width: 3),
                                      Text('Samedi $dateStr',
                                          style: TextStyle(color: Colors.grey.shade500,
                                              fontSize: 11)),
                                    ]),
                                    if (paye)
                                      Text('${fmt.format(kMontantHebdo)} CFA',
                                          style: const TextStyle(color: Colors.green,
                                              fontWeight: FontWeight.bold, fontSize: 11)),
                                    if (!paye)
                                      Text('Non encaissée',
                                          style: TextStyle(color: Colors.red.shade400,
                                              fontSize: 11)),
                                  ])),
                              const SizedBox(width: 8),
                              _buildHistoriqueAction(
                                membre:     membre,
                                sem:        sem,
                                paye:       paye,
                                cotId:      cotId,
                                setModal:   setModal,
                                historique: historique!,
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!loading && membre.telephone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _ouvrirWhatsApp(membre.telephone, membre.nom,
                                semCourante, payeCourante);
                          },
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          label: const Text('Envoyer le récapitulatif via WhatsApp',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // BOUTON ACTION DANS L'HISTORIQUE
  // ══════════════════════════════════════════════════════════
  Widget _buildHistoriqueAction({
    required Membre membre,
    required int sem,
    required bool paye,
    required int? cotId,
    required StateSetter setModal,
    required List<Map<String, dynamic>> historique,
  }) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    if (!paye) {
      return GestureDetector(
        onTap: () async {
          final store   = TontineStore();
          final dateStr = DateFormat('dd/MM/yyyy').format(store.dateDuSamedi(sem));

          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [
                Icon(Icons.monetization_on_rounded, color: Colors.green),
                SizedBox(width: 10), Text("Confirmer"),
              ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(membre.nom,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200)),
                  child: Column(children: [
                    _confirmRow('Semaine', 'N° $sem'),
                    _confirmRow('Date samedi', dateStr),
                    _confirmRow('Montant', '${fmt.format(kMontantHebdo)} CFA',
                        valueColor: Colors.green),
                  ]),
                ),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                    child: const Text('ANNULER')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('CONFIRMER', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (ok != true) return;

          setState(() => _isLoading = true);
          try {
            final res      = await ApiService().encaisser(membreId: membre.id, numSemaine: sem);
            final newCotId = res['id'] as int?;

            store.encaisserLocal(membre.id, sem);
            if (newCotId != null) store.saveCotisationId(membre.id, sem, newCotId);

            final idx = historique.indexWhere((h) => h['semaine'] == sem);
            if (idx >= 0) {
              setModal(() {
                historique[idx]['paye']         = true;
                historique[idx]['statut']        = 'paye';
                historique[idx]['montant']       = kMontantHebdo;
                historique[idx]['cotisation_id'] = newCotId;
              });
            }
            _showSnack('${membre.nom} — Sem.$sem encaissée ✓', Colors.green);
          } on ApiException catch (e) {
            _showSnack(e.firstError ?? e.message, Colors.red);
          } finally {
            setState(() => _isLoading = false);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_circle_outline_rounded, color: Colors.green.shade700, size: 15),
            const SizedBox(width: 4),
            Text('Encaisser', style: TextStyle(color: Colors.green.shade700,
                fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () async {
          final store         = TontineStore();
          final resolvedCotId = cotId ?? store.getCotisationId(membre.id, sem);

          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Icon(Icons.undo_rounded, color: Colors.orange.shade700),
                const SizedBox(width: 10), const Text('Annuler ?'),
              ]),
              content: Text('Annuler l\'encaissement sem.$sem de ${membre.nom} ?\n\n'
                  'La semaine restera visible comme impayée.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                    child: const Text('NON')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('OUI, ANNULER', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (ok != true) return;

          setState(() => _isLoading = true);
          try {
            if (resolvedCotId != null) {
              await ApiService().annulerCotisation(resolvedCotId);
            }
            store.annulerLocal(membre.id, sem);

            final idx = historique.indexWhere((h) => h['semaine'] == sem);
            if (idx >= 0) {
              setModal(() {
                historique[idx]['paye']   = false;
                historique[idx]['statut'] = 'impaye';
                historique[idx]['montant'] = 0;
              });
            }
            _showSnack('Sem.$sem marquée impayée pour ${membre.nom}', Colors.orange);
          } on ApiException catch (e) {
            _showSnack(e.message, Colors.red);
          } finally {
            setState(() => _isLoading = false);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.undo_rounded, color: Colors.orange.shade700, size: 15),
            const SizedBox(width: 4),
            Text('Annuler', style: TextStyle(color: Colors.orange.shade700,
                fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
    }
  }

  // ── Actions bottom sheet ──────────────────────────────────
  void _showActions(Membre membre) {
    final store   = TontineStore();
    final paye    = store.aPayeSemaine(membre.id, store.semaineCourante);
    final sem     = store.semaineCourante;
    final dateStr = DateFormat('dd/MM/yyyy').format(store.dateDuSamedi(sem));
    final fmt     = NumberFormat('#,###', 'fr_FR');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 16),
          Text(membre.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('${fmt.format(kMontantHebdo)} CFA / samedi',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: paye ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: paye ? Colors.green.shade200 : Colors.orange.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(paye ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: paye ? Colors.green : Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                paye
                    ? 'Sem.$sem ($dateStr) encaissée ✓'
                    : 'Sem.$sem ($dateStr) — non encaissée',
                style: TextStyle(
                    color: paye ? Colors.green.shade700 : Colors.orange.shade700,
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (!paye)
            _actionTile(Icons.check_circle_rounded, Colors.green,
                'Encaisser semaine $sem',
                '${fmt.format(kMontantHebdo)} CFA — $dateStr',
                    () { Navigator.pop(context); _encaisser(membre); }),
          if (paye)
            _actionTile(Icons.undo_rounded, Colors.orange,
                'Annuler encaissement sem.$sem',
                'Sera marquée impayée dans l\'historique',
                    () { Navigator.pop(context); _annuler(membre); }),
          _actionTile(Icons.history_rounded, Colors.blueGrey,
              'Voir l\'historique complet',
              'Toutes les semaines payées et impayées',
                  () { Navigator.pop(context); _showHistorique(membre); }),
          if (membre.telephone.isNotEmpty)
            _actionTile(Icons.send_rounded, const Color(0xFF25D366),
                'Contacter via WhatsApp', membre.telephone, () {
                  Navigator.pop(context);
                  _ouvrirWhatsApp(membre.telephone, membre.nom, sem, paye);
                }),
        ]),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TontineStore(),
      builder: (context, _) {
        final store          = TontineStore();
        final sem            = store.semaineCourante;
        final fmt            = NumberFormat('#,###', 'fr_FR');
        final pct            = sem / kTotalSemaines;
        final dateSamCourant = DateFormat('dd MMM yyyy', 'fr_FR')
            .format(store.dateDuSamedi(sem));
        final nbPayesCetteSem =
            _membres.where((m) => store.aPayeSemaine(m.id, sem)).length;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              title: const Text('Cotisations',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: _primary, centerTitle: true, elevation: 0,
              actions: [
                if (_isLoading)
                  const Padding(padding: EdgeInsets.all(16),
                      child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                else
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _charger),
              ],
            ),
            body: Column(children: [

              // ══════════════════════════════════════════════
              // HEADER COMPACTÉ — tout sur 2 lignes denses
              // ══════════════════════════════════════════════
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A148C), _violet, Color(0xFF1565C0)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24)),
                ),
                // ↓ padding réduit : était fromLTRB(20,18,20,26)
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(children: [

                  // Ligne 1 : montant + stats en une seule rangée
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Montant hebdo
                      Row(children: [
                        Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.calendar_view_week_rounded,
                                color: Colors.white, size: 16)),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${fmt.format(kMontantHebdo)} CFA',
                              style: const TextStyle(color: Colors.white, fontSize: 20,
                                  fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          const Text('par samedi  •  52 sem./an',
                              style: TextStyle(color: Colors.white70, fontSize: 9)),
                        ]),
                      ]),
                      // Stats compactes
                      Row(children: [
                        _stat(_nbPayes.toString(),  'Payés',   Colors.greenAccent.shade400),
                        _dv(),
                        _stat(_nbRetard.toString(), 'Retard',  Colors.orangeAccent),
                        _dv(),
                        _stat(_nbImpaye.toString(), 'Impayés', Colors.redAccent.shade100),
                      ]),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 8),

                  // Ligne 2 : semaine en cours + barre de progression
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Infos semaine
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.lock_clock, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Sem.$sem ($dateSamCourant) — $nbPayesCetteSem/${_membres.length} encaissés',
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            if (_estSamediAujourdhui) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text("AUJOURD'HUI !",
                                    style: TextStyle(color: Colors.greenAccent,
                                        fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              _estSamediAujourdhui
                                  ? 'Journée de collecte'
                                  : 'Prochain : ${DateFormat('dd MMM', 'fr_FR').format(_prochainSamedi)}',
                              style: const TextStyle(color: Colors.white60, fontSize: 9),
                            ),
                          ]),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      // Pourcentage + progression
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${(pct * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w900, fontSize: 18)),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text('sem.$sem/$kTotalSemaines',
                                style: const TextStyle(color: Colors.white54, fontSize: 9)),
                          ),
                        ]),
                        Text(
                          '${fmt.format(_membres.fold(0, (s, m) => s + m.totalCotiseCfa))} CFA',
                          style: const TextStyle(color: Colors.white60, fontSize: 9),
                        ),
                      ]),
                    ],
                  ),

                  const SizedBox(height: 8),
                  // Barre de progression
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: pct,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                          minHeight: 6)),
                ]),
              ),

              // Recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un membre...',
                    prefixIcon: const Icon(Icons.search, color: _violet),
                    filled: true, fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),

              // Filtres
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: Row(children: [
                  _chip('Tous', Colors.blueGrey), _chip('Payé', Colors.green),
                  _chip('En retard', Colors.orange), _chip('Impayé', Colors.red),
                ]),
              ),

              // Liste membres
              Expanded(
                child: TontineStore().isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Aucun membre trouvé',
                          style: TextStyle(color: Colors.grey.shade400)),
                    ]))
                    : ListView.builder(
                  itemCount: _filtered.length,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemBuilder: (_, i) => _buildTile(_filtered[i]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildTile(Membre membre) {
    final store  = TontineStore();
    final sem    = store.semaineCourante;
    final statut = store.calculerStatut(membre.id);
    final sc     = statut == 'Payé' ? Colors.green
        : statut == 'En retard' ? Colors.orange : Colors.red;
    final paye = store.aPayeSemaine(membre.id, sem);
    final fmt  = NumberFormat('#,###', 'fr_FR');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sc.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showActions(membre),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            Container(width: 46, height: 46,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF4A148C), _violet],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(membre.nom[0],
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(membre.nom,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: sc.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(statut, style: TextStyle(color: sc, fontSize: 9,
                          fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    if (paye)
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('Sem.$sem ✓',
                              style: const TextStyle(color: Colors.green,
                                  fontSize: 9, fontWeight: FontWeight.bold)))
                    else if (membre.semainesCotisees > 0)
                      Text('${membre.semainesCotisees} sem. payées',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                  ]),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${membre.semainesCotisees}/$kTotalSemaines',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 13, color: _violet)),
              const Text('semaines', style: TextStyle(color: Colors.grey, fontSize: 8)),
            ]),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: membre.progressionAnnuelle,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(sc), minHeight: 5)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${fmt.format(membre.totalCotiseCfa)} CFA versés',
                style: TextStyle(color: Colors.grey.shade500,
                    fontSize: 10, fontWeight: FontWeight.w500)),
            Text('${(membre.progressionAnnuelle * 100).toStringAsFixed(0)}% de l\'année',
                style: const TextStyle(color: _violet,
                    fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ])),
      ),
    );
  }

  Widget _stat(String v, String l, Color c) => Column(children: [
    Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
    Text(l, style: const TextStyle(color: Colors.white60, fontSize: 8)),
  ]);

  Widget _dv() =>
      Container(height: 22, width: 1, margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.white.withOpacity(0.2));

  Widget _chip(String label, Color color) {
    final sel = _filterStatut == label;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
            label: Text(label), selected: sel,
            onSelected: (_) => setState(() => _filterStatut = label),
            selectedColor: color.withOpacity(0.15), backgroundColor: Colors.white,
            side: BorderSide(color: sel ? color : Colors.grey.shade200),
            labelStyle: TextStyle(color: sel ? color : Colors.black87,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12)));
  }

  Widget _actionTile(IconData icon, Color color, String title,
      String subtitle, VoidCallback onTap) =>
      Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2))),
          child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20)),
              title: Text(title, style: TextStyle(color: color,
                  fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              onTap: onTap));

  Widget _confirmRow(String label, String value, {Color? valueColor}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
                fontSize: valueColor != null ? 16 : 14)),
          ]));

  Widget _resumeBox(String nb, String label, String sousTitre, Color color) =>
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(nb, style: TextStyle(fontSize: 24,
                  fontWeight: FontWeight.w900, color: color)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, color: color,
                  fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text(sousTitre,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          ]));

  void _showSnack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: color, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  void _showDejaPayeDialog(Membre membre) => showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.block_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          const Text('Déjà encaissé !',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))
        ]),
        content: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200)),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${membre.nom} a déjà cotisé pour la semaine ${TontineStore().semaineCourante}.',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Un seul encaissement par samedi est autorisé.',
                      style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                ])),
        actions: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context),
              child: const Text('COMPRIS', style: TextStyle(color: Colors.white)))
        ],
      ));
}