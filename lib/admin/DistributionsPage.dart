import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ← si pas encore importé dans main.dart
import 'package:intl/intl.dart';
import '../Core/Tontine_store.dart';

// ============================================================
// PAGE DISTRIBUTIONS — clavier isolé + validation réelle
// ============================================================

class DistributionsPage extends StatefulWidget {
  const DistributionsPage({super.key});
  @override
  State<DistributionsPage> createState() => _DistributionsPageState();
}

class _DistributionsPageState extends State<DistributionsPage> {
  // ── Formulaire ────────────────────────────────────────────
  Membre? _selectedMembre;
  bool    _isSaving   = false;

  final _montantCtrl = TextEditingController();
  final _dateCtrl    = TextEditingController();
  final _noteCtrl    = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  // ── Historique ────────────────────────────────────────────
  List<Map<String, dynamic>> _historique = [];
  bool    _isLoading = true;
  String? _error;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _bg      = Color(0xFFF4F7FA);

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (TontineStore().membres.isEmpty) await TontineStore().chargerMembres();
      await _chargerHistorique();
    });
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _dateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerHistorique() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await ApiService().getDistributions();
      final data = (res['data'] as List?) ?? (res as List?) ?? [];
      setState(() => _historique = data.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Validation et création ────────────────────────────────
  Future<void> _creerDistribution() async {
    FocusScope.of(context).unfocus();

    if (_selectedMembre == null) {
      _showErreur('Bénéficiaire manquant', 'Veuillez sélectionner un bénéficiaire avant de continuer.');
      return;
    }

    final montantStr = _montantCtrl.text.trim();
    if (montantStr.isEmpty) {
      _showErreur('Montant manquant', 'Veuillez saisir un montant pour la distribution.');
      return;
    }

    final montant = int.tryParse(montantStr.replaceAll(RegExp(r'\s'), ''));
    if (montant == null || montant <= 0) {
      _showErreur('Montant invalide',
          'Le montant saisi ("$montantStr") n\'est pas valide.\nSaisissez un nombre entier supérieur à 0.');
      return;
    }

    if (montant > 10000000) {
      _showErreur('Montant trop élevé',
          'Le montant ${NumberFormat('#,###', 'fr_FR').format(montant)} CFA semble anormalement élevé.\n'
              'Veuillez vérifier et corriger.');
      return;
    }

    final dateSaisie = _dateCtrl.text.trim();
    if (dateSaisie.isEmpty) {
      _showErreur('Date manquante', 'Veuillez saisir la date de remise au format JJ/MM/AAAA.');
      return;
    }

    DateTime? dateParsed;
    try {
      dateParsed = DateFormat('dd/MM/yyyy').parseStrict(dateSaisie);
    } catch (_) {
      _showErreur('Format de date invalide',
          '"$dateSaisie" n\'est pas une date valide.\nUtilisez le format JJ/MM/AAAA (ex: 18/04/2026).');
      return;
    }

    if (dateParsed.isAfter(DateTime.now().add(const Duration(days: 365)))) {
      _showErreur('Date dans le futur',
          'La date saisie est dans plus d\'un an. Vérifiez que la date est correcte.');
      return;
    }

    final dateApi = DateFormat('yyyy-MM-dd').format(dateParsed);
    final fmt     = NumberFormat('#,###', 'fr_FR');

    final ok = await _confirm(
      titre: 'Confirmer la distribution',
      icon:  Icons.outbox_rounded,
      color: Colors.green,
      lignes: [
        ('Bénéficiaire', _selectedMembre!.nom),
        ('Montant',      '${fmt.format(montant)} CFA'),
        ('Date',         dateSaisie),
        if (_noteCtrl.text.trim().isNotEmpty) ('Note', _noteCtrl.text.trim()),
      ],
    );
    if (!ok) return;

    setState(() => _isSaving = true);
    try {
      await ApiService().creerDistribution(
        membreId: _selectedMembre!.id,
        montant:  montant,
        date:     dateApi,
        note:     _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      _showSnack('Distribution de ${fmt.format(montant)} CFA enregistrée pour ${_selectedMembre!.nom} ✓',
          Colors.green);
      setState(() => _selectedMembre = null);
      _montantCtrl.clear();
      _noteCtrl.clear();
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      await _chargerHistorique();
    } on ApiException catch (e) {
      _showErreur('Erreur serveur', e.firstError ?? e.message);
    } catch (e) {
      _showErreur('Erreur réseau', 'Impossible de contacter le serveur.\nVérifiez votre connexion internet.\n\nDétail : $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErreur(String titre, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(titre,
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context),
            child: const Text('COMPRIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String titre,
    required IconData icon,
    required Color color,
    required List<(String, String)> lignes,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(titre,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: lignes.map((l) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l.$1, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(width: 16),
              Flexible(child: Text(l.$2,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.right)),
            ]),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  // ══════════════════════════════════════════════════════════
  // ✅ FIX : DatePicker sans locale — utilise Localizations.override
  //    pour injecter les delegates FR sans crasher si absents au niveau app.
  // ══════════════════════════════════════════════════════════
  Future<void> _pickDate() async {
    final initial = (() {
      try { return DateFormat('dd/MM/yyyy').parse(_dateCtrl.text); }
      catch (_) { return DateTime.now(); }
    })();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      // ✅ CORRECTION : on n'utilise plus `locale:` ici.
      // On injecte la localisation FR via Localizations.override dans le builder
      // pour éviter "No MaterialLocalizations found".
      builder: (ctx, child) {
        return Localizations.override(
          context: ctx,
          locale: const Locale('fr', 'FR'),
          delegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          child: Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _primary),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  // ── Picker membre ─────────────────────────────────────────
  void _showMemberPicker() {
    FocusScope.of(context).unfocus();
    String filter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setModal) {
        final store    = TontineStore();
        final membres  = store.membres.where((m) => m.isActive && !m.aAbandonne).toList();
        final filtered = membres.where((m) =>
        m.nom.toLowerCase().contains(filter.toLowerCase()) ||
            m.numRegistre.toString().contains(filter)).toList();

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.70,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 50, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text('Sélectionner un bénéficiaire',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setModal(() => filter = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: _primary),
                    hintText: 'Rechercher par nom ou n° registre...',
                    filled: true, fillColor: Colors.grey.shade50,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (store.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                Expanded(child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('Aucun membre actif trouvé',
                        style: TextStyle(color: Colors.grey.shade400)),
                  ]),
                ))
              else
                Expanded(child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (_, i) {
                    final m   = filtered[i];
                    final fmt = NumberFormat('#,###', 'fr_FR');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _primary.withOpacity(0.1),
                        child: Text(m.nom[0],
                            style: const TextStyle(color: _primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(m.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '#${m.numRegistre} • ${m.profession} • ${fmt.format(m.totalCotiseCfa)} CFA cotisés',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                      onTap: () {
                        setState(() => _selectedMembre = m);
                        Navigator.pop(context);
                      },
                    );
                  },
                )),
            ]),
          ),
        );
      }),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Distributions',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: _primary,
          centerTitle: true, elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _chargerHistorique),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(children: [
            _buildFormCard(),
            const SizedBox(height: 20),
            _buildHistorique(),
          ]),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Nouvelle distribution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
              const Divider(height: 28),

              _label('Bénéficiaire *'),
              InkWell(
                onTap: _showMemberPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _selectedMembre != null ? _primary : Colors.grey.shade300,
                        width: _selectedMembre != null ? 2 : 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.person_rounded,
                        color: _selectedMembre == null ? Colors.grey.shade400 : _primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      _selectedMembre?.nom ?? 'Sélectionner un bénéficiaire',
                      style: TextStyle(
                        color: _selectedMembre == null ? Colors.grey.shade400 : Colors.black87,
                        fontWeight: _selectedMembre == null ? FontWeight.normal : FontWeight.bold,
                      ),
                    )),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: _selectedMembre == null ? Colors.grey.shade400 : _primary),
                  ]),
                ),
              ),

              if (_selectedMembre != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '${_selectedMembre!.semainesCotisees} semaines payées  •  '
                          '${fmt.format(_selectedMembre!.totalCotiseCfa)} CFA cotisés',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12,
                          fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              ],

              const SizedBox(height: 16),

              _label('Montant (CFA) *'),
              TextFormField(
                controller: _montantCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                decoration: _inputDeco(Icons.payments_outlined, 'Ex: 300000'),
              ),

              const SizedBox(height: 16),

              _label('Date de remise *'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _dateCtrl,
                    readOnly: true,
                    decoration: _inputDeco(Icons.calendar_today_rounded, 'JJ/MM/AAAA')
                        .copyWith(suffixIcon: const Icon(Icons.edit_calendar_rounded, color: _primary)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _label('Note (optionnel)'),
              TextFormField(
                controller: _noteCtrl,
                textInputAction: TextInputAction.done,
                onEditingComplete: () => FocusScope.of(context).unfocus(),
                decoration: _inputDeco(Icons.notes_rounded, 'Motif ou commentaire...'),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_selectedMembre == null || _isSaving) ? null : _creerDistribution,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.outbox_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Enregistrement...' : 'ENREGISTRER LA DISTRIBUTION',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMembre == null ? Colors.grey : const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorique() {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.history_toggle_off_rounded, color: Colors.blueGrey.shade600, size: 22),
            const SizedBox(width: 8),
            const Text('Historique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              '${fmt.format(_historique.fold(0, (s, d) => s + (d['montant'] as int? ?? 0)))} CFA',
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_error != null)
          Center(child: Column(children: [
            Icon(Icons.wifi_off, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _chargerHistorique,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ]))
        else if (_historique.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.outbox_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Aucune distribution enregistrée',
                    style: TextStyle(color: Colors.grey.shade400)),
              ]),
            ))
          else
            ...(_historique.map((d) {
              final nom     = d['membre']?['nom'] ?? '—';
              final montant = d['montant'] as int? ?? 0;
              final date    = d['date_distribution'] ?? '';
              final note    = d['note'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade100),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                      blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.12),
                    child: Text(nom.isNotEmpty ? nom[0] : '?',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.event_rounded, size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text('Remis le $date',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    ]),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(note, style: TextStyle(color: Colors.grey.shade400,
                          fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                  ]),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${fmt.format(montant)}',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            color: Colors.green, fontSize: 15)),
                    const Text('CFA', style: TextStyle(color: Colors.green, fontSize: 9)),
                  ]),
                ),
              );
            })),

        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(text,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13)),
  );

  InputDecoration _inputDeco(IconData icon, String hint) => InputDecoration(
    prefixIcon: Icon(icon, color: _primary, size: 20),
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400),
    filled: true, fillColor: const Color(0xFFF8F9FA),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2)),
  );
}