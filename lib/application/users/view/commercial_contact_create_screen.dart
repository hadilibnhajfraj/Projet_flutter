import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dash_master_toolkit/application/users/controller/commercial_contact_create_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:dash_master_toolkit/application/users/controller/commercial_contact_controller.dart';
import 'package:dash_master_toolkit/application/users/model/commercial_contact_model.dart';
class CommercialContactCreateScreen extends StatelessWidget {
  CommercialContactCreateScreen({super.key});

  final c = Get.put(CommercialContactCreateController());

  static const Color kPrimary = Color(0xFF1976D2);
  static const Color kPageBg = Color(0xFFF3F6FF);
  static const Color kCardBg = Colors.white;
  static const Color kFieldBg = Color(0xFFEAF0FF);
  static const Color kTextDark = Color(0xFF111827);

  InputDecoration _dec(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: kFieldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: kPrimary.withOpacity(.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      labelStyle: const TextStyle(
        color: kTextDark,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(color: Colors.grey),
      suffixIcon: Icon(icon, color: kPrimary),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kPrimary, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: kTextDark,
          ),
        ),
      ],
    );
  }

  Widget _tf(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData icon = Icons.edit_outlined,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dec(label, hint, icon),
    );
  }

Future<void> _handleSubmit(BuildContext context) async {
  try {
    final ok = await c.submit();

    if (!context.mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("First name, last name and phone number are required."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (Get.isRegistered<CommercialContactController>()) {
      await Get.find<CommercialContactController>().fetchContacts();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Commercial contact created successfully."),
        backgroundColor: Colors.green,
      ),
    );

    if (!context.mounted) return;
    GoRouter.of(context).go('/users/commercial-contacts');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Creation failed: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: kPageBg,
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kPrimary,
                          kPrimary.withOpacity(.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withOpacity(.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Wrap(
                      runSpacing: 14,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.business_center_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "New Commercial Contact",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Add customer details and requested products.",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: c.loading.value ? null : () => _handleSubmit(context),
                          icon: c.loading.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save, color: Colors.white),
                          label: const Text("Save"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(.18),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // CUSTOMER INFORMATION
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 12,
                          color: Colors.black12,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Customer Information", Icons.person_outline),
                        const SizedBox(height: 18),

                        isMobile
                            ? Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: c.typeClient.value,
                                    items: const [
                                      DropdownMenuItem(value: "Tuteur", child: Text("Tuteur")),
                                      DropdownMenuItem(value: "Cloture", child: Text("Cloture")),
                                    ],
                                    onChanged: c.loading.value
                                        ? null
                                        : (v) => c.typeClient.value = v ?? "autre",
                                    decoration: _dec(
                                      "Client Type",
                                      "Select client type",
                                      Icons.category_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _tf(
                                    "Company Name",
                                    "Enter company name",
                                    c.nomSocieteCtrl,
                                    icon: Icons.apartment_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                  _tf(
                                    "Last Name *",
                                    "Enter last name",
                                    c.nomCtrl,
                                    icon: Icons.person_outline,
                                  ),
                                  const SizedBox(height: 14),
                                  _tf(
                                    "First Name *",
                                    "Enter first name",
                                    c.prenomCtrl,
                                    icon: Icons.badge_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                  _tf(
                                    "Location",
                                    "City / Region",
                                    c.localisationCtrl,
                                    icon: Icons.location_on_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                  _tf(
                                    "Phone Number *",
                                    "Enter phone number",
                                    c.telephoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    icon: Icons.phone_outlined,
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: c.typeClient.value,
                                    items: const [
                                       DropdownMenuItem(value: "Tuteur", child: Text("Tuteur")),
                                      DropdownMenuItem(value: "Cloture", child: Text("Cloture")),
                                    ],
                                    onChanged: c.loading.value
    ? null
    : (v) => c.typeClient.value = v ?? "Tuteur",
                                    decoration: _dec(
                                      "Client Type",
                                      "Select client type",
                                      Icons.category_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _tf(
                                    "Company Name",
                                    "Enter company name",
                                    c.nomSocieteCtrl,
                                    icon: Icons.apartment_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _tf(
                                          "Last Name *",
                                          "Enter last name",
                                          c.nomCtrl,
                                          icon: Icons.person_outline,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _tf(
                                          "First Name *",
                                          "Enter first name",
                                          c.prenomCtrl,
                                          icon: Icons.badge_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _tf(
                                          "Location",
                                          "City / Region",
                                          c.localisationCtrl,
                                          icon: Icons.location_on_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _tf(
                                          "Phone Number *",
                                          "Enter phone number",
                                          c.telephoneCtrl,
                                          keyboardType: TextInputType.phone,
                                          icon: Icons.phone_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                        const SizedBox(height: 14),

                        _tf(
                          "Message",
                          "Write a message or customer request",
                          c.messageCtrl,
                          maxLines: 4,
                          icon: Icons.message_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // PRODUCTS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 12,
                          color: Colors.black12,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _sectionTitle("Requested Products", Icons.inventory_2_outlined),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: c.loading.value ? null : c.addProduitRow,
                              icon: const Icon(Icons.add),
                              label: const Text("Add"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (c.produits.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: kFieldBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              "No product added.",
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Column(
                            children: List.generate(c.produits.length, (i) {
                              final item = c.produits[i];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: kFieldBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kPrimary.withOpacity(.12)),
                                ),
                                child: isMobile
                                    ? Column(
                                        children: [
                                          TextFormField(
                                            initialValue: item.produit,
                                            decoration: _dec(
                                              "Product",
                                              "Product name",
                                              Icons.widgets_outlined,
                                            ),
                                            onChanged: (v) => item.produit = v,
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            initialValue: item.qte.toString(),
                                            keyboardType: TextInputType.number,
                                            decoration: _dec(
                                              "Quantity",
                                              "Enter quantity",
                                              Icons.numbers_outlined,
                                            ),
                                            onChanged: (v) {
                                              final n = double.tryParse(v.replaceAll(",", "."));
                                              item.qte = (n == null || n <= 0) ? 1 : n;
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: IconButton(
                                              onPressed: c.loading.value ? null : () => c.removeProduitRow(i),
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              tooltip: "Delete",
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              initialValue: item.produit,
                                              decoration: _dec(
                                                "Product",
                                                "Product name",
                                                Icons.widgets_outlined,
                                              ),
                                              onChanged: (v) => item.produit = v,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              initialValue: item.qte.toString(),
                                              keyboardType: TextInputType.number,
                                              decoration: _dec(
                                                "Quantity",
                                                "Enter quantity",
                                                Icons.numbers_outlined,
                                              ),
                                              onChanged: (v) {
                                                final n = double.tryParse(v.replaceAll(",", "."));
                                                item.qte = (n == null || n <= 0) ? 1 : n;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            onPressed: c.loading.value ? null : () => c.removeProduitRow(i),
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            tooltip: "Delete",
                                          ),
                                        ],
                                      ),
                              );
                            }),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: c.loading.value ? null : () => _handleSubmit(context),
                      icon: c.loading.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text("Save Contact"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}