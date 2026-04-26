import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Core/Tontine_store.dart';

// ============================================================
// PAGE BÉNÉFICE COMPLET
// ============================================================

class BeneficePage extends StatefulWidget {
  const BeneficePage({super.key});
  @override
  State<BeneficePage> createState() => _BeneficePageState();
}

class _BeneficePageState extends State<BeneficePage> {
  Map<String, dynamic>? _data;
  bool    _isLoading    = true;
  bool    _isCalculating = false;
  String? _error;
  int _annee = DateTime.now().year;

  static const Color _gold    = Color(0xFFFF8F00);
  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() { super.initState(); _charger(); }

  Future<void> _charger() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiService().getBenefices(annee: _annee);
      setState(() => _data = res);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.calculate_rounded, color: _gold),
          const SizedBox(width: 10),
          const Text('Calculer les bénéfs ?'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cette action va calculer le bénéfice sur chaque membre après 52 semaines.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _gold.withOpacity(0.3))),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Règle du prélèvement :',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(height: 4),
                  Text('• Tontine 5 000 F → prélève 5 000 F',
                      style: TextStyle(fontSize: 11)),
                  Text('• Tontine 60 000 F → prélève 60 000 F',
                      style: TextStyle(fontSize: 11)),
                  Text('• Peu importe le nombre de semaines payées',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('Opération idempotente — sans risque de doublon.',
                    style: TextStyle(fontSize: 10, color: Colors.blue)),
              ),
            ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('ANNULER')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _gold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
            label: const Text('CALCULER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isCalculating = true);
    try {
      final res = await ApiService().calculerBenefices(annee: _annee);
      final msg = res['message'] as String? ?? 'Calcul terminé';
      _showSnack(msg, Colors.green);
      await _charger();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _gold,
        elevation: 0,
        centerTitle: true,
        title: const Text('Bénéfice Complet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading || _isCalculating)
            const Padding(padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _charger,
            ),
        ],
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: Column(children: [

        // ── Carte récapitulative ──────────────────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: _gold.withOpacity(0.35),
                blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.stars_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Bénéfices prélevés — 52 semaines',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            _isLoading
                ? const LinearProgressIndicator(backgroundColor: Colors.white30,
                valueColor: AlwaysStoppedAnimation(Colors.white))
                : Text(
              '${fmt.format(_data?['total_benefices'] ?? 0)} CFA',
              style: const TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${_data?['nb_membres'] ?? 0} membres prélevés — Année $_annee',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 16),

            // Bouton calculer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isCalculating ? null : _calculer,
                icon: _isCalculating
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFFF8F00)))
                    : const Icon(Icons.calculate_rounded, size: 18),
                label: Text(
                  _isCalculating ? 'Calcul en cours...' : 'CALCULER LES BÉNÉFICES',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ]),
        ),

        // ── En-tête liste ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: _gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.list_alt_rounded, color: _gold, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('Historique des prélèvements',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
        const SizedBox(height: 8),

        // ── Liste ─────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : _buildListe(fmt),
        ),
      ]),
    );
  }

  Widget _buildListe(NumberFormat fmt) {
    final benefices = ((_data?['benefices']) as List? ?? [])
        .cast<Map<String, dynamic>>();

    if (benefices.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucun bénéfice enregistré pour $_annee',
                style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 8),
            Text('Appuyez sur "Calculer" après la semaine 52',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ]));
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        itemCount: benefices.length,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemBuilder: (_, i) {
          final b       = benefices[i];
          final membre  = b['membre'] as Map<String, dynamic>?;
          final nom     = membre?['nom'] ?? '—';
          final numReg  = membre?['num_registre'] ?? '—';
          final total   = b['total_cotise'] as int? ?? 0;
          final benef   = b['montant_benefice'] as int? ?? 0;
          final net     = b['benefice_net'] as int? ?? 0;
          final date    = b['date_prelevement'] as String? ?? '';
          final tontine = (membre?['tontine'] as Map?)?.containsKey('nom') == true
              ? membre!['tontine']['nom'] as String
              : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Avatar avec numéro registre
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF8F00), Color(0xFFFFB300)]),
                      shape: BoxShape.circle),
                  child: Center(child: Text(nom.isNotEmpty ? nom[0] : '?',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('#$numReg',
                        style: TextStyle(color: Colors.grey.shade500,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(nom,
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  if (tontine != null)
                    Text(tontine,
                        style: TextStyle(color: _gold.withOpacity(0.9),
                            fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _infoChip('Cotisé', fmt.format(total), Colors.blue),
                    const SizedBox(width: 6),
                    _infoChip('Prélevé', fmt.format(benef), _gold),
                  ]),
                  const SizedBox(height: 2),
                  Text('Le $date',
                      style: TextStyle(color: Colors.grey.shade400,
                          fontSize: 10)),
                ])),
                // Bénéfice net
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('NET', style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 9)),
                  Text('${fmt.format(net)} F',
                      style: TextStyle(
                          color: net >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _infoChip(String label, String val, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7)),
    child: Text('$label : $val F',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
  );

  Widget _buildError() => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
    const SizedBox(height: 12),
    Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
  ]));

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}