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
import '../Core/tontine_picker_widget.dart';

// ============================================================
// PAGE MEMBRES — API intégrée + Tontine
// ============================================================

class MembresPage extends StatefulWidget {
  const MembresPage({super.key});
  @override
  State<MembresPage> createState() => _MembresPageState();
}

class _MembresPageState extends State<MembresPage> {
  String _searchQuery = '';
  String _filterType  = 'Tous';

  // ── CORRECTION : _selectedTontine au niveau de la classe, pas dans initState
  TontineModel? _selectedTontine;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _bg      = Color(0xFFF0F4F8);

  final _nomCtrl        = TextEditingController();
  final _telCtrl        = TextEditingController();
  final _adresseCtrl    = TextEditingController();
  final _professionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TontineStore().membres.isEmpty) TontineStore().chargerMembres();
      // Précharger les tontines au démarrage
      if (TontineStore().tontines.isEmpty) TontineStore().chargerTontines();
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _adresseCtrl.dispose();
    _professionCtrl.dispose();
    super.dispose();
  }

  // ── Filtre liste membres ──────────────────────────────────
  List<Membre> get _filtered {
    final store = TontineStore();
    return store.membres.where((m) {
      final matchSearch = m.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.numRegistre.toString().contains(_searchQuery);
      bool matchStatut = true;
      if (_filterType == 'Actifs')     matchStatut = m.isActive  && !m.aAbandonne;
      if (_filterType == 'Inactifs')   matchStatut = !m.isActive && !m.aAbandonne;
      if (_filterType == 'Abandonnés') matchStatut = m.aAbandonne;
      return matchSearch && matchStatut;
    }).toList();
  }

  // ── Enregistrement membre ─────────────────────────────────
  Future<void> _saveMembre([Membre? membre]) async {
    if (_nomCtrl.text.trim().isEmpty || _professionCtrl.text.trim().isEmpty) {
      _showSnack('Nom et profession obligatoires', Colors.red);
      return;
    }
    // Tontine obligatoire uniquement à la création
    if (membre == null && _selectedTontine == null) {
      _showSnack('Veuillez sélectionner une tontine', Colors.orange);
      return;
    }

    final data = {
      'nom':        _nomCtrl.text.trim(),
      'telephone':  _telCtrl.text.trim(),
      'adresse':    _adresseCtrl.text.trim(),
      'profession': _professionCtrl.text.trim(),
      if (_selectedTontine != null) 'tontine_id': _selectedTontine!.id,
    };

    try {
      if (membre == null) {
        final res       = await ApiService().creerMembre(data);
        final newMembre = Membre.fromJson(res);
        TontineStore().ajouterMembre(newMembre);
        if (mounted) {
          Navigator.pop(context);
          _showSnack(
            'Membre #${newMembre.numRegistre} — ${newMembre.tontineLabel} ✓',
            Colors.green,
          );
        }
      } else {
        final res = await ApiService().modifierMembre(membre.id, data);
        TontineStore().mettreAJourMembre(Membre.fromJson(res));
        if (mounted) {
          Navigator.pop(context);
          _showSnack('Membre mis à jour', Colors.green);
        }
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.firstError ?? e.message, Colors.red);
    }
  }

  // ── Abandon ───────────────────────────────────────────────
  Future<void> _abandonner(Membre membre) async {
    final fmt = NumberFormat('#,###', 'fr_FR');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.exit_to_app_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          const Text('Abandon confirmé ?'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${membre.nom} souhaite quitter la tontine.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: membre.perdArgentSiAbandon ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: membre.perdArgentSiAbandon
                      ? Colors.red.shade200
                      : Colors.green.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total cotisé : ${fmt.format(membre.totalCotiseCfa)} CFA',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                membre.perdArgentSiAbandon
                    ? '⚠️ < ${fmt.format(kSeuilAbandonnement)} CFA → PERD son argent'
                    : '✅ ≥ ${fmt.format(kSeuilAbandonnement)} CFA → Peut récupérer son dû',
                style: TextStyle(
                    color: membre.perdArgentSiAbandon
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res     = await ApiService().abandonnerMembre(membre.id);
      final updated = Membre.fromJson(res['membre'] ?? res);
      TontineStore().mettreAJourMembre(updated);
      if (mounted) {
        _showSnack('${membre.nom} marqué abandonné.', Colors.red.shade700);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, Colors.red);
    }
  }

  // ── Suppression ───────────────────────────────────────────
  Future<void> _supprimer(Membre membre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('supprimer ?'),
        content: Text(
            'Retirer définitivement ${membre.nom} ?\n\n'
                'Son nom restera visible dans l\'historique des sanctions et distributions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('NON')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('oui, supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().supprimerMembre(membre.id);
      TontineStore().supprimerMembre(membre.id);
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, Colors.red);
    }
  }

  // ── Formulaire création / modification ────────────────────
  void _showForm([Membre? membre]) {
    // Réinitialiser les champs
    _nomCtrl.text        = membre?.nom        ?? '';
    _telCtrl.text        = membre?.telephone  ?? '';
    _adresseCtrl.text    = membre?.adresse    ?? '';
    _professionCtrl.text = membre?.profession ?? '';
    _selectedTontine     = membre?.tontine;   // pré-remplir si modification

    // Charger les tontines si besoin
    if (TontineStore().tontines.isEmpty) {
      TontineStore().chargerTontines();
    }

    final store   = TontineStore();
    final nextNum = (store.membres.isEmpty
        ? 0
        : store.membres
        .map((m) => m.numRegistre)
        .reduce((a, b) => a > b ? a : b)) +
        1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // ── StatefulBuilder indispensable pour que setSheet() rafraîchisse
      //    le sélecteur de tontine à l'intérieur du bottom sheet
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Poignée ──────────────────────────────
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  // ── En-tête ──────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_add_rounded,
                          color: _primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            membre == null
                                ? 'Nouveau Membre'
                                : 'Modifier Membre',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primary),
                          ),
                          Text(
                            membre == null
                                ? 'N° Registre : #$nextNum — ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'
                                : 'N° Registre : #${membre.numRegistre}',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ]),
                  ]),
                  const SizedBox(height: 20),

                  // ── Champs texte ─────────────────────────
                  _fField(_nomCtrl, 'Nom Complet *', Icons.person),
                  const SizedBox(height: 12),
                  _fField(_professionCtrl, 'Profession *',
                      Icons.work_rounded),
                  const SizedBox(height: 12),
                  _fField(_telCtrl, 'Téléphone (WhatsApp) *', Icons.phone,
                      type: TextInputType.phone),
                  const SizedBox(height: 12),
                  _fField(_adresseCtrl, 'Adresse / Quartier',
                      Icons.location_on),
                  const SizedBox(height: 16),

                  // ── SÉLECTEUR TONTINE ────────────────────
                  const Text('Tontine *',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      // showTontinePicker ouvre le picker dans ctx2
                      // pour rester dans le contexte du bottom sheet
                      final t = await showTontinePicker(ctx2);
                      if (t != null) {
                        setSheet(() => _selectedTontine = t);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _selectedTontine == null
                            ? Colors.grey.shade50
                            : _selectedTontine!.categorieColor
                            .withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedTontine == null
                              ? Colors.grey.shade300
                              : _selectedTontine!.categorieColor
                              .withOpacity(0.5),
                          width: _selectedTontine == null ? 1 : 2,
                        ),
                      ),
                      child: _selectedTontine == null
                      // ── Aucune tontine ────────────────
                          ? Row(children: [
                        Icon(Icons.touch_app_rounded,
                            color: Colors.grey.shade400, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text('Sélectionner la tontine',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    'Appuyez pour choisir le montant de cotisation',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11)),
                              ]),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400),
                      ])
                      // ── Tontine sélectionnée ──────────
                          : Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: _selectedTontine!.categorieColor
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.check_circle_rounded,
                              color:
                              _selectedTontine!.categorieColor,
                              size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedTontine!.nom,
                                  style: TextStyle(
                                      color: _selectedTontine!
                                          .categorieColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                Text(
                                  '${NumberFormat('#,###', 'fr_FR').format(_selectedTontine!.montant)} F / semaine',
                                  style: TextStyle(
                                      color: _selectedTontine!
                                          .categorieColor
                                          .withOpacity(0.8),
                                      fontSize: 12),
                                ),
                              ]),
                        ),
                        // Bouton "Changer"
                        GestureDetector(
                          onTap: () async {
                            final t = await showTontinePicker(ctx2);
                            if (t != null) {
                              setSheet(() => _selectedTontine = t);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: _selectedTontine!.categorieColor
                                    .withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(8)),
                            child: Text(
                              'Changer',
                              style: TextStyle(
                                  color:
                                  _selectedTontine!.categorieColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Bouton enregistrer ───────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () => _saveMembre(membre),
                      child: Text(
                          membre == null ? 'ENREGISTRER' : 'METTRE À JOUR',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions bottom sheet ──────────────────────────────────
  void _showActions(Membre membre) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10)),
          ),
          Text(membre.nom,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          Text('#${membre.numRegistre} • ${membre.profession}',
              style:
              TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          // Badge tontine dans le menu actions
          if (membre.tontine != null) ...[
            const SizedBox(height: 4),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: membre.tontineColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.savings_rounded,
                    size: 12, color: membre.tontineColor),
                const SizedBox(width: 5),
                Text(
                  membre.tontineLabel,
                  style: TextStyle(
                      color: membre.tontineColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ],
          const Divider(height: 20),
          _aTile(Icons.account_circle_rounded, 'Voir le profil complet',
              _primary, () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MembreProfilPage(membre: membre)));
              }),
          _aTile(Icons.edit_rounded, 'Modifier', Colors.blue, () {
            Navigator.pop(context);
            _showForm(membre);
          }),
          if (!membre.aAbandonne)
            _aTile(
              membre.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_rounded,
              membre.isActive ? 'Désactiver' : 'Réactiver',
              membre.isActive ? Colors.orange : Colors.green,
                  () async {
                Navigator.pop(context);
                try {
                  if (membre.isActive) {
                    await ApiService()
                        .modifierMembre(membre.id, {'is_active': false});
                    membre.isActive = false;
                  } else {
                    await ApiService().reactiver(membre.id);
                    membre.isActive = true;
                  }
                  TontineStore().notifyListeners();
                } catch (_) {}
              },
            ),
          if (!membre.aAbandonne)
            _aTile(Icons.exit_to_app_rounded, 'Marquer comme abandonné',
                Colors.red.shade700, () {
                  Navigator.pop(context);
                  _abandonner(membre);
                }),
          _aTile(Icons.delete_forever_rounded, 'Supprimer définitivement',
              Colors.red, () {
                Navigator.pop(context);
                _supprimer(membre);
              }),
        ]),
      ),
    );
  }

  // ── BUILD PRINCIPAL ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TontineStore(),
      builder: (context, _) {
        final store       = TontineStore();
        final fmt         = NumberFormat('#,###', 'fr_FR');
        final nbActifs    = store.membres.where((m) => m.isActive && !m.aAbandonne).length;
        final nbInactifs  = store.membres.where((m) => !m.isActive && !m.aAbandonne).length;
        final nbAbandons  = store.membres.where((m) => m.aAbandonne).length;
        final totalCotise = store.membres.fold(0, (s, m) => s + m.totalCotiseCfa);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              backgroundColor: _primary,
              elevation: 0,
              centerTitle: true,
              title: const Text('Annuaire des Membres',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: store.chargerMembres),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: _primary,
              onPressed: () => _showForm(),
              icon:
              const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('NOUVEAU',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            body: Column(children: [
              // ── Header stats ──────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF1565C0),
                      Color(0xFF1976D2)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
                ),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _hStat(nbActifs.toString(), 'Actifs',
                            Colors.greenAccent),
                        _divH(),
                        _hStat(nbInactifs.toString(), 'Inactifs',
                            Colors.white70),
                        _divH(),
                        _hStat(nbAbandons.toString(), 'Abandons',
                            Colors.redAccent.shade100),
                        _divH(),
                        _hStat(store.membres.length.toString(), 'Total',
                            Colors.white),
                      ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white70,
                              size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Total cotisé : ${fmt.format(totalCotise)} CFA',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ]),
                  ),
                ]),
              ),

              // ── Recherche + filtres ───────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un nom ou n° registre...',
                        prefixIcon:
                        const Icon(Icons.search, color: _primary),
                        filled: true,
                        fillColor: const Color(0xFFF1F3F4),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                        children: ['Tous', 'Actifs', 'Inactifs', 'Abandonnés']
                            .map((type) {
                          final sel = _filterType == type;
                          Color chipColor = _primary;
                          if (type == 'Abandonnés') chipColor = Colors.red;
                          if (type == 'Inactifs') chipColor = Colors.grey;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(type),
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _filterType = type),
                              selectedColor: chipColor.withOpacity(0.15),
                              backgroundColor: Colors.grey.shade100,
                              side: BorderSide(
                                  color: sel
                                      ? chipColor
                                      : Colors.grey.shade200),
                              labelStyle: TextStyle(
                                  color: sel ? chipColor : Colors.black87,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12),
                            ),
                          );
                        }).toList()),
                  ),
                ]),
              ),

              // ── Liste ─────────────────────────────────────
              Expanded(
                child: store.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : store.errorMsg != null
                    ? Center(
                    child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off,
                              size: 48,
                              color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(store.errorMsg!,
                              style: TextStyle(
                                  color: Colors.grey.shade500)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: store.chargerMembres,
                              child: const Text('Réessayer')),
                        ]))
                    : _filtered.isEmpty
                    ? Center(
                    child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off_rounded,
                              size: 60,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Aucun membre trouvé',
                              style: TextStyle(
                                  color: Colors.grey.shade400)),
                        ]))
                    : RefreshIndicator(
                  onRefresh: store.chargerMembres,
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    padding: const EdgeInsets.fromLTRB(
                        15, 10, 15, 100),
                    itemBuilder: (_, i) =>
                        _buildCard(_filtered[i]),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── Carte membre ──────────────────────────────────────────
  Widget _buildCard(Membre membre) {
    final fmt        = NumberFormat('#,###', 'fr_FR');
    final estAbandon = membre.aAbandonne;
    final borderColor = estAbandon
        ? Colors.red.shade300
        : membre.isActive
        ? Colors.green.withOpacity(0.3)
        : Colors.grey.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: estAbandon ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MembreProfilPage(membre: membre))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // ── Ligne principale ────────────────────────────
            Row(children: [
              // Avatar + numéro
              Stack(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: estAbandon
                              ? [
                            Colors.red.shade400,
                            Colors.red.shade600
                          ]
                              : membre.isActive
                              ? [_primary, const Color(0xFF0288D1)]
                              : [
                            Colors.grey.shade400,
                            Colors.grey.shade500
                          ])),
                  child: Center(
                      child: Text(membre.nom[0],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20))),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border:
                        Border.all(color: Colors.grey.shade200)),
                    child: Text('#${membre.numRegistre}',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600)),
                  ),
                ),
              ]),
              const SizedBox(width: 12),

              // Infos texte
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + badge statut
                      Row(children: [
                        Expanded(
                            child: Text(membre.nom,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color:
                              membre.statutColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(membre.statutLabel,
                              style: TextStyle(
                                  color: membre.statutColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 2),

                      // Profession • adresse
                      Text(
                        '${membre.profession} • ${membre.adresse}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Badge tontine ← NOUVEAU (après profession/adresse)
                      if (membre.tontine != null)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: membre.tontineColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.savings_rounded,
                                size: 10, color: membre.tontineColor),
                            const SizedBox(width: 4),
                            Text(
                              '${fmt.format(membre.montantCotisation)} F/sem',
                              style: TextStyle(
                                  color: membre.tontineColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ),

                      const SizedBox(height: 2),

                      // Date inscription
                      Row(children: [
                        Icon(Icons.event_rounded,
                            size: 10, color: Colors.blue.shade300),
                        const SizedBox(width: 3),
                        Text(
                          'Inscrit le ${membre.dateInscription}',
                          style: TextStyle(
                              color: Colors.blue.shade400,
                              fontSize: 9,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ]),
              ),

              IconButton(
                  icon: Icon(Icons.more_vert,
                      color: Colors.grey.shade400),
                  onPressed: () => _showActions(membre)),
            ]),

            const SizedBox(height: 10),

            // ── Barre de progression ────────────────────────
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: membre.progressionAnnuelle,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              estAbandon
                                  ? Colors.red.shade400
                                  : membre.isActive
                                  ? Colors.green
                                  : Colors.grey),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${membre.semainesCotisees}/$kTotalSemaines sem.  •  ${fmt.format(membre.totalCotiseCfa)} CFA',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
              ),
              const SizedBox(width: 10),
              if (membre.estEligibleMoto && !estAbandon)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                      color:
                      const Color(0xFFE65100).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.two_wheeler_rounded,
                        color: Color(0xFFE65100), size: 12),
                    SizedBox(width: 3),
                    Text('Moto ✓',
                        style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),

            // ── Alerte abandon ──────────────────────────────
            if (estAbandon && membre.perdArgentSiAbandon)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'A cotisé ${fmt.format(membre.totalCotiseCfa)} CFA '
                          '< ${fmt.format(kSeuilAbandonnement)} CFA → perd son argent',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  // ── Widgets helpers ───────────────────────────────────────
  Widget _hStat(String v, String l, Color c) => Column(children: [
    Text(v,
        style: TextStyle(
            color: c, fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(l,
        style:
        const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);

  Widget _divH() => Container(
      height: 28,
      width: 1,
      color: Colors.white.withOpacity(0.2));

  Widget _aTile(
      IconData icon, String title, Color color, VoidCallback onTap) =>
      ListTile(
          leading: Icon(icon, color: color),
          title: Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600)),
          onTap: onTap);

  Widget _fField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _primary),
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2)),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ============================================================
// PAGE PROFIL COMPLET — Cotisations payées ET impayées + PDF
// ============================================================

class MembreProfilPage extends StatefulWidget {
  final Membre membre;
  const MembreProfilPage({super.key, required this.membre});
  @override
  State<MembreProfilPage> createState() => _MembreProfilPageState();
}

class _MembreProfilPageState extends State<MembreProfilPage> {
  Map<String, dynamic>? _data;
  bool _isLoading       = true;
  bool _isGeneratingPdf = false;

  static const Color _primary  = Color(0xFF1565C0);
  static const Color _whatsapp = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);
    try {
      _data = await ApiService().getMembre(widget.membre.id);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  // ── Accesseurs données API ────────────────────────────────
  List<Map<String, dynamic>> get _toutesLesCotisations =>
      ((_data?['membre']?['cotisations'] ?? _data?['cotisations'])
      as List? ??
          [])
          .cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _cotisationsPayees =>
      _toutesLesCotisations
          .where((c) => c['statut'] == 'paye' || c['paye'] == true)
          .toList();

  List<Map<String, dynamic>> get _cotisationsImpayes =>
      _toutesLesCotisations
          .where((c) => c['statut'] == 'impaye' || c['paye'] == false)
          .toList();

  List<Map<String, dynamic>> get _distributions =>
      ((_data?['membre']?['distributions'] ?? _data?['distributions'])
      as List? ??
          [])
          .cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _sanctions =>
      ((_data?['membre']?['sanctions'] ?? _data?['sanctions'])
      as List? ??
          [])
          .cast<Map<String, dynamic>>();

  // ── Montant propre au membre (depuis son tontine) ─────────
  // Utilise le montant réel du membre ; fallback kMontantHebdo
  int get _montantMembre => widget.membre.montantCotisation;

  int get _totalCotisPaye =>
      _cotisationsPayees.fold(
          0, (s, c) => s + (c['montant'] as int? ?? _montantMembre));

  // ── Génération PDF ────────────────────────────────────────
  Future<File> _genererPDF({String type = 'complet'}) async {
    final membre = widget.membre;
    final doc    = pw.Document();
    final fmt    = NumberFormat('#,###', 'fr_FR');
    final now    = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());

    final totalDistrib   = _distributions.fold(0, (s, d) => s + (d['montant'] as int? ?? 0));
    final totalSanctions = _sanctions.fold(0, (s, s2) => s + (s2['montant'] as int? ?? 0));
    final nbSemPayees    = _cotisationsPayees.length;
    final nbSemImpayes   = _cotisationsImpayes.length;
    final totalPayeReel  = _totalCotisPaye;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue800, width: 2))),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('J-SOLUTION',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800)),
                    pw.Text('Généré le $now',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                  ]),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                    color: PdfColors.blue800,
                    borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text(
                  type == 'complet' ? 'DOSSIER COMPLET' : type.toUpperCase(),
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            ]),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey500)),
      ),
      build: (ctx) => [
        // ─ Fiche identité ──────────────────────────────────
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColors.blue200),
          ),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 60, height: 60,
                  decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      shape: pw.BoxShape.circle),
                  child: pw.Center(
                      child: pw.Text(membre.nom[0],
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 26,
                              fontWeight: pw.FontWeight.bold))),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                              mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(membre.nom,
                                    style: pw.TextStyle(
                                        fontSize: 18,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: pw.BoxDecoration(
                                    color: membre.isActive
                                        ? PdfColors.green100
                                        : PdfColors.red100,
                                    borderRadius:
                                    pw.BorderRadius.circular(6),
                                  ),
                                  child: pw.Text(membre.statutLabel,
                                      style: pw.TextStyle(
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          color: membre.isActive
                                              ? PdfColors.green800
                                              : PdfColors.red800)),
                                ),
                              ]),
                          pw.SizedBox(height: 6),
                          _pdfRow('N° Registre', '#${membre.numRegistre}'),
                          _pdfRow('Profession', membre.profession),
                          _pdfRow('Téléphone', membre.telephone),
                          _pdfRow('Adresse', membre.adresse),
                          _pdfRow('Inscription', membre.dateInscription),
                          // ← NOUVEAU : tontine dans la fiche PDF
                          if (membre.tontine != null)
                            _pdfRow('Tontine de ', '${membre.tontineLabel} / semaine'),
                        ])),
              ]),
        ),

        // ─ Résumé financier ────────────────────────────────
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RÉSUMÉ FINANCIER',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700)),
                pw.SizedBox(height: 10),
                pw.Row(children: [
                  _pdfBox('$nbSemPayees payées', 'Semaines', PdfColors.teal700),
                  pw.SizedBox(width: 6),
                  _pdfBox('$nbSemImpayes impayées', 'Semaines', PdfColors.red400),
                  pw.SizedBox(width: 6),
                  _pdfBox('${fmt.format(totalPayeReel)} CFA', 'Cotisations versées', PdfColors.blue800),
                  pw.SizedBox(width: 6),
                  _pdfBox('${fmt.format(totalDistrib)} CFA', 'Distributions', PdfColors.green700),
                ]),
                if (membre.aAbandonne) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                        color: PdfColors.red100,
                        borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Text(
                      membre.perdArgentSiAbandon
                          ? '⚠ MEMBRE ABANDONNÉ — A cotisé ${fmt.format(membre.totalCotiseCfa)} CFA → PERD SON ARGENT'
                          : '⚠ MEMBRE ABANDONNÉ — Peut récupérer son dû.',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900),
                    ),
                  ),
                ],
              ]),
        ),

        // ─ Cotisations PAYÉES ───────────────────────────────
        if ((type == 'complet' || type == 'cotisations') &&
            _cotisationsPayees.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          // ← CORRECTION : utilise le montant du membre, pas kMontantHebdo
          _pdfSectionTitle(
            'COTISATIONS PAYÉES ($nbSemPayees sem. × ${fmt.format(_montantMembre)} F)',
            PdfColors.teal700,
          ),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: ['Semaine', 'Date samedi', 'Montant'],
            rows: _cotisationsPayees
                .map((c) => [
              'Sem. ${c['num_semaine'] ?? '—'}',
              c['date_samedi']?.toString() ?? '—',
              '${fmt.format(c['montant'] ?? _montantMembre)} CFA',
            ])
                .toList(),
          ),
          pw.SizedBox(height: 6),
          _pdfTotalRow('TOTAL COTISATIONS PAYÉES',
              '${fmt.format(totalPayeReel)} CFA',
              PdfColors.teal800, PdfColors.teal50, PdfColors.teal200),
        ],

        // ─ Semaines IMPAYÉES ────────────────────────────────
        if ((type == 'complet' || type == 'cotisations') &&
            _cotisationsImpayes.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _pdfSectionTitle(
              'SEMAINES NON ENCAISSÉES ($nbSemImpayes sem.)',
              PdfColors.red700),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: ['Semaine', 'Date samedi', 'Statut'],
            rows: _cotisationsImpayes
                .map((c) => [
              'Sem. ${c['num_semaine'] ?? '—'}',
              c['date_samedi']?.toString() ?? '—',
              'Non encaissée',
            ])
                .toList(),
            statusColIndex: 2,
          ),
          pw.SizedBox(height: 6),
          // ← CORRECTION : montant non perçu selon le montant du membre
          _pdfTotalRow(
              'MONTANT NON PERÇU',
              '${fmt.format(nbSemImpayes * _montantMembre)} CFA attendus',
              PdfColors.red800, PdfColors.red50, PdfColors.red200),
        ],

        // ─ Distributions ────────────────────────────────────
        if ((type == 'complet' || type == 'distributions') &&
            _distributions.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _pdfSectionTitle('DISTRIBUTIONS', PdfColors.green700),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: ['Date', 'Note', 'Montant'],
            rows: _distributions
                .map((d) => [
              d['date_distribution']?.toString() ?? '—',
              d['note']?.toString() ?? '—',
              '${fmt.format(d['montant'] ?? 0)} CFA',
            ])
                .toList(),
          ),
          pw.SizedBox(height: 6),
          _pdfTotalRow(
              'TOTAL DISTRIBUTIONS',
              '${fmt.format(totalDistrib)} CFA',
              PdfColors.green800, PdfColors.green50, PdfColors.green200),
        ],

        // ─ Sanctions ────────────────────────────────────────
        if ((type == 'complet' || type == 'sanctions') &&
            _sanctions.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _pdfSectionTitle('SANCTIONS', PdfColors.red700),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: ['Date', 'Motif', 'Montant', 'Statut'],
            rows: _sanctions
                .map((s) => [
              s['date_sanction']?.toString() ?? '—',
              (s['motif']?.toString() ?? '')
                  .replaceAll('_', ' '),
              '${fmt.format(s['montant'] ?? 0)} CFA',
              s['statut'] == 'paye' ? 'Payé' : 'En attente',
            ])
                .toList(),
            statusColIndex: 3,
          ),
          pw.SizedBox(height: 6),
          _pdfTotalRow(
              'TOTAL SANCTIONS',
              '${fmt.format(totalSanctions)} CFA',
              PdfColors.red800, PdfColors.red50, PdfColors.red200),
        ],
      ],
    ));

    final dir      = await getTemporaryDirectory();
    final filename = '${membre.nom.replaceAll(' ', '_')}_N${membre.numRegistre}_$type'
        '_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ── PDF helpers ───────────────────────────────────────────
  pw.Widget _pdfRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(children: [
      pw.Text('$label : ',
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700)),
      pw.Expanded(
          child: pw.Text(value,
              style: const pw.TextStyle(fontSize: 10))),
    ]),
  );

  pw.Widget _pdfBox(String val, String label, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(val,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(label,
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 7)),
              ]),
        ),
      );

  pw.Widget _pdfSectionTitle(String title, PdfColor color) =>
      pw.Container(
        padding:
        const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(title,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _pdfTable(
      {required List<String> headers,
        required List<List<String>> rows,
        int? statusColIndex}) {
    return pw.Table(
      border:
      pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration:
          const pw.BoxDecoration(color: PdfColors.blue100),
          children: headers
              .map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(h,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9)),
          ))
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final i   = entry.key;
          final row = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i % 2 == 0
                    ? PdfColors.white
                    : PdfColors.grey50),
            children: row.asMap().entries.map((e) {
              final isStatus =
                  statusColIndex != null && e.key == statusColIndex;
              PdfColor tc = PdfColors.black;
              if (isStatus) {
                if (e.value == 'Payé') tc = PdfColors.green700;
                if (e.value == 'En attente') tc = PdfColors.orange700;
                if (e.value == 'Non encaissée') tc = PdfColors.red700;
              }
              return pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(e.value,
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: tc,
                        fontWeight: isStatus
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal)),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  pw.Widget _pdfTotalRow(String label, String value,
      PdfColor textColor, PdfColor bg, PdfColor border) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: border)),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor)),
            ]),
      );

  // ── Export & partage ──────────────────────────────────────
  Future<void> _exporterEtPartager(
      {required String type, required bool viaWhatsApp}) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final file = await _genererPDF(type: type);
      if (viaWhatsApp) {
        final tel    = widget.membre.telephone.replaceAll(RegExp(r'[^0-9]'), '');
        final numero = tel.startsWith('0') ? '229${tel.substring(1)}' : tel;
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
          'Bonjour ${widget.membre.nom},\nVeuillez trouver ci-joint votre relevé de tontine.\nMerci 🙏',
          subject: 'Relevé Tontine — ${widget.membre.nom}',
        );
        final waUrl = Uri.parse('https://wa.me/$numero');
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        await Printing.sharePdf(
            bytes: await file.readAsBytes(),
            filename: file.path.split('/').last);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color:
                  const Color(0xFFE65100).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: Color(0xFFE65100), size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exporter PDF',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                      '${widget.membre.nom} — #${widget.membre.numRegistre}',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11)),
                ]),
          ]),
          const SizedBox(height: 20),
          _exportTile('Dossier complet', Icons.folder_rounded,
              'Cotisations (payées + impayées) + Distributions + Sanctions',
              Colors.blue, () => _lancerExport('complet')),
          _exportTile('Cotisations uniquement',
              Icons.monetization_on_rounded,
              'Payées et non encaissées + totaux', Colors.teal,
                  () => _lancerExport('cotisations')),
          _exportTile('Distributions uniquement',
              Icons.account_balance_wallet_rounded, 'Montants reçus',
              Colors.green, () => _lancerExport('distributions')),
          _exportTile('Sanctions uniquement', Icons.gavel_rounded,
              'Amendes et pénalités', Colors.red,
                  () => _lancerExport('sanctions')),
        ]),
      ),
    );
  }

  Widget _exportTile(String title, IconData icon, String subtitle,
      Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: ListTile(
        leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle,
            style:
            TextStyle(color: Colors.grey.shade500, fontSize: 10)),
        trailing: Icon(Icons.chevron_right_rounded, color: color),
        onTap: onTap,
      ),
    );
  }

  void _lancerExport(String type) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          const Text('Comment envoyer le PDF ?',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Text('WhatsApp : ${widget.membre.telephone}',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _whatsapp,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: _isGeneratingPdf
                  ? null
                  : () async {
                Navigator.pop(context);
                await _exporterEtPartager(
                    type: type, viaWhatsApp: true);
              },
              icon: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
              label: const Text('Envoyer via WhatsApp',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE65100)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: _isGeneratingPdf
                  ? null
                  : () async {
                Navigator.pop(context);
                await _exporterEtPartager(
                    type: type, viaWhatsApp: false);
              },
              icon: const Icon(Icons.download_rounded,
                  color: Color(0xFFE65100)),
              label: const Text('Télécharger / Imprimer',
                  style: TextStyle(
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── BUILD PROFIL ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final m   = widget.membre;
    final fmt = NumberFormat('#,###', 'fr_FR');
    final pct = m.progressionAnnuelle;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280, // légèrement agrandi pour la tontine
          pinned: true,
          backgroundColor: _primary,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
          actions: [
            _isGeneratingPdf
                ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
                : IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.white),
                onPressed: _showExportOptions),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF1565C0),
                      Color(0xFF0288D1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2.5)),
                        child: Center(
                            child: Text(m.nom[0],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(m.nom,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text(m.profession,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(children: [
                                _pill('#${m.numRegistre}',
                                    Icons.badge_rounded),
                                const SizedBox(width: 6),
                                _pill(m.statutLabel, Icons.circle,
                                    color: m.statutColor),
                              ]),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: 10),

                    // ← NOUVEAU : badge tontine dans le header profil
                    if (m.tontine != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.savings_rounded,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                '${m.tontineLabel} — ${fmt.format(m.montantCotisation)} F/sem',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ]),
                      ),

                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          _pill('Inscrit le ${m.dateInscription}',
                              Icons.event_rounded),
                          _pill('Tél: ${m.telephone}', Icons.phone),
                        ]),
                    const SizedBox(height: 12),
                    Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${m.semainesCotisees}/$kTotalSemaines semaines',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Text(
                              '${fmt.format(m.totalCotiseCfa)} CFA cotisés',
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor:
                          Colors.white.withOpacity(0.2),
                          valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              Colors.greenAccent),
                          minHeight: 7),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _isLoading
              ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()))
              : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.aAbandonne)
                    _alertCard(
                        Icons.exit_to_app_rounded,
                        Colors.red.shade700,
                        'Membre abandonné',
                        m.perdArgentSiAbandon
                            ? 'A cotisé ${fmt.format(m.totalCotiseCfa)} CFA (< ${fmt.format(kSeuilAbandonnement)} CFA). Perd son argent.'
                            : 'A cotisé ${fmt.format(m.totalCotiseCfa)} CFA. Peut récupérer son dû.'),
                  if (m.estEligibleMoto && !m.aAbandonne)
                    _alertCard(
                        Icons.two_wheeler_rounded,
                        const Color(0xFFE65100),
                        'Éligible au complément moto',
                        '${m.semainesCotisees} semaines cotisées (≥ $kSeuilEligibilite). Ce membre peut faire une demande.'),
                  const SizedBox(height: 16),

                  // ── Cotisations payées ──────────────────
                  _sectionHeader(
                      'Cotisations payées (${_cotisationsPayees.length})',
                      Icons.check_circle_rounded,
                      Colors.teal),
                  const SizedBox(height: 8),
                  _exportRow('cotisations', Colors.teal),
                  const SizedBox(height: 8),
                  if (_cotisationsPayees.isEmpty)
                    _emptyCard('Aucune cotisation payée')
                  else
                    ..._cotisationsPayees.map((c) => _simpleCard(
                      Icons.calendar_view_week_rounded,
                      const Color(0xFF6A1B9A),
                      'Semaine ${c['num_semaine']} — ${c['date_samedi'] ?? ''}',
                      'Payé ✓',
                      Colors.green,
                      '${fmt.format(c['montant'] ?? _montantMembre)} CFA',
                      Colors.green,
                    )),
                  if (_cotisationsPayees.isNotEmpty)
                    _totalRow('Total payé',
                        fmt.format(_totalCotisPaye), Colors.teal),

                  const SizedBox(height: 16),

                  // ── Semaines impayées ───────────────────
                  _sectionHeader(
                      'Semaines non encaissées (${_cotisationsImpayes.length})',
                      Icons.radio_button_unchecked,
                      Colors.red),
                  const SizedBox(height: 8),
                  if (_cotisationsImpayes.isEmpty)
                    _emptyCard(
                        'Toutes les semaines sont encaissées ✓')
                  else
                    ..._cotisationsImpayes.map((c) => _simpleCard(
                      Icons.calendar_view_week_rounded,
                      Colors.red.shade300,
                      'Semaine ${c['num_semaine']} — ${c['date_samedi'] ?? ''}',
                      'Non encaissée',
                      Colors.red.shade400,
                      '0 CFA',
                      Colors.red.shade400,
                    )),
                  // ← CORRECTION : montant non perçu selon le membre
                  if (_cotisationsImpayes.isNotEmpty)
                    _totalRow(
                        'Montant non perçu',
                        fmt.format(
                            _cotisationsImpayes.length * _montantMembre),
                        Colors.red),

                  const SizedBox(height: 20),

                  // ── Distributions ───────────────────────
                  _sectionHeader('Distributions',
                      Icons.account_balance_wallet_rounded,
                      Colors.green),
                  const SizedBox(height: 8),
                  _exportRow('distributions', Colors.green),
                  const SizedBox(height: 8),
                  if (_distributions.isEmpty)
                    _emptyCard('Aucune distribution')
                  else
                    ..._distributions.map((d) => _simpleCard(
                      Icons.outbox_rounded,
                      Colors.green,
                      d['note'] ?? 'Distribution',
                      'Le ${d['date_distribution'] ?? ''}',
                      Colors.grey.shade500,
                      '${fmt.format(d['montant'] ?? 0)} CFA',
                      Colors.green.shade700,
                    )),
                  if (_distributions.isNotEmpty)
                    _totalRow(
                        'Total reçu',
                        fmt.format(_distributions.fold(
                            0,
                                (s, d) =>
                            s + (d['montant'] as int? ?? 0))),
                        Colors.green),

                  const SizedBox(height: 20),

                  // ── Sanctions ───────────────────────────
                  _sectionHeader('Sanctions', Icons.gavel_rounded,
                      Colors.red),
                  const SizedBox(height: 8),
                  _exportRow('sanctions', Colors.red),
                  const SizedBox(height: 8),
                  if (_sanctions.isEmpty)
                    _emptyCard('Aucune sanction')
                  else
                    ..._sanctions.map((s) {
                      final isPaid = s['statut'] == 'paye';
                      final motif =
                      (s['motif'] as String? ?? '')
                          .replaceAll('_', ' ');
                      return _simpleCard(
                        Icons.gavel_rounded,
                        isPaid ? Colors.green : Colors.red,
                        motif,
                        '${s['date_sanction'] ?? ''} • ${isPaid ? 'Payé' : 'En attente'}',
                        Colors.grey.shade500,
                        '${fmt.format(s['montant'] ?? 0)} CFA',
                        Colors.red,
                      );
                    }),
                  if (_sanctions.isNotEmpty)
                    _totalRow(
                        'Total sanctions',
                        fmt.format(_sanctions.fold(
                            0,
                                (s, s2) =>
                            s + (s2['montant'] as int? ?? 0))),
                        Colors.red),

                  const SizedBox(height: 80),
                ]),
          ),
        ),
      ]),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'wa',
              backgroundColor: _whatsapp,
              mini: true,
              onPressed: _showExportOptions,
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
              heroTag: 'pdf',
              backgroundColor: const Color(0xFFE65100),
              onPressed:
              _isGeneratingPdf ? null : _showExportOptions,
              icon: _isGeneratingPdf
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.white),
              label: Text(
                  _isGeneratingPdf ? 'Génération...' : 'Exporter PDF',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
    );
  }

  Widget _pill(String text, IconData icon, {Color? color}) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color ?? Colors.white70, size: 11),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _alertCard(IconData icon, Color color, String title,
      String message) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(message,
                            style: TextStyle(
                                color: color.withOpacity(0.8), fontSize: 11)),
                      ])),
            ]),
      );

  Widget _sectionHeader(
      String title, IconData icon, Color color) =>
      Row(children: [
        Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color)),
      ]);

  Widget _exportRow(String type, Color color) =>
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _lancerExport(type),
              icon: Icon(Icons.picture_as_pdf_rounded,
                  color: color, size: 15),
              label: Text('PDF',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            )),
        const SizedBox(width: 8),
        Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _lancerExport(type),
              icon: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 15),
              label: const Text('WhatsApp',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _whatsapp,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            )),
      ]);

  Widget _simpleCard(
      IconData icon,
      Color iconColor,
      String title,
      String subtitle,
      Color subtitleColor,
      String trailing,
      Color trailingColor) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ]),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 16)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(subtitle,
                        style:
                        TextStyle(color: subtitleColor, fontSize: 10)),
                  ])),
          Text(trailing,
              style: TextStyle(
                  color: trailingColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
      );

  Widget _totalRow(String label, String value, Color color) =>
      Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5)),
              Text('$value CFA',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ]),
      );

  Widget _emptyCard(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12)),
    child: Center(
        child: Text(msg,
            style: TextStyle(
                color: Colors.grey.shade400, fontSize: 12))),
  );
}