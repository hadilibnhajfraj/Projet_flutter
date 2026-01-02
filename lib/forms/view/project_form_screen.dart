import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

import '../../pages/google_map/location_picker_screen.dart';
import '../controller/project_form_controller.dart';
import '../../providers/api_client.dart';

// ⚠️ ces imports existent déjà chez toi selon ton template
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

  @override
  void initState() {
    super.initState();

    c = Get.isRegistered<ProjectFormController>()
        ? Get.find<ProjectFormController>()
        : Get.put(ProjectFormController(), permanent: true);

    themeController = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put(ThemeController());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screenWidth = MediaQuery.of(context).size.width;

    final isMobile = responsiveValue<bool>(
      context,
      xs: true,
      sm: true,
      md: false,
      lg: false,
      xl: false,
    );

    return Scaffold(
      backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: [
              const rf.Condition.between(start: 0, end: 340, value: 10),
              const rf.Condition.between(start: 341, end: 992, value: 16),
            ],
            defaultValue: 24,
          ).value,
        ),
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
                      validator: (v) =>
                          c.requiredValidator(v, "Date de Démarrage"),
                    ),
                  ),
                ),

                _statusDropdown(theme),

                _field(
                  theme: theme,
                  title: "Type de projet et Adresse du Chantier",
                  controller: c.typeAdresseChantier,
                  validator: (v) => c.requiredValidator(v, "Type + Adresse"),
                ),

                _twoCols(
                  isMobile: isMobile,
                  left: _field(
                    theme: theme,
                    title: "Ingénieur Responsable",
                    controller: c.ingenieurResponsable,
                    validator: (v) =>
                        c.requiredValidator(v, "Ingénieur Responsable"),
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
                    validator: (v) =>
                        c.phoneValidator(v, "Téléphone Architecte"),
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

                // ✅ COMMENTAIRES MANUEL
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
                  width: 160,
                  onPressed: _submit,
                  text: "Enregistrer",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ TITRE avec étoile automatique
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
              setState(() {});
            },
            decoration: inputDecoration(context, hintText: "Sélectionner une date")
                .copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () async {
                  await c.pickDateDemarrage(context);
                  setState(() {});
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
            items: _statusOptions
                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) {
              c.statut.text = val ?? "";
              setState(() {});
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
                decoration: inputDecoration(context,
                    hintText: "Saisir une adresse ou choisir sur la carte"),
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

  // ✅ SUBMIT avec DIO (token auto)
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
      "entrepriseFluide": c.entrepriseFluide.text.trim().isEmpty
          ? null
          : c.entrepriseFluide.text.trim(),
      "entrepriseElectricite": c.entrepriseElectricite.text.trim().isEmpty
          ? null
          : c.entrepriseElectricite.text.trim(),
      "adresse": c.localisationAdresse.text.trim().isEmpty
          ? null
          : c.localisationAdresse.text.trim(),
      "location": {"lat": c.latitude.value, "lng": c.longitude.value},
      "comments": allComments,
    };

    try {
      final res = await ApiClient.instance.dio.post('/projects', data: payload);

      if (res.statusCode == 201 || res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Projet enregistré ✅")),
        );

        // optionnel: clear form
        // c.formKey.currentState?.reset();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur API (${res.statusCode}): ${res.data}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur réseau : $e")),
      );
    }
  }

  // ----------------- UI HELPERS -----------------
  Widget _twoCols({
    required bool isMobile,
    required Widget left,
    required Widget right,
  }) {
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
