import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Core/Tontine_store.dart';
// ============================================================
// PAGE DISTRIBUTIONS — API intégrée
// ============================================================

class DistributionsPage extends StatefulWidget {
  const DistributionsPage({super.key});

  @override
  State<DistributionsPage> createState() => _DistributionsPageState();
}

class _DistributionsPageState extends State<DistributionsPage> {
  // ── Formulaire ────────────────────────────────────────────
  Membre?  _selectedMembre;
  String   _filterText      = '';
  bool     _isSaving        = false;
  final _montantCtrl = TextEditingController();
  final _dateCtrl    = TextEditingController();
  final _noteCtrl    = TextEditingController();

  // ── Historique ────────────────────────────────────────────
  List<Map<String, dynamic>> _historique = [];
  bool   _isLoading  = true;
  String? _error;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _bg      = Color(0xFFF4F7FA);

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Charge les membres si pas encore fait
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


  // ── Créer une distribution ────────────────────────────────
  Future<void> _creerDistribution() async {
    if (_selectedMembre == null) {
      _showSnack('Sélectionnez un bénéficiaire', Colors.orange);
      return;
    }
    final montant = int.tryParse(_montantCtrl.text.trim());
    if (montant == null || montant <= 0) {
      _showSnack('Montant invalide', Colors.orange);
      return;
    }
    final dateSaisie = _dateCtrl.text.trim();
    if (dateSaisie.isEmpty) {
      _showSnack('Date requise', Colors.orange);
      return;
    }

    // Convertit dd/MM/yyyy → yyyy-MM-dd pour l'API
    String dateApi;
    try {
      final parsed = DateFormat('dd/MM/yyyy').parse(dateSaisie);
      dateApi = DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      _showSnack('Format de date invalide (JJ/MM/AAAA)', Colors.red);
      return;
    }

    // Confirmation
    final ok = await _confirm(
      titre: 'Confirmer la distribution',
      icon:  Icons.outbox_rounded,
      color: Colors.green,
      lignes: [
        ('Bénéficiaire', _selectedMembre!.nom),
        ('Montant',      '${NumberFormat('#,###', 'fr_FR').format(montant)} CFA'),
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
      _showSnack('Distribution enregistrée ✓', Colors.green);
      // Reset
      setState(() { _selectedMembre = null; });
      _montantCtrl.clear();
      _noteCtrl.clear();
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      // Recharge
      await _chargerHistorique();
    } on ApiException catch (e) {
      _showSnack(e.firstError ?? e.message, Colors.red);
    } catch (_) {
      _showSnack('Erreur réseau', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirm({
    required String titre,
    required IconData icon,
    required Color color,
    required List<(String, String)> lignes,
  }) async {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(titre, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: lignes.map((l) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l.$1, style: TextStyle(color: Colors.grey.shade600)),
              Text(l.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // ── Picker membre ─────────────────────────────────────────
  void _showMemberPicker() {
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
            m.numRegistre.toString().contains(filter)
        ).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 50, height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20),
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
                  hintText: 'Rechercher...',
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (store.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final m = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _primary.withOpacity(0.1),
                      child: Text(m.nom[0],
                          style: const TextStyle(color: _primary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(m.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('#${m.numRegistre} • ${m.profession}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    onTap: () {
                      setState(() => _selectedMembre = m);
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

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Distributions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: _primary,
          centerTitle: true, elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _chargerHistorique),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nouvelle distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
            const Divider(height: 28),

            // Bénéficiaire
            _label('Bénéficiaire'),
            InkWell(
              onTap: _showMemberPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedMembre != null ? _primary : Colors.grey.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.person, color: _selectedMembre == null ? Colors.grey : _primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _selectedMembre?.nom ?? 'Cliquer pour sélectionner',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _selectedMembre == null ? Colors.grey : Colors.black,
                      fontWeight: _selectedMembre == null ? FontWeight.normal : FontWeight.bold,
                    ),
                  )),
                  const Icon(Icons.arrow_drop_down),
                ]),
              ),
            ),

            if (_selectedMembre != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedMembre!.semainesCotisees} sem. — ${fmt.format(_selectedMembre!.totalCotiseCfa)} CFA cotisés',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 16),
            _label('Montant (CFA)'),
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(Icons.payments_outlined, 'Ex: 300000'),
            ),

            const SizedBox(height: 16),
            _label('Date de remise'),
            TextField(
              controller: _dateCtrl,
              keyboardType: TextInputType.datetime,
              decoration: _inputDeco(Icons.edit_calendar_rounded, 'JJ/MM/AAAA'),
            ),

            const SizedBox(height: 16),
            _label('Note (optionnel)'),
            TextField(
              controller: _noteCtrl,
              decoration: _inputDeco(Icons.notes_rounded, 'Motif ou commentaire...'),
            ),

            const SizedBox(height: 24),

            // Bouton
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
            const Text('Historique des distributions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          // Résumé total
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
            TextButton(onPressed: _chargerHistorique, child: const Text('Réessayer')),
          ]))
        else if (_historique.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.outbox_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Aucune distribution', style: TextStyle(color: Colors.grey.shade400)),
              ]),
            ))
          else
            ...(_historique.take(10).map((d) {
              final nom     = d['membre']?['nom'] ?? '—';
              final montant = d['montant'] as int? ?? 0;
              final date    = d['date_distribution'] ?? '';
              final note    = d['note'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: Text(nom.isNotEmpty ? nom[0] : '?',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Remis le $date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (note.isNotEmpty)
                      Text(note, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontStyle: FontStyle.italic)),
                  ]),
                  trailing: Text('${fmt.format(montant)} CFA',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                ),
              );
            })),

        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13)),
  );

  InputDecoration _inputDeco(IconData icon, String hint) => InputDecoration(
    prefixIcon: Icon(icon, color: _primary, size: 20),
    hintText: hint,
    filled: true, fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
  );
}