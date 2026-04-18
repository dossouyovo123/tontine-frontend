import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({super.key});

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  String _nom = "Paul Kouadio";
  String _phone = "+225 0102030405";

  // Utilisation de File pour l'image locale et String pour l'image par défaut
  File? _imageFile;
  final String _defaultNetWorkImage = "https://i.pravatar.cc/150?u=paul";

  // --- LOGIQUE RÉELLE DE SÉLECTION DE PHOTO ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Ouvre la galerie
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Compresse légèrement pour plus de fluidité
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo de profil mise à jour !"), backgroundColor: Colors.green),
      );
    }
  }

  // Widget helper pour afficher l'image (soit locale, soit réseau)
  ImageProvider _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    }
    return NetworkImage(_defaultNetWorkImage);
  }

  // --- LES AUTRES FONCTIONS (MODIF TEXTE / PASS) ---
  void _editField(String label, String currentVal, Function(String) onSave) {
    TextEditingController controller = TextEditingController(text: currentVal);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Modifier $label", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                setState(() => onSave(controller.text));
                Navigator.pop(context);
              },
              child: const Text("ENREGISTRER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _editPassword() {
    TextEditingController oldPass = TextEditingController();
    TextEditingController newPass = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Changement de mot de passe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: oldPass, obscureText: true, decoration: const InputDecoration(labelText: "Ancien mot de passe")),
            const SizedBox(height: 15),
            TextField(controller: newPass, obscureText: true, decoration: const InputDecoration(labelText: "Nouveau mot de passe")),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.pop(context),
              child: const Text("VALIDER", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Ma Tontine", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        actions: [
          // MINI PHOTO DANS LE HEADER
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: _getProfileImage(),
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER VERT ---
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: _getProfileImage(),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: _pickImage, // APPEL DE LA GALERIE
                          child: const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFF1565C0),
                            child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_nom, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("Membre Certifié", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 25),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildSectionCard([
                    _infoTile(Icons.person_outline, "Nom", _nom, () => _editField("Nom", _nom, (val) => _nom = val)),
                    const Divider(height: 1, indent: 60),
                    _infoTile(Icons.phone_iphone, "Téléphone", _phone, () => _editField("Téléphone", _phone, (val) => _phone = val)),
                    const Divider(height: 1, indent: 60),
                    _infoTile(Icons.lock_reset_rounded, "Sécurité", "Modifier le mot de passe", _editPassword),
                  ]),
                  const SizedBox(height: 20),
                  _buildActionCard(Icons.menu_book_rounded, "Règlement intérieur", "Consulter les règles", () => _showReglement(context)),
                  const SizedBox(height: 35),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () {},
                    child: const Text("SAUVEGARDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    child: const Text("Déconnexion", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widgets de construction réutilisables...
  Widget _buildSectionCard(List<Widget> children) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(children: children));

  Widget _infoTile(IconData icon, String label, String value, VoidCallback onTap) => ListTile(onTap: onTap, leading: Icon(icon, color: Colors.grey[600]), title: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), trailing: const Icon(Icons.edit, size: 16, color: Colors.blue));

  Widget _buildActionCard(IconData icon, String title, String sub, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.withOpacity(0.2))), child: Row(children: [Icon(icon, color: const Color(0xFF2E7D32)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey))])), const Icon(Icons.chevron_right, size: 18, color: Colors.grey)])));

  void _showReglement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scroll) => Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              const Text("Règlement Intérieur", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const Divider(height: 30),
              Expanded(child: ListView(controller: scroll, children: const [
                Text("Art 1. Les cotisations sont obligatoires...", style: TextStyle(fontSize: 14)),
                SizedBox(height: 10),
                Text("Art 2. Tout retard entraîne une amende de 2000 CFA.", style: TextStyle(fontSize: 14)),
              ])),
            ],
          ),
        ),
      ),
    );
  }
}