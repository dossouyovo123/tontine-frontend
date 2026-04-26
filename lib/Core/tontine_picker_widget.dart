import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'Tontine_store.dart';

// ============================================================
// WIDGET SÉLECTEUR TONTINE EN 2 ÉTAPES
// Usage : showTontinePicker(context) → Future<TontineModel?>
// ============================================================

Future<TontineModel?> showTontinePicker(BuildContext context) {
  return showModalBottomSheet<TontineModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TontinePickerSheet(),
  );
}

class _TontinePickerSheet extends StatefulWidget {
  const _TontinePickerSheet();
  @override
  State<_TontinePickerSheet> createState() => _TontinePickerSheetState();
}

class _TontinePickerSheetState extends State<_TontinePickerSheet>
    with SingleTickerProviderStateMixin {

  String?            _selectedCategorie;
  late AnimationController _anim;
  late Animation<double>   _fade;

  static const _ordre = ['petits', 'moyens', 'grands', 'premium'];

  static const _icons = <String, IconData>{
    'petits':  Icons.savings_rounded,
    'moyens':  Icons.account_balance_wallet_rounded,
    'grands':  Icons.trending_up_rounded,
    'premium': Icons.workspace_premium_rounded,
  };

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  Map<String, List<TontineModel>> get _grouped =>
      TontineStore().tontinesParCategorie;

  // Trier selon l'ordre défini
  List<String> get _categories =>
      _ordre.where((c) => _grouped.containsKey(c)).toList();

  void _selectCategorie(String cat) {
    _anim.reverse().then((_) {
      setState(() => _selectedCategorie = cat);
      _anim.forward();
    });
  }

  void _retour() {
    _anim.reverse().then((_) {
      setState(() => _selectedCategorie = null);
      _anim.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // ── Poignée ───────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          // ── En-tête ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [
              if (_selectedCategorie != null)
                GestureDetector(
                  onTap: _retour,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_rounded, size: 18),
                  ),
                ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _selectedCategorie == null
                      ? 'Choisir la catégorie'
                      : kCategorieLibelles[_selectedCategorie] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  _selectedCategorie == null
                      ? 'Étape 1 sur 2 — Sélectionnez une catégorie'
                      : 'Étape 2 sur 2 — Sélectionnez le montant',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 8),
          const Divider(),
          // ── Contenu animé ─────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: _selectedCategorie == null
                  ? _buildEtape1(ctrl)
                  : _buildEtape2(ctrl),
            ),
          ),
        ]),
      ),
    );
  }

  // ── ÉTAPE 1 : Cartes de catégories ────────────────────────
  Widget _buildEtape1(ScrollController ctrl) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: _categories.map((cat) {
        final tontines = _grouped[cat] ?? [];
        final min = tontines.map((t) => t.montant).reduce((a, b) => a < b ? a : b);
        final max = tontines.map((t) => t.montant).reduce((a, b) => a > b ? a : b);
        final color   = kCategorieColors[cat]  ?? Colors.blue;
        final libelle = kCategorieLibelles[cat] ?? cat;
        final icon    = _icons[cat] ?? Icons.monetization_on;

        return GestureDetector(
          onTap: () => _selectCategorie(cat),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(libelle, style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 16, color: color)),
                const SizedBox(height: 4),
                Text(
                  '${fmt.format(min)} F — ${fmt.format(max)} F',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                // Aperçu des montants sous forme de petits badges
                Wrap(
                  spacing: 6,
                  children: tontines.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${fmt.format(t.montant)} F',
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ])),
              Icon(Icons.chevron_right_rounded, color: color, size: 28),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── ÉTAPE 2 : Boutons de montants ─────────────────────────
  Widget _buildEtape2(ScrollController ctrl) {
    final fmt      = NumberFormat('#,###', 'fr_FR');
    final cat      = _selectedCategorie!;
    final color    = kCategorieColors[cat] ?? Colors.blue;
    final tontines = (_grouped[cat] ?? [])..sort((a, b) => a.montant.compareTo(b.montant));

    return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: tontines.map((t) {
        return GestureDetector(
          onTap: () => Navigator.pop(context, t),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      '${fmt.format(t.montant)} F',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w900, fontSize: 28),
                    ),
                    const SizedBox(width: 10),
                    // ← Badge distinctif pour 10500 vs 10000
                    if (t.necessiteBadge)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('≠ 10 000 F',
                            style: TextStyle(color: Colors.black87,
                                fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    t.nom,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (t.description != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(t.description!,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ])),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}