import 'package:flutter/material.dart';
import '../Core/Tontine_store.dart';

// ============================================================
// ÉTAPE 3 — Saisir le nouveau mot de passe
// ============================================================

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String resetToken;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.resetToken,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  bool  _isObscure1      = true;
  bool  _isObscure2      = true;
  bool  _isLoading       = false;

  static const Color _primary = Color(0xFF1565C0);

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final p = _passwordCtrl.text;
    final c = _confirmCtrl.text;
    return p.length >= 6 && p == c;
  }

  Future<void> _resetPassword() async {
    if (!_isValid) {
      if (_passwordCtrl.text.length < 6) {
        _showSnack('Le mot de passe doit faire au moins 6 caractères', Colors.orange);
      } else {
        _showSnack('Les mots de passe ne correspondent pas', Colors.red);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService().resetPassword(
        email:                widget.email,
        resetToken:           widget.resetToken,
        password:             _passwordCtrl.text,
        passwordConfirmation: _confirmCtrl.text,
      );

      if (!mounted) return;

      // Succès → retour login avec message
      _showSuccessDialog();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    } catch (_) {
      _showSnack('Erreur réseau', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 56),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mot de passe réinitialisé !',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Votre mot de passe a été mis à jour avec succès.\nConnectez-vous avec vos nouveaux identifiants.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
          ),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // Vide toute la pile et retourne au login
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
            child: const Text(
              'SE CONNECTER',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
                decoration: BoxDecoration(color: _primary.withOpacity(0.08), shape: BoxShape.circle),
                child: const Icon(Icons.lock_reset_rounded, size: 64, color: _primary),
              ),
              const SizedBox(height: 28),

              const Text(
                'Nouveau mot de passe',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Choisissez un mot de passe sécurisé\nd\'au moins 6 caractères.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.6),
              ),

              const SizedBox(height: 40),

              // Nouveau mot de passe
              TextField(
                controller: _passwordCtrl,
                obscureText: _isObscure1,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: _primary),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure1 ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                    onPressed: () => setState(() => _isObscure1 = !_isObscure1),
                  ),
                  filled: true, fillColor: Colors.grey.shade50,
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

              const SizedBox(height: 16),

              // Indicateur de force
              if (_passwordCtrl.text.isNotEmpty) _buildStrengthIndicator(),

              const SizedBox(height: 16),

              // Confirmation
              TextField(
                controller: _confirmCtrl,
                obscureText: _isObscure2,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: _primary),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure2 ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                    onPressed: () => setState(() => _isObscure2 = !_isObscure2),
                  ),
                  // Indicateur de correspondance
                  suffixIconConstraints: const BoxConstraints(minWidth: 80),
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: _confirmCtrl.text.isNotEmpty
                          ? (_confirmCtrl.text == _passwordCtrl.text ? Colors.green : Colors.red)
                          : Colors.grey.shade200,
                      width: _confirmCtrl.text.isNotEmpty ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                ),
              ),
              if (_confirmCtrl.text.isNotEmpty && _confirmCtrl.text != _passwordCtrl.text)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(children: [
                    const Icon(Icons.close, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('Les mots de passe ne correspondent pas',
                        style: TextStyle(color: Colors.red.shade600, fontSize: 11)),
                  ]),
                ),

              const SizedBox(height: 40),

              // Bouton
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid ? _primary : Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: (_isLoading || !_isValid) ? null : _resetPassword,
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                    'RÉINITIALISER LE MOT DE PASSE',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthIndicator() {
    final p   = _passwordCtrl.text;
    int score = 0;
    if (p.length >= 6)                            score++;
    if (p.length >= 10)                           score++;
    if (p.contains(RegExp(r'[A-Z]')))             score++;
    if (p.contains(RegExp(r'[0-9]')))             score++;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?]'))) score++;

    final colors = [Colors.red, Colors.orange, Colors.yellow.shade700, Colors.lightGreen, Colors.green];
    final labels = ['Très faible', 'Faible', 'Moyen', 'Bon', 'Excellent'];
    final idx    = (score - 1).clamp(0, 4);

    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 5,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(colors[idx]),
            minHeight: 4,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(labels[idx], style: TextStyle(color: colors[idx], fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }
}