import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../services/address_service.dart';
import '../../providers/api_client.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert'; // jsonDecode + utf8
import 'package:http/http.dart' as http; // http.get
class ProjectFormController extends GetxController {
  
  final formKey = GlobalKey<FormState>();
var projectModele = "project".obs;

/// 🔥 AJOUT ICI
bool get isProject => projectModele.value == "project";
bool get isRevendeur => projectModele.value == "revendeur";
bool get isApplicateur => projectModele.value == "applicateur";
  // ---------------- Fields ----------------
  // CRM ACTION
final RxnString selectedAction = RxnString();
  final nomProjet = TextEditingController();
  final dateDemarrage = TextEditingController();
  final statut = TextEditingController();
  final typeAdresseChantier = TextEditingController();


final comptoir = TextEditingController();
final telephoneComptoir = TextEditingController();

final dallagiste = TextEditingController();
final telephoneDallagiste = TextEditingController();
  final ingenieurResponsable = TextEditingController();
  final telephoneIngenieur = TextEditingController();
final emailIngenieur = TextEditingController();
final emailArchitecte = TextEditingController();

final dateVisite = TextEditingController();
final Rxn<DateTime> selectedDateVisite = Rxn<DateTime>();
  // optional in UI
  final architecte = TextEditingController();
  final telephoneArchitecte = TextEditingController();

  final matriculeFiscale = TextEditingController();

  final entreprise = TextEditingController();
  final registreCommerce = TextEditingController();
  final fonction = TextEditingController();
  // optional in UI
  final promoteur = TextEditingController();
  final bureauEtude = TextEditingController();

  final bureauControle = TextEditingController();

  final entrepriseFluide = TextEditingController();
  final entrepriseElectricite = TextEditingController();
  final revendeurNom = TextEditingController();
final revendeurPrenom = TextEditingController();
final revendeurEmail = TextEditingController();
final revendeurStatut = TextEditingController(text: "prospect");

  final localisationAdresse = TextEditingController();
  final commentaireCtrl = TextEditingController();
  final adresseRevendeur = TextEditingController();
  // ---------------- Extra fields ----------------
  final typeProjet = TextEditingController();
  final surfaceProspectee = TextEditingController(); // number (m²)
  final pourcentageReussite = TextEditingController(); // number (0-100)
  final validationStatut = TextEditingController(text: "Non validé"); // API expects FR
final telephoneComptoir2 = TextEditingController();

final emailDallagiste = TextEditingController();
final serviceTechnique = TextEditingController();
final montantMarche = TextEditingController();
  // ---------------- Location ----------------
  final RxnDouble latitude = RxnDouble();
  final RxnDouble longitude = RxnDouble();

  final RxList<Map<String, dynamic>> locationComments = <Map<String, dynamic>>[].obs;
  final Rxn<DateTime> selectedDateDemarrage = Rxn<DateTime>();

  Timer? _debounce;
  String _lastAuto = "";

  @override
  void onInit() {
    super.onInit();
    localisationAdresse.addListener(_onAddressChanged);
  }

  String _trim(String v) => v.trim();

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }
String formatDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return "";

  final date = DateTime.tryParse(isoDate);
  if (date == null) return "";

  return DateFormat("dd/MM/yyyy").format(date);
}
void resetForm() {
  nomProjet.clear();
  dateDemarrage.clear();
  statut.clear();
  typeAdresseChantier.clear();
  montantMarche.clear();

  ingenieurResponsable.clear();
  telephoneIngenieur.clear();

  architecte.clear();
  telephoneArchitecte.clear();

  matriculeFiscale.clear();
  adresseRevendeur.clear();

  entreprise.clear();
  promoteur.clear();
  bureauEtude.clear();
  bureauControle.clear();

  entrepriseFluide.clear();
  entrepriseElectricite.clear();

  localisationAdresse.clear();
  commentaireCtrl.clear();

  // 🔥 REVENDEUR
  comptoir.clear();
  telephoneComptoir.clear();
  telephoneComptoir2.clear();
  registreCommerce.clear();
  fonction.clear();

  // 🔥 APPLICATEUR
  dallagiste.clear();
  telephoneDallagiste.clear();
  emailDallagiste.clear();
  serviceTechnique.clear();

  typeProjet.clear();
  surfaceProspectee.clear();
  pourcentageReussite.clear();

  validationStatut.text = "Non validé";

  latitude.value = null;
  longitude.value = null;

  selectedAction.value = null;

  locationComments.clear();
  selectedDateDemarrage.value = null;
  selectedDateVisite.value = null;
  revendeurNom.clear();
revendeurPrenom.clear();
revendeurEmail.clear();
revendeurStatut.text = "prospect";

  update();
}
String? emailValidator(String? v, String label) {
  final value = (v ?? "").trim();

  if (value.isEmpty) return "$label is required";

  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  if (!emailRegex.hasMatch(value)) {
    return "Invalid $label";
  }

  return null;
}
void onProjectModeleChanged(String mode) {
  projectModele.value = mode;

  if (mode == "revendeur") {
    // 🔥 RESET UNIQUEMENT CHANTIER
    dateDemarrage.clear();
    typeAdresseChantier.clear();
    localisationAdresse.clear();

    latitude.value = null;
    longitude.value = null;

    statut.clear();
    pourcentageReussite.clear();
    surfaceProspectee.clear();

    entreprise.clear();
    promoteur.clear();
    bureauEtude.clear();
    bureauControle.clear();

    // ❌ NE PAS TOUCHER AUX CHAMPS REVENDEUR
    // adresseRevendeur.clear(); ❌ SUPPRIMER
  }

  if (mode != "revendeur") {
    // 🔥 RESET REVENDEUR (logique inverse)
    comptoir.clear();
    telephoneComptoir.clear();
    telephoneComptoir2.clear();
    registreCommerce.clear();
    fonction.clear();

    revendeurNom.clear();
    revendeurPrenom.clear();
    revendeurEmail.clear();
    revendeurStatut.text = "prospect";

    adresseRevendeur.clear(); // ✅ ici c'est correct
  }

  update();
}
  // =========================
  // LOAD PROJECT (edit)
  // =========================
 Future<void> loadProject(String id) async {

  final res = await ApiClient.instance.dio.get('/projects/$id');
  final j = Map<String, dynamic>.from(res.data);

  // =========================
  // BASIC INFO
  // =========================

  nomProjet.text = (j['nomProjet'] ?? '').toString();
  dateDemarrage.text = (j['dateDemarrage'] ?? '').toString();
  statut.text = (j['statut'] ?? '').toString();
  typeAdresseChantier.text = (j['typeAdresseChantier'] ?? '').toString();
  montantMarche.text = (j['montantMarche'] ?? '').toString();

  ingenieurResponsable.text = (j['ingenieurResponsable'] ?? '').toString();
  telephoneIngenieur.text = (j['telephoneIngenieur'] ?? '').toString();
  adresseRevendeur.text = (j['adresseRevendeur'] ?? '').toString();
  architecte.text = (j['architecte'] ?? '').toString();
  telephoneArchitecte.text = (j['telephoneArchitecte'] ?? '').toString();
latitude.value = j["location"]?["lat"];
longitude.value = j["location"]?["lng"];
  matriculeFiscale.text =
      (j['matriculeFiscale'] ?? j['matricule_fiscale'] ?? '').toString();
      revendeurNom.text = (j['revendeurNom'] ?? '').toString();
revendeurPrenom.text = (j['revendeurPrenom'] ?? '').toString();
revendeurEmail.text = (j['revendeurEmail'] ?? '').toString();
revendeurStatut.text = (j['revendeurStatut'] ?? 'prospect').toString();
dateDemarrage.text = formatDate(j["startDate"]);
commentaireCtrl.text =
    j["localisationCommentaire"] ??
    j["commentaireAction"] ??
    "";
  entreprise.text = (j['entreprise'] ?? '').toString();
  promoteur.text = (j['promoteur'] ?? '').toString();
  bureauEtude.text = (j['bureauEtude'] ?? '').toString();
  bureauControle.text = (j['bureauControle'] ?? '').toString();
  projectModele.value = (j['projectModele'] ?? 'project').toString();

comptoir.text = (j['comptoir'] ?? '').toString();
telephoneComptoir.text = (j['telephoneComptoir'] ?? '').toString();
telephoneComptoir2.text = (j['telephoneComptoir2'] ?? '').toString();
// 🔥 REVENDEUR
registreCommerce.text = (j['registreCommerce'] ?? '').toString();
fonction.text = (j['fonction'] ?? '').toString();

dallagiste.text = (j['dallagiste'] ?? '').toString();
telephoneDallagiste.text = (j['telephoneDallagiste'] ?? '').toString();

emailDallagiste.text = (j['emailDallagiste'] ?? '').toString();
serviceTechnique.text = (j['serviceTechnique'] ?? '').toString();

  entrepriseFluide.text = (j['entrepriseFluide'] ?? '').toString();
  entrepriseElectricite.text = (j['entrepriseElectricite'] ?? '').toString();

  localisationAdresse.text = (j['adresse'] ?? '').toString();
  commentaireCtrl.text =
      (j['localisationCommentaire'] ?? '').toString();

  typeProjet.text = (j['typeProjet'] ?? '').toString();

  validationStatut.text =
      (j['validationStatut'] ?? 'Non validé').toString();

  // =========================
  // NUMBERS
  // =========================

  final pr = _toDouble(j['pourcentageReussite']);
  pourcentageReussite.text = pr == null ? '' : pr.toString();

  final sp = _toDouble(j['surfaceProspectee']);
  surfaceProspectee.text = sp == null ? '' : sp.toString();

  // =========================
  // DATE DEMARRAGE
  // =========================

  final dt = dateDemarrage.text.trim();

  if (dt.isNotEmpty) {
    try {
      selectedDateDemarrage.value =
          DateFormat('yyyy-MM-dd').parseStrict(dt);
    } catch (_) {}
  }

  // =========================
  // LOCATION
  // =========================

  double? lat;
  double? lng;

  final loc = j['location'];

  if (loc is Map) {
    lat = _toDouble(loc['lat'] ?? loc['latitude']);
    lng = _toDouble(loc['lng'] ?? loc['lon'] ?? loc['longitude']);
  }

  lat ??= _toDouble(j['lat'] ?? j['latitude']);
  lng ??= _toDouble(j['lng'] ?? j['lon'] ?? j['longitude']);

  if (lat != null && lng != null) {
    latitude.value = lat;
    longitude.value = lng;
  } else {
    latitude.value = null;
    longitude.value = null;
  }

  // =========================
  // COMMENTS LOCATION
  // =========================

  final cmts = j['comments'];

  if (cmts is List) {
    locationComments.value =
        cmts.map((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    locationComments.clear();
  }

  // =========================
  // CRM ACTION
  // =========================

 // =========================
// DATE VISITE
// =========================

final dv = (
  j['dateVisite'] ??
  j['date_visite'] ??
  j['dateAction'] ??
  ''
).toString();

if (dv.isNotEmpty) {

  try {

    final parsed = DateTime.parse(dv);

    selectedDateVisite.value = parsed;

    dateVisite.text = DateFormat('yyyy-MM-dd').format(parsed);

  } catch (_) {

    dateVisite.text = dv;

  }

} else {

  dateVisite.text = "";

}

  // =========================
  // NEXT ACTION
  // =========================

  final next = (
    j['nextAction'] ??
    j['firstAction'] ??
    j['typeAction'] ??
    ''
  ).toString();

  selectedAction.value =
      next.isEmpty ? null : next;


/// 🔥 AUTO ADAPT nomProjet pour revendeur
if (projectModele.value == "revendeur" && comptoir.text.isNotEmpty) {
  nomProjet.text = comptoir.text;
}
  update();
}
Future<void> pickDateVisite(BuildContext context) async {

  final initial = selectedDateVisite.value ?? DateTime.now();

  final picked = await showDatePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    initialDate: initial,
  );

  if (picked == null) return;

  selectedDateVisite.value = picked;

  dateVisite.text = DateFormat('yyyy-MM-dd').format(picked);
}
  // =========================
  // DATE PICKER
  // =========================
  Future<void> pickDateDemarrage(BuildContext context) async {
  FocusScope.of(context).unfocus();

  final now = DateTime.now();
  DateTime initialDate = selectedDateDemarrage.value ?? now;

  final txt = dateDemarrage.text.trim();

  if (txt.isNotEmpty) {
    try {
      // ✅ CORRECT FORMAT (dd/MM/yyyy)
      initialDate = DateFormat('dd/MM/yyyy').parseStrict(txt);
    } catch (_) {
      initialDate = now;
    }
  }

  final picked = await showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("Select a date"),
        content: SizedBox(
          width: 420,
          height: 360,
          child: CalendarDatePicker(
            initialDate: initialDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onDateChanged: (d) => Navigator.of(ctx).pop(d),
          ),
        ),
      );
    },
  );

  if (picked == null) return;

  setDateDemarrage(picked);
}

 void setDateDemarrage(DateTime d) {
  selectedDateDemarrage.value = d;

  // ✅ FORMAT UI (CORRIGÉ)
  final formatted = DateFormat('dd/MM/yyyy').format(d);

  dateDemarrage.value = dateDemarrage.value.copyWith(
    text: formatted,
    selection: TextSelection.collapsed(offset: formatted.length),
    composing: TextRange.empty,
  );

  update(['dateDemarrage']);
}

  // =========================
  // AUTO GEOCODE
  // =========================
  LatLng? _extractLatLngFromGoogleMaps(String input) {
  final s = input.trim();

  // formats fréquents :
  // 1) .../@36.8093547,10.1316342,17z
  final at = RegExp(r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)');
  final m1 = at.firstMatch(s);
  if (m1 != null) {
    final lat = double.tryParse(m1.group(1)!);
    final lng = double.tryParse(m1.group(2)!);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }

  // 2) ...?q=36.8093547,10.1316342  (ou query=)
  final q = RegExp(r'(?:\?|&)(?:q|query)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)');
  final m2 = q.firstMatch(s);
  if (m2 != null) {
    final lat = double.tryParse(m2.group(1)!);
    final lng = double.tryParse(m2.group(2)!);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }

  // 3) lien court g.page / goo.gl/maps => pas fiable sans requête réseau
  return null;
}


  void _onAddressChanged() {
  final q = localisationAdresse.text.trim();
  if (q.length < 3) return;
  if (q == _lastAuto) return;

  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 400), () async {
    // ✅ 1) Si c’est un lien Google Maps, on extrait direct lat/lng
    if (_looksLikeMapsUrl(q)) {
      final ll = _extractLatLngFromGoogleMaps(q);
      if (ll != null) {
        _lastAuto = q;
        setLocation(lat: ll.latitude, lng: ll.longitude, address: q); // on garde le lien dans le champ
        return;
      }
      // si lien court => fallback vers autoGeocode
    }

    // ✅ 2) Sinon auto geocode normal
    await _autoGeocode(q);
  });
}

bool _looksLikeMapsUrl(String s) {
  final x = s.toLowerCase();
  return x.contains("maps.app.goo.gl") ||
      x.contains("google.com/maps") ||
      x.contains("goo.gl/maps");
}

Future<void> _autoGeocode(String query) async {
  try {
    // ✅ 1) si l'utilisateur colle un lien Google Maps
    if (_looksLikeMapsUrl(query)) {
      final uri = Uri.parse("${AddressService.apiBase}/utils/expand-maps")
          .replace(queryParameters: {"url": query.trim()});

      final res = await http.get(uri).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data["lat"] != null && data["lng"] != null) {
          final lat = (data["lat"] as num).toDouble();
          final lng = (data["lng"] as num).toDouble();

          _lastAuto = query.trim();
          setLocation(lat: lat, lng: lng, address: query.trim());
          return;
        }
      }
      // si expand échoue, on continue vers geocode normal
    }

    // ✅ 2) geocode normal (texte)
    final results = await AddressService.search(query);
    if (results.isEmpty) return;

    final best = results.first;
    _lastAuto = best.displayName;
    setLocation(lat: best.lat, lng: best.lon, address: best.displayName);
  } catch (_) {}
}

  // =========================
  // VALIDATORS (EN)
  // =========================
  String? requiredValidator(String? v, String label) {
    if (v == null || v.trim().isEmpty) return "$label is required";
    return null;
  }

  String? phoneValidator(String? v, String label) {
    final value = (v ?? "").trim();
    if (value.isEmpty) return "$label is required";
    if (!RegExp(r'^[0-9+\s\-()]{6,30}$').hasMatch(value)) {
      return "Invalid $label";
    }
    return null;
  }

  String? phoneOptionalValidator(String? v, String label) {
    final value = (v ?? "").trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^[0-9+\s\-()]{6,30}$').hasMatch(value)) {
      return "Invalid $label";
    }
    return null;
  }

  String? numberValidator(String? v, String label, {double? min, double? max}) {
    final s = (v ?? "").trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s.replaceAll(',', '.'));
    if (n == null) return "$label must be a number";
    if (min != null && n < min) return "$label must be >= $min";
    if (max != null && n > max) return "$label must be <= $max";
    return null;
  }

  String? percentValidator(String? v) => numberValidator(v, "Success rate", min: 0, max: 100);
  String? surfaceValidator(String? v) => numberValidator(v, "Prospected area", min: 0);

  bool get hasLocation => latitude.value != null && longitude.value != null;

  void setLocation({required double lat, required double lng, String? address}) {
    latitude.value = lat;
    longitude.value = lng;

    if (address != null && address.trim().isNotEmpty) {
      final newText = address.trim();
      if (localisationAdresse.text.trim() != newText) {
        localisationAdresse.text = newText;
      }
    }

    update(['location']);
  }

  double? get surfaceProspecteeValue {
    final s = _trim(surfaceProspectee.text);
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  double? get pourcentageReussiteValue {
    final s = _trim(pourcentageReussite.text);
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  @override
  void onClose() {
    _debounce?.cancel();
    localisationAdresse.removeListener(_onAddressChanged);

    nomProjet.dispose();
    dateDemarrage.dispose();
    statut.dispose();
    typeAdresseChantier.dispose();
    ingenieurResponsable.dispose();
    telephoneIngenieur.dispose();
    architecte.dispose();
    telephoneArchitecte.dispose();
    matriculeFiscale.dispose();
    entreprise.dispose();
    promoteur.dispose();
    bureauEtude.dispose();
    bureauControle.dispose();
    entrepriseFluide.dispose();
    entrepriseElectricite.dispose();
    adresseRevendeur.dispose();
    localisationAdresse.dispose();
    commentaireCtrl.dispose();
    typeProjet.dispose();
    surfaceProspectee.dispose();
    pourcentageReussite.dispose();
    validationStatut.dispose();
    comptoir.dispose();
telephoneComptoir.dispose();
montantMarche.dispose();
telephoneComptoir2.dispose();
registreCommerce.dispose();
fonction.dispose();

dallagiste.dispose();
telephoneDallagiste.dispose();
emailDallagiste.dispose();
serviceTechnique.dispose();

emailIngenieur.dispose();
emailArchitecte.dispose();
dateVisite.dispose();

    super.onClose();
  }

}