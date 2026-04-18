import 'package:flutter/material.dart';
import 'Member/MemberDashboard.dart';
import 'Member/coti_sanc_distr.dart';
import'Member/Member_distributions.dart';
import'Member/MemberProfilePage.dart';

class MainNavigationMembre extends StatefulWidget {
  const MainNavigationMembre({super.key});

  @override
  State<MainNavigationMembre> createState() => _MainNavigationMembreState();
}

class _MainNavigationMembreState extends State<MainNavigationMembre> {
  int _currentIndex = 0;

  // ON DÉFINIT L'ORDRE STRICT ICI (0, 1, 2, 3)
  final List<Widget> _pages = [
    const MemberDashboard(),      // Index 0
    const MemberCotisations(),    // Index 1
    const MemberDistributions(),  // Index 2 (DISTRIBUTIONS)
    const MemberProfilePage(),    // Index 3 (PROFIL)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack va chercher l'enfant au numéro _currentIndex
      body: IndexedStack(
          index: _currentIndex,
          children: _pages
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // OBLIGATOIRE pour 4 éléments
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        onTap: (int index) {
          setState(() {
            _currentIndex = index; // index 2 affichera _pages[2] (Distris)
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),           // 0
          BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: "Finances"), // 1
          BottomNavigationBarItem(icon: Icon(Icons.wallet_giftcard), label: "Distris"),  // 2
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),           // 3
        ],
      ),
    );
  }

}












