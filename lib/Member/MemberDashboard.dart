import 'package:flutter/material.dart';
import 'NotificationPage.dart'; // Import de la nouvelle page

class MemberDashboard extends StatelessWidget {
  const MemberDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Ma Tontine", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        actions: [
          // ICÔNE NOTIFICATION AVEC BADGE
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationPage()));
                },
              ),
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                ),
              )
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER DYNAMIQUE
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 10, 25, 0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(radius: 32, backgroundImage: NetworkImage("https://i.pravatar.cc/150?u=paul")),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Bonjour,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                          Text("Paul Kouadio", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Résumé de mes activités", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 15),

                  // CARTES STYLE MAQUETTE (AVEC DÉGRADÉS)
                  _buildCoolCard("Mes Cotisations", "20,000 CFA", [Color(0xFF1976D2), Color(0xFF42A5F5)], Icons.account_balance_wallet),
                  _buildCoolCard("Mes Sanctions", "5,000 CFA", [Color(0xFFD32F2F), Color(0xFFEF5350)], Icons.gavel_rounded),
                  _buildCoolCard("Mes Distributions", "50,000 CFA", [Color(0xFF388E3C), Color(0xFF66BB6A)], Icons.stars_rounded),

                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Dernières alertes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton (
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationPage())),
                        child: const Text("Voir tout", style: TextStyle(color: Color(0xFF2E7D32))),
                      )
                    ],
                  ),

                  _buildNotificationMini("Cotisation Avril", "Il reste 3 jours pour payer", "2h", Colors.orange),
                  _buildNotificationMini("Distribution validée", "Paiement de 50,000 CFA effectué", "Hier", Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET CARTE AMÉLIORÉE
  Widget _buildCoolCard(String title, String amount, List<Color> colors, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 5),
              Text(amount, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(icon, color: Colors.white30, size: 40),
        ],
      ),
    );
  }

  Widget _buildNotificationMini(String title, String subtitle, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.notifications_active_rounded, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ),
    );
  }
}