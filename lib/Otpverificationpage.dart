import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Core/Tontine_store.dart';
import 'Resetpasswordpage.dart';

// ============================================================
// ÉTAPE 2 — Saisir l'OTP à 6 chiffres
// ============================================================

class OtpVerificationPage extends StatefulWidget {
  final String email;
  const OtpVerificationPage({super.key, required this.email});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // 6 controllers, un par chiffre
  final List<TextEditingController> _ctrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes =
  List.generate(6, (_) => FocusNode());

  bool _isLoading  = false;
  bool _isResending = false;
  int  _countdown  = 60; // secondes avant de pouvoir renvoyer
  Timer? _timer;

  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Focus auto sur le premier champ
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) { t.cancel(); return; }
      setState(() => _countdown--);
    });
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verifierOtp() async {
    if (_otp.length < 6) {
      _showSnack('Entrez les 6 chiffres du code', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().verifyOtp(widget.email, _otp);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordPage(
          email:      widget.email,
          resetToken: res['reset_token'],
        )),
      );
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
      // Efface les champs en cas d'erreur
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
    } catch (_) {
      _showSnack('Erreur réseau', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renvoyer() async {
    if (_countdown > 0) return;
    setState(() => _isResending = true);
    try {
      await ApiService().forgotPassword(widget.email);
      _showSnack('Nouveau code envoyé !', Colors.green);
      _startCountdown();
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
    } on ApiException catch (e) {
      _showSnack(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isResending = false);
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

  // Gestion de la saisie case par case
  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {}); // Pour mettre à jour le bouton
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
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_open_rounded, size: 64, color: Colors.green.shade600),
              ),
              const SizedBox(height: 28),

              const Text(
                'Vérification OTP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.6),
                  children: [
                    const TextSpan(text: 'Un code a 6 chiffres a été envoyé à\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(color: _primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Champs OTP 6 cases
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => _buildOtpBox(i)),
              ),

              const SizedBox(height: 40),

              // Bouton vérifier
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _otp.length == 6 ? _primary : Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: (_isLoading || _otp.length < 6) ? null : _verifierOtp,
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                    'VÉRIFIER LE CODE',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Renvoyer
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Pas reçu le code ? ",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                GestureDetector(
                  onTap: _countdown == 0 ? _renvoyer : null,
                  child: _isResending
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                    _countdown > 0 ? 'Renvoyer (${_countdown}s)' : 'Renvoyer',
                    style: TextStyle(
                      color: _countdown > 0 ? Colors.grey.shade400 : _primary,
                      fontWeight: FontWeight.bold, fontSize: 13,
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // Indicateur de progression
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.timer_outlined, color: Colors.orange.shade600, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Ce code expire dans 15 minutes.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _ctrls[index],
        focusNode: _nodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: _primary,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _ctrls[index].text.isNotEmpty
              ? _primary.withOpacity(0.08)
              : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _ctrls[index].text.isNotEmpty ? _primary : Colors.grey.shade300,
              width: _ctrls[index].text.isNotEmpty ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2.5),
          ),
        ),
        onChanged: (v) => _onChanged(index, v),
      ),
    );
  }
}