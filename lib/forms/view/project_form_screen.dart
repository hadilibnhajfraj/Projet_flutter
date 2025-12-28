import 'dart:convert';
import 'package:dash_master_toolkit/pages/google_map/map_imports.dart';
import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/forms/form_imports.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;
import 'package:http/http.dart' as http;

import '../../pages/google_map/location_picker_screen.dart';
import '../controller/project_form_controller.dart';
import '../../widgets/address_autocomplete_field.dart';
import '../../services/address_service.dart';
import '../../providers/api_client.dart';
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

    // ✅ IMPORTANT: une seule instance + permanent (sinon date peut rester vide)
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
                      validator: (v) => c.requiredValidator(v, "Date de Démarrage"),
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

  // ----------------- ✅ DATE FIELD (popup calendrier) -----------------
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
          _title(theme, title),
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
          _title(theme, "Statut du Projet"),
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
            validator: null,
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
        _title(theme, "Localisation (obligatoire)"),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: AddressAutocompleteField(
                controller: c.localisationAdresse,
                hintText: "Saisir une adresse (ex: Tunisie, Tunis, Sfax...)",
                validator: (v) => c.requiredValidator(
                  c.localisationAdresse.text,
                  "Localisation",
                ),
                onSelected: (AddressSuggestion s) {
                  c.setLocation(lat: s.lat, lng: s.lon, address: s.displayName);
                },
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
              color: hasLoc
                  ? colorPrimary100
                  : (themeController.isDarkMode ? colorGrey300 : colorGrey700),
              fontWeight: FontWeight.w600,
            ),
          );
        }),
        const SizedBox(height: 12),
        _title(theme, "Commentaire(s)"),
        const SizedBox(height: 6),
        _addCommentUI(theme),
        const SizedBox(height: 10),
        _commentsList(theme),
      ],
    );
  }

  Widget _addCommentUI(ThemeData theme) {
    final commentCtrl = TextEditingController();

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: commentCtrl,
            decoration: inputDecoration(
              context,
              hintText: "Ajouter un commentaire (ex: accès chantier, repère...)",
            ),
          ),
        ),
        const SizedBox(width: 10),
        CommonButton(
          borderRadius: 10,
          width: 120,
          onPressed: () {
            final txt = commentCtrl.text.trim();
            if (txt.isEmpty) return;

            c.locationComments.add({
              "comment": txt,
              "createdAt": DateTime.now().toIso8601String(),
            });
            commentCtrl.clear();
          },
          text: "Ajouter",
        ),
      ],
    );
  }

  Widget _commentsList(ThemeData theme) {
    return Obx(() {
      if (c.locationComments.isEmpty) {
        return Text(
          "Aucun commentaire.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: themeController.isDarkMode ? colorGrey300 : colorGrey600,
          ),
        );
      }

      return Column(
        children: c.locationComments.map((item) {
          final comment = (item["comment"] ?? "").toString();
          final createdAt = (item["createdAt"] ?? "").toString();

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeController.isDarkMode ? colorGrey800 : colorGrey50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: themeController.isDarkMode ? colorGrey700 : colorGrey200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorGrey500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => c.locationComments.remove(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
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
      const SnackBar(content: Text("La localisation (carte) est obligatoire")),
    );
    return;
  }

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
    "comments": c.locationComments.toList(),
  };

  try {
    // ✅ IMPORTANT: on utilise Dio => token ajouté automatiquement
    final res = await ApiClient.instance.dio.post('/projects', data: payload);

    if (res.statusCode == 201 || res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Projet enregistré avec succès ✅")),
      );
    } else if (res.statusCode == 401) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expirée. Reconnecte-toi.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur API (${res.statusCode}) : ${res.data}")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erreur réseau : $e")),
    );
  }
}

  // ----------------- UI HELPERS -----------------
  Widget _twoCols({required bool isMobile, required Widget left, required Widget right}) {
    if (isMobile) return Column(children: [left, right]);
    return Row(children: [Expanded(child: left), const SizedBox(width: 10), Expanded(child: right)]);
  }

  Widget _title(ThemeData theme, String title) {
    return Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700));
  }

  Widget _field({
    required ThemeData theme,
    required String title,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(theme, title),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            decoration: inputDecoration(context, hintText: title),
          ),
        ],
      ),
    );
  }

  Widget _commonBackgroundWidget({
    required Widget child,
    required double? screenWidth,
  }) {
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
