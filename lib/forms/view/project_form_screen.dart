import 'package:dash_master_toolkit/application/users/controller/user_grid_controller.dart';
import 'package:dash_master_toolkit/application/users/model/project_grid_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/widgets/common_app_widget.dart';

import '../../pages/google_map/location_picker_screen.dart';
import '../controller/project_form_controller.dart';
import '../../providers/api_client.dart';
import 'package:dash_master_toolkit/forms/view/project_timeline_screen.dart';
// template imports
import 'package:dash_master_toolkit/forms/form_imports.dart';
import 'package:dash_master_toolkit/pages/google_map/map_imports.dart';

// IMPORTANT: sections (WITHOUT scaffold)
import 'package:dash_master_toolkit/forms/view/devis_form_section.dart';
import 'package:dash_master_toolkit/forms/view/bon_de_commande_form_section.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final Map<String, String> actionLabels = {
  "Visite": "Site Visit",
  "Plan technique": "Technical Plan",
  "Echantillonnage": "Sampling",
  "Devis envoyé": "Quote Sent",
  "Negociation": "Negotiation",
  "Relance": "Follow-up",
  "Commande gagnée": "Won",
  "Commande perdue": "Lost",
};
  late final ProjectFormController c;
  late final ThemeController themeController;
Uint8List? selectedFileBytes;
String? actionFileName;
String? selectedAction;
  final List<Map<String, String>> _statusOptions = const [
  {"label": "Identification", "value": "Identification"},
  {"label": "Technical Proposal", "value": "Proposition technique"},
  {"label": "Commercial Proposal", "value": "Proposition commerciale"},
  {"label": "Negotiation", "value": "Négociation"},
  {"label": "Delivery", "value": "Livraison"},
  {"label": "Loyalty", "value": "Fidélisation"},
];

  // ✅ Display (EN) -> API value (FR)
  final List<Map<String, String>> _validationOptions = const [
    {"label": "Validated", "value": "Validé"},
    {"label": "Not validated", "value": "Non validé"},
  ];

  String? _projectId;
  bool _loadedOnce = false;
  bool _loading = false;
String? _getValidAction() {
  final valid = actionLabels.keys.toList();

  final v = c.selectedAction.value;

  if (v == null) return null;

  if (valid.contains(v)) return v;

  if (v == "Visite chantier") return "Visite";

  return null;
}
  // Block Purchase Order until Quotation is valid
  bool _devisIsValid = false;

  @override
  void initState() {
    super.initState();

    c = Get.isRegistered<ProjectFormController>()
        ? Get.find<ProjectFormController>()
        : Get.put(ProjectFormController()); // not permanent

    themeController = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put(ThemeController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<ProjectFormController>()) {
      Get.delete<ProjectFormController>();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;

    final id = GoRouterState.of(context).uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      _projectId = id;
      _loadForEdit(id);
    } else {
      _projectId = null;
      c.resetForm();
    }
  }

  Future<void> _loadForEdit(String id) async {
    setState(() => _loading = true);
    try {
      await c.loadProject(id);

      // ✅ Ensure dropdowns show correct values if API returns FR values
      if (c.statut.text.trim().isEmpty) c.statut.text = "";
      if (c.validationStatut.text.trim().isEmpty) c.validationStatut.text = "Non validé";

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Project loading error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
Future pickActionFile() async {

  final result = await FilePicker.platform.pickFiles(
    withData: true, // 🔥 IMPORTANT WEB
  );

  if (result != null) {

    setState(() {
      selectedFileBytes = result.files.single.bytes;
      actionFileName = result.files.single.name;
    });

  }
}
Future<void> _refreshCardColors() async {
  if (_projectId == null) return;

  // ✅ refresh project in grid list (colors change without refresh)
  if (Get.isRegistered<UserGridController>()) {
    await UserGridController.to.refreshProjectById(_projectId!);
  }

  // ✅ (optionnel) reload this screen data (if you display devis/bc details here)
  await c.loadProject(_projectId!);

  if (mounted) setState(() {});
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 992;
  

    return Scaffold(
      backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 14 : 24),
              child: Form(
                key: c.formKey,
                child: _commonBackgroundWidget(
                  screenWidth: screenWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
DropdownButtonFormField<String>(
  value: c.projectModele.value,
  decoration: const InputDecoration(
    labelText: "Project Type",
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: "project", child: Text("Project")),
    DropdownMenuItem(value: "revendeur", child: Text("Revendeur")),
    DropdownMenuItem(value: "applicateur", child: Text("Applicateur")),
  ],
 onChanged: (v) {
  c.onProjectModeleChanged(v!);
  setState(() {});
},
),
                      _twoCols(
                        isMobile: isMobile,
                        left: _field(
                          theme: theme,
                          title: c.projectModele.value == "revendeur"
    ? "Nom Société / Personne"
    : "Project Name",
                          controller: c.nomProjet,
                          validator: (v) => c.requiredValidator(v, "Project Name"),
                        ),
                        right: GetBuilder<ProjectFormController>(
                          id: 'dateDemarrage',
                          builder: (_) => _dateField(
                            theme: theme,
                            title: "Start Date",
                            controller: c.dateDemarrage,
                            validator: (v) => c.requiredValidator(v, "Start Date"),
                          ),
                        ),
                      ),

                      if (c.isProject) ...[
  _statusDropdown(theme),
],
                      /// 🔥 NEW PROJECT MODELE

const SizedBox(height: 16),

                     if (c.isProject) ...[
  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Project Type (optional)",
      controller: c.typeProjet,
      validator: null,
    ),
    right: _field(
      theme: theme,
      title: "Site Type + Address",
      controller: c.typeAdresseChantier,
      validator: (v) => c.requiredValidator(v, "Site Type + Address"),
    ),
  ),
],

                      if (c.isProject) ...[
  _twoCols(
    isMobile: isMobile,
    left: _validationDropdown(theme),
    right: _field(
      theme: theme,
      title: "Success Rate (0 - 100)",
      controller: c.pourcentageReussite,
      validator: c.percentValidator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    ),
  ),
],

                     if (c.isProject) ...[
  _field(
    theme: theme,
    title: "Prospected Area (m²) (optional)",
    controller: c.surfaceProspectee,
    validator: c.surfaceValidator,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ),
],

                      /// 🔥 DYNAMIC FIELDS BASED ON MODELE

if (c.projectModele.value == "project") ...[
  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Responsible Engineer",
      controller: c.ingenieurResponsable,
      validator: null,
    ),
    right: _field(
      theme: theme,
      title: "Engineer Phone",
      controller: c.telephoneIngenieur,
      validator: null,
      keyboardType: TextInputType.phone,
    ),
  ),
],

if (c.projectModele.value == "revendeur") ...[
  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Comptoir (Société)",
      controller: c.comptoir,
       validator: null,
    ),
    right: _field(
      theme: theme,
      title: "Téléphone Comptoir",
      controller: c.telephoneComptoir,
       validator: null,
    ),
  ),

  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Téléphone Comptoir 2",
      controller: c.telephoneComptoir2,
      validator: null,
      keyboardType: TextInputType.phone,
    ),
    right: _field(
      theme: theme,
      title: "Registre de commerce",
      controller: c.registreCommerce,
      validator: null,
    ),
  ),

  /// 🔥 NEW DROPDOWN FONCTION
  Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      value: c.fonction.text.isEmpty ? null : c.fonction.text,
      decoration: const InputDecoration(
        labelText: "Fonction",
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: "achat", child: Text("Achat")),
        DropdownMenuItem(value: "gerant", child: Text("Gérant")),
      ],
      onChanged: (v) {
        c.fonction.text = v ?? "";
      },
      validator: (v) {
        if (v == null || v.isEmpty) {
          return "Fonction obligatoire";
        }
        return null;
      },
    ),
  ),
  /// 🔥 INFOS PERSONNE REVENDEUR
_twoCols(
  isMobile: isMobile,
  left: _field(
    theme: theme,
    title: "Nom revendeur",
    controller: c.revendeurNom,
    validator: null,
  ),
  right: _field(
    theme: theme,
    title: "Prénom revendeur",
    controller: c.revendeurPrenom,
     validator: null,
  ),
),

_field(
  theme: theme,
  title: "Email revendeur",
  controller: c.revendeurEmail,
  validator: null,
  keyboardType: TextInputType.emailAddress,
),

/// 🔥 STATUT REVENDEUR
DropdownButtonFormField<String>(
  value: c.revendeurStatut.text,
  decoration: const InputDecoration(
    labelText: "Statut revendeur",
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: "prospect", child: Text("Prospect")),
    DropdownMenuItem(value: "offre", child: Text("Offre")),
    DropdownMenuItem(value: "actif", child: Text("Actif")),
    DropdownMenuItem(value: "rate", child: Text("Raté")),
  ],
  onChanged: (v) {
    c.revendeurStatut.text = v ?? "prospect";
  },
),
_field(
  theme: theme,
  title: "Adresse revendeur",
  controller: c.adresseRevendeur,
  validator: (v) => c.requiredValidator(v, "Adresse"),
),
],
if (c.isApplicateur) ...[

  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Dallagiste",
      controller: c.dallagiste,
      validator: (v) => c.requiredValidator(v, "Dallagiste"),
    ),
    right: _field(
      theme: theme,
      title: "Téléphone Dallagiste",
      controller: c.telephoneDallagiste,
      validator: (v) => c.phoneValidator(v, "Téléphone"),
    ),
  ),

  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Email Dallagiste",
      controller: c.emailDallagiste,
    ),
    right: _field(
      theme: theme,
      title: "Service Technique",
      controller: c.serviceTechnique,
    ),
  ),

  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Matricule fiscale",
      controller: c.matriculeFiscale,
      validator: (v) => c.requiredValidator(v, "Matricule"),
    ),
    right: _field(
      theme: theme,
      title: "Registre de commerce",
      controller: c.registreCommerce,
      validator: (v) => c.requiredValidator(v, "Registre"),
    ),
  ),

  _field(
    theme: theme,
    title: "Adresse applicateur",
    controller: c.localisationAdresse,
    validator: (v) => c.requiredValidator(v, "Adresse"),
  ),

],
                      if (c.projectModele.value == "project") ...[
  if (c.isProject) ...[
  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Engineer Email",
      controller: c.emailIngenieur,
      validator: null,
      keyboardType: TextInputType.emailAddress,
    ),
    right: _field(
      theme: theme,
      title: "Architect Email",
      controller: c.emailArchitecte,
      validator: null,
      keyboardType: TextInputType.emailAddress,
    ),
  ),
]
],

                     if (c.isProject) ...[
  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Architect (optional)",
      controller: c.architecte,
      validator: null,
    ),
    right: _field(
      theme: theme,
      title: "Architect Phone (optional)",
      controller: c.telephoneArchitecte,
      validator: null,
      keyboardType: TextInputType.phone,
    ),
  ),
],
                      Padding(
  padding: const EdgeInsets.only(bottom: 16, top: 5),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _requiredTitle(theme, "Visit Date", required: true),
      const SizedBox(height: 6),
      TextFormField(
        controller: c.dateVisite,
        validator: (v) => c.requiredValidator(v, "Visit Date"),
        readOnly: true,
        onTap: () async {
          await c.pickDateVisite(context);
          if (mounted) setState(() {});
        },
        decoration: inputDecoration(
          context,
          hintText: "Select visit date",
        ).copyWith(
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              await c.pickDateVisite(context);
              if (mounted) setState(() {});
            },
          ),
        ),
      ),
    ],
  ),
),

                    if (c.isProject) ...[
  _field(
    theme: theme,
    title: "Company",
    controller: c.entreprise,
    validator: null,
  ),
],

                      _field(
                        theme: theme,
                        title: "Tax Registration Number (optional)",
                        controller: c.matriculeFiscale,
                        validator: null,
                      ),

                   if (c.isProject) ...[
  _field(
    theme: theme,
    title: "Developer (optional)",
    controller: c.promoteur,
    validator: null,
  ),

  _field(
    theme: theme,
    title: "Design Office (optional)",
    controller: c.bureauEtude,
    validator: null,
  ),

  _field(
    theme: theme,
    title: "Control Office",
    controller: c.bureauControle,
    validator: null,
  ),
],
                      if (c.isProject) ...[
  _twoCols(
    isMobile: isMobile,
    left: _field(
      theme: theme,
      title: "Plumbing/HVAC Company (optional)",
      controller: c.entrepriseFluide,
      validator: null,
    ),
    right: _field(
      theme: theme,
      title: "Electrical Company (optional)",
      controller: c.entrepriseElectricite,
      validator: null,
    ),
  ),
],

                      const SizedBox(height: 14),
                      if (c.isProject) ...[
  _locationBlock(theme),
],
_field(
  theme: theme,
  title: "Montant du marché",
  controller: c.montantMarche,
  keyboardType: TextInputType.number,
),

                      _field(
                        theme: theme,
                        title: "Comments (optional)",
                        controller: c.commentaireCtrl,
                        validator: null,
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                      ),
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    const Text(
      "Next Action",
      style: TextStyle(
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 6),

 DropdownButtonFormField<String>(
  value: _getValidAction(),
  validator: (v) {
    if (v == null || v.isEmpty) {
      return "Next Action is required";
    }
    return null;
  },
  decoration: const InputDecoration(
    border: OutlineInputBorder(),
  ),
  items: actionLabels.entries.map((e) {
    return DropdownMenuItem(
      value: e.key,     // 🔥 FR (backend)
      child: Text(e.value), // 🔥 EN (UI)
    );
  }).toList(),
  onChanged: (v) {
    c.selectedAction.value = v; // ✅ garde FR
  },
),
  ],
),
if (c.selectedAction.value != null) ...[
  const SizedBox(height: 10),

  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      const Text(
        "Fichier (optionnel)",
        style: TextStyle(fontWeight: FontWeight.w600),
      ),

      const SizedBox(height: 6),

      ElevatedButton.icon(
        icon: const Icon(Icons.attach_file),
        label: Text(actionFileName ?? "Choisir fichier"),
        onPressed: pickActionFile,
      ),

    ],
  ),
],
                      const SizedBox(height: 18),

                      // ✅ Primary button: stay on page
                      CommonButton(
  borderRadius: 8,
  width: 180,
  onPressed: () => _submit(goBackAfterSave: false),
  text: _projectId == null ? "Create" : "Update",
),

                      // ✅ Global button in update mode: Update + redirect
                     /* if (_projectId != null) ...[
                        const SizedBox(height: 10),
                        CommonButton(
                          borderRadius: 8,
                          width: 240,
                          onPressed: () => _submit(goBackAfterSave: true),
                          text: "Update & Back to List",
                        ),
                      ],*/

                      // QUOTATION + PURCHASE ORDER (ONLY when editing)
                      if (_projectId != null) ...[
  const SizedBox(height: 18),

  DevisFormSection(
    projectId: _projectId!,
    isEdit: true,
    onMatriculeSaved: (m) {
      c.matriculeFiscale.text = m;
      setState(() {});
    },
    onDevisValidityChanged: (ok) {
      setState(() => _devisIsValid = ok);
    },

    // ✅ NEW: refresh card color after upload/delete
    onUploaded: () async {
      await _refreshCardColors();
    },
  ),

  const SizedBox(height: 12),

                       BonDeCommandeFormSection(
    projectId: _projectId!,
    devisIsValid: _devisIsValid,

    // ✅ NEW: refresh card color after upload/delete
    onUploaded: () async {
      await _refreshCardColors();
    },
  ),
const SizedBox(height: 16),

ElevatedButton(
  child: const Text("CRM Timeline"),
  onPressed: () {

    context.go(
      "/forms/project-timeline?projectId=$_projectId"
    );

  },
),
  // ✅✅✅ MOVED HERE: button after Purchase Order
  const SizedBox(height: 16),
  CommonButton(
    borderRadius: 8,
    width: 240,
    onPressed: () => _submit(goBackAfterSave: true),
    text: "Update & Back to List",
  ),
],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ----------------- DATE FIELD -----------------
  Widget _dateField({
    required ThemeData theme,
    required String title,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredTitle(theme, title, required: validator != null),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            readOnly: true,
            onTap: () async {
              await c.pickDateDemarrage(context);
              if (mounted) setState(() {});
            },
            decoration: inputDecoration(context, hintText: "Select a date").copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () async {
                  await c.pickDateDemarrage(context);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------- STATUS (EN label / FR API value) -----------------
  Widget _statusDropdown(ThemeData theme) {
    final currentApiValue = c.statut.text.trim();
    final currentItem = _statusOptions.firstWhere(
      (e) => e["value"] == currentApiValue,
      orElse: () => _statusOptions.first,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredTitle(theme, "Project status", required: true),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentItem["value"], // FR value stored
             validator: (v) {
    if (v == null || v.isEmpty) {
      return "Project status is required";
    }
    return null;
  },
            decoration: inputDecoration(context, hintText: "Choose a status"),
            items: _statusOptions
                .map((s) => DropdownMenuItem(
                      value: s["value"], // FR
                      child: Text(s["label"]!), // EN
                    ))
                .toList(),
            onChanged: (val) {
              c.statut.text = val ?? "";
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ----------------- VALIDATION (EN label / FR API value) -----------------
  Widget _validationDropdown(ThemeData theme) {
    final currentApiValue = c.validationStatut.text.trim();
    final currentItem = _validationOptions.firstWhere(
      (e) => e["value"] == currentApiValue,
      orElse: () => _validationOptions.last, // default Non validé
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredTitle(theme, "Validation status", required: false),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentItem["value"], // FR stored
            decoration: inputDecoration(context, hintText: "Choose"),
            items: _validationOptions
                .map((s) => DropdownMenuItem(
                      value: s["value"], // FR
                      child: Text(s["label"]!), // EN
                    ))
                .toList(),
            onChanged: (val) {
              c.validationStatut.text = val ?? "Non validé"; // FR to API
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ----------------- FIELD -----------------
  Widget _field({
    required ThemeData theme,
    required String title,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredTitle(theme, title, required: validator != null),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: inputDecoration(context, hintText: title),
          ),
        ],
      ),
    );
  }

  Widget _requiredTitle(ThemeData theme, String title, {required bool required}) {
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        children: [
          TextSpan(text: title),
          if (required)
            TextSpan(
              text: " *",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  // ----------------- LOCATION -----------------
 Widget _locationBlock(ThemeData theme) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _requiredTitle(theme, "Location", required: true),
      const SizedBox(height: 6),

      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: c.localisationAdresse,
              validator: (v) {
  final hasAddress = v != null && v.trim().isNotEmpty;
  final hasCoords = c.latitude.value != null && c.longitude.value != null;

  if (!hasAddress && !hasCoords) {
    return "Location is required";
  }
  return null;
},
              keyboardType: TextInputType.url, // ✅ utile sur mobile pour coller des liens
              decoration: inputDecoration(
                context,
                hintText: "Enter an address or pick on the map",
              ),
            ),
          ),
          const SizedBox(width: 10),
          CommonButton(
            borderRadius: 10,
            width: 170,
            onPressed: _pickLocation,
            text: "Pick on map",
          ),
        ],
      ),

      const SizedBox(height: 8),

      Obx(() {
  final lat = c.latitude.value;
  final lng = c.longitude.value;

  final hasLoc = lat != null && lng != null;

  final url = hasLoc
      ? "https://www.google.com/maps?q=$lat,$lng"
      : "";

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// 📍 COORDONNÉES
      Text(
        hasLoc
            ? "Lat: ${lat.toStringAsFixed(7)}, Lng: ${lng.toStringAsFixed(7)}"
            : "Select an address or choose it on the map.",
        style: theme.textTheme.bodySmall?.copyWith(
          color: hasLoc ? colorPrimary100 : colorGrey700,
          fontWeight: FontWeight.w600,
        ),
      ),

      /// 🔗 LIEN DIRECT GOOGLE MAPS
      if (hasLoc) ...[
        const SizedBox(height: 6),

        InkWell(
          onTap: () async {
            final uri = Uri.parse(url);
            await launchUrl(uri);
          },
          child: Row(
            children: [
              const Icon(Icons.link, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  url,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
})
    ],
  );
}

  Future<void> _pickLocation() async {
    final currentLat = c.latitude.value;
    final currentLng = c.longitude.value;

    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialPosition: (currentLat != null && currentLng != null)
              ? LatLng(currentLat, currentLng)
              : null,
          initialAddress: c.localisationAdresse.text.trim().isEmpty
              ? null
              : c.localisationAdresse.text.trim(),
        ),
      ),
    );

    if (result == null) return;

    c.setLocation(lat: result.lat, lng: result.lng, address: result.address);

    if (result.comment.isNotEmpty) {
      c.locationComments.add({
        "comment": result.comment,
        "createdAt": DateTime.now().toIso8601String(),
      });
    }
  }
  DateTime? parseDate(String? input) {
  if (input == null || input.isEmpty) return null;

  try {
    return DateFormat("dd/MM/yyyy").parse(input);
  } catch (e) {
    return null;
  }
}

Future<void> _submit({required bool goBackAfterSave}) async {
  String? clean(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
  final ok = c.formKey.currentState?.validate() ?? false;
  if (!ok) return;

if (c.isProject && !c.hasLocation)  {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Location is required")),
  );
  return;
}

  final manualComment = c.commentaireCtrl.text.trim();

  DateTime? parsed = parseDate(c.dateDemarrage.text);

final payload = {
  "nomProjet": clean(c.nomProjet.text),
  "projectModele": c.projectModele.value,

  /// =====================
  /// 🔵 PROJECT ONLY
  /// =====================


"dateDemarrage": c.isProject && parsed != null
    ? "${parsed.year.toString().padLeft(4, '0')}-"
      "${parsed.month.toString().padLeft(2, '0')}-"
      "${parsed.day.toString().padLeft(2, '0')}"
    : null,
  "statut": c.isProject ? clean(c.statut.text) : null,
  "typeAdresseChantier": c.isProject ? clean(c.typeAdresseChantier.text) : null,

  "adresse": (c.isProject || c.isApplicateur)
      ? clean(c.localisationAdresse.text)
      : null,

  "location": c.isProject
      ? {
          "lat": c.latitude.value,
          "lng": c.longitude.value,
        }
      : null,

  "typeProjet": c.isProject ? clean(c.typeProjet.text) : null,
  "pourcentageReussite": c.isProject ? c.pourcentageReussiteValue : null,
  "surfaceProspectee": c.isProject ? c.surfaceProspecteeValue : null,

  "entreprise": c.isProject ? clean(c.entreprise.text) : null,
  "promoteur": c.isProject ? clean(c.promoteur.text) : null,
  "bureauEtude": c.isProject ? clean(c.bureauEtude.text) : null,
  "bureauControle": c.isProject ? clean(c.bureauControle.text) : null,

  "entrepriseFluide": c.isProject ? clean(c.entrepriseFluide.text) : null,
  "entrepriseElectricite": c.isProject ? clean(c.entrepriseElectricite.text) : null,

  "ingenieurResponsable": c.isProject ? clean(c.ingenieurResponsable.text) : null,
  "telephoneIngenieur": c.isProject ? clean(c.telephoneIngenieur.text) : null,
  "emailIngenieur": c.isProject ? clean(c.emailIngenieur.text) : null,

  "architecte": c.isProject ? clean(c.architecte.text) : null,
  "telephoneArchitecte": c.isProject ? clean(c.telephoneArchitecte.text) : null,
  "emailArchitecte": c.isProject ? clean(c.emailArchitecte.text) : null,

  /// =====================
  /// 🟠 REVENDEUR
  /// =====================
  "comptoir": c.isRevendeur ? clean(c.comptoir.text) : null,
  "telephoneComptoir": c.isRevendeur ? clean(c.telephoneComptoir.text) : null,
  "telephoneComptoir2": c.isRevendeur ? clean(c.telephoneComptoir2.text) : null,
  "registreCommerce": c.isRevendeur ? clean(c.registreCommerce.text) : null,
  "fonction": c.isRevendeur ? clean(c.fonction.text) : null,

  "revendeurNom": c.isRevendeur ? clean(c.revendeurNom.text) : null,
  "revendeurPrenom": c.isRevendeur ? clean(c.revendeurPrenom.text) : null,
  "revendeurEmail": c.isRevendeur ? clean(c.revendeurEmail.text) : null,
  "revendeurStatut": c.isRevendeur ? c.revendeurStatut.text : null,
  "adresseRevendeur": c.isRevendeur ? clean(c.adresseRevendeur.text) : null,

  /// =====================
  /// 🔵 APPLICATEUR
  /// =====================
  "dallagiste": c.isApplicateur ? clean(c.dallagiste.text) : null,
  "telephoneDallagiste": c.isApplicateur ? clean(c.telephoneDallagiste.text) : null,
  "emailDallagiste": c.isApplicateur ? clean(c.emailDallagiste.text) : null,
  "serviceTechnique": c.isApplicateur ? clean(c.serviceTechnique.text) : null,
  "registreCommerce": c.isApplicateur ? clean(c.registreCommerce.text) : null,
  "matriculeFiscale": c.isApplicateur ? clean(c.matriculeFiscale.text) : null,

  /// =====================
  /// GLOBAL
  /// =====================
  "montantMarche": clean(c.montantMarche.text),
  "validationStatut": clean(c.validationStatut.text) ?? "Non validé",
  "dateVisite": clean(c.dateVisite.text),
  "firstAction": c.selectedAction.value,
  "localisationCommentaire": clean(c.commentaireCtrl.text), // 📍

"commentaireAction": clean(c.commentaireCtrl.text), // 🧠 (optionnel si action)

};

  try {

    dynamic data;

    /// ======================
    /// CREATE PROJECT
    /// ======================
    if (_projectId == null) {

      final res = await ApiClient.instance.dio.post(
        '/projects',
        data: payload, // ✅ JSON ONLY
      );

      data = res.data;

      final projectId = data["id"];

      /// ✅ CREATE ACTION WITH FILE
      if (selectedFileBytes != null && c.selectedAction.value != null) {

        await ApiClient.instance.dio.post(
          "/projects/$projectId/actions",
          data: dio.FormData.fromMap({

            "typeAction": c.selectedAction.value,
            "commentaire": c.commentaireCtrl.text.trim(),

            "file": dio.MultipartFile.fromBytes(
              selectedFileBytes!,
              filename: actionFileName,
            ),

          }),
        );
      }

    }

    /// ======================
    /// UPDATE PROJECT
    /// ======================
    else {

      final res = await ApiClient.instance.dio.put(
        '/projects/$_projectId',
        data: payload, // ✅ JSON ONLY
      );

      data = res.data;

      if (selectedFileBytes != null && c.selectedAction.value != null) {

        await ApiClient.instance.dio.post(
          "/projects/$_projectId/actions",
          data: dio.FormData.fromMap({

            "typeAction": c.selectedAction.value,
            "commentaire": c.commentaireCtrl.text.trim(),

            "file": dio.MultipartFile.fromBytes(
              selectedFileBytes!,
              filename: actionFileName,
            ),

          }),
        );
      }
    }

    /// ======================
    /// REFRESH UI
    /// ======================
    final map = Map<String, dynamic>.from(data as Map);
    
    final project = ProjectGridData.fromJson(map);

    final gridCtrl = Get.isRegistered<UserGridController>()
        ? Get.find<UserGridController>()
        : Get.put(UserGridController(), permanent: true);

    gridCtrl.upsertProject(project);
    gridCtrl.forceRefresh();

    if (project.id != null && project.id!.isNotEmpty) {
      await gridCtrl.refreshProjectById(project.id!);
    }

    /// ======================
    /// CREATE MODE
    /// ======================
    if (_projectId == null) {

      setState(() => _projectId = project.id);

      await c.loadProject(project.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project created ✅")),
      );

      if (goBackAfterSave) context.go(MyRoute.userGridScreen);

      /// RESET FILE
      selectedFileBytes = null;
      actionFileName = null;

      return;
    }

    /// ======================
    /// UPDATE MODE
    /// ======================
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Project updated ✅")),
    );

    if (goBackAfterSave) {
      context.go(MyRoute.userGridScreen);
    }

    /// RESET FILE
    selectedFileBytes = null;
    actionFileName = null;

  } catch (e) {

    print("ERROR => $e");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Network error: $e")),
    );
  }
 
}

  // ----------------- UI HELPERS -----------------
  Widget _twoCols({required bool isMobile, required Widget left, required Widget right}) {
    if (isMobile) return Column(children: [left, right]);
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _commonBackgroundWidget({required Widget child, required double? screenWidth}) {
    return Container(
      width: screenWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeController.isDarkMode ? colorDark : colorWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: child,
    );
  }
}