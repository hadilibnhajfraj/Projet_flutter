import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../model/commercial_contact_models.dart';
import '../../../services/commercial_contact_api.dart';

class CommercialContactCreateController extends GetxController {
  final loading = false.obs;

  final typeClient = "Tuteur".obs;
  final statut = "user_injoignable".obs;

  final nomSocieteCtrl = TextEditingController();
  final nomCtrl = TextEditingController();
  final prenomCtrl = TextEditingController();
  final localisationCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final messageCtrl = TextEditingController();

  final nbAppelsCtrl = TextEditingController(text: "0");
  final sujetDiscussionCtrl = TextEditingController();
  var pipelineStage = "Prospect".obs;

final dateAppelCtrl = TextEditingController();
DateTime? dateAppel;
  final commentaireRelanceCtrl = TextEditingController();
  final dateRelanceCtrl = TextEditingController();
  final heureRelanceCtrl = TextEditingController();

  final produits = <CommercialProductInput>[CommercialProductInput()].obs;
  final userNom = "najeh".obs;

final projects = <CommercialProjectInput>[
  CommercialProjectInput()
].obs;

void addProjectRow() {
  projects.add(
    CommercialProjectInput(
      createdBy: userNom.value, // ✅ auto assign
    ),
  );
  projects.refresh();
}

void removeProjectRow(int index) {
  projects.removeAt(index);
  if (projects.isEmpty) {
    projects.add(CommercialProjectInput());
  }
  projects.refresh();
}
  bool get canScheduleRelance =>
      statut.value == "ok" || statut.value == "rappeler_plus_tard";

  @override
  void onInit() {
    super.onInit();
    ever(userNom, (value) {
    for (var p in projects) {
      p.createdBy = value;
    }
    projects.refresh();
  });

    if (produits.isEmpty) {
      produits.add(
        CommercialProductInput(
          produit: "PROBAR",
          qte: 1,
        ),
      );
    }
  }

  void addProduitRow() {
    produits.add(
      CommercialProductInput(
        produit: "PROBAR",
        qte: 1,
      ),
    );
    produits.refresh();
  }

  void removeProduitRow(int index) {
    if (index >= 0 && index < produits.length) {
      produits.removeAt(index);
    }

    if (produits.isEmpty) {
      produits.add(
        CommercialProductInput(
          produit: "PROBAR",
          qte: 1,
        ),
      );
    }

    produits.refresh();
  }

  Future<void> pickRelanceDate(BuildContext context) async {
    final now = DateTime.now();

    DateTime initialDate = now;
    if (dateRelanceCtrl.text.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(dateRelanceCtrl.text.trim());
      if (parsed != null) initialDate = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      dateRelanceCtrl.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> pickRelanceTime(BuildContext context) async {
    TimeOfDay initialTime = TimeOfDay.now();

    if (heureRelanceCtrl.text.trim().isNotEmpty) {
      final parts = heureRelanceCtrl.text.trim().split(":");
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          initialTime = TimeOfDay(hour: h, minute: m);
        }
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      heureRelanceCtrl.text = "$hh:$mm";
    }
  }

  Future<bool> submit() async {
    final nom = nomCtrl.text.trim();
    final prenom = prenomCtrl.text.trim();
    final tel = telephoneCtrl.text.trim();

    if (nom.isEmpty || prenom.isEmpty || tel.isEmpty) {
      return false;
    }

    final cleanedProduits = produits
        .map(
          (p) => CommercialProductInput(
            produit: p.produit.trim().isEmpty ? "PROBAR" : p.produit.trim(),
            qte: p.qte <= 0 ? 1 : p.qte,
          ),
        )
        .toList();

    CommercialRelanceInput? relance;

    if (canScheduleRelance && dateRelanceCtrl.text.trim().isNotEmpty) {
      relance = CommercialRelanceInput(
        dateRelance: dateRelanceCtrl.text.trim(),
        heureRelance: heureRelanceCtrl.text.trim().isEmpty
            ? null
            : heureRelanceCtrl.text.trim(),
        commentaire: commentaireRelanceCtrl.text.trim(),
        nbAppels: int.tryParse(nbAppelsCtrl.text.trim()) ?? 0,
        sujetDiscussion: sujetDiscussionCtrl.text.trim(),
      );
    }

    final dto = CommercialContactCreateDto(
      typeClient: typeClient.value,
      statut: statut.value,
      nomSociete: nomSocieteCtrl.text,
      nom: nomCtrl.text,
      prenom: prenomCtrl.text,
      localisation: localisationCtrl.text,
      telephone: telephoneCtrl.text,
      message: messageCtrl.text,
      nbAppels: int.tryParse(nbAppelsCtrl.text.trim()) ?? 0,
      sujetDiscussion: sujetDiscussionCtrl.text.trim(),
      produits: cleanedProduits,
      projects: projects,
      relance: relance,
    );

    loading.value = true;

    try {
      await CommercialContactApi.instance.createContact(dto);
      return true;
    } catch (e) {
      debugPrint("CREATE_CONTACT_ERROR: $e");
      rethrow;
    } finally {
      loading.value = false;
    }
  }

  void resetForm() {
    typeClient.value = "Tuteur";
    statut.value = "user_injoignable";

    nomSocieteCtrl.clear();
    nomCtrl.clear();
    prenomCtrl.clear();
    localisationCtrl.clear();
    telephoneCtrl.clear();
    messageCtrl.clear();

    nbAppelsCtrl.text = "0";
    sujetDiscussionCtrl.clear();

    commentaireRelanceCtrl.clear();
    dateRelanceCtrl.clear();
    heureRelanceCtrl.clear();

    produits.clear();
    produits.add(
      CommercialProductInput(
        produit: "PROBAR",
        qte: 1,
      ),
    );
    produits.refresh();
  }

  @override
  void onClose() {
    nomSocieteCtrl.dispose();
    nomCtrl.dispose();
    prenomCtrl.dispose();
    localisationCtrl.dispose();
    telephoneCtrl.dispose();
    messageCtrl.dispose();

    nbAppelsCtrl.dispose();
    sujetDiscussionCtrl.dispose();

    commentaireRelanceCtrl.dispose();
    dateRelanceCtrl.dispose();
    heureRelanceCtrl.dispose();

    super.onClose();
  }
}