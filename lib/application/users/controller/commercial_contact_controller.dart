import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../model/commercial_contact_model.dart';
import 'package:dash_master_toolkit/services/commercial_contact_service.dart';

class CommercialContactController extends GetxController {
  CommercialContactController({required this.token});

  final String token;
  final CommercialContactService _service = CommercialContactService();

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final RxList<CommercialContact> contacts = <CommercialContact>[].obs;

  final TextEditingController searchCtrl = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchContacts();
  }

  Future<void> fetchContacts({String? query}) async {
    try {
      isLoading.value = true;
      error.value = '';

      final data = await _service.fetchMyContacts(
        token: token,
        query: query,
      );

      contacts.assignAll(data);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateContact({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      isLoading.value = true;
      error.value = '';

      await _service.updateContact(
        token: token,
        id: id,
        data: data,
      );

      await fetchContacts(query: searchCtrl.text);
      Get.snackbar(
        'Success',
        'Contact updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      isLoading.value = true;
      error.value = '';

      await _service.deleteContact(token: token, id: id);
      contacts.removeWhere((e) => e.id == id);

      Get.snackbar(
        'Success',
        'Contact deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade900,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    searchCtrl.dispose();
    super.onClose();
  }
}