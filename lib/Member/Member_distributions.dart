import 'package:flutter/material.dart';

class MemberDistributions extends StatefulWidget {
  const MemberDistributions({super.key});

  @override
  State<MemberDistributions> createState() => _MemberDistributionsState();
}

class _MemberDistributionsState extends State<MemberDistributions> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("Mes Gains / Distributions", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche dédiée aux cycles
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Rechercher un cycle ou une date...",
                prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFF1565C0)),
                filled: true,
                fillColor: const Color(0xFFF1F3F4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _distributionCard(context, "Cycle A - Tontine Scolaire", "50,000 CFA", "10 Fév 2026"),
                _distributionCard(context, "Cycle B - Tontine Fêtes", "150,000 CFA", "10 Jan 2026"),
                _distributionCard(context, "Cycle Spécial - Mariage", "25,000 CFA", "15 Déc 2025"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _distributionCard(BuildContext context, String cycle, String amount, String date) {
    if (_searchQuery.isNotEmpty && !cycle.toLowerCase().contains(_searchQuery) && !date.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const CircleAvatar(
          backgroundColor: Colors.white24,
          child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
        ),
        title: Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        subtitle: Text("Reçue le $date\n$cycle", style: const TextStyle(color: Colors.white70, fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.file_download_rounded, color: Colors.white, size: 28),
          onPressed: () => _showDownloadFeedback(context),
        ),
      ),
    );
  }

  void _showDownloadFeedback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Téléchargement du reçu PDF en cours..."),
        backgroundColor: Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}