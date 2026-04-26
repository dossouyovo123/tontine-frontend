import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import '../Core/Tontine_store.dart';
import 'package:intl/intl.dart';
import 'LoginPage.dart';
import 'admin/DashboardPage.dart';
import 'admin/MembresPage.dart';
import 'admin/CotisationsPage.dart';
import 'admin/DistributionsPage.dart';
import 'admin/Sanctions.dart';
import 'admin/ComplementsPage.dart';
import'admin/DepensesPage.dart';
import'admin/BeneficePage.dart';
// ============================================================
// MAIN
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const TontineAdminApp());
}

class TontineAdminApp extends StatelessWidget {
  const TontineAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TontineStore>.value(
      value: TontineStore(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'J-solution',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
          scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginPage(),
          '/main':  (_) => const MainNavigation(),
        },
      ),
    );
  }
}

// ============================================================
// APP BAR RÉUTILISABLE
// ============================================================

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String        title;
  final bool          showBackButton;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
    centerTitle: true,
    backgroundColor: const Color(0xFF1565C0),
    elevation: 0,
    leading: showBackButton ? const BackButton(color: Colors.white) : null,
    actions: actions,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  );

  @override
  Size get preferredSize => const Size.fromHeight(65.0);
}

// ============================================================
// NAVIGATION PRINCIPALE
// ============================================================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // ✅ Un seul appel chargerMembres(), via postFrameCallback pour ne pas
    // bloquer le premier rendu. LoginPage n'en appelle plus un second.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TontineStore().membres.isEmpty) {
        TontineStore().chargerMembres();
      }
    });
  }

  final List<Widget> _pages = const [
    DashboardPage(),
    MembresPage(),
    CotisationsPage(),
    DistributionsPage(),
    AdminMoreMenu(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _currentIndex, children: _pages),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor:   const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle:   const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded), label: 'Membres'),
          BottomNavigationBarItem(
              icon: Icon(Icons.monetization_on_rounded), label: 'Cotisations'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded), label: 'Distris'),
          BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded), label: 'Plus'),
        ],
      ),
    ),
  );
}

// ============================================================
// MENU "PLUS" ADMIN
// ============================================================

class AdminMoreMenu extends StatelessWidget {
  const AdminMoreMenu({super.key});
  static const Color _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: const CustomAppBar(title: 'Menu Administrateur'),
      body: Column(children: [
        _buildProfileHeader(),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [

            const _SectionLabel('GESTION'),
            _buildMenuTile(context,
                Icons.two_wheeler_rounded,
                const Color(0xFFE65100),
                [const Color(0xFFE65100), const Color(0xFFFF7043)],
                'Compléments Motos',
                'Demandes et attributions de motos',
                const ComplementsPage()),
            _buildMenuTile(context,
                Icons.gavel_rounded,
                Colors.blueGrey,
                [Colors.blueGrey.shade600, Colors.blueGrey.shade400],
                'Gestion des Sanctions',
                'Appliquer une nouvelle amende',
                const SanctionsPage()),

            _buildMenuTile(context,
                Icons.receipt_long_rounded,
                const Color(0xFFE53935),
                [const Color(0xFFE53935), const Color(0xFFEF5350)],
                'Gestion des Dépenses',
                'Enregistrer et suivre les dépenses',
                const DepensesGestionPage()),

            const SizedBox(height: 16),
            const _SectionLabel('HISTORIQUES'),
            _buildMenuTile(context,
                Icons.stars_rounded,
                const Color(0xFFFF8F00),
                [const Color(0xFFFF8F00), const Color(0xFFFFB300)],
                'Bénéfice Complet',
                'Prélèvements après 52 semaines',
                const BeneficePage()),
            _buildMenuTile(context,
                Icons.history_rounded,
                Colors.orange.shade700,
                [Colors.orange.shade700, Colors.orange.shade400],
                'Historique Distributions',
                'Voir et télécharger tous les reçus',
                const HistoriqueDistributionsPage()),
            _buildMenuTile(context,
                Icons.assignment_late_rounded,
                Colors.red.shade600,
                [Colors.red.shade700, Colors.red.shade400],
                'Historique Sanctions',
                'Suivi des amendes et impayés',
                const HistoriqueSanctionsPage()),
            // ← NOUVEAU
            _buildMenuTile(context,
                Icons.receipt_long_rounded,
                const Color(0xFFE53935),
                [Colors.red.shade800, Colors.red.shade600],
                'Historique Dépenses',
                'Toutes les dépenses enregistrées',
                const HistoriqueDepensesPage()),

            const SizedBox(height: 16),
            const _SectionLabel('MON COMPTE'),
            _buildMenuTile(context,
                Icons.admin_panel_settings_rounded,
                const Color(0xFF1565C0),
                [const Color(0xFF0D47A1), const Color(0xFF1976D2)],
                'Profil Administrateur',
                'Informations personnelles et sécurité',
                const ProfilAdminPage()),

            const SizedBox(height: 20),
            _buildLogoutButton(context),
          ]),
        ),
      ]),
    );
  }

  Widget _buildProfileHeader() => Container(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: const CircleAvatar(
          radius: 32, backgroundColor: Colors.white24,
          child: Icon(Icons.admin_panel_settings_rounded,
              size: 38, color: Colors.white),
        ),
      ),
      const SizedBox(width: 16),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Session Admin',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text('Gestion de la tontine',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    ]),
  );

  Widget _buildMenuTile(BuildContext context, IconData icon, Color color,
      List<Color> gradient, String title, String subtitle, Widget destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.chevron_right_rounded, color: color, size: 20),
        ),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => destination)),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100)),
    child: ListTile(
      leading: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 26),
      title: Text('Déconnexion',
          style: TextStyle(
              color: Colors.red.shade600, fontWeight: FontWeight.bold)),
      subtitle: Text('Quitter la session admin',
          style: TextStyle(color: Colors.red.shade300, fontSize: 11)),
      onTap: () async {
        // ── Confirmation avant déconnexion ────────────────
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade600),
              const SizedBox(width: 10),
              Text('Déconnexion',
                  style: TextStyle(
                      color: Colors.red.shade600, fontWeight: FontWeight.bold)),
            ]),
            content: const Text(
              'Voulez-vous vraiment quitter la session admin ?\n\n'
                  'Vous devrez vous reconnecter pour accéder à l\'application.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ANNULER'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 16),
                label: const Text('SE DÉCONNECTER',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (ok != true) return;

        // ✅ ORDRE CRITIQUE du logout :
        // 1. Appel API logout (révoque le token côté serveur)
        await ApiService().logout();
        // 2. Reset du store
        TontineStore().reset();
        // 3. Navigation → login
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      },
    ),
  );
}

// ============================================================
// HISTORIQUE DISTRIBUTIONS — API
// ============================================================

class HistoriqueDistributionsPage extends StatefulWidget {
  const HistoriqueDistributionsPage({super.key});
  @override
  State<HistoriqueDistributionsPage> createState() =>
      _HistoriqueDistributionsPageState();
}

class _HistoriqueDistributionsPageState
    extends State<HistoriqueDistributionsPage> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _distributions = [];
  bool    _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _charger(); }

  Future<void> _charger() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await ApiService().getDistributions();
      final data = (res['data'] as List?) ?? [];
      setState(() => _distributions = data.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _distributions.where((d) =>
      (d['membre']?['nom'] ?? '').toString().toLowerCase()
          .contains(_searchQuery.toLowerCase())).toList();

  int get _total =>
      _distributions.fold(0, (s, d) => s + (d['montant'] as int? ?? 0));

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Historique Distributions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        centerTitle: true,
        elevation: 0,
        // ✅ Même bouton retour que SanctionsPage et HistoriqueSanctionsPage
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
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.green.shade800, Colors.green.shade600]),
              borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statCard('${fmt.format(_total)}', 'CFA distribués', Colors.white),
            Container(height: 30, width: 1, color: Colors.white.withOpacity(0.3)),
            _statCard('${_distributions.length}', 'distributions', Colors.white),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un bénéficiaire...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF1565C0)),
              filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
        ]))
            : _filtered.isEmpty
            ? const Center(child: Text('Aucune distribution trouvée'))
            : RefreshIndicator(
          onRefresh: _charger,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final d       = _filtered[i];
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
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8, offset: const Offset(0, 2))]),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: Text(nom.isNotEmpty ? nom[0] : '?',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remis le $date',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12)),
                        if (note.isNotEmpty)
                          Text(note, style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                      ]),
                  trailing: Text('${fmt.format(montant)} CFA',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green, fontSize: 14)),
                ),
              );
            },
          ),
        )),
      ]),
    );
  }

  Widget _statCard(String val, String label, Color color) =>
      Column(children: [
        Text(val, style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]);
}
// ============================================================
// HISTORIQUE SANCTIONS — API
// ============================================================

class HistoriqueSanctionsPage extends StatefulWidget {
  const HistoriqueSanctionsPage({super.key});
  @override
  State<HistoriqueSanctionsPage> createState() =>
      _HistoriqueSanctionsPageState();
}

class _HistoriqueSanctionsPageState extends State<HistoriqueSanctionsPage> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _sanctions = [];
  bool    _isLoading = true;
  String? _error;

  static const Color _redDark = Color(0xFFB71C1C);

  @override
  void initState() { super.initState(); _charger(); }

  Future<void> _charger() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res  = await ApiService().getSanctions();
      final data = (res['data'] as List?) ?? [];
      setState(() => _sanctions = data.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Erreur réseau');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Marquer payé avec confirmation — identique à SanctionsPage
  Future<void> _marquerPaye(Map<String, dynamic> s) async {
    final nom = s['membre']?['nom'] ?? '—';
    final fmt = NumberFormat('#,###', 'fr_FR');
    final montant = s['montant'] as int? ?? 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green),
          SizedBox(width: 10),
          Text('Sanction payée ?'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$nom a réglé sa sanction ?'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Montant encaissé :',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${fmt.format(montant)} CFA',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NON'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            label: const Text('OUI, CONFIRMER',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    try {
      await ApiService().marquerSanctionPayee(s['id'] as int);
      setState(() => s['statut'] = 'paye');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sanction de $nom marquée comme payée ✓',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  List<Map<String, dynamic>> get _filtered => _sanctions.where((s) =>
      (s['membre']?['nom'] ?? '').toString().toLowerCase()
          .contains(_searchQuery.toLowerCase())).toList();

  int get _totalEncaisse => _sanctions.where((s) => s['statut'] == 'paye')
      .fold(0, (sum, s) => sum + (s['montant'] as int? ?? 0));
  int get _totalAttente  => _sanctions.where((s) => s['statut'] != 'paye')
      .fold(0, (sum, s) => sum + (s['montant'] as int? ?? 0));

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Historique Sanctions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _redDark,
        centerTitle: true,
        elevation: 0,
        // ✅ Même bouton retour que SanctionsPage
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
      body: Column(children: [
        // ── Résumé stats ────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.red.shade800, Colors.red.shade600]),
              borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statCard('${fmt.format(_totalEncaisse)} CFA', 'encaissés', Colors.greenAccent),
            Container(height: 30, width: 1, color: Colors.white.withOpacity(0.3)),
            _statCard('${fmt.format(_totalAttente)} CFA', 'en attente', Colors.orangeAccent),
            Container(height: 30, width: 1, color: Colors.white.withOpacity(0.3)),
            _statCard('${_sanctions.length}', 'sanctions', Colors.white),
          ]),
        ),

        // ── Recherche ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Chercher un membre...',
              prefixIcon: const Icon(Icons.search, color: _redDark),
              filled: true, fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Liste ───────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _charger,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ]))
              : _filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.gavel_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucune sanction trouvée',
                style: TextStyle(color: Colors.grey.shade400)),
          ]))
              : RefreshIndicator(
            onRefresh: _charger,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final s         = _filtered[i];
                final nom       = s['membre']?['nom'] ?? '—';
                final motif     = (s['motif'] as String? ?? '').replaceAll('_', ' ');
                final montant   = s['montant'] as int? ?? 0;
                final date      = s['date_sanction'] ?? '';
                final isPaid    = s['statut'] == 'paye';
                final isAbsence = motif.toLowerCase().contains('absence');

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    // ✅ Tap → confirmation avant marquage
                    onTap: isPaid ? null : () => _marquerPaye(s),
                    leading: CircleAvatar(
                      backgroundColor:
                      (isPaid ? Colors.green : Colors.red).withOpacity(0.1),
                      child: Icon(
                        isPaid
                            ? Icons.check_circle_rounded
                            : isAbsence
                            ? Icons.person_off_rounded
                            : Icons.access_time_rounded,
                        color: isPaid ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(nom,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(motif, style: const TextStyle(fontSize: 12)),
                      Text('Le $date',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      if (!isPaid)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200)),
                          child: Text('Appuyer pour marquer payé',
                              style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 10, fontWeight: FontWeight.w500)),
                        ),
                    ]),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${fmt.format(montant)} CFA',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(isPaid ? 'Payé ✓' : 'En attente',
                            style: TextStyle(
                                color: isPaid ? Colors.green : Colors.orange,
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _statCard(String val, String label, Color color) => Column(children: [
    Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
  ]);
}

// ============================================================
// PROFIL ADMIN — API
// ============================================================

class ProfilAdminPage extends StatefulWidget {
  const ProfilAdminPage({super.key});
  @override
  State<ProfilAdminPage> createState() => _ProfilAdminPageState();
}

class _ProfilAdminPageState extends State<ProfilAdminPage> {
  final _nomCtrl      = TextEditingController();
  final _telCtrl      = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _passConfCtrl = TextEditingController();
  bool _isObscure1    = true;
  bool _isObscure2    = true;
  bool _isLoading     = false;
  bool _isLoadingData = true;

  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() { super.initState(); _chargerProfil(); }

  @override
  void dispose() {
    _nomCtrl.dispose(); _telCtrl.dispose();
    _passCtrl.dispose(); _passConfCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerProfil() async {
    try {
      final res = await ApiService().req('GET', '/me');
      _nomCtrl.text = res['nom'] ?? '';
      _telCtrl.text = res['telephone'] ?? '';
    } catch (_) {}
    if (mounted) setState(() => _isLoadingData = false);
  }

  Future<void> _sauvegarder() async {
    final data = <String, dynamic>{};
    if (_nomCtrl.text.trim().isNotEmpty) data['nom'] = _nomCtrl.text.trim();
    if (_telCtrl.text.trim().isNotEmpty) data['telephone'] = _telCtrl.text.trim();
    if (_passCtrl.text.isNotEmpty) {
      if (_passCtrl.text != _passConfCtrl.text) {
        _showSnack('Les mots de passe ne correspondent pas', Colors.red);
        return;
      }
      data['password']              = _passCtrl.text;
      data['password_confirmation'] = _passConfCtrl.text;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService().req('PUT', '/me', body: data);
      _passCtrl.clear(); _passConfCtrl.clear();
      _showSnack('Profil mis à jour avec succès ✓', Colors.green);
    } on ApiException catch (e) {
      _showSnack(e.firstError ?? e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Profil Administrateur',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _primary, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(children: [
          Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Container(
              height: 100, width: double.infinity,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30))),
            ),
            Positioned(
              top: 30,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 58, backgroundColor: const Color(0xFFE3F2FD),
                  child: _nomCtrl.text.isNotEmpty
                      ? Text(_nomCtrl.text[0],
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _primary))
                      : const Icon(Icons.person_rounded,
                      size: 68, color: _primary),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('INFORMATIONS PERSONNELLES'),
              _card([
                _textField(_nomCtrl, 'Nom complet', Icons.badge_outlined),
                const SizedBox(height: 16),
                _textField(_telCtrl, 'Téléphone', Icons.phone_android_rounded,
                    type: TextInputType.phone),
              ]),
              const SizedBox(height: 24),
              _sectionLabel('CHANGER LE MOT DE PASSE'),
              _card([
                _passField(_passCtrl, 'Nouveau mot de passe', _isObscure1,
                        () => setState(() => _isObscure1 = !_isObscure1),
                    hint: 'Laisser vide si inchangé'),
                const SizedBox(height: 16),
                _passField(_passConfCtrl, 'Confirmer le mot de passe',
                    _isObscure2,
                        () => setState(() => _isObscure2 = !_isObscure2)),
              ]),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _isLoading ? null : _sauvegarder,
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : const Text('ENREGISTRER LES MODIFICATIONS',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold,
        color: Colors.grey.shade600, letterSpacing: 1.3)),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))]),
    child: Column(children: children),
  );

  Widget _textField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl, keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primary),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      );

  Widget _passField(TextEditingController ctrl, String label, bool obscure,
      VoidCallback onToggle, {String? hint}) =>
      TextField(
        controller: ctrl, obscureText: obscure,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: _primary),
          suffixIcon: IconButton(
              icon: Icon(obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: onToggle, color: Colors.grey),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}

// ============================================================
// SECTION LABEL
// ============================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(text, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold,
        color: Colors.grey.shade500, letterSpacing: 1.3)),
  );
}