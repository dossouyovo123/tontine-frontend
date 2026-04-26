import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../Core/Tontine_store.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ============================================================
// PAGE GESTION DES DÉPENSES
// ============================================================

class DepensesGestionPage extends StatefulWidget {
  const DepensesGestionPage({super.key});
  @override
  State<DepensesGestionPage> createState() => _DepensesGestionPageState();
}

class _DepensesGestionPageState extends State<DepensesGestionPage> {
  final _motifCtrl  = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  DateTime _dateDepense = DateTime.now();
  File? _imageFile;
  bool _isSubmitting = false;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent  = Color(0xFFE53935);

  @override
  void dispose() {
    _motifCtrl.dispose(); _montantCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateDepense,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _dateDepense = d);
  }

  Future<void> _soumettre() async {
    if (_motifCtrl.text.trim().isEmpty) {
      _showSnack('Motif obligatoire', Colors.red); return;
    }
    final montant = int.tryParse(_montantCtrl.text.trim());
    if (montant == null || montant <= 0) {
      _showSnack('Montant invalide', Colors.red); return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().creerDepense(
        motif:       _motifCtrl.text.trim(),
        montant:     montant,
        dateDepense: DateFormat('yyyy-MM-dd').format(_dateDepense),
        notes:       _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        imageFile:   _imageFile,
      );

      _motifCtrl.clear(); _montantCtrl.clear(); _notesCtrl.clear();
      setState(() { _imageFile = null; _dateDepense = DateTime.now(); });
      _showSnack('Dépense enregistrée ✓', Colors.green);
    } on ApiException catch (e) {
      _showSnack(e.firstError ?? e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _accent,
        elevation: 0, centerTitle: true,
        title: const Text('Nouvelle Dépense',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Icône header ────────────────────────────────────
          Center(child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _accent.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_rounded, color: _accent, size: 36),
          )),
          const SizedBox(height: 20),

          // ── Motif ───────────────────────────────────────────
          _label('Motif de la dépense *'),
          const SizedBox(height: 6),
          _field(_motifCtrl, 'Ex: Achat fournitures, Transport...',
              Icons.edit_note_rounded),
          const SizedBox(height: 16),

          // ── Montant ─────────────────────────────────────────
          _label('Montant (CFA) *'),
          const SizedBox(height: 6),
          _field(_montantCtrl, '0', Icons.payments_rounded,
              type: TextInputType.number),
          const SizedBox(height: 16),

          // ── Date ────────────────────────────────────────────
          _label('Date de la dépense'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, color: _primary, size: 20),
                const SizedBox(width: 12),
                Text(DateFormat('dd/MM/yyyy').format(_dateDepense),
                    style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── Notes ───────────────────────────────────────────
          _label('Notes (optionnel)'),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Informations supplémentaires...',
              prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.notes_rounded, color: _primary, size: 20)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              fillColor: Colors.white, filled: true,
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primary, width: 2)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Image justificative ─────────────────────────────
          _label('Image justificative (optionnelle)'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: _imageFile != null ? null : 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _imageFile != null
                        ? _primary.withOpacity(0.5)
                        : Colors.grey.shade300,
                    style: _imageFile != null
                        ? BorderStyle.solid
                        : BorderStyle.solid,
                    width: _imageFile != null ? 2 : 1),
              ),
              child: _imageFile == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: Colors.grey.shade400, size: 32),
                  const SizedBox(height: 6),
                  Text('Appuyez pour ajouter une image',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                ],
              )
                  : Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_imageFile!,
                      width: double.infinity, fit: BoxFit.cover,
                      height: 200),
                ),
                Positioned(top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageFile = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 28),

          // ── Bouton soumettre ─────────────────────────────────
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: _isSubmitting ? null : _soumettre,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(_isSubmitting ? 'Enregistrement...' : 'ENREGISTRER LA DÉPENSE',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl, keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: _primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          fillColor: Colors.white, filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primary, width: 2)),
        ),
      );

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ============================================================
// PAGE HISTORIQUE DES DÉPENSES
// ============================================================

class HistoriqueDepensesPage extends StatefulWidget {
  const HistoriqueDepensesPage({super.key});
  @override
  State<HistoriqueDepensesPage> createState() => _HistoriqueDepensesPageState();
}

class _HistoriqueDepensesPageState extends State<HistoriqueDepensesPage> {
  List<Map<String, dynamic>> _depenses = [];
  bool    _isLoading = true;
  String? _error;
  String  _searchQuery = '';

  static const Color _accent  = Color(0xFFE53935);
  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() { super.initState(); _charger(); }

  Future<void> _charger() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiService().getDepenses();
      setState(() => _depenses = ((res['depenses'] as List?) ?? [])
          .cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _depenses.where((d) =>
      (d['motif'] as String? ?? '').toLowerCase()
          .contains(_searchQuery.toLowerCase())).toList();

  int get _total => _depenses.fold(0, (s, d) => s + (d['montant'] as int? ?? 0));

  // ── Supprimer ─────────────────────────────────────────────
  Future<void> _supprimer(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.delete_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10), const Text('Supprimer ?'),
        ]),
        content: Text(
            'Supprimer la dépense "${d['motif']}" ?\nCette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('NON')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OUI', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().supprimerDepense(d['id'] as int);
      setState(() => _depenses.removeWhere((x) => x['id'] == d['id']));
      _showSnack('Dépense supprimée', Colors.green);
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    }
  }

  // ── Modifier ──────────────────────────────────────────────
  void _showEditForm(Map<String, dynamic> d) {
    final motifCtrl   = TextEditingController(text: d['motif'] ?? '');
    final montantCtrl = TextEditingController(
        text: (d['montant'] as int? ?? 0).toString());
    final notesCtrl   = TextEditingController(text: d['notes'] ?? '');
    DateTime date = DateTime.now();
    try {
      final parts = (d['date_depense'] as String? ?? '').split('/');
      if (parts.length == 3) {
        date = DateTime(int.parse(parts[2]),
            int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    File? newImage;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10)))),
                  Row(children: [
                    Icon(Icons.edit_rounded, color: _accent),
                    const SizedBox(width: 10),
                    const Text('Modifier la dépense',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ]),
                  const SizedBox(height: 16),

                  // Motif
                  TextField(controller: motifCtrl,
                      decoration: InputDecoration(labelText: 'Motif *',
                        prefixIcon: Icon(Icons.edit_note_rounded, color: _primary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true, fillColor: Colors.grey.shade50,
                      )),
                  const SizedBox(height: 12),

                  // Montant
                  TextField(controller: montantCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Montant (CFA) *',
                        prefixIcon: Icon(Icons.payments_rounded, color: _primary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true, fillColor: Colors.grey.shade50,
                      )),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(controller: notesCtrl, maxLines: 2,
                      decoration: InputDecoration(labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes_rounded, color: _primary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true, fillColor: Colors.grey.shade50,
                      )),
                  const SizedBox(height: 12),

                  // Nouvelle image
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final p = await picker.pickImage(
                          source: ImageSource.gallery, imageQuality: 75);
                      if (p != null) setSheet(() => newImage = File(p.path));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300)),
                      child: Row(children: [
                        Icon(Icons.photo_library_rounded, color: _primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          newImage != null
                              ? 'Nouvelle image sélectionnée'
                              : (d['has_image'] == true
                              ? 'Modifier l\'image existante'
                              : 'Ajouter une image'),
                          style: TextStyle(color: newImage != null
                              ? _primary : Colors.grey.shade500),
                        )),
                        if (newImage != null)
                          GestureDetector(
                            onTap: () => setSheet(() => newImage = null),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.red, size: 18),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(width: double.infinity, height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: isSaving ? null : () async {
                        final montant = int.tryParse(montantCtrl.text.trim());
                        if (motifCtrl.text.trim().isEmpty || montant == null) {
                          _showSnack('Motif et montant requis', Colors.red);
                          return;
                        }
                        setSheet(() => isSaving = true);
                        try {
                          final updated = await ApiService().modifierDepense(
                            id:        d['id'] as int,
                            motif:     motifCtrl.text.trim(),
                            montant:   montant,
                            notes:     notesCtrl.text.trim().isEmpty
                                ? null : notesCtrl.text.trim(),
                            imageFile: newImage,
                          );
                          final idx = _depenses.indexWhere(
                                  (x) => x['id'] == d['id']);
                          if (idx >= 0) setState(() => _depenses[idx] = updated);
                          if (mounted) Navigator.pop(ctx);
                          _showSnack('Dépense modifiée ✓', Colors.green);
                        } on ApiException catch (e) {
                          _showSnack(e.firstError ?? e.message, Colors.red);
                        } finally {
                          setSheet(() => isSaving = false);
                        }
                      },
                      child: Text(isSaving ? 'Enregistrement...' : 'ENREGISTRER',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ])),
          ),
        ),
      ),
    );
  }

  // ── Voir image ────────────────────────────────────────────
  void _voirImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
          Positioned(top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _accent,
        elevation: 0, centerTitle: true,
        title: const Text('Historique des Dépenses',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _charger),
        ],
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DepensesGestionPage()))
            .then((_) => _charger()),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('AJOUTER', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [

        // ── Total ────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.red.shade800, Colors.red.shade600]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCard('${fmt.format(_total)} CFA', 'Total dépenses', Colors.white),
                Container(height: 30, width: 1,
                    color: Colors.white.withOpacity(0.3)),
                _statCard('${_depenses.length}', 'Dépenses', Colors.orangeAccent),
              ]),
        ),

        // ── Recherche ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un motif...',
              prefixIcon: Icon(Icons.search, color: _accent),
              filled: true, fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Liste ─────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _charger,
                child: const Text('Réessayer')),
          ]))
              : _filtered.isEmpty
              ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_long_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucune dépense trouvée',
                style: TextStyle(color: Colors.grey.shade400)),
          ]))
              : RefreshIndicator(
            onRefresh: _charger,
            child: ListView.builder(
              itemCount: _filtered.length,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemBuilder: (_, i) => _buildCard(_filtered[i], fmt),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> d, NumberFormat fmt) {
    final hasImage = d['has_image'] == true;
    final imageUrl = d['image_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Icône catégorie
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _accent.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_rounded, color: _accent, size: 20),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d['motif'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('Le ${d['date_depense'] ?? ''}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            if ((d['notes'] as String?)?.isNotEmpty == true)
              Text(d['notes']!,
                  style: TextStyle(color: Colors.grey.shade400,
                      fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),

          // Montant + actions
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fmt.format(d['montant'] ?? 0)} CFA',
                style: TextStyle(color: _accent,
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              // Voir image
              if (hasImage && imageUrl != null)
                GestureDetector(
                  onTap: () => _voirImage(imageUrl),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.visibility_rounded,
                        color: Colors.blue.shade700, size: 15),
                  ),
                ),
              // Modifier
              GestureDetector(
                onTap: () => _showEditForm(d),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(7)),
                  child: Icon(Icons.edit_rounded,
                      color: Colors.orange.shade700, size: 15),
                ),
              ),
              // Supprimer
              GestureDetector(
                onTap: () => _supprimer(d),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(7)),
                  child: Icon(Icons.delete_rounded,
                      color: Colors.red.shade700, size: 15),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _statCard(String val, String label, Color color) =>
      Column(children: [
        Text(val, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(
            color: Colors.white70, fontSize: 10)),
      ]);

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}