import 'package:flutter/material.dart';
import '../model/commercial_contact_model.dart';
import 'package:dash_master_toolkit/services/commercial_contact_service.dart';
import 'package:dash_master_toolkit/application/users/view/commercial_timeline_screen.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:html' as html;
class CommercialContactListGetxScreen extends StatefulWidget {
  final String token;
  
  const CommercialContactListGetxScreen({
    super.key,
    required this.token,
  });

  @override
  State<CommercialContactListGetxScreen> createState() =>
      _CommercialContactListGetxScreenState();
}

class _CommercialContactListGetxScreenState
    extends State<CommercialContactListGetxScreen> {
  final CommercialContactService _service = CommercialContactService();
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  String? selectedUser;
  String? selectedType;
  int currentPage = 1;
  int rowsPerPage = 10;
  bool _loading = true;
  String? _error;
  List<CommercialContact> _contacts = [];

  static const Color kPrimary = Color(0xFF1976D2);
  static const Color kBg = Color(0xFFF8FAFC);
  static const Color kText = Color(0xFF101828);
  static const Color kMuted = Color(0xFF667085);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }
List<CommercialContact> get paginatedContacts {
  final start = (currentPage - 1) * rowsPerPage;
  final end = start + rowsPerPage;

  if (start >= _contacts.length) return [];

  return _contacts.sublist(
    start,
    end > _contacts.length ? _contacts.length : end,
  );
}
void _exportContactsExcel() {
  final items = _contacts;

  var excelFile = excel.Excel.createExcel();
  excel.Sheet sheet = excelFile['Contacts'];

  final headers = [
    'ID',
    'Full Name',
    'First Name',
    'Last Name',
    'Company',
    'Phone',
    'Location',
    'Client Type',
    'Status',
    'Pipeline',
    'Calls',
    'Subject',
    'Message',
    'Date Appel',
    'User',
    'Products',
    'Projects',
    'Relances',
    'Created At',
  ];

  sheet.appendRow(headers);

  /// 🎨 HEADER STYLE
  for (int i = 0; i < headers.length; i++) {
    sheet
        .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .cellStyle = excel.CellStyle(
      bold: true,
      backgroundColorHex: "#111827",
      fontColorHex: "#FFFFFF",
    );
  }

  /// 🔥 GROUP BY USER
  Map<String, List<CommercialContact>> grouped = {};

  for (var c in items) {
    final user = c.userNom ?? "Unknown";
    grouped.putIfAbsent(user, () => []).add(c);
  }

  int rowIndex = 1;

  grouped.forEach((user, contacts) {
    /// 🔥 TOTAL PROJECTS PAR USER
    int totalProjects =
        contacts.fold(0, (sum, c) => sum + c.projects.length);

    /// 🔥 USER HEADER ROW
    sheet.appendRow([
      "", // ID
      "👤 $user ($totalProjects projects)", // Full Name
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      user,
      "",
      "",
      "",
      "",
    ]);

    /// 🎨 STYLE USER ROW
    for (int col = 0; col < headers.length; col++) {
      sheet
          .cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: rowIndex))
          .cellStyle = excel.CellStyle(
        bold: true,
        backgroundColorHex: "#E0F2FE",
      );
    }

    rowIndex++;

    /// 🔥 CONTACTS
    for (var c in contacts) {
      /// PRODUITS
      String produits = c.produits
          .map((p) => "${p.produit} (${p.qte})")
          .join(" | ");

      /// PROJECTS
      String projects = c.projects
          .map((p) =>
              "${p.nomProjet} (${p.localisation})")
          .join(" | ");

      /// RELANCES
      String relances = c.relances
          .map((r) =>
              "${r.dateRelance ?? ''} ${r.heureRelance ?? ''}")
          .join(" | ");

      sheet.appendRow([
        c.id,
        c.fullName,
        c.prenom,
        c.nom,
        c.nomSociete ?? "",
        c.telephone,
        c.localisation ?? "",
        c.typeClient,
        c.statut,
        c.pipelineStage,
        c.nbAppels,
        c.sujetDiscussion ?? "",
        c.message ?? "",
        c.dateAppel?.toIso8601String() ?? "",
        c.userNom ?? "",
        produits,
        projects,
        relances,
        c.createdAt?.toIso8601String() ?? "",
      ]);

      rowIndex++;
    }

    /// ESPACE ENTRE USERS
    sheet.appendRow([""]);
    rowIndex++;
  });

  /// WIDTH
  for (int i = 0; i < headers.length; i++) {
    sheet.setColWidth(i, 28);
  }

  /// SAVE
  final bytes = excelFile.encode();
  if (bytes == null) return;

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', 'contacts_full_grouped.xlsx')
    ..click();

  html.Url.revokeObjectUrl(url);
}
Future<void> _loadContacts({
  String? query,
  String? userNom,
  String? typeClient,
}) async {
  try {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final data = await _service.fetchMyContacts(
      token: widget.token,
      query: query,
      userNom: userNom,        // ✅ IMPORTANT
      typeClient: typeClient,  // ✅ IMPORTANT
    );

    if (mounted) {
      setState(() {
        _contacts = data;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
      });
    }
  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}

  Future<void> _updateContact({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _service.updateContact(
      token: widget.token,
      id: id,
      data: data,
    );
    await _loadContacts(query: _searchController.text);
  }

  Future<void> _deleteContact(String id) async {
    await _service.deleteContact(
      token: widget.token,
      id: id,
    );

    if (mounted) {
      setState(() {
        _contacts.removeWhere((e) => e.id == id);
      });
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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

  Color _statusBgColor(String status) {
    switch (status) {
      case 'ok':
        return const Color(0xFFEAFBF0);
      case 'rappeler_plus_tard':
        return const Color(0xFFFFF7E6);
      case 'user_injoignable':
        return const Color(0xFFFFF1F2);
      case 'client_refuse':
        return const Color(0xFFF2F4F7);
      default:
        return const Color(0xFFF2F4F7);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'ok':
        return const Color(0xFF15803D);
      case 'rappeler_plus_tard':
        return const Color(0xFFB54708);
      case 'user_injoignable':
        return const Color(0xFFDC2626);
      case 'client_refuse':
        return const Color(0xFF475467);
      default:
        return const Color(0xFF475467);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ok':
        return 'OK';
      case 'rappeler_plus_tard':
        return 'Call back later';
      case 'user_injoignable':
        return 'Unreachable';
      case 'client_refuse':
        return 'Client refused';
      default:
        return status;
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

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusBgColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: _statusTextColor(status),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProductsCell(List<CommercialContactProduct> produits) {
    final items = produits.isEmpty
        ? [CommercialContactProduct(id: '', produit: 'PROBAR', qte: 1)]
        : produits;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.take(3).map((p) {
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
        borderSide: const BorderSide(color: kPrimary),
      ),
    );
  }

  Future<void> _confirmDelete(CommercialContact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text("Delete"),
          content: Text(
            "Do you really want to delete ${contact.fullName}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _deleteContact(contact.id);
        _showSuccess("Contact deleted successfully");
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _showRelanceDialog(CommercialContact contact) async {
    final dateCtrl = TextEditingController(
      text: contact.relances.isNotEmpty
          ? (contact.relances.first.dateRelance ?? "")
          : "",
    );
    final heureCtrl = TextEditingController(
      text: contact.relances.isNotEmpty
          ? (contact.relances.first.heureRelance ?? "")
          : "",
    );
    final commentaireCtrl = TextEditingController(
      text: contact.relances.isNotEmpty
          ? (contact.relances.first.commentaire ?? "")
          : "",
    );

    Future<void> pickDate(BuildContext dialogContext) async {
      final picked = await showDatePicker(
        context: dialogContext,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateCtrl.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    }

    Future<void> pickTime(BuildContext dialogContext) async {
      final picked = await showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        final hh = picked.hour.toString().padLeft(2, '0');
        final mm = picked.minute.toString().padLeft(2, '0');
        heureCtrl.text = "$hh:$mm";
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text("Follow-up - ${contact.fullName}"),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  decoration: _inputDecoration("Follow-up date"),
                  onTap: () => pickDate(dialogContext),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heureCtrl,
                  readOnly: true,
                  decoration: _inputDecoration("Follow-up time"),
                  onTap: () => pickTime(dialogContext),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentaireCtrl,
                  maxLines: 3,
                  decoration: _inputDecoration("Comment"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  final payload = {
                    "dateRelance": dateCtrl.text.trim(),
                    "heureRelance": heureCtrl.text.trim().isEmpty
                        ? null
                        : heureCtrl.text.trim(),
                    "commentaire": commentaireCtrl.text.trim().isEmpty
                        ? null
                        : commentaireCtrl.text.trim(),
                    if (contact.statut != "ok" &&
                        contact.statut != "rappeler_plus_tard")
                      "statut": "rappeler_plus_tard",
                  };

                  await _updateContact(id: contact.id, data: payload);

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                  _showError(e.toString());
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      _showSuccess("Follow-up saved successfully");
    }
  }

  Future<void> _showEditDialog(CommercialContact contact) async {
    final nomSocieteCtrl = TextEditingController(text: contact.nomSociete ?? "");
    final nomCtrl = TextEditingController(text: contact.nom);
    final prenomCtrl = TextEditingController(text: contact.prenom);
    final localisationCtrl =
        TextEditingController(text: contact.localisation ?? "");
    final telephoneCtrl = TextEditingController(text: contact.telephone);
    final messageCtrl = TextEditingController(text: contact.message ?? "");
    final nbAppelsCtrl = TextEditingController(text: contact.nbAppels.toString());
    final sujetDiscussionCtrl =
        TextEditingController(text: contact.sujetDiscussion ?? "");
    final dateAppelCtrl = TextEditingController(
  text: contact.dateAppel != null
      ? "${contact.dateAppel!.year}-${contact.dateAppel!.month.toString().padLeft(2, '0')}-${contact.dateAppel!.day.toString().padLeft(2, '0')}"
      : "",
      
);

DateTime? dateAppel = contact.dateAppel;

String selectedPipeline =
    contact.pipelineStage.isNotEmpty ? contact.pipelineStage : "Prospect";

    String selectedType =
        contact.typeClient.isNotEmpty ? contact.typeClient : "autre";
    String selectedStatut =
        contact.statut.isNotEmpty ? contact.statut : "user_injoignable";

    final produits = (contact.produits.isEmpty
            ? [CommercialContactProduct(id: "", produit: "PROBAR", qte: 1)]
            : contact.produits)
        .map((e) => {
              "produitCtrl": TextEditingController(
                text: e.produit.isEmpty ? "PROBAR" : e.produit,
              ),
              "qteCtrl": TextEditingController(text: e.qte.toString()),
            })
        .toList();

    final dateRelanceCtrl = TextEditingController(
      text: contact.relances.isNotEmpty
          ? (contact.relances.first.dateRelance ?? "")
          : "",
    );
    final heureRelanceCtrl = TextEditingController(
      text: contact.relances.isNotEmpty
          ? (contact.relances.first.heureRelance ?? "")
          : "",
    );
    final commentaireRelanceCtrl = TextEditingController(
      text: contact.relances.isNotEmpty
          ? (contact.relances.first.commentaire ?? "")
          : "",
    );
final projects = (contact.projects.isEmpty
        ? [CommercialProject(id: "", nomProjet: "")]
        : contact.projects)
    .map((p) {
  final proj = p as CommercialProject;

  return {
    "nomCtrl": TextEditingController(text: proj.nomProjet ?? ""),
    "locCtrl": TextEditingController(text: proj.localisation ?? ""),
    "typeCtrl": TextEditingController(text: proj.typeProjet ?? ""),
    "descCtrl": TextEditingController(text: proj.description ?? ""),
  };
}).toList();
    Future<void> pickDate(BuildContext dialogContext) async {
      final picked = await showDatePicker(
        context: dialogContext,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateRelanceCtrl.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    }

    Future<void> pickTime(BuildContext dialogContext) async {
      final picked = await showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        final hh = picked.hour.toString().padLeft(2, '0');
        final mm = picked.minute.toString().padLeft(2, '0');
        heureRelanceCtrl.text = "$hh:$mm";
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canScheduleRelance = selectedStatut == "ok" ||
                selectedStatut == "rappeler_plus_tard";

            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: 900,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Edit contact",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: nomCtrl,
                              decoration: _inputDecoration("Last name"),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: prenomCtrl,
                              decoration: _inputDecoration("First name"),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: telephoneCtrl,
                              decoration: _inputDecoration("Phone"),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: TextField(
                              controller: nomSocieteCtrl,
                              decoration: _inputDecoration("Company"),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: TextField(
                              controller: localisationCtrl,
                              decoration: _inputDecoration("Location"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedType,
                              items: const [
                                DropdownMenuItem(
                                    value: "Tuteur", child: Text("Tuteur")),
                                DropdownMenuItem(
                                    value: "Cloture", child: Text("Cloture")),
                                DropdownMenuItem(
                                    value: "Batiment", child: Text("Batiment")),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() {
                                    selectedType = v;
                                  });
                                }
                              },
                              decoration: _inputDecoration("Client type"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedStatut,
                              items: const [
                                DropdownMenuItem(value: "ok", child: Text("OK")),
                                DropdownMenuItem(
                                  value: "rappeler_plus_tard",
                                  child: Text("Call back later"),
                                ),
                                DropdownMenuItem(
                                  value: "user_injoignable",
                                  child: Text("Unreachable"),
                                ),
                                DropdownMenuItem(
                                  value: "client_refuse",
                                  child: Text("Client refused"),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() {
                                    selectedStatut = v;
                                  });
                                }
                              },
                              decoration: _inputDecoration("Status"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

Row(
  children: [

    /// ✅ DATE APPEL
    Expanded(
      child: TextField(
        controller: dateAppelCtrl,
        readOnly: true,
        decoration: _inputDecoration("Call Date"),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: dateAppel ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked != null) {
            setDialogState(() {
              dateAppel = picked;
              dateAppelCtrl.text =
                  "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
            });
          }
        },
      ),
    ),

    const SizedBox(width: 12),

    /// ✅ PIPELINE
    Expanded(
      child: DropdownButtonFormField<String>(
        value: selectedPipeline,
        items: const [
          DropdownMenuItem(value: "Prospect", child: Text("Prospect")),
          DropdownMenuItem(value: "Plan technique", child: Text("Plan technique")),
          DropdownMenuItem(value: "Echantillonnage", child: Text("Echantillonnage")),
          DropdownMenuItem(value: "Devis envoyé", child: Text("Devis envoyé")),
          DropdownMenuItem(value: "Negociation", child: Text("Négociation")),
          DropdownMenuItem(value: "Relance", child: Text("Relance")),
          DropdownMenuItem(value: "Gagné", child: Text("Commande gagnée")),
          DropdownMenuItem(value: "Perdu", child: Text("Commande perdue")),
        ],
        onChanged: (v) {
          if (v != null) {
            setDialogState(() {
              selectedPipeline = v;
            });
          }
        },
        decoration: _inputDecoration("Next Action"),
      ),
    ),
  ],
),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nbAppelsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration("Number of calls"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: sujetDiscussionCtrl,
                              decoration: _inputDecoration("Discussion topic"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration("Message"),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Products",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: List.generate(produits.length, (index) {
                          final row = produits[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller:
                                        row["produitCtrl"] as TextEditingController,
                                    decoration: _inputDecoration("Product"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller:
                                        row["qteCtrl"] as TextEditingController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: _inputDecoration("Qty"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: () {
                                    if (produits.length > 1) {
                                      setDialogState(() {
                                        produits.removeAt(index);
                                      });
                                    }
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              produits.add({
                                "produitCtrl":
                                    TextEditingController(text: "PROBAR"),
                                "qteCtrl": TextEditingController(text: "1"),
                              });
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Add product"),
                        ),
                      ),
                      const SizedBox(height: 18),
const Text(
  "Projects",
  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
),
const SizedBox(height: 10),

Column(
  children: List.generate(projects.length, (index) {
    final row = projects[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row["nomCtrl"] as TextEditingController,
                  decoration: _inputDecoration("Project name"),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (projects.length > 1) {
                    setDialogState(() => projects.removeAt(index));
                  }
                },
                icon: const Icon(Icons.delete, color: Colors.red),
              )
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            controller: row["locCtrl"] as TextEditingController,
            decoration: _inputDecoration("Location"),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: row["typeCtrl"] as TextEditingController,
            decoration: _inputDecoration("Type"),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: row["descCtrl"] as TextEditingController,
            maxLines: 2,
            decoration: _inputDecoration("Description"),
          ),
        ],
      ),
    );
  }),
),

OutlinedButton.icon(
  onPressed: () {
    setDialogState(() {
      projects.add({
        "nomCtrl": TextEditingController(),
        "locCtrl": TextEditingController(),
        "typeCtrl": TextEditingController(),
        "descCtrl": TextEditingController(),
      });
    });
  },
  icon: const Icon(Icons.add),
  label: const Text("Add project"),
),
                      const SizedBox(height: 18),
                      if (canScheduleRelance)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: kPrimary.withOpacity(.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Follow-up",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: dateRelanceCtrl,
                                      readOnly: true,
                                      decoration:
                                          _inputDecoration("Follow-up date"),
                                      onTap: () => pickDate(dialogContext),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: heureRelanceCtrl,
                                      readOnly: true,
                                      decoration:
                                          _inputDecoration("Follow-up time"),
                                      onTap: () => pickTime(dialogContext),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: commentaireRelanceCtrl,
                                maxLines: 3,
                                decoration:
                                    _inputDecoration("Follow-up comment"),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              try {
                                final payload = {
                                  "typeClient": selectedType,
                                  "statut": selectedStatut,
                                  "nomSociete":
                                      nomSocieteCtrl.text.trim().isEmpty
                                          ? null
                                          : nomSocieteCtrl.text.trim(),
                                  "pipelineStage": selectedPipeline,
"dateAppel": dateAppel?.toIso8601String(),
                                  "nom": nomCtrl.text.trim(),
                                  "prenom": prenomCtrl.text.trim(),
                                  "localisation":
                                      localisationCtrl.text.trim().isEmpty
                                          ? null
                                          : localisationCtrl.text.trim(),
                                  "telephone": telephoneCtrl.text.trim(),
                                  "message": messageCtrl.text.trim().isEmpty
                                      ? null
                                      : messageCtrl.text.trim(),
                                  "nbAppels":
                                      int.tryParse(nbAppelsCtrl.text.trim()) ?? 0,
                                  "sujetDiscussion":
                                      sujetDiscussionCtrl.text.trim().isEmpty
                                          ? null
                                          : sujetDiscussionCtrl.text.trim(),
                                  "produits": produits.map((row) {
                                    final produit =
                                        (row["produitCtrl"]
                                                as TextEditingController)
                                            .text
                                            .trim();
                                    final qte = double.tryParse(
                                            (row["qteCtrl"]
                                                    as TextEditingController)
                                                .text
                                                .trim()) ??
                                        1;
                                    return {
                                      "produit":
                                          produit.isEmpty ? "PROBAR" : produit,
                                      "qte": qte <= 0 ? 1 : qte,
                                    };
                                  }).toList(),
                      // ✅ PROJECTS (PAS DE final)
  "projects": projects.map((row) {
    return {
      "nomProjet":
          (row["nomCtrl"] as TextEditingController).text.trim(),
      "localisation":
          (row["locCtrl"] as TextEditingController).text.trim(),
      "typeProjet":
          (row["typeCtrl"] as TextEditingController).text.trim(),
      "description":
          (row["descCtrl"] as TextEditingController).text.trim(),
    };
  }).toList(),
                                  if (canScheduleRelance &&
                                      dateRelanceCtrl.text.trim().isNotEmpty)
                                    "dateRelance": dateRelanceCtrl.text.trim(),
                                  if (canScheduleRelance &&
                                      heureRelanceCtrl.text.trim().isNotEmpty)
                                    "heureRelance": heureRelanceCtrl.text.trim(),
                                  if (canScheduleRelance &&
                                      commentaireRelanceCtrl.text
                                          .trim()
                                          .isNotEmpty)
                                    "commentaire":
                                        commentaireRelanceCtrl.text.trim(),
                                };

                                await _updateContact(
                                  id: contact.id,
                                  data: payload,
                                );

                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop(true);
                                }
                              } catch (e) {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop(false);
                                }
                                _showError(e.toString());
                              }
                            },
                            child: const Text("Save"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      _showSuccess("Contact updated successfully");
    }
  }

  Widget _buildTable() {
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
                    '${_contacts.length} records',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 520,
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Scrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columnSpacing: 28,
                      headingRowHeight: 56,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 90,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kText,
                        fontSize: 13,
                      ),
                      columns: const [
                        DataColumn(label: Text('Full Name')),
                        DataColumn(label: Text('Company')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Client Type')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Calls')),
                        DataColumn(label: Text('Subject')),
                        DataColumn(label: Text('Products')),
                        DataColumn(label: Text('Follow-up')),
                        DataColumn(label: Text('Message')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: paginatedContacts.map((contact)  {
                        final relance = contact.relances.isNotEmpty
                            ? contact.relances.first
                            : null;

                        return DataRow(
                          cells: [
                            DataCell(
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
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

      /// 🔥 TEXTE + CREATED BY
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.fullName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "👤 Created by: ${contact.userNom ?? '-'}",
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  (contact.nomSociete ?? '').trim().isNotEmpty
                                      ? contact.nomSociete!
                                      : 'N/A',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: Text(
                                  contact.telephone,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Text(
                                  (contact.localisation ?? '').trim().isNotEmpty
                                      ? contact.localisation!
                                      : 'N/A',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(_buildTypeBadge(contact.typeClient)),
                            DataCell(_buildStatusBadge(contact.statut)),
                            DataCell(Text('${contact.nbAppels}')),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  (contact.sujetDiscussion ?? '')
                                          .trim()
                                          .isNotEmpty
                                      ? contact.sujetDiscussion!
                                      : '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: _buildProductsCell(contact.produits),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  relance == null
                                      ? '-'
                                      : '${relance.dateRelance ?? '-'} ${relance.heureRelance ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  (contact.message ?? '').trim().isNotEmpty
                                      ? contact.message!
                                      : '-',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => _showEditDialog(contact),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Calendar',
                                    onPressed: () => _showRelanceDialog(contact),
                                    icon: const Icon(
                                      Icons.event_repeat_outlined,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(contact),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                        /// 🔥 TIMELINE (ICI)
      IconButton(
        tooltip: 'Timeline',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommercialTimelineScreen(
                contactId: contact.id,
                token: widget.token,
              ),
            ),
          );
        },
        icon: const Icon(Icons.timeline, color: Colors.purple),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildSearchBar() {
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
    child: Column(
      children: [
        /// 🔍 SEARCH TEXT
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Search by name, company, phone or location...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (value) => _loadContacts(
                  query: value,
                  userNom: selectedUser,
                  typeClient: selectedType,
                ),
              ),
            ),
            const SizedBox(width: 12),

            /// 🔍 SEARCH BUTTON
            ElevatedButton.icon(
              onPressed: () => _loadContacts(
                query: _searchController.text,
                userNom: selectedUser,
                typeClient: selectedType,
              ),
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),

            const SizedBox(width: 10),

            /// 🔄 RESET
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  selectedUser = null;
                  selectedType = null;
                });
                _loadContacts();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        /// 🔥 FILTERS (USER + TYPE)
        Row(
          children: [
            /// 👤 USER FILTER
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedUser,
                hint: const Text("Filter by User"),
                items: const [
                  DropdownMenuItem(value: "najeh", child: Text("Najeh")),
                  DropdownMenuItem(value: "moumen", child: Text("Moumen")),
                  DropdownMenuItem(value: "mayssa", child: Text("Mayssa")),
                ],
                onChanged: (v) {
                  setState(() {
                    selectedUser = v;
                  });
                  _loadContacts(
                    query: _searchController.text,
                    userNom: selectedUser,
                    typeClient: selectedType,
                  );
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            /// 🏢 TYPE FILTER
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedType,
                hint: const Text("Filter by Type"),
                items: const [
                  DropdownMenuItem(value: "Tuteur", child: Text("Tuteur")),
                  DropdownMenuItem(value: "Cloture", child: Text("Cloture")),
                  DropdownMenuItem(value: "Batiment", child: Text("Batiment")),
                ],
                onChanged: (v) {
                  setState(() {
                    selectedType = v;
                  });
                  _loadContacts(
                    query: _searchController.text,
                    userNom: selectedUser,
                    typeClient: selectedType,
                  );
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.business),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            ElevatedButton.icon(
  onPressed: _exportContactsExcel,
  icon: const Icon(Icons.download),
  label: const Text("Export Excel"),
),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
            _error!,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
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
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
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

    return RefreshIndicator(
      onRefresh: () => _loadContacts(query: _searchController.text),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSearchBar(),
          const SizedBox(height: 18),
          _buildTable(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Commercial Contacts'),
        centerTitle: false,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
}