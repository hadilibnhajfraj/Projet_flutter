import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../services/address_service.dart';
import '../../providers/api_client.dart';

class ProjectFormController extends GetxController {
  final formKey = GlobalKey<FormState>();

  // ---------------- Fields ----------------
  final nomProjet = TextEditingController();
  final dateDemarrage = TextEditingController();
  final statut = TextEditingController();
  final typeAdresseChantier = TextEditingController();

  final ingenieurResponsable = TextEditingController();
  final telephoneIngenieur = TextEditingController();

  // optional in UI
  final architecte = TextEditingController();
  final telephoneArchitecte = TextEditingController();

  final matriculeFiscale = TextEditingController();

  final entreprise = TextEditingController();

  // optional in UI
  final promoteur = TextEditingController();
  final bureauEtude = TextEditingController();

  final bureauControle = TextEditingController();

  final entrepriseFluide = TextEditingController();
  final entrepriseElectricite = TextEditingController();

  final localisationAdresse = TextEditingController();
  final commentaireCtrl = TextEditingController();

  // ---------------- Extra fields ----------------
  final typeProjet = TextEditingController();
  final surfaceProspectee = TextEditingController(); // number (m²)
  final pourcentageReussite = TextEditingController(); // number (0-100)
  final validationStatut = TextEditingController(text: "Non validé"); // API expects FR

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

  void resetForm() {
    nomProjet.clear();
    dateDemarrage.clear();
    statut.clear();
    typeAdresseChantier.clear();

    ingenieurResponsable.clear();
    telephoneIngenieur.clear();

    architecte.clear();
    telephoneArchitecte.clear();

    matriculeFiscale.clear();

    entreprise.clear();
    promoteur.clear();
    bureauEtude.clear();
    bureauControle.clear();

    entrepriseFluide.clear();
    entrepriseElectricite.clear();

    localisationAdresse.clear();
    commentaireCtrl.clear();

    typeProjet.clear();
    surfaceProspectee.clear();
    pourcentageReussite.clear();
    validationStatut.text = "Non validé";

    latitude.value = null;
    longitude.value = null;
    locationComments.clear();
    selectedDateDemarrage.value = null;

    update();
  }

  // =========================
  // LOAD PROJECT (edit)
  // =========================
  Future<void> loadProject(String id) async {
    final res = await ApiClient.instance.dio.get('/projects/$id');
    final j = Map<String, dynamic>.from(res.data);

    nomProjet.text = (j['nomProjet'] ?? '').toString();
    dateDemarrage.text = (j['dateDemarrage'] ?? '').toString();
    statut.text = (j['statut'] ?? '').toString();
    typeAdresseChantier.text = (j['typeAdresseChantier'] ?? '').toString();

    ingenieurResponsable.text = (j['ingenieurResponsable'] ?? '').toString();
    telephoneIngenieur.text = (j['telephoneIngenieur'] ?? '').toString();

    architecte.text = (j['architecte'] ?? '').toString();
    telephoneArchitecte.text = (j['telephoneArchitecte'] ?? '').toString();

    matriculeFiscale.text = (j['matriculeFiscale'] ?? j['matricule_fiscale'] ?? '').toString();

    entreprise.text = (j['entreprise'] ?? '').toString();
    promoteur.text = (j['promoteur'] ?? '').toString();
    bureauEtude.text = (j['bureauEtude'] ?? '').toString();
    bureauControle.text = (j['bureauControle'] ?? '').toString();

    entrepriseFluide.text = (j['entrepriseFluide'] ?? '').toString();
    entrepriseElectricite.text = (j['entrepriseElectricite'] ?? '').toString();

    localisationAdresse.text = (j['adresse'] ?? '').toString();

    typeProjet.text = (j['typeProjet'] ?? '').toString();
    validationStatut.text = (j['validationStatut'] ?? 'Non validé').toString();

    final pr = _toDouble(j['pourcentageReussite']);
    pourcentageReussite.text = pr == null ? '' : pr.toString();

    final sp = _toDouble(j['surfaceProspectee']);
    surfaceProspectee.text = sp == null ? '' : sp.toString();

    final dt = dateDemarrage.text.trim();
    if (dt.isNotEmpty) {
      try {
        selectedDateDemarrage.value = DateFormat('yyyy-MM-dd').parseStrict(dt);
      } catch (_) {}
    }

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

    final cmts = j['comments'];
    if (cmts is List) {
      locationComments.value = cmts.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      locationComments.clear();
    }

    update();
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
        initialDate = DateFormat('yyyy-MM-dd').parseStrict(txt);
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
    final formatted = DateFormat('yyyy-MM-dd').format(d);

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
 // dans ProjectFormController

void _onAddressChanged() {
  final input = localisationAdresse.text.trim();
  if (input.length < 3) return;

  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 450), () async {
    await _resolveLocationInput(input);
  });
}

Future<void> _resolveLocationInput(String input) async {
  try {
    final v = input.trim();
    if (v.length < 3) return;

    // ✅ évite répétition
    if (_lastAuto == v) return;
    _lastAuto = v;

    // 1) ✅ Si l’utilisateur colle "lat,lng"
    final direct = _extractLatLng(v);
    if (direct != null) {
      setLocation(lat: direct.$1, lng: direct.$2);
      return;
    }

    // 2) ✅ Si l’utilisateur colle un lien Google Maps avec coordonnées dedans
    final fromUrl = _extractLatLngFromGoogleMapsUrl(v);
    if (fromUrl != null) {
      setLocation(lat: fromUrl.$1, lng: fromUrl.$2);
      return;
    }

    // 3) ✅ Sinon c'est une adresse texte -> geocoding normal
    final results = await AddressService.search(v);
    if (results.isEmpty) return;

    final best = results.first;
    setLocation(lat: best.lat, lng: best.lon);
  } catch (_) {}
}

// ---------------- helpers ----------------

(double, double)? _extractLatLng(String s) {
  // ex: "36.8093547, 10.1316342"
  final m = RegExp(r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(s);
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!);
  final lng = double.tryParse(m.group(2)!);
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat, lng);
}

(double, double)? _extractLatLngFromGoogleMapsUrl(String url) {
  // Exemples:
  // https://www.google.com/maps/place/.../@36.8093547,10.1316342,17z
  // https://www.google.com/maps?q=36.8093547,10.1316342
  // https://www.google.com/maps/search/?api=1&query=36.8093547,10.1316342

  // 1) @lat,lng
  final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (at != null) {
    final lat = double.tryParse(at.group(1)!);
    final lng = double.tryParse(at.group(2)!);
    if (lat != null && lng != null) return (lat, lng);
  }

  // 2) query=lat,lng
  final query = RegExp(r'(?:query=|q=)(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (query != null) {
    final lat = double.tryParse(query.group(1)!);
    final lng = double.tryParse(query.group(2)!);
    if (lat != null && lng != null) return (lat, lng);
  }

  return null;
}

Future<void> _autoLocate(String query) async {
  try {
    final q = query.trim();
    if (q.length < 3) return;

    // ✅ évite recherche répétée
    if (_lastAuto == q) return;
    _lastAuto = q;

    final results = await AddressService.search(q);
    if (results.isEmpty) return;

    final best = results.first;

    setLocation(
      lat: best.lat,
      lng: best.lon,
      // address: best.displayName, // optionnel
    );
  } catch (_) {}
}

  Future<void> _autoGeocode(String query) async {
    try {
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
    localisationAdresse.dispose();
    commentaireCtrl.dispose();
    typeProjet.dispose();
    surfaceProspectee.dispose();
    pourcentageReussite.dispose();
    validationStatut.dispose();

    super.onClose();
  }
}