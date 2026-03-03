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

// template imports
import 'package:dash_master_toolkit/forms/form_imports.dart';
import 'package:dash_master_toolkit/pages/google_map/map_imports.dart';

// IMPORTANT: sections (WITHOUT scaffold)
import 'package:dash_master_toolkit/forms/view/devis_form_section.dart';
import 'package:dash_master_toolkit/forms/view/bon_de_commande_form_section.dart';

class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final ProjectFormController c;
  late final ThemeController themeController;

  // ✅ Display (EN) -> API value (FR)
  final List<Map<String, String>> _statusOptions = const [
    {"label": "In progress", "value": "En cours"},
    {"label": "Preparation", "value": "Préparation"},
    {"label": "Completed", "value": "Terminé"},
  ];

  // ✅ Display (EN) -> API value (FR)
  final List<Map<String, String>> _validationOptions = const [
    {"label": "Validated", "value": "Validé"},
    {"label": "Not validated", "value": "Non validé"},
  ];

  String? _projectId;
  bool _loadedOnce = false;
  bool _loading = false;

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

                      _twoCols(
                        isMobile: isMobile,
                        left: _field(
                          theme: theme,
                          title: "Project Name",
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

                      _statusDropdown(theme),

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

                      _field(
                        theme: theme,
                        title: "Prospected Area (m²) (optional)",
                        controller: c.surfaceProspectee,
                        validator: c.surfaceValidator,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),

                      _twoCols(
                        isMobile: isMobile,
                        left: _field(
                          theme: theme,
                          title: "Responsible Engineer",
                          controller: c.ingenieurResponsable,
                          validator: (v) => c.requiredValidator(v, "Responsible Engineer"),
                        ),
                        right: _field(
                          theme: theme,
                          title: "Engineer Phone",
                          controller: c.telephoneIngenieur,
                          validator: (v) => c.phoneValidator(v, "Engineer Phone"),
                          keyboardType: TextInputType.phone,
                        ),
                      ),

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

                      _field(
                        theme: theme,
                        title: "Company",
                        controller: c.entreprise,
                        validator: (v) => c.requiredValidator(v, "Company"),
                      ),

                      _field(
                        theme: theme,
                        title: "Tax Registration Number (optional)",
                        controller: c.matriculeFiscale,
                        validator: null,
                      ),

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
                        validator: (v) => c.requiredValidator(v, "Control Office"),
                      ),

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

                      const SizedBox(height: 14),
                      _locationBlock(theme),

                      _field(
                        theme: theme,
                        title: "Comments (optional)",
                        controller: c.commentaireCtrl,
                        validator: null,
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                      ),

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
          _requiredTitle(theme, "Project status", required: false),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentItem["value"], // FR value stored
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
                validator: (v) => c.requiredValidator(v, "Location"),
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
          final hasLoc = c.hasLocation;
          return Text(
            hasLoc
                ? "Lat: ${c.latitude.value}, Lng: ${c.longitude.value}"
                : "Select an address or choose it on the map.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: hasLoc ? colorPrimary100 : colorGrey700,
              fontWeight: FontWeight.w600,
            ),
          );
        }),
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

Future<void> _submit({required bool goBackAfterSave}) async {
  final ok = c.formKey.currentState?.validate() ?? false;
  if (!ok) return;

  if (!c.hasLocation) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Location is required")),
    );
    return;
  }

  final manualComment = c.commentaireCtrl.text.trim();

  final payload = {
    "nomProjet": c.nomProjet.text.trim(),
    "dateDemarrage": c.dateDemarrage.text.trim(),
    "statut": c.statut.text.trim().isEmpty ? null : c.statut.text.trim(), // FR
    "typeAdresseChantier": c.typeAdresseChantier.text.trim(),
    "ingenieurResponsable": c.ingenieurResponsable.text.trim(),
    "telephoneIngenieur": c.telephoneIngenieur.text.trim(),
    "architecte": c.architecte.text.trim().isEmpty ? null : c.architecte.text.trim(),
    "telephoneArchitecte": c.telephoneArchitecte.text.trim().isEmpty ? null : c.telephoneArchitecte.text.trim(),
    "matriculeFiscale": c.matriculeFiscale.text.trim().isEmpty ? null : c.matriculeFiscale.text.trim(),
    "entreprise": c.entreprise.text.trim(),
    "promoteur": c.promoteur.text.trim().isEmpty ? null : c.promoteur.text.trim(),
    "bureauEtude": c.bureauEtude.text.trim().isEmpty ? null : c.bureauEtude.text.trim(),
    "bureauControle": c.bureauControle.text.trim(),
    "entrepriseFluide": c.entrepriseFluide.text.trim().isEmpty ? null : c.entrepriseFluide.text.trim(),
    "entrepriseElectricite": c.entrepriseElectricite.text.trim().isEmpty ? null : c.entrepriseElectricite.text.trim(),
    "adresse": c.localisationAdresse.text.trim().isEmpty ? null : c.localisationAdresse.text.trim(),
    "location": {"lat": c.latitude.value, "lng": c.longitude.value},
    "localisationCommentaire": manualComment.isEmpty ? null : manualComment,
    "typeProjet": c.typeProjet.text.trim().isEmpty ? null : c.typeProjet.text.trim(),
    "validationStatut": c.validationStatut.text.trim().isEmpty
        ? "Non validé"
        : c.validationStatut.text.trim(), // FR
    "pourcentageReussite": c.pourcentageReussiteValue,
    "surfaceProspectee": c.surfaceProspecteeValue,
  };

  try {
    dynamic data;

    if (_projectId == null) {
      final res = await ApiClient.instance.dio.post('/projects', data: payload);
      data = res.data;
    } else {
      final res = await ApiClient.instance.dio.put('/projects/$_projectId', data: payload);
      data = res.data;
    }

    final map = Map<String, dynamic>.from(data as Map);
    final project = ProjectGridData.fromJson(map);

    final gridCtrl = Get.isRegistered<UserGridController>()
        ? Get.find<UserGridController>()
        : Get.put(UserGridController(), permanent: true);

    // ✅ Update list immediately
    gridCtrl.upsertProject(project);
    gridCtrl.forceRefresh();

    // ✅✅✅ VERY IMPORTANT: re-fetch full project (brings devisCount/bonCommandeCount)
    // This fixes the "need refresh to see colors"
    if (project.id != null && project.id!.isNotEmpty) {
      await gridCtrl.refreshProjectById(project.id!);
    }

    // ---- CREATE MODE ----
    if (_projectId == null) {
      setState(() => _projectId = project.id);

      // Reload form state for edit mode
      await c.loadProject(project.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Project created ✅ Now upload Quotation, then Purchase Order"),
        ),
      );

      if (goBackAfterSave) context.go(MyRoute.userGridScreen);
      return;
    }

    // ---- UPDATE MODE ----
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Project updated ✅")),
    );

    if (goBackAfterSave) {
      context.go(MyRoute.userGridScreen);
    }
  } catch (e) {
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