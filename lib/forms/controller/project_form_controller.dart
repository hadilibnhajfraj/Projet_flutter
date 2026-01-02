import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/address_service.dart';

class ProjectFormController extends GetxController {
  final formKey = GlobalKey<FormState>();

  // Champs
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

  // Adresse editable
  final localisationAdresse = TextEditingController();

  // ✅ Commentaires (manuel textarea)
  final commentaireCtrl = TextEditingController();

  // lat/lng
  final RxnDouble latitude = RxnDouble();
  final RxnDouble longitude = RxnDouble();

  // ✅ commentaires depuis map + autres
  final RxList<Map<String, dynamic>> locationComments =
      <Map<String, dynamic>>[].obs;

  // ✅ Date sélectionnée
  final Rxn<DateTime> selectedDateDemarrage = Rxn<DateTime>();

  Timer? _debounce;
  String _lastAuto = "";

  @override
  void onInit() {
    super.onInit();
    localisationAdresse.addListener(_onAddressChanged);

    // init selectedDateDemarrage si l'input a déjà une valeur
    final txt = dateDemarrage.text.trim();
    if (txt.isNotEmpty) {
      try {
        selectedDateDemarrage.value = DateFormat('yyyy-MM-dd').parseStrict(txt);
      } catch (_) {}
    }
  }

  // =========================
  // ✅ DATE PICKER (clic date = sélection directe)
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
              onDateChanged: (d) {
                Navigator.of(ctx).pop(d); // ✅ choix direct
              },
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    setDateDemarrage(picked);
  }

  // =========================
  // ✅ SET DATE + FORCER MAJ INPUT
  // =========================
  void setDateDemarrage(DateTime d) {
    selectedDateDemarrage.value = d;

    final formatted = DateFormat('yyyy-MM-dd').format(d);

    // ✅ force l'affichage dans l'input
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

    super.onClose();
  }
}
