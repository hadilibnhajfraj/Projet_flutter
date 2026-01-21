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

// template imports chez toi
import 'package:dash_master_toolkit/forms/form_imports.dart';
import 'package:dash_master_toolkit/pages/google_map/map_imports.dart';

class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final ProjectFormController c;
  late final ThemeController themeController;

  final List<String> _statusOptions = const ["En cours", "Préparation", "Terminé"];
  final List<String> _validationOptions = const ["Validé", "Non validé"];

  String? _projectId;
  bool _loadedOnce = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    c = Get.isRegistered<ProjectFormController>()
        ? Get.find<ProjectFormController>()
        : Get.put(ProjectFormController()); // ✅ pas permanent

    themeController = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put(ThemeController());
  }

  @override
  void dispose() {
    // ✅ on supprime seulement le form controller (pas le ThemeController)
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
      if (mounted) setState(() {}); // refresh dropdowns
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement projet : $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // ✅ FIX: plus de responsive_framework TABLET => compile OK sur web
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
                          title: "Nom du Projet",
                          controller: c.nomProjet,
                          validator: (v) => c.requiredValidator(v, "Nom du Projet"),
                        ),
                        right: GetBuilder<ProjectFormController>(
                          id: 'dateDemarrage',
                          builder: (_) => _dateField(
                            theme: theme,
                            title: "Date de Démarrage",
                            controller: c.dateDemarrage,
                            validator: (v) => c.requiredValidator(v, "Date de Démarrage"),
                          ),
                        ),
                      ),

                      _statusDropdown(theme),

                      // ✅ typeProjet + typeAdresseChantier
                      _twoCols(
                        isMobile: isMobile,
                        left: _field(
                          theme: theme,
                          title: "Type de projet (optionnel)",
                          controller: c.typeProjet,
                          validator: null,
                        ),
                        right: _field(
                          theme: theme,
                          title: "Type + Adresse du Chantier",
                          controller: c.typeAdresseChantier,
                          validator: (v) => c.requiredValidator(v, "Type + Adresse"),
                        ),
                      ),

                      // ✅ validation + pourcentage
                      _twoCols(
                        isMobile: isMobile,
                        left: _validationDropdown(theme),
                        right: _field(
                          theme: theme,
                          title: "Pourcentage de réussite (0 - 100)",
                          controller: c.pourcentageReussite,
                          validator: c.percentValidator,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),

                      // ✅ surface
                      _field(
                        theme: theme,
                        title: "Surface prospectée (m²) (optionnel)",
                        controller: c.surfaceProspectee,
                        validator: c.surfaceValidator,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),

                      _twoCols(
                        isMobile: isMobile,
                        left: _field(
                          theme: theme,
                          title: "Ingénieur Responsable",
                          controller: c.ingenieurResponsable,
                          validator: (v) => c.requiredValidator(v, "Ingénieur Responsable"),
                        ),
                        right: _field(
                          theme: theme,
                          title: "Téléphone Ingénieur",
                          controller: c.telephoneIngenieur,
                          validator: (v) => c.phoneValidator(v, "Téléphone Ingénieur"),
                          keyboardType: TextInputType.phone,
                        ),
                      ),

                      _twoCols(
                        isMobile: isMobile,
                        left: _field(
                          theme: theme,
                          title: "Architecte",
                          controller: c.architecte,
                          validator: (v) => c.requiredValidator(v, "Architecte"),
                        ),
                        right: _field(
                          theme: theme,
                          title: "Téléphone Architecte",
                          controller: c.telephoneArchitecte,
                          validator: (v) => c.phoneValidator(v, "Téléphone Architecte"),
                          keyboardType: TextInputType.phone,
                        ),
                      ),

                      _field(
                        theme: theme,
                        title: "Entreprise",
                        controller: c.entreprise,
                        validator: (v) => c.requiredValidator(v, "Entreprise"),
                      ),
                      _field(
                        theme: theme,
                        title: "Promoteur",
                        controller: c.promoteur,
                        validator: (v) => c.requiredValidator(v, "Promoteur"),
                      ),
                      _field(
                        theme: theme,
                        title: "Bureau d’étude",
                        controller: c.bureauEtude,
                        validator: (v) => c.requiredValidator(v, "Bureau d’étude"),
                      ),
                      _field(
                        theme: theme,
                        title: "Bureau de contrôle",
                        controller: c.bureauControle,
                        validator: (v) => c.requiredValidator(v, "Bureau de contrôle"),
                      ),

                      _twoCols(
                        isMobile: isMobile,
                        left: _field(
                          theme: theme,
                          title: "Entreprise Fluide (optionnel)",
                          controller: c.entrepriseFluide,
                          validator: null,
                        ),
                        right: _field(
                          theme: theme,
                          title: "Entreprise Électricité (optionnel)",
                          controller: c.entrepriseElectricite,
                          validator: null,
                        ),
                      ),

                      const SizedBox(height: 14),
                      _locationBlock(theme),

                      _field(
                        theme: theme,
                        title: "Commentaires (optionnel)",
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
                        text: _projectId == null ? "Créer" : "Mettre à jour",
                      ),
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
            decoration: inputDecoration(context, hintText: "Sélectionner une date").copyWith(
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
    final current = c.statut.text.trim();
    final currentValue = _statusOptions.contains(current) ? current : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredTitle(theme, "Statut du Projet", required: false),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentValue,
            decoration: inputDecoration(context, hintText: "Choisir un statut"),
            items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              c.statut.text = val ?? "";
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ----------------- ✅ VALIDATION -----------------
  Widget _validationDropdown(ThemeData theme) {
    final current = c.validationStatut.text.trim();
    final currentValue = _validationOptions.contains(current) ? current : "Non validé";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredTitle(theme, "Validation", required: false),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentValue,
            decoration: inputDecoration(context, hintText: "Choisir"),
            items: _validationOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              c.validationStatut.text = val ?? "Non validé";
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
        _requiredTitle(theme, "Localisation", required: true),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.localisationAdresse,
                validator: (v) => c.requiredValidator(v, "Localisation"),
                decoration: inputDecoration(
                  context,
                  hintText: "Saisir une adresse ou choisir sur la carte",
                ),
              ),
            ),
            const SizedBox(width: 10),
            CommonButton(
              borderRadius: 10,
              width: 170,
              onPressed: _pickLocation,
              text: "Choisir sur la carte",
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() {
          final hasLoc = c.hasLocation;
          return Text(
            hasLoc
                ? "Lat: ${c.latitude.value}, Lng: ${c.longitude.value}"
                : "Sélectionne une adresse ou choisis sur la carte.",
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
        const SnackBar(content: Text("La localisation est obligatoire")),
      );
      return;
    }

    final manualComment = c.commentaireCtrl.text.trim();
    final allComments = [
      ...c.locationComments.toList(),
      if (manualComment.isNotEmpty)
        {"comment": manualComment, "createdAt": DateTime.now().toIso8601String()},
    ];

    final payload = {
      "nomProjet": c.nomProjet.text.trim(),
      "dateDemarrage": c.dateDemarrage.text.trim(),
      "statut": c.statut.text.trim().isEmpty ? null : c.statut.text.trim(),
      "typeAdresseChantier": c.typeAdresseChantier.text.trim(),
      "ingenieurResponsable": c.ingenieurResponsable.text.trim(),
      "telephoneIngenieur": c.telephoneIngenieur.text.trim(),
      "architecte": c.architecte.text.trim(),
      "telephoneArchitecte": c.telephoneArchitecte.text.trim(),
      "entreprise": c.entreprise.text.trim(),
      "promoteur": c.promoteur.text.trim(),
      "bureauEtude": c.bureauEtude.text.trim(),
      "bureauControle": c.bureauControle.text.trim(),
      "entrepriseFluide": c.entrepriseFluide.text.trim().isEmpty ? null : c.entrepriseFluide.text.trim(),
      "entrepriseElectricite": c.entrepriseElectricite.text.trim().isEmpty ? null : c.entrepriseElectricite.text.trim(),
      "adresse": c.localisationAdresse.text.trim().isEmpty ? null : c.localisationAdresse.text.trim(),
      "location": {"lat": c.latitude.value, "lng": c.longitude.value},
      "localisationCommentaire": manualComment.isEmpty ? null : manualComment,

      // ✅ nouveaux champs
      "typeProjet": c.typeProjet.text.trim().isEmpty ? null : c.typeProjet.text.trim(),
      "validationStatut": c.validationStatut.text.trim().isEmpty ? "Non validé" : c.validationStatut.text.trim(),
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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_projectId == null ? "Projet créé ✅" : "Projet mis à jour ✅")),
      );

      context.go(MyRoute.userGridScreen);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur réseau : $e")),
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
