import 'package:flutter/material.dart';
import 'ReglementPage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [


          SingleChildScrollView(
            // Padding réduit
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 60),
            child: Column(
              children: [
                // Header réduit
                const CircleAvatar(
                  radius: 35, // Plus petit (était 45)
                  backgroundColor: Color(0xFFF0F4F8),
                  child: Icon(Icons.person_add_rounded, size: 35, color: Color(0xFF1565C0)),
                ),

                const SizedBox(height: 43), // Espacement réduit

                const Text("Créer un compte",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),

                const SizedBox(height: 5),

                const Text("Rejoignez votre groupe de tontine",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13)),

                const SizedBox(height: 25), // Espacement réduit (était 40)

                // LES CHAMPS DE SAISIE (Hauteur réduite via contentPadding dans _buildField)
                _buildField("Nom complet", Icons.person_outline),
                const SizedBox(height: 12), // Plus serré
                _buildField("Téléphone", Icons.phone_android_rounded, type: TextInputType.phone),
                const SizedBox(height: 12),
                _buildField("Mot de passe", Icons.lock_outline_rounded, obscure: true),
                const SizedBox(height: 12),
                _buildField("Confirmer mot de passe", Icons.lock_clock_outlined, obscure: true),

                const SizedBox(height: 15),

                // ZONE RÈGLEMENT COMPACTE
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReglementPage()),
                    );
                    if (result == true) setState(() => _isAccepted = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 35,
                          width: 35,
                          child: Checkbox(
                            value: _isAccepted,
                            activeColor: const Color(0xFF1565C0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) => setState(() => _isAccepted = val!),
                          ),
                        ),
                        const Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: "J'accepte les ",
                              style: TextStyle(fontSize: 12),
                              children: [
                                TextSpan(
                                  text: " conditions et règlements intérieur",
                                  style: TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25), // Réduit

                // BOUTON INSCRIPTION PLUS FIN
                Container(
                  width: double.infinity,
                  height: 50, // Moins haut (était 55)
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAccepted ? const Color(0xFF1565C0) : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isAccepted ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Inscription validée !"))
                      );
                    } : null,
                    child: const Text("S'INSCRIRE",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 15),

                // LIEN RETOUR LOGIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Déjà membre ?", style: TextStyle(fontSize: 13)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                          "Se connecter",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 13)
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text}) {
    return Container(
      // Hauteur visuelle plus fine
      child: TextField(
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(fontSize: 14), // Texte saisi plus petit
        decoration: InputDecoration(
          isDense: true, // IMPORTANT : Réduit l'espace interne
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF1565C0), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
          ),
        ),
      ),
    );
  }
}