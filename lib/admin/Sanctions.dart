import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Core/Tontine_store.dart';

class SanctionsPage extends StatefulWidget {
  const SanctionsPage({super.key});
  @override
  State<SanctionsPage> createState() => _SanctionsPageState();
}

class _SanctionsPageState extends State<SanctionsPage> {
  Membre? _selectedMembre;
  String? _selectedMotif;
  bool    _isSaving   = false;
  final _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _sanctions = [];
  bool    _isLoading = true;
  String? _error;

  static const Color _redDark = Color(0xFFB71C1C);
  static const Color _bg      = Color(0xFFF0F4F8);

  final List<Map<String, dynamic>> _motifs = [
    {'label': 'Absence non justifiée', 'api_key': 'absence_non_justifiee', 'montant': kSanctionAbsence, 'icon': Icons.person_off_rounded,    'color': Colors.red},
    {'label': 'Retard réunion',         'api_key': 'retard_reunion',        'montant': kSanctionRetard,  'icon': Icons.access_time_rounded,    'color': Colors.orange},
    {'label': 'Retard cotisation',      'api_key': 'retard_cotisation',     'montant': kSanctionRetard,  'icon': Icons.monetization_on_rounded,'color': Colors.deepOrange},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (TontineStore().membres.isEmpty) await TontineStore().chargerMembres();
      await _chargerSanctions();
    });
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _chargerSanctions() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await ApiService().getSanctions();
      final data = (res['data'] as List?) ?? (res as List?) ?? [];
      setState(() => _sanctions = data.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _montantDuMotif {
    if (_selectedMotif == null) return 0;
    return _motifs.firstWhere((m) => m['api_key'] == _selectedMotif,
        orElse: () => {'montant': 0})['montant'] as int;
  }

  Future<void> _appliquerSanction() async {
    // ✅ Ferme le clavier avant tout
    FocusScope.of(context).unfocus();
    if (_selectedMembre == null || _selectedMotif == null) return;

    final fmt        = NumberFormat('#,###', 'fr_FR');
    final motifLabel = _motifs.firstWhere((m) => m['api_key'] == _selectedMotif)['label'] as String;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.gavel_rounded, color: _redDark),
          SizedBox(width: 10), Text('Confirmer'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dRow('Membre',  _selectedMembre!.nom),
          _dRow('Motif',   motifLabel),
          _dRow('Montant', '${fmt.format(_montantDuMotif)} CFA'),
          _dRow('Date',    DateFormat('dd/MM/yyyy').format(DateTime.now())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _redDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;

    setState(() => _isSaving = true);
    try {
      await ApiService().creerSanction(
        membreId: _selectedMembre!.id,
        motif:    _selectedMotif!,
        notes:    _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      _showSnack('Sanction de ${fmt.format(_montantDuMotif)} CFA enregistrée', _redDark);
      setState(() { _selectedMembre = null; _selectedMotif = null; });
      _noteCtrl.clear();
      await _chargerSanctions();
    } on ApiException catch (e) {
      _showSnack(e.firstError ?? e.message, Colors.red);
    } catch (_) {
      _showSnack('Erreur réseau', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _marquerPaye(Map<String, dynamic> s) async {
    final nom = s['membre']?['nom'] ?? '—';
    final ok  = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sanction payée ?'),
        content: Text('$nom a réglé sa sanction ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NON')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OUI, CONFIRMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await ApiService().marquerSanctionPayee(s['id'] as int);
      setState(() => s['statut'] = 'paye');
      _showSnack('Sanction marquée comme payée ✓', Colors.green);
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  void _showSnack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  // ── Picker membre ─────────────────────────────────────────
  void _showMemberPicker() {
    // ✅ Ferme le clavier avant d'ouvrir le picker
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
          // ✅ Le bottom sheet remonte avec le clavier interne
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const Padding(padding: EdgeInsets.all(16),
                  child: Text('Sanctionner un membre',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setModal(() => filter = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: _redDark),
                    hintText: 'Rechercher...',
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
                Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('Aucun membre trouvé', style: TextStyle(color: Colors.grey.shade400)),
                ])))
              else
                Expanded(child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.red.shade50,
                          child: Text(m.nom[0],
                              style: TextStyle(color: _redDark, fontWeight: FontWeight.bold))),
                      title: Text(m.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('#${m.numRegistre} • ${m.profession}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      onTap: () { setState(() => _selectedMembre = m); Navigator.pop(context); },
                    );
                  },
                )),
            ]),
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // ✅ GestureDetector : tape partout → ferme le clavier
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        // ✅ CRITIQUE : le clavier ne pousse plus le contenu
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Gestion des Sanctions',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: _redDark,
          centerTitle: true, elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _chargerSanctions),
          ],
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        ),
        // ✅ Scroll global — padding bas dynamique selon clavier
        body: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          // ✅ Glisser vers le bas ferme le clavier
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildBareme(),
            const SizedBox(height: 16),
            _sectionTitle('Appliquer une sanction', Icons.gavel_rounded),
            const SizedBox(height: 10),
            _buildFormulaire(),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _sectionTitle('Historique sanctions', Icons.history_rounded),
              _buildResumeStats(),
            ]),
            const SizedBox(height: 8),
            _buildHistorique(),
          ]),
        ),
      ),
    );
  }

  Widget _buildBareme() {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFF8F5)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_rounded, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Text('Barème des sanctions',
              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Row(children: _motifs.map((m) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (m['color'] as Color).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (m['color'] as Color).withOpacity(0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(m['icon'] as IconData, color: m['color'] as Color, size: 18),
              const SizedBox(height: 4),
              Text(m['label'].toString().split(' ').first,
                  style: TextStyle(color: m['color'] as Color, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('${fmt.format(m['montant'])} CFA',
                  style: TextStyle(color: m['color'] as Color, fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
          ),
        ))).toList()),
      ]),
    );
  }

  Widget _buildFormulaire() {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        _formLabel('Membre sanctionné'),
        GestureDetector(
          onTap: _showMemberPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _selectedMembre != null ? _redDark : Colors.grey.shade300),
              color: const Color(0xFFF8F9FA),
            ),
            child: Row(children: [
              Icon(Icons.person_search_rounded, color: _selectedMembre != null ? _redDark : Colors.grey),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _selectedMembre?.nom ?? 'Choisir le membre...',
                style: TextStyle(
                  color: _selectedMembre != null ? Colors.black : Colors.grey.shade600,
                  fontWeight: _selectedMembre != null ? FontWeight.bold : FontWeight.normal, fontSize: 15,
                ),
              )),
              const Icon(Icons.arrow_drop_down),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        _formLabel('Motif de sanction'),
        ..._motifs.map((motif) {
          final isSelected = _selectedMotif == motif['api_key'];
          final Color mc   = motif['color'] as Color;
          return GestureDetector(
            onTap: () => setState(() => _selectedMotif = motif['api_key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? mc.withOpacity(0.1) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? mc : Colors.grey.shade200, width: isSelected ? 2 : 1),
              ),
              child: Row(children: [
                Icon(motif['icon'] as IconData, color: isSelected ? mc : Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(motif['label'].toString(),
                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? mc : Colors.black87, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: mc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text('${fmt.format(motif['montant'])} CFA',
                      style: TextStyle(color: mc, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ]),
            ),
          );
        }),

        if (_selectedMotif != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Row(children: [
                Icon(Icons.receipt_rounded, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Montant :', style: TextStyle(fontWeight: FontWeight.w500)),
              ]),
              Text('${fmt.format(_montantDuMotif)} CFA',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 16)),
            ]),
          ),
        ],

        const SizedBox(height: 16),

        // ✅ Note : textInputAction.done + unfocus au Done
        _formLabel('Note (optionnel)'),
        TextField(
          controller: _noteCtrl,
          textInputAction: TextInputAction.done,
          onEditingComplete: () => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.notes_rounded, color: _redDark, size: 20),
            hintText: 'Commentaire...',
            filled: true, fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _redDark, width: 2)),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: (_selectedMembre != null && _selectedMotif != null) ? _redDark : Colors.grey.shade400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_selectedMembre == null || _selectedMotif == null || _isSaving) ? null : _appliquerSanction,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.gavel_rounded, color: Colors.white),
            label: Text(_isSaving ? 'Enregistrement...' : 'Appliquer',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  Widget _buildResumeStats() {
    final fmt      = NumberFormat('#,###', 'fr_FR');
    final encaisse = _sanctions.where((s) => s['statut'] == 'paye').fold(0, (s, x) => s + (x['montant'] as int? ?? 0));
    final attente  = _sanctions.where((s) => s['statut'] != 'paye').fold(0, (s, x) => s + (x['montant'] as int? ?? 0));
    return Row(children: [
      _statChip('${fmt.format(encaisse)} CFA', Colors.green),
      const SizedBox(width: 1),
      _statChip('${fmt.format(attente)} CFA ', Colors.orange),
    ]);
  }

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
  );

  Widget _buildHistorique() {
    final fmt = NumberFormat('#,###', 'fr_FR');
    if (_isLoading) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    if (_error != null) return Center(child: Column(children: [
      Icon(Icons.wifi_off, size: 40, color: Colors.grey.shade300),
      const SizedBox(height: 8),
      Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
      TextButton(onPressed: _chargerSanctions, child: const Text('Réessayer')),
    ]));
    if (_sanctions.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.gavel_rounded, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('Aucune sanction', style: TextStyle(color: Colors.grey.shade400)),
      ]),
    ));

    return Column(children: _sanctions.map((s) {
      final nom       = s['membre']?['nom'] ?? '—';
      final motif     = (s['motif'] as String? ?? '').replaceAll('_', ' ');
      final montant   = s['montant'] as int? ?? 0;
      final date      = s['date_sanction'] ?? '';
      final isPaid    = s['statut'] == 'paye';
      final isAbsence = motif.toLowerCase().contains('absence');

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]),
        child: ListTile(
          onTap: isPaid ? null : () => _marquerPaye(s),
          leading: CircleAvatar(
            backgroundColor: (isPaid ? Colors.green : Colors.red).withOpacity(0.1),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : isAbsence ? Icons.person_off_rounded : Icons.access_time_rounded,
              color: isPaid ? Colors.green : Colors.red,
            ),
          ),
          title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(motif, style: const TextStyle(fontSize: 12)),
            Text('Le $date', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            if (!isPaid)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Text('Appuyer pour marquer payé',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.w500)),
              ),
          ]),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fmt.format(montant)} CFA',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
            const SizedBox(height: 2),
            Text(isPaid ? 'Payé' : 'En attente',
                style: TextStyle(color: isPaid ? Colors.green : Colors.orange,
                    fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
    }).toList());
  }

  Widget _dRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );

  Widget _formLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600, fontSize: 12)),
  );

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: _redDark.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: _redDark, size: 18),
    ),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  ]);
}