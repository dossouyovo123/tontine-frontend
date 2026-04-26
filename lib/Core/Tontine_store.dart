import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
// ============================================================
// CONSTANTES MÉTIER
// ============================================================

const int kMontantHebdo       = 10000; // fallback uniquement
const int kSeuilAbandonnement = 50000;
const int kSeuilEligibilite   = 12;
const int kTotalSemaines      = 52;
const int kSanctionRetard     = 300;
const int kSanctionAbsence    = 500;

// ── Catégories tontine ────────────────────────────────────────
const Map<String, String> kCategorieLibelles = {
  'petits':  'Petits montants',
  'moyens':  'Moyens montants',
  'grands':  'Grands montants',
  'premium': 'Premium',
};

const Map<String, Color> kCategorieColors = {
  'petits':  Color(0xFF2E7D32),
  'moyens':  Color(0xFF1565C0),
  'grands':  Color(0xFFE65100),
  'premium': Color(0xFF6A1B9A),
};

// ============================================================
// MODÈLE TONTINE
// ============================================================

class TontineModel {
  final int    id;
  final String nom;
  final String categorie;
  final int    montant;
  final String? description;
  final bool   isActive;

  const TontineModel({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.montant,
    this.description,
    this.isActive = true,
  });

  factory TontineModel.fromJson(Map<String, dynamic> j) => TontineModel(
    id:          j['id'] as int,
    nom:         j['nom'] as String,
    categorie:   j['categorie'] as String,
    montant:     j['montant'] as int,
    description: j['description'] as String?,
    isActive:    j['is_active'] == true || j['is_active'] == 1,
  );

  String get categorieLibelle => kCategorieLibelles[categorie] ?? categorie;
  Color  get categorieColor   => kCategorieColors[categorie]   ?? Colors.blue;

  /// Libellé montant avec badge si 10500 pour éviter confusion avec 10000
  bool get necessiteBadge => montant == 10500;
}

// ============================================================
// SERVICE API
// ============================================================

class ApiService {
 static const String baseUrl = 'https://tontineapp.com/api/v1';
  static final ApiService _i = ApiService._();
  ApiService._();
  factory ApiService() => _i;

  String? _token;

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final p = await SharedPreferences.getInstance();
    return _token = p.getString('api_token');
  }

  Future<void> saveToken(String t) async {
    _token = t;
    (await SharedPreferences.getInstance()).setString('api_token', t);
  }

  Future<void> clearToken() async {
    _token = null;
    (await SharedPreferences.getInstance()).remove('api_token');
  }

  Future<Map<String, String>> _h({bool auth = true}) async {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final t = await getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<dynamic> req(String method, String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final uri     = Uri.parse('$baseUrl$path');
    final headers = await _h(auth: auth);
    late http.Response r;

    switch (method) {
      case 'GET':    r = await http.get(uri,    headers: headers); break;
      case 'POST':   r = await http.post(uri,   headers: headers, body: body != null ? jsonEncode(body) : null); break;
      case 'PUT':    r = await http.put(uri,    headers: headers, body: body != null ? jsonEncode(body) : null); break;
      case 'DELETE': r = await http.delete(uri, headers: headers); break;
      default:       throw Exception('Méthode HTTP non supportée : $method');
    }

    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return data;
    throw ApiException(r.statusCode, data['message'] ?? 'Erreur', data['errors']);
  }
// ── Bénéfices ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getBenefices({int? annee}) async =>
      (await req('GET',
          annee != null ? '/benefices?annee=$annee' : '/benefices'))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> calculerBenefices({int? annee}) async =>
      (await req('POST', '/benefices/calculer',
          body: annee != null ? {'annee': annee} : {}))
      as Map<String, dynamic>;

  Future<void> supprimerBenefice(int id) async =>
      req('DELETE', '/benefices/$id');

// ── Dépenses ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDepenses() async =>
      (await req('GET', '/depenses')) as Map<String, dynamic>;

  /// Crée une dépense — multipart pour l'image
  Future<Map<String, dynamic>> creerDepense({
    required String motif,
    required int    montant,
    required String dateDepense,
    String?  notes,
    File?    imageFile,
  }) async {
    final token = await getToken();
    final uri   = Uri.parse('$baseUrl/depenses');
    final mReq  = http.MultipartRequest('POST', uri);

    mReq.headers['Accept']        = 'application/json';
    mReq.headers['Authorization'] = 'Bearer $token';
    mReq.fields['motif']          = motif;
    mReq.fields['montant']        = montant.toString();
    mReq.fields['date_depense']   = dateDepense;
    if (notes != null) mReq.fields['notes'] = notes;

    if (imageFile != null) {
      mReq.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    final streamed = await mReq.send();
    final res      = await http.Response.fromStream(streamed);
    final data     = jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, data['message'] ?? 'Erreur', data['errors']);
  }

  /// Modifie une dépense — multipart pour l'image
  Future<Map<String, dynamic>> modifierDepense({
    required int    id,
    required String motif,
    required int    montant,
    String? notes,
    File?   imageFile,
    bool    supprimerImage = false,
  }) async {
    final token = await getToken();
    final uri   = Uri.parse('$baseUrl/depenses/$id/update');
    final mReq  = http.MultipartRequest('POST', uri);

    mReq.headers['Accept']        = 'application/json';
    mReq.headers['Authorization'] = 'Bearer $token';
    mReq.fields['motif']          = motif;
    mReq.fields['montant']        = montant.toString();
    if (notes != null) mReq.fields['notes'] = notes;
    if (supprimerImage) mReq.fields['supprimer_image'] = '1';

    if (imageFile != null) {
      mReq.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    final streamed = await mReq.send();
    final res      = await http.Response.fromStream(streamed);
    final data     = jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, data['message'] ?? 'Erreur', data['errors']);
  }

  Future<void> supprimerDepense(int id) async =>
      req('DELETE', '/depenses/$id');
  // ── Auth ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await req('POST', '/login',
        body: {'email': email, 'password': password}, auth: false);
    await saveToken(r['token']);
    return r as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try { await req('POST', '/logout'); } catch (_) {}
    await clearToken();
  }

  // ── Reset password ────────────────────────────────────────
  Future<Map<String, dynamic>> forgotPassword(String email) async =>
      (await req('POST', '/forgot-password', body: {'email': email}, auth: false))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async =>
      (await req('POST', '/verify-otp', body: {'email': email, 'otp': otp}, auth: false))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async =>
      (await req('POST', '/reset-password', body: {
        'email': email, 'reset_token': resetToken,
        'password': password, 'password_confirmation': passwordConfirmation,
      }, auth: false)) as Map<String, dynamic>;

  // ── Dashboard ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard()          async => (await req('GET', '/dashboard'))           as Map<String, dynamic>;
  Future<Map<String, dynamic>> getStatsCotisations()   async => (await req('GET', '/stats/cotisations'))   as Map<String, dynamic>;
  Future<Map<String, dynamic>> getStatsSanctions()     async => (await req('GET', '/stats/sanctions'))     as Map<String, dynamic>;
  Future<Map<String, dynamic>> getStatsMembres()       async => (await req('GET', '/stats/membres'))       as Map<String, dynamic>;

  // ── Tontines ← NOUVEAU ────────────────────────────────────
  Future<Map<String, dynamic>> getTontines() async =>
      (await req('GET', '/tontines')) as Map<String, dynamic>;

  // ── Membres ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getMembres({String? filter, String? search, int page = 1}) async {
    var p = '/membres?page=$page';
    if (filter != null) p += '&filter=$filter';
    if (search != null) p += '&search=${Uri.encodeComponent(search)}';
    return (await req('GET', p)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMembre(int id) async =>
      (await req('GET', '/membres/$id')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> creerMembre(Map<String, dynamic> data) async =>
      (await req('POST', '/membres', body: data)) as Map<String, dynamic>;

  Future<Map<String, dynamic>> modifierMembre(int id, Map<String, dynamic> data) async =>
      (await req('PUT', '/membres/$id', body: data)) as Map<String, dynamic>;

  Future<void> supprimerMembre(int id) async => req('DELETE', '/membres/$id');

  Future<Map<String, dynamic>> abandonnerMembre(int id) async =>
      (await req('POST', '/membres/$id/abandonner')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> reactiver(int id) async =>
      (await req('POST', '/membres/$id/reactiver')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getHistoriqueMembre(int id) async =>
      (await req('GET', '/membres/$id/historique')) as Map<String, dynamic>;

  Future<List<int>> exportPdfMembre(int id) async {
    final t = await getToken();
    final r = await http.get(Uri.parse('$baseUrl/membres/$id/pdf'),
        headers: {'Authorization': 'Bearer $t'});
    if (r.statusCode == 200) return r.bodyBytes;
    throw ApiException(r.statusCode, 'Erreur PDF');
  }

  // ── Cotisations ───────────────────────────────────────────
  Future<Map<String, dynamic>> getCotisationsSemaine([int? semaine]) async =>
      (await req('GET', semaine != null ? '/cotisations/semaine/$semaine' : '/cotisations/semaine'))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> encaisser({required int membreId, required int numSemaine, int? annee}) async =>
      (await req('POST', '/cotisations/encaisser', body: {
        'membre_id': membreId, 'num_semaine': numSemaine,
        if (annee != null) 'annee': annee,
      })) as Map<String, dynamic>;

  Future<void> annulerCotisation(int id) async => req('PUT', '/cotisations/$id/annuler');

  Future<Map<String, dynamic>> getCotisationsMembre(int membreId) async =>
      (await req('GET', '/membres/$membreId/cotisations')) as Map<String, dynamic>;

  // ── Sanctions ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getSanctions({String? statut, int? membreId}) async {
    var p = '/sanctions?';
    if (statut   != null) p += 'statut=$statut&';
    if (membreId != null) p += 'membre_id=$membreId';
    return (await req('GET', p)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> creerSanction({required int membreId, required String motif, String? notes, String? dateSanction}) async =>
      (await req('POST', '/sanctions', body: {
        'membre_id': membreId, 'motif': motif,
        if (notes        != null) 'notes':         notes,
        if (dateSanction != null) 'date_sanction': dateSanction,
      })) as Map<String, dynamic>;

  Future<Map<String, dynamic>> marquerSanctionPayee(int id) async =>
      (await req('POST', '/sanctions/$id/marquer-paye')) as Map<String, dynamic>;

  Future<void> supprimerSanction(int id) async => req('DELETE', '/sanctions/$id');

  // ── Distributions ─────────────────────────────────────────
  Future<Map<String, dynamic>> getDistributions({int? membreId}) async =>
      (await req('GET', membreId != null ? '/distributions?membre_id=$membreId' : '/distributions'))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> creerDistribution({required int membreId, required int montant, required String date, String? note}) async =>
      (await req('POST', '/distributions', body: {
        'membre_id': membreId, 'montant': montant, 'date_distribution': date,
        if (note != null) 'note': note,
      })) as Map<String, dynamic>;

  Future<void> supprimerDistribution(int id) async => req('DELETE', '/distributions/$id');

  // ── Compléments ───────────────────────────────────────────
  Future<Map<String, dynamic>> getComplements({String? statut}) async =>
      (await req('GET', statut != null ? '/complements?statut=$statut' : '/complements'))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> creerComplement({required int membreId, required int montantMoto, String? description}) async =>
      (await req('POST', '/complements', body: {
        'membre_id': membreId, 'montant_moto_estime': montantMoto,
        if (description != null) 'description_moto': description,
      })) as Map<String, dynamic>;

  Future<Map<String, dynamic>> approuverComplement(int id, {String? notes}) async =>
      (await req('POST', '/complements/$id/approuver', body: notes != null ? {'notes_admin': notes} : null))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> refuserComplement(int id, {String? notes}) async =>
      (await req('POST', '/complements/$id/refuser', body: notes != null ? {'notes_admin': notes} : null))
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> attribuerMoto(int id) async =>
      (await req('POST', '/complements/$id/attribuer')) as Map<String, dynamic>;
}

// ============================================================
// EXCEPTION API
// ============================================================

class ApiException implements Exception {
  final int     statusCode;
  final String  message;
  final dynamic errors;

  ApiException(this.statusCode, this.message, [this.errors]);

  @override String toString() => message;
  bool get isUnauthorized => statusCode == 401;
  bool get isValidation   => statusCode == 422;

  String? get firstError {
    if (errors == null) return null;
    if (errors is Map && (errors as Map).isNotEmpty) {
      final v = (errors as Map).values.first;
      return v is List ? v.first as String : v.toString();
    }
    return null;
  }
}

// ============================================================
// MODÈLE MEMBRE — MODIFIÉ : tontine intégrée
// ============================================================

class Membre {
  final int    id;
  final int    numRegistre;
  String  nom;
  String  telephone;
  String  adresse;
  String  profession;
  bool    isActive;
  bool    aAbandonne;
  final String dateInscription;

  int  semainesCotisees;
  int  totalCotiseCfa;
  bool estEligibleMoto;
  bool perdArgentSiAbandon;

  // ← NOUVEAU
  final int?          tontineId;
  final TontineModel? tontine;
  final int           montantCotisation; // montant propre au membre

  Membre({
    required this.id,
    required this.numRegistre,
    required this.nom,
    required this.telephone,
    this.adresse = '',
    required this.profession,
    this.isActive         = true,
    this.aAbandonne       = false,
    required this.dateInscription,
    this.semainesCotisees    = 0,
    this.totalCotiseCfa      = 0,
    this.estEligibleMoto     = false,
    this.perdArgentSiAbandon = true,
    this.tontineId           = null,    // ← NOUVEAU
    this.tontine             = null,    // ← NOUVEAU
    this.montantCotisation   = kMontantHebdo, // ← NOUVEAU
  });

  factory Membre.fromJson(Map<String, dynamic> j) {
    TontineModel? tontine;
    if (j['tontine'] != null) {
      tontine = TontineModel.fromJson(j['tontine'] as Map<String, dynamic>);
    }

    return Membre(
      id:              j['id'] as int,
      numRegistre:     j['num_registre'] as int,
      nom:             j['nom'] as String,
      telephone:       j['telephone']  as String? ?? '',
      adresse:         j['adresse']    as String? ?? '',
      profession:      j['profession'] as String? ?? '',
      isActive:        j['is_active']  == true || j['is_active']  == 1,
      aAbandonne:      j['a_abandonne'] == true || j['a_abandonne'] == 1,
      dateInscription: j['date_inscription'] as String? ?? '',
      semainesCotisees:    j['semaines_cotisees']    as int? ?? 0,
      totalCotiseCfa:      j['total_cotise_cfa']     as int? ?? 0,
      estEligibleMoto:     j['est_eligible_moto']    == true,
      perdArgentSiAbandon: j['perd_argent_si_abandon'] == true ||
          (j['total_cotise_cfa'] as int? ?? 0) < kSeuilAbandonnement,
      tontineId:           j['tontine_id'] as int?,
      tontine:             tontine,
      montantCotisation:   j['montant_cotisation'] as int? ??
          tontine?.montant         ??
          kMontantHebdo,
    );
  }

  String get statutLabel =>
      aAbandonne ? 'ABANDONNÉ' : (isActive ? 'ACTIF' : 'INACTIF');

  Color get statutColor =>
      aAbandonne ? Colors.red.shade700 : (isActive ? Colors.green : Colors.grey);

  double get progressionAnnuelle =>
      (semainesCotisees / kTotalSemaines).clamp(0.0, 1.0);

  /// Nom court de la tontine pour l'affichage dans les listes
  String get tontineLabel => tontine?.nom ?? 'Tontine non définie';

  /// Couleur de la catégorie
  Color get tontineColor => tontine?.categorieColor ?? Colors.grey;
}

// ============================================================
// STORE GLOBAL — MODIFIÉ
// ============================================================

class TontineStore extends ChangeNotifier {
  static final TontineStore _i = TontineStore._();
  TontineStore._();
  factory TontineStore() => _i;

  Map<int, Map<int, String>> cotisationsParMembre = {};
  Map<int, Map<int, int>>    _cotisationIds       = {};

  List<Membre>       membres   = [];
  List<TontineModel> tontines  = []; // ← NOUVEAU
  bool               isLoading = false;
  String?            errorMsg;

  Map<int, Set<int>> cotisationsSemaines = {};

  void reset() {
    membres               = [];
    tontines              = []; // ← NOUVEAU
    cotisationsParMembre  = {};
    _cotisationIds        = {};
    cotisationsSemaines   = {};
    isLoading             = false;
    errorMsg              = null;
    notifyListeners();
  }

  // ── Dates (inchangées) ────────────────────────────────────
  DateTime get premierSamediJanvier {
    final a    = DateTime.now().year;
    final jan1 = DateTime(a, 1, 1);
    final j    = (DateTime.saturday - jan1.weekday + 7) % 7;
    return jan1.add(Duration(days: j));
  }

  DateTime dateDuSamedi(int semaine) =>
      premierSamediJanvier.add(Duration(days: (semaine - 1) * 7));

  int get semaineCourante {
    final debut = premierSamediJanvier;
    final now   = DateTime.now();
    if (now.isBefore(debut)) return 1;
    return ((now.difference(debut).inDays) ~/ 7 + 1).clamp(1, kTotalSemaines);
  }

  // ── Statut ────────────────────────────────────────────────
  String calculerStatut(int membreId) {
    final sem    = semaineCourante;
    final statut = statutSemaine(membreId, sem);
    if (statut == 'paye') return 'Payé';
    if (DateTime.now().weekday > DateTime.saturday) return 'En retard';
    return 'Impayé';
  }

  bool aPayeSemaine(int membreId, int semaine) =>
      cotisationsParMembre[membreId]?[semaine] == 'paye';

  String statutSemaine(int membreId, int semaine) =>
      cotisationsParMembre[membreId]?[semaine] ?? 'impaye';

  void saveCotisationId(int membreId, int semaine, int cotisationId) {
    _cotisationIds.putIfAbsent(membreId, () => {});
    _cotisationIds[membreId]![semaine] = cotisationId;
  }

  int? getCotisationId(int membreId, int semaine) =>
      _cotisationIds[membreId]?[semaine];

  // ── Chargement tontines ← NOUVEAU ────────────────────────
  Future<void> chargerTontines() async {
    try {
      final res = await ApiService().getTontines();
      final cats = (res['categories'] as List? ?? []);
      tontines = cats
          .expand((cat) => (cat['tontines'] as List? ?? []))
          .map((t) => TontineModel.fromJson(t as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Tontines groupées par catégorie (pour le picker)
  Map<String, List<TontineModel>> get tontinesParCategorie {
    final map = <String, List<TontineModel>>{};
    for (final t in tontines) {
      map.putIfAbsent(t.categorie, () => []).add(t);
    }
    return map;
  }

  // ── Chargement membres ────────────────────────────────────
  bool _chargeEnCours = false;

  Future<void> chargerMembres() async {
    if (_chargeEnCours) return;
    _chargeEnCours = true;
    isLoading = true; errorMsg = null; notifyListeners();
    try {
      // Charge les tontines en parallèle si pas encore chargées
      if (tontines.isEmpty) unawaited(chargerTontines());

      final res  = await ApiService().getMembres();
      final data = (res['data'] as List?) ?? (res['membres'] as List?) ?? [];
      membres = data
          .map((j) => Membre.fromJson(j as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      errorMsg = e.message;
    } catch (_) {
      errorMsg = 'Erreur réseau';
    }
    _chargeEnCours = false;
    isLoading = false; notifyListeners();
  }

  Future<void> chargerCotisationsSemaine([int? semaine]) async {
    final s = semaine ?? semaineCourante;
    try {
      final res   = await ApiService().getCotisationsSemaine(s);
      final items = (res['membres'] as List? ?? []);

      for (final item in items) {
        final mid    = item['membre_id'] as int;
        final statut = item['statut'] as String? ?? 'impaye';
        final cotId  = item['cotisation_id'] as int?;

        cotisationsParMembre.putIfAbsent(mid, () => {});
        cotisationsParMembre[mid]![s] = statut;
        if (cotId != null) saveCotisationId(mid, s, cotId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur chargement cotisations: $e");
    }
  }

  Future<void> chargerHistoriqueMembre(int membreId) async {
    try {
      final res   = await ApiService().getCotisationsMembre(membreId);
      final items = (res['cotisations'] as List? ?? []);
      cotisationsParMembre[membreId] = {};
      for (final c in items) {
        final sem    = c['num_semaine'] as int;
        final statut = c['statut'] as String? ?? 'impaye';
        final cotId  = c['id'] as int?;
        cotisationsParMembre[membreId]![sem] = statut;
        if (cotId != null) saveCotisationId(membreId, sem, cotId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur historique: $e");
    }
  }

  // ── Mutations membres ─────────────────────────────────────
  void ajouterMembre(Membre m)  { membres.add(m);                         notifyListeners(); }
  void supprimerMembre(int id)  { membres.removeWhere((m) => m.id == id); notifyListeners(); }

  void mettreAJourMembre(Membre m) {
    final idx = membres.indexWhere((e) => e.id == m.id);
    if (idx >= 0) membres[idx] = m;
    notifyListeners();
  }

  // ── Mutations cotisations ← MODIFIÉ : utilise montant du membre ──
  void encaisserLocal(int membreId, int semaine) {
    cotisationsParMembre.putIfAbsent(membreId, () => {});
    cotisationsParMembre[membreId]![semaine] = 'paye';
    cotisationsSemaines.putIfAbsent(membreId, () => {}).add(semaine);

    try {
      final m = membres.firstWhere((e) => e.id == membreId);
      m.semainesCotisees++;
      m.totalCotiseCfa += m.montantCotisation; // ← MODIFIÉ
      m.estEligibleMoto = m.semainesCotisees >= kSeuilEligibilite;
    } catch (_) {}

    notifyListeners();
  }

  void annulerLocal(int membreId, int semaine) {
    cotisationsParMembre[membreId]?[semaine] = 'impaye';
    cotisationsSemaines[membreId]?.remove(semaine);

    try {
      final m = membres.firstWhere((e) => e.id == membreId);
      if (m.semainesCotisees > 0) {
        m.semainesCotisees--;
        m.totalCotiseCfa -= m.montantCotisation; // ← MODIFIÉ
        m.estEligibleMoto = m.semainesCotisees >= kSeuilEligibilite;
      }
    } catch (_) {}

    notifyListeners();
  }
}

// Helper pour appel async non-attendu
void unawaited(Future<void> future) => future.ignore();