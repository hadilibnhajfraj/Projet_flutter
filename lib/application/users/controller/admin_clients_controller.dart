import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dash_master_toolkit/application/users/model/client_model.dart';
import 'package:dash_master_toolkit/services/client_service.dart';

class AdminClientsController extends GetxController {
  final ClientService _service = ClientService();

  final RxBool isLoading = true.obs;
  final RxBool isAdmin = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxList<ClientModel> filteredClients = <ClientModel>[].obs;

  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(filterClients);
    loadClients();
  }

  Future<void> loadClients() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final role = await _service.getRole();
      print('ROLE DANS CONTROLLER = $role');

      if (role != 'admin' && role != 'superadmin') {
        isAdmin.value = false;
        errorMessage.value =
            "Accès refusé. Seuls admin et superadmin peuvent consulter cette page.";
        return;
      }

      isAdmin.value = true;

      final data = await _service.getAllClients();
      clients.assignAll(data);
      filteredClients.assignAll(data);
    } catch (e) {
      errorMessage.value = e.toString();
      print('ERREUR LOAD CLIENTS = $e');
    } finally {
      isLoading.value = false;
    }
  }

  void filterClients() {
    final query = searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      filteredClients.assignAll(clients);
      return;
    }

    filteredClients.assignAll(
      clients.where((client) {
        return (client.code ?? '').toLowerCase().contains(query) ||
            (client.raisonSociale ?? '').toLowerCase().contains(query) ||
            (client.adresse ?? '').toLowerCase().contains(query) ||
            (client.region ?? '').toLowerCase().contains(query) ||
            (client.matriculeFiscal ?? '').toLowerCase().contains(query) ||
            (client.identifiantUnique ?? '').toLowerCase().contains(query) ||
            (client.contact ?? '').toLowerCase().contains(query);
      }).toList(),
    );
  }

  String formatText(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    return value;
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}