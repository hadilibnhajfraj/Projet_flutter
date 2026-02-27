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

// ✅ IMPORTANT: sections (WITHOUT scaffold)
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

  // ✅ ENGLISH OPTIONS
// ✅ Display (EN) -> API value (FR)
final List<Map<String, String>> _statusOptions = const [
  {"label": "In progress", "value": "En cours"},
  {"label": "Preparation", "value": "Préparation"},
  {"label": "Completed", "value": "Terminé"},
];
  final List<String> _validationOptions = const ["Validated", "Not Validated"];

  String? _projectId;
  bool _loadedOnce = false;
  bool _loading = false;

  // ✅ block Purchase Order until Quotation is valid
  bool _devisIsValid = false;

  @override
  void initState() {
    super.initState();

    c = Get.isRegistered<ProjectFormController>()
        ? Get.find<ProjectFormController>()
        : Get.put(ProjectFormController()); // ✅ not permanent

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
                          title: "Project Type ",
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
                        title: "Prospected Area (m²)",
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
                          title: "Architect )",
                          controller: c.architecte,
                          validator: null,
                        ),
                        right: _field(
                          theme: theme,
                          title: "Architect Phone ",
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
                        title: "Tax Registration Number ",
                        controller: c.matriculeFiscale,
                        validator: null,
                      ),

                      _field(
                        theme: theme,
                        title: "Promoteur",
                        controller: c.promoteur,
                        validator: null,
                      ),
                      _field(
                        theme: theme,
                        title: "Design Office ",
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
                          title: "Plumbing/HVAC Company ",
                          controller: c.entrepriseFluide,
                          validator: null,
                        ),
                        right: _field(
                          theme: theme,
                          title: "Electrical Company ",
                          controller: c.entrepriseElectricite,
                          validator: null,
                        ),
                      ),

                      const SizedBox(height: 14),
                      _locationBlock(theme),

                      _field(
                        theme: theme,
                        title: "Comments ",
                        controller: c.commentaireCtrl,
                        validator: null,
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                      ),

                      const SizedBox(height: 18),

                      CommonButton(
                        borderRadius: 8,
                        width: 180,
                        onPressed: _submit,
                        text: _projectId == null ? "Create" : "Update",
                      ),

                      // ✅ QUOTATION + PURCHASE ORDER (ONLY when editing)
                      if (_projectId != null) ...[
                        const SizedBox(height: 18),

                        // ✅ Quotation section
                        DevisFormSection(
                          projectId: _projectId!,
                          isEdit: true,
                          onMatriculeSaved: (m) {
                            c.matriculeFiscale.text = m;
                            setState(() {});
                          },

                          // ✅ must exist in DevisFormSection
                          // -> returns true if quotation list is not empty
                          onDevisValidityChanged: (ok) {
                            setState(() => _devisIsValid = ok);
                          },
                        ),

                        const SizedBox(height: 12),

                        // ✅ Purchase order section (blocked if quotation not valid)
                        BonDeCommandeFormSection(
                          projectId: _projectId!,
                          devisIsValid: _devisIsValid,
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

  // ----------------- STATUS -----------------
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
          value: currentItem["value"], // ✅ store API value (FR)
          decoration: inputDecoration(context, hintText: "Choose a status"),
          items: _statusOptions
              .map((s) => DropdownMenuItem(
                    value: s["value"], // ✅ FR value
                    child: Text(s["label"]!), // ✅ EN label
                  ))
              .toList(),
          onChanged: (val) {
            c.statut.text = val ?? ""; // ✅ sends FR to backend
            if (mounted) setState(() {});
          },
        ),
      ],
    ),
  );
}

  // ----------------- VALIDATION -----------------
  Widget _validationDropdown(ThemeData theme) {
    final current = c.validationStatut.text.trim();
    final currentValue = _validationOptions.contains(current) ? current : "Not Validated";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredTitle(theme, "Validation Status", required: false),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentValue,
            decoration: inputDecoration(context, hintText: "Choose"),
            items: _validationOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              c.validationStatut.text = val ?? "Not Validated";
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

  Future<void> _submit() async {
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
  
      "statut": c.statut.text.trim().isEmpty ? null : c.statut.text.trim(),
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
      "validationStatut": c.validationStatut.text.trim().isEmpty ? "Not Validated" : c.validationStatut.text.trim(),
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

      gridCtrl.upsertProject(project);

      // ✅ After creation: stay on the page and show Quotation + Purchase Order
      if (_projectId == null) {
        setState(() => _projectId = project.id);
        await c.loadProject(project.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Project created ✅ You can now upload the Quotation, then the Purchase Order"),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project updated ✅")),
      );

      context.go(MyRoute.userGridScreen);
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