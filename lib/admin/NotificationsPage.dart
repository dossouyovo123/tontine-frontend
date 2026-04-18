import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Nécessaire pour wa.me

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  // --- LOGIQUE FUTURE : RÉCUPÉRATION ET ENVOI ---

  // Cette fonction simulera plus tard la récupération des numéros
  // de tous les membres enregistrés par l'admin.
  Future<void> _envoyerRappelGeneral(BuildContext context) async {
    // 1. Plus tard, tu feras ici : List<Membre> membres = await database.getMembres();
    // 2. Pour l'instant, on simule l'intention

    Navigator.pop(context); // Ferme le dialogue

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Préparation du message groupé pour WhatsApp..."),
        backgroundColor: Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Note technique : Pour envoyer à TOUT LE MONDE sur WhatsApp sans les avoir
    // dans l'app, l'admin devra utiliser une "Liste de diffusion" sur WhatsApp.
    // L'app peut lui copier le texte parfait à coller dans sa liste.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("Centre de Communication",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        centerTitle: true,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: "Partage Rapide (WhatsApp/SMS)"),
            const SizedBox(height: 15),

            Row(
              children: [
                _buildActionBtn(
                    context,
                    "Rappel\nGénéral",
                    Icons.groups_rounded,
                    Colors.orange,
                    "Générer un rappel pour TOUS les membres enregistrés ?"),
                const SizedBox(width: 12),
                _buildActionBtn(
                    context,
                    "Reçu\nGain",
                    Icons.receipt_long_rounded,
                    Colors.green,
                    "Générer le message de gain pour le bénéficiaire ?"),
                const SizedBox(width: 12),
                _buildActionBtn(
                    context,
                    "Avis\nSanction",
                    Icons.gavel_rounded,
                    Colors.red,
                    "Préparer le message de sanction ?"),
              ],
            ),

            const SizedBox(height: 35),

            const _SectionTitle(title: "Modèles de Messages"),
            const SizedBox(height: 12),

            _buildTemplateCard(
              context,
              "Rappel de Cotisation",
              "Bonjour à tous, petit rappel pour les cotisations de ce mois. Merci de régulariser avant le 05.",
              Icons.message_rounded,
              Colors.blue,
            ),
            _buildTemplateCard(
              context,
              "Annonce de Gain",
              "Félicitations ! Votre tour de tontine est arrivé. Le montant est disponible chez le trésorier.",
              Icons.emoji_events_rounded,
              Colors.green,
            ),

            const SizedBox(height: 35),

            const _SectionTitle(title: "Historique des Communications", icon: Icons.history_rounded),
            const SizedBox(height: 15),

            _buildHistoryItem("WhatsApp : Groupe Tontine", "Rappel général généré", "10:30", Colors.orange),
            _buildHistoryItem("WhatsApp : Individuel", "Reçu de gain envoyé", "Hier", Colors.green),
            _buildHistoryItem("SMS : Relance", "Sanction notifiée", "05 Mars", Colors.red),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE COMPOSANTS ---

  Widget _buildTemplateCard(BuildContext context, String title, String preview, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.copy_all_rounded, size: 20, color: Colors.grey),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Modèle '$title' prêt à être collé !"), backgroundColor: Colors.blue),
          );
        },
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, String title, IconData icon, Color color, String msg) {
    return Expanded(
      child: InkWell(
        onTap: () => _showConfirmDialog(context, title.replaceAll('\n', ' '), msg),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, height: 1.1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String subtitle, String date, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
          Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _envoyerRappelGeneral(context),
            child: const Text("Générer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionTitle({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: Colors.black54), const SizedBox(width: 8)],
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}