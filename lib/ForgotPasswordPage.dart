import 'package:flutter/material.dart';
import '../Core/Tontine_store.dart';
import 'Otpverificationpage.dart';

// ============================================================
// ÉTAPE 1 — Saisir l'email pour recevoir l'OTP
// ============================================================

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool  _isLoading = false;

  static const Color _primary = Color(0xFF1565C0);

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _envoyerOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Veuillez entrer une adresse email valide', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService().forgotPassword(email);

      if (!mounted) return;

      // Peu importe si l'email existe ou non, on passe à l'étape OTP
      // (le backend retourne toujours le même message pour la sécurité)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpVerificationPage(email: email)),
      );
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    } catch (_) {
      _showSnack('Erreur réseau. Vérifiez votre connexion.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Icône
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded, size: 64, color: _primary),
              ),
              const SizedBox(height: 30),

              const Text(
                'Mot de passe oublié',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Entrez votre email administrateur.\nVous recevrez un code OTP à 6 chiffres.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.6),
              ),

              const SizedBox(height: 40),

              // Champ email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Votre adresse Email',
                  hintText: 'admin@tontine.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: _primary),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Bouton envoyer
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 4,
                    shadowColor: _primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isLoading ? null : _envoyerOtp,
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                    'ENVOYER LE CODE OTP',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Info sécurité
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: Colors.blue.shade600, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le code OTP expire dans 15 minutes. Vérifiez également vos spams.',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}