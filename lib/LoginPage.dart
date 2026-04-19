import 'package:flutter/material.dart';
import '../Core/Tontine_store.dart';
import 'ForgotPasswordPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscure = true;
  bool _isLoading = false;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  static const Color _primary = Color(0xFF1565C0);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // ✅ Login API + sauvegarde token
      await ApiService().login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (!mounted) return;

      // ✅ NE PAS appeler chargerMembres() ici.
      // MainNavigation.initState() s'en charge via postFrameCallback.
      // Appeler les deux créait une race condition qui corrompait
      // le token en mémoire et provoquait des 401 sur la nouvelle session.

      Navigator.pushReplacementNamed(context, '/main');

    } on ApiException catch (e) {
      _showError(e.firstError ?? e.message);
    } catch (_) {
      _showError('Erreur réseau. Vérifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: Form(
            key: _formKey,
            child: Column(children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    size: 60, color: _primary),
              ),
              const SizedBox(height: 28),

              const Text('Espace Administrateur',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _primary)),
              const SizedBox(height: 8),
              Text('Connectez-vous pour gérer la tontine',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),

              const SizedBox(height: 48),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email requis';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Adresse Email',
                  hintText: 'admin@tontine.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: _primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _primary, width: 2)),
                ),
              ),
              const SizedBox(height: 20),

              // Mot de passe
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _isObscure,
                textInputAction: TextInputAction.done,
                onEditingComplete: _login,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Mot de passe requis';
                  if (v.length < 6) return 'Minimum 6 caractères';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: _primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _primary, width: 2)),
                ),
              ),

              // Mot de passe oublié
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                  child: const Text('Mot de passe oublié ?',
                      style: TextStyle(
                          color: _primary, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 24),

              // Bouton connexion
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text('SE CONNECTER',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 40),

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.verified_user_outlined,
                    size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text('Connexion sécurisée',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}