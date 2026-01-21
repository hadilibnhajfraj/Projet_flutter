import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../services/address_service.dart';
import '../../providers/api_client.dart';

class ProjectFormController extends GetxController {
  final formKey = GlobalKey<FormState>();

  // ---------------- Champs existants ----------------
  final nomProjet = TextEditingController();
  final dateDemarrage = TextEditingController();
  final statut = TextEditingController();
  final typeAdresseChantier = TextEditingController();

  final ingenieurResponsable = TextEditingController();
  final telephoneIngenieur = TextEditingController();

  final architecte = TextEditingController();
  final telephoneArchitecte = TextEditingController();

  final entreprise = TextEditingController();
  final promoteur = TextEditingController();
  final bureauEtude = TextEditingController();
  final bureauControle = TextEditingController();

  final entrepriseFluide = TextEditingController();
  final entrepriseElectricite = TextEditingController();

  final localisationAdresse = TextEditingController();
  final commentaireCtrl = TextEditingController();

  // ---------------- ✅ NOUVEAUX CHAMPS ----------------
  final typeProjet = TextEditingController();
  final surfaceProspectee = TextEditingController();       // numérique (m²)
  final pourcentageReussite = TextEditingController();     // numérique (0-100)
  final validationStatut = TextEditingController(text: "Non validé"); // enum

  // ---------------- Localisation ----------------
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

  // ---------------- Utils ----------------
  String _trim(String v) => v.trim();

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  // ✅ reset (mode création)
  void resetForm() {
    nomProjet.clear();
    dateDemarrage.clear();
    statut.clear();
    typeAdresseChantier.clear();

    ingenieurResponsable.clear();
    telephoneIngenieur.clear();
    architecte.clear();
    telephoneArchitecte.clear();

    entreprise.clear();
    promoteur.clear();
    bureauEtude.clear();
    bureauControle.clear();

    entrepriseFluide.clear();
    entrepriseElectricite.clear();

    localisationAdresse.clear();
    commentaireCtrl.clear();

    // ✅ nouveaux champs reset
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
  // ✅ LOAD PROJECT (edit)
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

    entreprise.text = (j['entreprise'] ?? '').toString();
    promoteur.text = (j['promoteur'] ?? '').toString();
    bureauEtude.text = (j['bureauEtude'] ?? '').toString();
    bureauControle.text = (j['bureauControle'] ?? '').toString();

    entrepriseFluide.text = (j['entrepriseFluide'] ?? '').toString();
    entrepriseElectricite.text = (j['entrepriseElectricite'] ?? '').toString();

    localisationAdresse.text = (j['adresse'] ?? '').toString();

    // ✅ nouveaux champs (load)
    typeProjet.text = (j['typeProjet'] ?? '').toString();
    validationStatut.text = (j['validationStatut'] ?? 'Non validé').toString();

    final pr = _toDouble(j['pourcentageReussite']);
    pourcentageReussite.text = pr == null ? '' : pr.toString();

    final sp = _toDouble(j['surfaceProspectee']);
    surfaceProspectee.text = sp == null ? '' : sp.toString();

    // ✅ date picker sync
    final dt = dateDemarrage.text.trim();
    if (dt.isNotEmpty) {
      try {
        selectedDateDemarrage.value = DateFormat('yyyy-MM-dd').parseStrict(dt);
      } catch (_) {}
    }

    // ✅ LOCATION (supporte plusieurs formats)
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

    // ✅ comments
    final cmts = j['comments'];
    if (cmts is List) {
      locationComments.value = cmts.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      locationComments.clear();
    }

    update();
  }

  // =========================
  // ✅ DATE PICKER
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
          title: const Text("Sélectionner une date"),
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
  // ✅ AUTO GEOCODE
  // =========================
  void _onAddressChanged() {
    final q = localisationAdresse.text.trim();
    if (q.length < 3) return;
    if (q == _lastAuto) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () async {
      await _autoGeocode(q);
    });
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
  // ✅ VALIDATORS
  // =========================
  String? requiredValidator(String? v, String label) {
    if (v == null || v.trim().isEmpty) return "$label est obligatoire";
    return null;
  }

  String? phoneValidator(String? v, String label) {
    final value = (v ?? "").trim();
    if (value.isEmpty) return "$label est obligatoire";
    if (!RegExp(r'^[0-9+\s\-()]{6,30}$').hasMatch(value)) {
      return "$label invalide";
    }
    return null;
  }

  // ✅ numeric validators
  String? numberValidator(String? v, String label, {double? min, double? max}) {
    final s = (v ?? "").trim();
    if (s.isEmpty) return null; // champ optionnel
    final n = double.tryParse(s.replaceAll(',', '.'));
    if (n == null) return "$label doit être un nombre";
    if (min != null && n < min) return "$label doit être >= $min";
    if (max != null && n > max) return "$label doit être <= $max";
    return null;
  }

  String? percentValidator(String? v) =>
      numberValidator(v, "Pourcentage de réussite", min: 0, max: 100);

  String? surfaceValidator(String? v) =>
      numberValidator(v, "Surface prospectée", min: 0);

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

  // ✅ helpers to get double from controllers
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
    entreprise.dispose();
    promoteur.dispose();
    bureauEtude.dispose();
    bureauControle.dispose();
    entrepriseFluide.dispose();
    entrepriseElectricite.dispose();
    localisationAdresse.dispose();
    commentaireCtrl.dispose();

    // ✅ nouveaux champs dispose
    typeProjet.dispose();
    surfaceProspectee.dispose();
    pourcentageReussite.dispose();
    validationStatut.dispose();

    super.onClose();
  }
}
