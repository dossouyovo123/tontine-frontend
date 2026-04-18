import 'package:flutter/material.dart';

class ReglementPage extends StatelessWidget {
  const ReglementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Règlement Intérieur"),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CONDITIONS D'UTILISATION",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                  const Divider(),
                  _art("Art 1. Ponctualité", "Toute cotisation doit être versée avant le 5 du mois. Passé ce délai, une amende de 2.000 CFA sera appliquée automatiquement."),
                  _art("Art 2. Présence", "La présence aux réunions mensuelles est obligatoire. L'absence non justifiée coûte 1.000 CFA."),
                  _art("Art 3. Remboursement", "En cas de retrait de la tontine, le membre récupère ses fonds après déduction des frais de gestion."),
                  _art("Art 4. Confidentialité", "Les informations du groupe restent privées."),
                ],
              ),
            ),
          ),
          // Bouton de validation en bas
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () => Navigator.pop(context, true), // Renvoie 'true' à la page précédente
              child: const Text("J'AI LU ET J'ACCEPTE", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _art(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          Text(content, style: const TextStyle(color: Colors.black87, height: 1.4)),
        ],
      ),
    );
  }
}