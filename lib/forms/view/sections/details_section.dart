// lib/forms/view/sections/details_section.dart
//
// Step 2 — Type-specific fields (Project / Revendeur / Applicateur).
//
// GetX rules: Obx wraps the Column that reads c.projectModele.value directly.
// No setState() anywhere.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:dash_master_toolkit/forms/controller/project_form_controller.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/view/widgets/crm_widgets.dart';

class DetailsSection extends StatelessWidget {
  final ProjectFormController c;
  final bool isMobile;

  const DetailsSection({super.key, required this.c, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    // Obx directly reads c.projectModele.value → correct usage.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Obx(() {
        final type = c.projectModele.value;
        if (type == 'project') return _ProjectDetails(c: c, isMobile: isMobile);
        if (type == 'revendeur') return _RevendeurDetails(c: c, isMobile: isMobile);
        return _ApplicateurDetails(c: c, isMobile: isMobile);
      }),
    );
  }
}

// ── Project details ───────────────────────────────────────────────────────────

class _ProjectDetails extends StatelessWidget {
  final ProjectFormController c;
  final bool isMobile;

  const _ProjectDetails({required this.c, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CrmSectionTitle(
          title: 'Project Details', icon: Icons.construction_rounded),
      const SizedBox(height: 12),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Project Type (optional)',
            controller: c.typeProjet),
        right: CrmTextField(
            label: 'Site Type + Address',
            controller: c.typeAdresseChantier,
            validator: (v) => c.requiredValidator(v, 'Site Type + Address')),
      ),
      CrmTextField(
          label: 'Prospected Area m² (optional)',
          controller: c.surfaceProspectee,
          validator: c.surfaceValidator,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true)),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Developer (optional)', controller: c.promoteur),
        right: CrmTextField(
            label: 'Design Office (optional)', controller: c.bureauEtude),
      ),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Control Office', controller: c.bureauControle),
        right: CrmTextField(
            label: 'Tax Number (optional)', controller: c.matriculeFiscale),
      ),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Plumbing/HVAC Co. (optional)',
            controller: c.entrepriseFluide),
        right: CrmTextField(
            label: 'Electrical Co. (optional)',
            controller: c.entrepriseElectricite),
      ),
    ]);
  }
}

// ── Revendeur details ─────────────────────────────────────────────────────────

class _RevendeurDetails extends StatelessWidget {
  final ProjectFormController c;
  final bool isMobile;

  static const _fonctionOptions = [
    {'label': 'Achat',  'value': 'achat'},
    {'label': 'Gérant', 'value': 'gerant'},
  ];

  static const _statutOptions = [
    {'label': 'Prospect', 'value': 'prospect'},
    {'label': 'Offre',    'value': 'offre'},
    {'label': 'Actif',    'value': 'actif'},
    {'label': 'Raté',     'value': 'rate'},
  ];

  const _RevendeurDetails({required this.c, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CrmSectionTitle(
          title: 'Revendeur Details', icon: Icons.store_rounded),
      const SizedBox(height: 12),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Comptoir (Société)', controller: c.comptoir),
        right: CrmTextField(
            label: 'Téléphone Comptoir',
            controller: c.telephoneComptoir),
      ),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Téléphone Comptoir 2',
            controller: c.telephoneComptoir2,
            keyboardType: TextInputType.phone),
        right: CrmTextField(
            label: 'Registre de commerce',
            controller: c.registreCommerce),
      ),
      CrmStringDropdown(
        label: 'Fonction',
        required: true,
        controller: c.fonction,
        options: _fonctionOptions,
        hint: 'Choisir',
        validator: (v) =>
            (v == null || v.isEmpty) ? 'Fonction obligatoire' : null,
      ),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Nom revendeur', controller: c.revendeurNom),
        right: CrmTextField(
            label: 'Prénom revendeur', controller: c.revendeurPrenom),
      ),
      CrmTextField(
          label: 'Email revendeur',
          controller: c.revendeurEmail,
          keyboardType: TextInputType.emailAddress),
      CrmStringDropdown(
        label: 'Statut revendeur',
        controller: c.revendeurStatut,
        options: _statutOptions,
        hint: 'Choisir',
        defaultValue: 'prospect',
      ),
      CrmTextField(
          label: 'Adresse revendeur',
          controller: c.adresseRevendeur,
          validator: (v) => c.requiredValidator(v, 'Adresse')),
    ]);
  }
}

// ── Applicateur details ───────────────────────────────────────────────────────

class _ApplicateurDetails extends StatelessWidget {
  final ProjectFormController c;
  final bool isMobile;

  const _ApplicateurDetails({required this.c, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CrmSectionTitle(
          title: 'Applicateur Details', icon: Icons.engineering_rounded),
      const SizedBox(height: 12),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Dallagiste',
            controller: c.dallagiste,
            validator: (v) => c.requiredValidator(v, 'Dallagiste')),
        right: CrmTextField(
            label: 'Téléphone Dallagiste',
            controller: c.telephoneDallagiste,
            validator: (v) => c.phoneValidator(v, 'Téléphone')),
      ),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Email Dallagiste', controller: c.emailDallagiste),
        right: CrmTextField(
            label: 'Service Technique', controller: c.serviceTechnique),
      ),
      crmTwoCols(
        isMobile: isMobile,
        left: CrmTextField(
            label: 'Matricule fiscale',
            controller: c.matriculeFiscale,
            validator: (v) => c.requiredValidator(v, 'Matricule')),
        right: CrmTextField(
            label: 'Registre de commerce',
            controller: c.registreCommerce,
            validator: (v) => c.requiredValidator(v, 'Registre')),
      ),
    ]);
  }
}
