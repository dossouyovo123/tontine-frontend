import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/Tontine_store.dart';

// ============================================================
// DASHBOARD — Sanctions séparées + sections compactes
// ============================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {

  Map<String, dynamic>? _data;
  bool    _isLoading = true;
  String? _error;
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _bg      = Color(0xFFF4F7FA);

  // ── Dates locales ─────────────────────────────────────────

  DateTime get _premierSamediJanvier {
    final a    = DateTime.now().year;
    final jan1 = DateTime(a, 1, 1);
    final j    = (DateTime.saturday - jan1.weekday + 7) % 7;
    return jan1.add(Duration(days: j));
  }

  DateTime _dateDuSamedi(int s) =>
      _premierSamediJanvier.add(Duration(days: (s - 1) * 7));

  int get _semaineCourante {
    final debut = _premierSamediJanvier;
    final now   = DateTime.now();
    if (now.isBefore(debut)) return 1;
    return ((now.difference(debut).inDays) ~/ 7 + 1).clamp(1, 52);
  }

  DateTime get _prochainSamedi {
    final now = DateTime.now();
    final d   = (DateTime.saturday - now.weekday + 7) % 7;
    return d == 0 ? now.add(const Duration(days: 7)) : now.add(Duration(days: d));
  }

  bool   get _estSamediAujourdhui => DateTime.now().weekday == DateTime.saturday;
  String get _dateSamediCourant   => DateFormat('dd/MM/yyyy').format(_dateDuSamedi(_semaineCourante));
  String get _dateSamediSuivant   => DateFormat('dd/MM/yyyy').format(_prochainSamedi);

  int safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _charger();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _charger() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiService().getDashboard();
      setState(() => _data = res);
      _animCtrl.forward(from: 0);
    } on ApiException catch (e) {
      if (e.isUnauthorized && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("Tableau de bord",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          _isLoading
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
          )
              : IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _charger,
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _charger,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _buildBody(context),
      ),
    );
  }

  // ── CORPS ─────────────────────────────────────────────────

  Widget _buildBody(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());

    // Membres
    final m        = (data['membres']  as Map?) ?? {};
    final total    = safeInt(m['total']);
    final actifs   = safeInt(m['actifs']);
    final inactifs = safeInt(m['inactifs']);
    final abandons = safeInt(m['abandonnes']);

    // Collecte semaine
    final cs       = (data['cotisations_semaine'] as Map?) ?? {};
    final nbPayes  = safeInt(cs['payes']);
    final nbRetard = safeInt(cs['retard']);
    final collecte = safeInt(cs['collecte']);

    // Financier
    final t             = (data['totaux'] as Map?) ?? {};
    final cots          = safeInt(t['cotisations']);
    final distrs        = safeInt(t['distributions']);
    // Clés retournées par DashboardController (doc 5)
    final sanctEncaisse = safeInt(t['sanctions_encaisse']);    // payées
    final sanctAttente  = safeInt(t['sanctions_en_attente']);  // en attente

    // Compléments
    final c      = (data['complements'] as Map?) ?? {};
    final cAttente = safeInt(c['en_attente']);
    final approu   = safeInt(c['approuves']);
    final attrib   = safeInt(c['moto_attribuee']);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Bannière semaine ─────────────────────────────
            _buildSemaineHeader(context),
            const SizedBox(height: 22),

            // ── Collecte de la semaine (3 cartes compactes) ──
            _buildSectionTitle(Icons.today_rounded, "Collecte de la semaine"),
            const SizedBox(height: 10),
            _grid3([
              _buildStatCard('$nbPayes',  'Payés ce jour',
                  const Color(0xFF43A047), Icons.check_circle_rounded),
              _buildStatCard('$nbRetard', 'En retard',
                  const Color(0xFFE53935), Icons.warning_amber_rounded),
              _buildStatCard('${fmt.format(collecte)} F', 'Collecté',
                  const Color(0xFF1E88E5), Icons.savings_rounded),
            ]),

            const SizedBox(height: 22),

            // ── Membres (2×2) ────────────────────────────────
            _buildSectionTitle(Icons.people_alt_rounded, "Annuaire des Membres"),
            const SizedBox(height: 10),
            _grid2([
              _buildStatCard('$total',    'Total Membres',    const Color(0xFF3949AB), Icons.group_add_rounded),
              _buildStatCard('$actifs',   'Membres Actifs',   const Color(0xFF1E88E5), Icons.people_alt_rounded),
              _buildStatCard('$inactifs', 'Membres Inactifs', Colors.blueGrey,         Icons.pause_circle_rounded),
              _buildStatCard('$abandons', 'Abandons',         const Color(0xFF8E24AA), Icons.exit_to_app_rounded),
            ]),

            const SizedBox(height: 22),

            // ── Bilan Financier ──────────────────────────────
            _buildSectionTitle(Icons.account_balance_wallet_rounded, "Bilan Financier"),
            const SizedBox(height: 10),
            // Cotisations & Distributions côte à côte
            _grid2([
              _buildStatCard('${fmt.format(cots)} F',   'Total Cotisations',
                  const Color(0xFF43A047), Icons.arrow_downward_rounded),
              _buildStatCard('${fmt.format(distrs)} F', 'Total Distributions',
                  const Color(0xFFFB8C00), Icons.outbox_rounded),
            ]),
            const SizedBox(height: 10),
            // Séparateur sanctions
            _buildSubSectionTitle(Icons.gavel_rounded, "Sanctions"),
            const SizedBox(height: 8),
            // Sanctions Payées | Sanctions en attente
            _grid2([
              _buildStatCard(
                '${fmt.format(sanctEncaisse)} F',
                'Sanctions Payées',
                const Color(0xFF00897B),
                Icons.check_circle_outline_rounded,
              ),
              _buildStatCard(
                '${fmt.format(sanctAttente)} F',
                'Sanctions en attente',
                const Color(0xFFE53935),
                Icons.hourglass_top_rounded,
              ),
            ]),

            const SizedBox(height: 22),

            // ── Compléments Motos (3 cartes compactes) ───────
            _buildSectionTitle(Icons.two_wheeler_rounded, "Compléments Motos"),
            const SizedBox(height: 10),
            _grid3([
              _buildStatCard('$cAttente', 'En attente', const Color(0xFFEF6C00), Icons.hourglass_top_rounded),
              _buildStatCard('$approu',   'Approuvées', const Color(0xFF1E88E5), Icons.thumb_up_alt_rounded),
              _buildStatCard('$attrib',   'Attribuées', const Color(0xFF43A047), Icons.two_wheeler_rounded),
            ]),

            const SizedBox(height: 28),

            Center(
              child: Text(
                "Mise à jour : ${TimeOfDay.now().format(context)}",
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── GRILLES ───────────────────────────────────────────────

  /// 2 colonnes — cartes standards
  Widget _grid2(List<Widget> children) => GridView.count(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.15,
    children: children,
  );

  /// 3 colonnes — cartes compactes
  Widget _grid3(List<Widget> children) => GridView.count(
    crossAxisCount: 3,
    crossAxisSpacing: 9,
    mainAxisSpacing: 9,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 0.92,
    children: children,
  );

  // ── EN-TÊTE SEMAINE ───────────────────────────────────────

  Widget _buildSemaineHeader(BuildContext context) {
    final pct = _semaineCourante / 52.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Semaine en cours',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 2),
            Text('Semaine $_semaineCourante / 52',
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Samedi collecte',
                  style: TextStyle(color: Colors.white60, fontSize: 9)),
              const SizedBox(height: 2),
              Text(_dateSamediCourant,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        if (!_estSamediAujourdhui)
          Row(children: [
            const Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 13),
            const SizedBox(width: 5),
            const Text('Prochain samedi : ',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
            Text(_dateSamediSuivant,
                style: const TextStyle(
                    color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ])
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.celebration_rounded, color: Colors.greenAccent, size: 13),
              SizedBox(width: 5),
              Text("Journée de collecte aujourd'hui !",
                  style: TextStyle(
                      color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pct * 100).toStringAsFixed(0)}% de l\'année',
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text('$_semaineCourante / 52 semaines',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
        ),
      ]),
    );
  }

  // ── TITRES ────────────────────────────────────────────────

  Widget _buildSectionTitle(IconData icon, String label) =>
      Row(children: [
        Icon(icon, color: _primary, size: 20),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ]);

  /// Sous-titre discret pour regrouper des cartes dans une section
  Widget _buildSubSectionTitle(IconData icon, String label) =>
      Row(children: [
        Icon(icon, color: Colors.black38, size: 15),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black45)),
      ]);

  // ── CARTE STATISTIQUE ─────────────────────────────────────

  Widget _buildStatCard(String value, String title, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          Positioned(
            right: -8, bottom: -8,
            child: Icon(icon, size: 58, color: Colors.white.withOpacity(0.10)),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 15),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(title,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── ERREUR ────────────────────────────────────────────────

  Widget _buildError() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(_error!, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _charger,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    ]),
  );
}