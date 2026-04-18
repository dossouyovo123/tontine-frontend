import 'package:flutter/material.dart';

class MemberCotisations extends StatefulWidget {
  const MemberCotisations({super.key});

  @override
  State<MemberCotisations> createState() => _MemberCotisationsState();
}

class _MemberCotisationsState extends State<MemberCotisations> {
  bool _isDescending = true;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Changé de 3 à 2
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        appBar: AppBar(
          title: const Text("Mes Finances", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(_isDescending ? Icons.sort_rounded : Icons.history_rounded, color: const Color(0xFF2E7D32)),
              onPressed: () {
                setState(() => _isDescending = !_isDescending);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isDescending ? "Tri: Plus récent" : "Tri: Plus ancien"),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // --- BARRE DE RECHERCHE ---
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Rechercher un mois, une année...",
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                  filled: true,
                  fillColor: const Color(0xFFF1F3F4),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // --- ONGLETS (COTISATIONS / SANCTIONS) ---
            Container(
              color: Colors.white,
              child: const TabBar(
                indicatorColor: Color(0xFF2E7D32),
                labelColor: Color(0xFF2E7D32),
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: "Cotisations"),
                  Tab(text: "Sanctions"),
                ],
              ),
            ),

            // --- LE CONTENU ---
            Expanded(
              child: TabBarView(
                children: [
                  // ONGLET COTISATIONS
                  _buildList([
                    _financeCard("Avril 2026", "20,000 CFA", "Payé", Colors.green, Icons.check_circle_outline),
                    _financeCard("Mars 2026", "20,000 CFA", "Retard/Payé", Colors.orange, Icons.warning_amber_rounded),
                    _financeCard("Février 2026", "20,000 CFA", "Payé", Colors.green, Icons.check_circle_outline),
                    _financeCard("Octobre 2025", "20,000 CFA", "Impayé", Colors.red, Icons.error_outline),
                  ]),

                  // ONGLET SANCTIONS
                  _buildList([
                    _financeCard("Retard paiement (Avril)", "2,000 CFA", "À régler", Colors.orange, Icons.gavel_rounded),
                    _financeCard("Absence réunion", "5,000 CFA", "Payé", Colors.green, Icons.check_circle_outline),
                    _financeCard("Enfreint règlement", "10,000 CFA", "Impayé", Colors.red, Icons.gavel_rounded),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIQUE DE FILTRE ET DE TRI ---
  Widget _buildList(List<Widget> children) {
    // Filtrage manuel pour la démo (sur la base des clés ValueKey)
    List<Widget> filteredChildren = children.where((widget) {
      if (_searchQuery.isEmpty) return true;
      return widget.toString().toLowerCase().contains(_searchQuery);
    }).toList();

    List<Widget> sortedChildren = _isDescending ? filteredChildren : filteredChildren.reversed.toList();

    if (sortedChildren.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            const Text("Aucun résultat trouvé", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      children: sortedChildren,
    );
  }

  // --- CARTE FINANCIÈRE ---
  Widget _financeCard(String title, String amount, String status, Color color, IconData icon) {
    // Filtre simple sur le titre pour la recherche
    if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    return Container(
      key: ValueKey(title),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(amount, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ),
    );
  }
}