import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../model/commercial_contact_models.dart';
import '../../../services/commercial_contact_api.dart';

class CommercialContactCreateController extends GetxController {
  final loading = false.obs;

  final typeClient = "Tuteur".obs;

  final nomSocieteCtrl = TextEditingController();
  final nomCtrl = TextEditingController();
  final prenomCtrl = TextEditingController();
  final localisationCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final messageCtrl = TextEditingController();

  final produits = <CommercialProductInput>[].obs;

  void addProduitRow() {
    produits.add(CommercialProductInput(produit: "", qte: 1));
  }

  void removeProduitRow(int index) {
    if (index >= 0 && index < produits.length) {
      produits.removeAt(index);
    }
  }

  Future<bool> submit() async {
    final nom = nomCtrl.text.trim();
    final prenom = prenomCtrl.text.trim();
    final tel = telephoneCtrl.text.trim();

    if (nom.isEmpty || prenom.isEmpty || tel.isEmpty) {
      return false;
    }

    final cleaned = produits
        .where((p) => p.produit.trim().isNotEmpty)
        .map((p) => CommercialProductInput(
              produit: p.produit.trim(),
              qte: p.qte <= 0 ? 1 : p.qte,
            ))
        .toList();

    final dto = CommercialContactCreateDto(
      typeClient: typeClient.value,
      nomSociete: nomSocieteCtrl.text,
      nom: nomCtrl.text,
      prenom: prenomCtrl.text,
      localisation: localisationCtrl.text,
      telephone: telephoneCtrl.text,
      message: messageCtrl.text,
      produits: cleaned,
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

  @override
  void onClose() {
    nomSocieteCtrl.dispose();
    nomCtrl.dispose();
    prenomCtrl.dispose();
    localisationCtrl.dispose();
    telephoneCtrl.dispose();
    messageCtrl.dispose();
    super.onClose();
  }
}