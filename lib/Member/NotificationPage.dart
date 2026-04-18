import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Notifications"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _notificationTile("Cotisation d'Avril", "C'est le moment de cotiser pour le cycle en cours.", "Aujourd'hui, 10:30", Icons.monetization_on, Colors.blue),
          _notificationTile("Sanction Appliquée", "Retard à la réunion du 15 Mars.", "Hier, 18:45", Icons.gavel_rounded, Colors.red),
          _notificationTile("Distribution Reçue", "Félicitations ! Vous avez reçu votre part.", "12 Mars, 09:00", Icons.card_giftcard, Colors.green),
          _notificationTile("Rappel Règlement", "Le nouveau règlement est disponible.", "10 Mars", Icons.info_outline, Colors.orange),
        ],
      ),
    );
  }

  Widget _notificationTile(String title, String body, String date, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(body, style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 8),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}