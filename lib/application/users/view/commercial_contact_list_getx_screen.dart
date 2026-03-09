import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/commercial_contact_controller.dart';
import '../model/commercial_contact_model.dart';

class CommercialContactListGetxScreen extends StatelessWidget {
  final String token;

  const CommercialContactListGetxScreen({
    super.key,
    required this.token,
  });

  Color _typeBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'tuteur':
        return const Color(0xFFE8F1FF);
      case 'cloture':
        return const Color(0xFFEAFBF0);
      default:
        return const Color(0xFFF2F4F7);
    }
  }

  Color _typeTextColor(String type) {
    switch (type.toLowerCase()) {
      case 'tuteur':
        return const Color(0xFF1D4ED8);
      case 'cloture':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF475467);
    }
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _typeBgColor(type),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.isEmpty ? 'N/A' : type,
        style: TextStyle(
          color: _typeTextColor(type),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProductsCell(List<CommercialContactProduct> produits) {
    if (produits.isEmpty) {
      return const Text('No products');
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: produits.take(3).map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Text(
            '${p.produit} (${p.qte})',
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

void _showDeleteDialog(
  BuildContext context,
  CommercialContactController controller,
  CommercialContact contact,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Delete Contact'),
      content: Text(
        'Are you sure you want to delete "${contact.nom} ${contact.prenom}"?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await controller.deleteContact(contact.id);
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

void _showEditDialog(
  BuildContext context,
  CommercialContactController controller,
  CommercialContact contact,
) {
  final nomCtrl = TextEditingController(text: contact.nom);
  final prenomCtrl = TextEditingController(text: contact.prenom);
  final societeCtrl = TextEditingController(text: contact.nomSociete ?? '');
  final telCtrl = TextEditingController(text: contact.telephone);
  final locCtrl = TextEditingController(text: contact.localisation ?? '');
  final msgCtrl = TextEditingController(text: contact.message ?? '');

  String selectedType =
      contact.typeClient.isNotEmpty ? contact.typeClient : 'autre';

  final List<Map<String, dynamic>> produits = contact.produits
      .map((p) => {
            'produit': p.produit,
            'qte': p.qte,
          })
      .toList();

  InputDecoration dec(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
      ),
      suffixIcon: Icon(icon, color: const Color(0xFF1976D2)),
    );
  }

  Widget sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1976D2), size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setModalState) {
        final isMobile = MediaQuery.of(context).size.width < 900;

        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            width: 950,
            constraints: const BoxConstraints(maxHeight: 760),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                // HEADER
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1976D2),
                        const Color(0xFF1976D2).withOpacity(.9),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.edit_note,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Commercial Contact',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Update customer information and requested products.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CUSTOMER INFO
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: const Color(0xFFE4E7EC)),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 12,
                                color: Color(0x0A000000),
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              sectionTitle(
                                "Customer Information",
                                Icons.person_outline,
                              ),
                              const SizedBox(height: 18),

                              DropdownButtonFormField<String>(
                                value: selectedType,
                                items: const [
                                  DropdownMenuItem(
                                    value: "Tuteur",
                                    child: Text("Tuteur"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Cloture",
                                    child: Text("Cloture"),
                                  ),
                                  DropdownMenuItem(
                                    value: "autre",
                                    child: Text("Other"),
                                  ),
                                  DropdownMenuItem(
                                    value: "societe",
                                    child: Text("Company"),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => selectedType = v);
                                  }
                                },
                                decoration: dec(
                                  "Client Type",
                                  "Select client type",
                                  Icons.category_outlined,
                                ),
                              ),

                              const SizedBox(height: 14),

                              TextField(
                                controller: societeCtrl,
                                decoration: dec(
                                  "Company Name",
                                  "Enter company name",
                                  Icons.apartment_outlined,
                                ),
                              ),

                              const SizedBox(height: 14),

                              if (isMobile) ...[
                                TextField(
                                  controller: nomCtrl,
                                  decoration: dec(
                                    "Last Name *",
                                    "Enter last name",
                                    Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: prenomCtrl,
                                  decoration: dec(
                                    "First Name *",
                                    "Enter first name",
                                    Icons.badge_outlined,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: locCtrl,
                                  decoration: dec(
                                    "Location",
                                    "City / Region",
                                    Icons.location_on_outlined,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: telCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: dec(
                                    "Phone Number *",
                                    "Enter phone number",
                                    Icons.phone_outlined,
                                  ),
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: nomCtrl,
                                        decoration: dec(
                                          "Last Name *",
                                          "Enter last name",
                                          Icons.person_outline,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: prenomCtrl,
                                        decoration: dec(
                                          "First Name *",
                                          "Enter first name",
                                          Icons.badge_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: locCtrl,
                                        decoration: dec(
                                          "Location",
                                          "City / Region",
                                          Icons.location_on_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: telCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: dec(
                                          "Phone Number *",
                                          "Enter phone number",
                                          Icons.phone_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 14),

                              TextField(
                                controller: msgCtrl,
                                maxLines: 4,
                                decoration: dec(
                                  "Message",
                                  "Write a message or customer request",
                                  Icons.message_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // PRODUCTS
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: const Color(0xFFE4E7EC)),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 12,
                                color: Color(0x0A000000),
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  sectionTitle(
                                    "Requested Products",
                                    Icons.inventory_2_outlined,
                                  ),
                                  const Spacer(),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setModalState(() {
                                        produits.add({
                                          'produit': '',
                                          'qte': 1.0,
                                        });
                                      });
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text("Add"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1976D2),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (produits.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
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
                                  children:
                                      List.generate(produits.length, (i) {
                                    final item = produits[i];

                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFF1976D2)
                                              .withOpacity(.12),
                                        ),
                                      ),
                                      child: isMobile
                                          ? Column(
                                              children: [
                                                TextFormField(
                                                  initialValue:
                                                      item['produit']
                                                              ?.toString() ??
                                                          '',
                                                  decoration: dec(
                                                    "Product",
                                                    "Product name",
                                                    Icons.widgets_outlined,
                                                  ),
                                                  onChanged: (v) =>
                                                      item['produit'] = v,
                                                ),
                                                const SizedBox(height: 12),
                                                TextFormField(
                                                  initialValue: item['qte']
                                                          ?.toString() ??
                                                      '1',
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: dec(
                                                    "Quantity",
                                                    "Enter quantity",
                                                    Icons.numbers_outlined,
                                                  ),
                                                  onChanged: (v) {
                                                    final n = double.tryParse(
                                                      v.replaceAll(",", "."),
                                                    );
                                                    item['qte'] =
                                                        (n == null || n <= 0)
                                                            ? 1
                                                            : n;
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: IconButton(
                                                    onPressed: () {
                                                      setModalState(() {
                                                        produits.removeAt(i);
                                                      });
                                                    },
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    initialValue:
                                                        item['produit']
                                                                ?.toString() ??
                                                            '',
                                                    decoration: dec(
                                                      "Product",
                                                      "Product name",
                                                      Icons.widgets_outlined,
                                                    ),
                                                    onChanged: (v) =>
                                                        item['produit'] = v,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  flex: 2,
                                                  child: TextFormField(
                                                    initialValue: item['qte']
                                                            ?.toString() ??
                                                        '1',
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration: dec(
                                                      "Quantity",
                                                      "Enter quantity",
                                                      Icons.numbers_outlined,
                                                    ),
                                                    onChanged: (v) {
                                                      final n = double.tryParse(
                                                        v.replaceAll(",", "."),
                                                      );
                                                      item['qte'] =
                                                          (n == null || n <= 0)
                                                              ? 1
                                                              : n;
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                IconButton(
                                                  onPressed: () {
                                                    setModalState(() {
                                                      produits.removeAt(i);
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    );
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // FOOTER
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE4E7EC)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (nomCtrl.text.trim().isEmpty ||
                              prenomCtrl.text.trim().isEmpty ||
                              telCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Last name, first name and phone are required.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final cleanProduits = produits
                              .where((p) =>
                                  (p['produit'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                              .map((p) => {
                                    'produit':
                                        p['produit'].toString().trim(),
                                    'qte': p['qte'] ?? 1,
                                  })
                              .toList();

                          await controller.updateContact(
                            id: contact.id,
                            data: {
                              'typeClient': selectedType,
                              'nomSociete': societeCtrl.text.trim(),
                              'nom': nomCtrl.text.trim(),
                              'prenom': prenomCtrl.text.trim(),
                              'localisation': locCtrl.text.trim(),
                              'telephone': telCtrl.text.trim(),
                              'message': msgCtrl.text.trim(),
                              'produits': cleanProduits,
                            },
                          );

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
  Widget _buildSearchBar(CommercialContactController controller) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, company, phone or location...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
              onSubmitted: (value) => controller.fetchContacts(query: value),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () =>
                controller.fetchContacts(query: controller.searchCtrl.text),
            icon: const Icon(Icons.search),
            label: const Text('Search'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () {
              controller.searchCtrl.clear();
              controller.fetchContacts();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    CommercialContactController controller,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE4E7EC)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_center_outlined, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Commercial Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${controller.contacts.length} records',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: const Color(0xFFE4E7EC),
              ),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF9FAFB),
                ),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xFFF8FAFC);
                  }
                  return Colors.white;
                }),
                columnSpacing: 24,
                horizontalMargin: 18,
                headingRowHeight: 56,
                dataRowMinHeight: 72,
                dataRowMaxHeight: 88,
                columns: const [
                  DataColumn(label: Text('Full Name')),
                  DataColumn(label: Text('Company')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Client Type')),
                  DataColumn(label: Text('Products')),
                  DataColumn(label: Text('Message')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: controller.contacts.map((contact) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFEAF2FF),
                              child: Text(
                                contact.nom.isNotEmpty
                                    ? contact.nom[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 170,
                              child: Text(
                                '${contact.nom} ${contact.prenom}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            (contact.nomSociete ?? '').trim().isNotEmpty
                                ? contact.nomSociete!
                                : 'N/A',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 110,
                          child: Text(
                            contact.telephone,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Text(
                            (contact.localisation ?? '').trim().isNotEmpty
                                ? contact.localisation!
                                : 'N/A',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_buildTypeBadge(contact.typeClient)),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: _buildProductsCell(contact.produits),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            (contact.message ?? '').trim().isNotEmpty
                                ? contact.message!
                                : '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Tooltip(
                              message: 'Edit',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    _showEditDialog(context, controller, contact),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Delete',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _showDeleteDialog(
                                  context,
                                  controller,
                                  contact,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 54, color: Color(0xFF98A2B3)),
            SizedBox(height: 12),
            Text(
              'No commercial contacts found.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Try changing your search criteria or add new contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDA4AF)),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFB42318),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CommercialContactController>()
        ? Get.find<CommercialContactController>()
        : Get.put(CommercialContactController(token: token));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Commercial Contacts'),
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.contacts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () =>
              controller.fetchContacts(query: controller.searchCtrl.text),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSearchBar(controller),
              const SizedBox(height: 18),
              if (controller.error.value.isNotEmpty)
                _buildError(controller.error.value)
              else if (controller.contacts.isEmpty)
                _buildEmpty()
              else
                _buildTable(context, controller),
            ],
          ),
        );
      }),
    );
  }
}