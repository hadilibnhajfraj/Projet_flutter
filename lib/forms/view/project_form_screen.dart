// lib/forms/view/project_form_screen.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dash_master_toolkit/application/users/controller/user_grid_controller.dart';
import 'package:dash_master_toolkit/application/users/model/project_grid_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/widgets/common_app_widget.dart';
import 'package:dash_master_toolkit/widgets/map_picker_widget.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import '../controller/project_form_controller.dart';
import '../../providers/api_client.dart';
import 'package:dash_master_toolkit/forms/view/project_timeline_screen.dart';
import 'package:dash_master_toolkit/forms/form_imports.dart';
import 'package:dash_master_toolkit/forms/view/devis_form_section.dart';
import 'package:dash_master_toolkit/forms/view/bon_de_commande_form_section.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/services/location_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WIZARD STEP DEFINITION
// ══════════════════════════════════════════════════════════════════════════════
class _WizardStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _WizardStep(
      {required this.title,
      required this.subtitle,
      required this.icon});
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────
  late final ProjectFormController c;
  late final ThemeController themeController;

  final _pageCtrl = PageController();
  int _currentStep = 0;

  // ── File ─────────────────────────────────────────────────────────────────
  Uint8List? selectedFileBytes;
  String? actionFileName;

  // ── Form state ───────────────────────────────────────────────────────────
  String? _projectId;
  bool _loadedOnce = false;
  bool _loading = false;
  bool _devisIsValid = false;

  // ── Address search ────────────────────────────────────────────────────────
  Timer? _addrDebounce;
  List<NominatimLocation> _addrSuggestions = [];
  bool _addrSearching = false;
  bool _showAddrSuggestions = false;
  String? _addrSearchError;

  // ── Action labels ─────────────────────────────────────────────────────────
  final Map<String, String> actionLabels = const {
    'Visite'          : 'Site Visit',
    'Plan technique'  : 'Technical Plan',
    'Echantillonnage' : 'Sampling',
    'Devis envoyé'    : 'Quote Sent',
    'Negociation'     : 'Negotiation',
    'Relance'         : 'Follow-up',
    'Commande gagnée' : 'Won',
    'Commande perdue' : 'Lost',
  };

  final List<Map<String, String>> _statusOptions = const [
    {'label': 'Identification',          'value': 'Identification'},
    {'label': 'Technical Proposal',      'value': 'Proposition technique'},
    {'label': 'Commercial Proposal',     'value': 'Proposition commerciale'},
    {'label': 'Negotiation',             'value': 'Négociation'},
    {'label': 'Delivery',                'value': 'Livraison'},
    {'label': 'Loyalty',                 'value': 'Fidélisation'},
  ];

  final List<Map<String, String>> _validationOptions = const [
    {'label': 'Validated',     'value': 'Validé'},
    {'label': 'Not validated', 'value': 'Non validé'},
  ];

  // ── Wizard steps config ───────────────────────────────────────────────────
  List<_WizardStep> get _steps => [
        const _WizardStep(
            title: 'General',
            subtitle: 'Project info & dates',
            icon: Icons.info_outline_rounded),
        const _WizardStep(
            title: 'Details',
            subtitle: 'Type-specific fields',
            icon: Icons.tune_rounded),
        const _WizardStep(
            title: 'Contacts',
            subtitle: 'People & companies',
            icon: Icons.people_outline_rounded),
        const _WizardStep(
            title: 'Location',
            subtitle: 'Address & map',
            icon: Icons.location_on_outlined),
        const _WizardStep(
            title: 'Action',
            subtitle: 'Next step & submit',
            icon: Icons.send_outlined),
      ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    c = Get.isRegistered<ProjectFormController>()
        ? Get.find<ProjectFormController>()
        : Get.put(ProjectFormController());
    themeController = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put(ThemeController());
  }

  @override
  void dispose() {
    _addrDebounce?.cancel();
    _pageCtrl.dispose();
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
    final id =
        GoRouterState.of(context).uri.queryParameters['id'];
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
      if (c.statut.text.trim().isEmpty) c.statut.text = '';
      if (c.validationStatut.text.trim().isEmpty) {
        c.validationStatut.text = 'Non validé';
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Loading error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── File picker ────────────────────────────────────────────────────────────
  Future<void> _pickActionFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      setState(() {
        selectedFileBytes = result.files.single.bytes;
        actionFileName    = result.files.single.name;
      });
    }
  }

  // ── Address search ─────────────────────────────────────────────────────────
  void _onLocationFieldChanged(String value) {
    _addrDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      if (mounted) {
        setState(() {
          _addrSuggestions = [];
          _showAddrSuggestions = false;
          _addrSearchError = null;
        });
      }
      return;
    }
    _addrDebounce = Timer(const Duration(milliseconds: 600),
        () => _searchAddressSuggestions(query));
  }

  Future<void> _searchAddressSuggestions(String query) async {
    if (!mounted) return;
    setState(() {
      _addrSearching    = true;
      _addrSearchError  = null;
      _showAddrSuggestions = true;
    });
    try {
      final results = await LocationService.searchPlaces(query);
      if (!mounted) return;
      setState(() {
        _addrSuggestions = results;
        _addrSearchError =
            results.isEmpty ? 'No results found in Tunisia' : null;
        _addrSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addrSuggestions = [];
        _addrSearchError = 'Search failed. Try again.';
        _addrSearching   = false;
      });
    }
  }

  void _selectAddrSuggestion(NominatimLocation result) {
    if (!mounted) return;
    setState(() {
      _showAddrSuggestions = false;
      _addrSuggestions     = [];
      _addrSearchError     = null;
    });
    c.setLocation(
      lat: result.latitude,
      lng: result.longitude,
      address: result.displayName,
      forceAddressUpdate: true,
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _goNext() {
    if (_currentStep < _steps.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  String? _getValidAction() {
    final valid = actionLabels.keys.toList();
    final v = c.selectedAction.value;
    if (v == null) return null;
    if (valid.contains(v)) return v;
    if (v == 'Visite chantier') return 'Visite';
    return null;
  }

  DateTime? _parseDate(String? input) {
    if (input == null || input.isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parse(input);
    } catch (_) {
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

    if (c.isProject && !c.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location is required')));
      return;
    }

    final parsed = _parseDate(c.dateDemarrage.text);
    final auth = Get.find<AuthService>();
    final currentUser = auth.getUserName();

    final payload = {
      'nomProjet'     : clean(c.nomProjet.text),
      'projectModele' : c.projectModele.value,
      'dateDemarrage' : c.isProject && parsed != null
          ? '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}'
          : null,
      'statut'               : c.isProject ? clean(c.statut.text) : null,
      'typeAdresseChantier'  : c.isProject ? clean(c.typeAdresseChantier.text) : null,
      'adresse'              : (c.isProject || c.isApplicateur)
          ? clean(c.localisationAdresse.text) : null,
      'location'             : c.isProject
          ? {'lat': c.latitude.value, 'lng': c.longitude.value} : null,
      'typeProjet'           : c.isProject ? clean(c.typeProjet.text) : null,
      'pourcentageReussite'  : c.isProject ? c.pourcentageReussiteValue : null,
      'surfaceProspectee'    : c.isProject ? c.surfaceProspecteeValue   : null,
      'entreprise'           : c.isProject ? clean(c.entreprise.text)   : null,
      'promoteur'            : c.isProject ? clean(c.promoteur.text)    : null,
      'bureauEtude'          : c.isProject ? clean(c.bureauEtude.text)  : null,
      'bureauControle'       : c.isProject ? clean(c.bureauControle.text) : null,
      'entrepriseFluide'     : c.isProject ? clean(c.entrepriseFluide.text) : null,
      'entrepriseElectricite': c.isProject ? clean(c.entrepriseElectricite.text) : null,
      'ingenieurResponsable' : c.isProject ? clean(c.ingenieurResponsable.text) : null,
      'telephoneIngenieur'   : c.isProject ? clean(c.telephoneIngenieur.text) : null,
      'emailIngenieur'       : c.isProject ? clean(c.emailIngenieur.text) : null,
      'architecte'           : c.isProject ? clean(c.architecte.text) : null,
      'telephoneArchitecte'  : c.isProject ? clean(c.telephoneArchitecte.text) : null,
      'emailArchitecte'      : c.isProject ? clean(c.emailArchitecte.text) : null,
      // Revendeur
      'comptoir'             : c.isRevendeur ? clean(c.comptoir.text)   : null,
      'telephoneComptoir'    : c.isRevendeur ? clean(c.telephoneComptoir.text) : null,
      'telephoneComptoir2'   : c.isRevendeur ? clean(c.telephoneComptoir2.text) : null,
      'registreCommerce'     : c.isRevendeur ? clean(c.registreCommerce.text) : null,
      'fonction'             : c.isRevendeur ? clean(c.fonction.text)   : null,
      'revendeurNom'         : c.isRevendeur ? clean(c.revendeurNom.text) : null,
      'revendeurPrenom'      : c.isRevendeur ? clean(c.revendeurPrenom.text) : null,
      'revendeurEmail'       : c.isRevendeur ? clean(c.revendeurEmail.text) : null,
      'revendeurStatut'      : c.isRevendeur ? c.revendeurStatut.text   : null,
      'adresseRevendeur'     : c.isRevendeur ? clean(c.adresseRevendeur.text) : null,
      // Applicateur
      'dallagiste'           : c.isApplicateur ? clean(c.dallagiste.text) : null,
      'telephoneDallagiste'  : c.isApplicateur ? clean(c.telephoneDallagiste.text) : null,
      'emailDallagiste'      : c.isApplicateur ? clean(c.emailDallagiste.text) : null,
      'serviceTechnique'     : c.isApplicateur ? clean(c.serviceTechnique.text) : null,
      'matriculeFiscale'     : c.isApplicateur ? clean(c.matriculeFiscale.text) : null,
      // Global
      'montantMarche'        : clean(c.montantMarche.text),
      'validationStatut'     : clean(c.validationStatut.text) ?? 'Non validé',
      'dateVisite'           : clean(c.dateVisite.text),
      'firstAction'          : c.selectedAction.value,
      'localisationCommentaire': clean(c.commentaireCtrl.text),
      'commentaireAction'    : clean(c.commentaireCtrl.text),
      'user_nom'             : currentUser,
    };

    try {
      dynamic data;
      if (_projectId == null) {
        final res = await ApiClient.instance.dio.post('/projects', data: payload);
        data = res.data;
        final projectId = data['id'];
        if (selectedFileBytes != null && c.selectedAction.value != null) {
          await ApiClient.instance.dio.post(
            '/projects/$projectId/actions',
            data: dio.FormData.fromMap({
              'typeAction' : c.selectedAction.value,
              'commentaire': c.commentaireCtrl.text.trim(),
              'file'       : dio.MultipartFile.fromBytes(
                  selectedFileBytes!, filename: actionFileName),
            }),
          );
        }
      } else {
        final res = await ApiClient.instance.dio
            .put('/projects/$_projectId', data: payload);
        data = res.data;
        if (selectedFileBytes != null && c.selectedAction.value != null) {
          await ApiClient.instance.dio.post(
            '/projects/$_projectId/actions',
            data: dio.FormData.fromMap({
              'typeAction' : c.selectedAction.value,
              'commentaire': c.commentaireCtrl.text.trim(),
              'file'       : dio.MultipartFile.fromBytes(
                  selectedFileBytes!, filename: actionFileName),
            }),
          );
        }
      }

      final map     = Map<String, dynamic>.from(data as Map);
      final project = ProjectGridData.fromJson(map);
      final gridCtrl = Get.isRegistered<UserGridController>()
          ? Get.find<UserGridController>()
          : Get.put(UserGridController(), permanent: true);
      gridCtrl.upsertProject(project);
      gridCtrl.forceRefresh();
      if (project.id != null && project.id!.isNotEmpty) {
        await gridCtrl.refreshProjectById(project.id!);
      }

      if (_projectId == null) {
        setState(() => _projectId = project.id);
        await c.loadProject(project.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project created ✅')));
        if (goBackAfterSave) context.go(MyRoute.userGridScreen);
        selectedFileBytes = null;
        actionFileName    = null;
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project updated ✅')));
      if (goBackAfterSave) context.go(MyRoute.userGridScreen);
      selectedFileBytes = null;
      actionFileName    = null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _refreshCardColors() async {
    if (_projectId == null) return;
    if (Get.isRegistered<UserGridController>()) {
      await UserGridController.to.refreshProjectById(_projectId!);
    }
    await c.loadProject(_projectId!);
    if (mounted) setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 992;

    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: kCrmBg,
      body: Column(children: [
        // ── Wizard header ────────────────────────────────────────────────
        _WizardHeader(
          steps:       _steps,
          currentStep: _currentStep,
          projectId:   _projectId,
        ),
        // ── Pages ─────────────────────────────────────────────────────────
        Expanded(
          child: Form(
            key: c.formKey,
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(theme, isMobile),
                _buildStep2(theme, isMobile),
                _buildStep3(theme, isMobile),
                _buildStep4(theme, isMobile),
                _buildStep5(theme, isMobile),
              ],
            ),
          ),
        ),
        // ── Nav buttons ───────────────────────────────────────────────────
        _WizardNavBar(
          currentStep : _currentStep,
          totalSteps  : _steps.length,
          onBack      : _goBack,
          onNext      : _goNext,
          onSubmit    : () => _submit(goBackAfterSave: false),
          onSubmitBack: () => _submit(goBackAfterSave: true),
          projectId   : _projectId,
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1: General Information
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1(ThemeData theme, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Project Type', Icons.category_rounded),
        const SizedBox(height: 12),
        // Project type selector
        Obx(() => Row(children: [
              _typeChip('Project', 'project',
                  Icons.construction_rounded, kCrmPrimary),
              const SizedBox(width: 10),
              _typeChip('Revendeur', 'revendeur',
                  Icons.store_rounded, kCrmWarning),
              const SizedBox(width: 10),
              _typeChip('Applicateur', 'applicateur',
                  Icons.engineering_rounded, kCrmInfo),
            ])),
        const SizedBox(height: 20),
        _sectionTitle('Basic Information', Icons.info_outline_rounded),
        const SizedBox(height: 12),
        _twoCols(
          isMobile: isMobile,
          left: _field(
            theme: theme,
            title: c.projectModele.value == 'revendeur'
                ? 'Société / Person Name'
                : 'Project Name',
            controller: c.nomProjet,
            validator: (v) => c.requiredValidator(v, 'Project Name'),
          ),
          right: GetBuilder<ProjectFormController>(
            id: 'dateDemarrage',
            builder: (_) => _dateField(
              theme: theme,
              title: 'Start Date',
              controller: c.dateDemarrage,
              validator: (v) => c.requiredValidator(v, 'Start Date'),
              onTap: () async {
                await c.pickDateDemarrage(context);
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
        _datePickerField(
          theme: theme,
          title: 'Visit Date',
          controller: c.dateVisite,
          required: true,
          onTap: () async {
            await c.pickDateVisite(context);
            if (mounted) setState(() {});
          },
        ),
        if (c.isProject) ...[
          const SizedBox(height: 8),
          _sectionTitle('Status', Icons.flag_outlined),
          const SizedBox(height: 12),
          _statusDropdown(theme),
          _twoCols(
            isMobile: isMobile,
            left: _validationDropdown(theme),
            right: _field(
              theme: theme,
              title: 'Success Rate (0–100)',
              controller: c.pourcentageReussite,
              validator: c.percentValidator,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _field(
          theme: theme,
          title: 'Market Amount',
          controller: c.montantMarche,
          keyboardType: TextInputType.number,
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: Type-specific Details
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2(ThemeData theme, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Obx(() {
        final type = c.projectModele.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == 'project') ...[
              _sectionTitle('Project Details', Icons.construction_rounded),
              const SizedBox(height: 12),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                  theme: theme,
                  title: 'Project Type (optional)',
                  controller: c.typeProjet,
                ),
                right: _field(
                  theme: theme,
                  title: 'Site Type + Address',
                  controller: c.typeAdresseChantier,
                  validator: (v) =>
                      c.requiredValidator(v, 'Site Type + Address'),
                ),
              ),
              _field(
                theme: theme,
                title: 'Prospected Area m² (optional)',
                controller: c.surfaceProspectee,
                validator: c.surfaceValidator,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                    theme: theme,
                    title: 'Developer (optional)',
                    controller: c.promoteur),
                right: _field(
                    theme: theme,
                    title: 'Design Office (optional)',
                    controller: c.bureauEtude),
              ),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                    theme: theme,
                    title: 'Control Office',
                    controller: c.bureauControle),
                right: _field(
                    theme: theme,
                    title: 'Tax Number (optional)',
                    controller: c.matriculeFiscale),
              ),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                    theme: theme,
                    title: 'Plumbing/HVAC Co. (optional)',
                    controller: c.entrepriseFluide),
                right: _field(
                    theme: theme,
                    title: 'Electrical Co. (optional)',
                    controller: c.entrepriseElectricite),
              ),
            ],
            if (type == 'revendeur') ...[
              _sectionTitle('Revendeur Details', Icons.store_rounded),
              const SizedBox(height: 12),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                    theme: theme,
                    title: 'Comptoir (Société)',
                    controller: c.comptoir),
                right: _field(
                    theme: theme,
                    title: 'Téléphone Comptoir',
                    controller: c.telephoneComptoir),
              ),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                  theme: theme,
                  title: 'Téléphone Comptoir 2',
                  controller: c.telephoneComptoir2,
                  keyboardType: TextInputType.phone,
                ),
                right: _field(
                    theme: theme,
                    title: 'Registre de commerce',
                    controller: c.registreCommerce),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  value: c.fonction.text.isEmpty ? null : c.fonction.text,
                  decoration: const InputDecoration(
                    labelText: 'Fonction',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'achat',  child: Text('Achat')),
                    DropdownMenuItem(value: 'gerant', child: Text('Gérant')),
                  ],
                  onChanged: (v) => c.fonction.text = v ?? '',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Fonction obligatoire' : null,
                ),
              ),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                    theme: theme,
                    title: 'Nom revendeur',
                    controller: c.revendeurNom),
                right: _field(
                    theme: theme,
                    title: 'Prénom revendeur',
                    controller: c.revendeurPrenom),
              ),
              _field(
                theme: theme,
                title: 'Email revendeur',
                controller: c.revendeurEmail,
                keyboardType: TextInputType.emailAddress,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  value: c.revendeurStatut.text,
                  decoration: const InputDecoration(
                    labelText: 'Statut revendeur',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'prospect', child: Text('Prospect')),
                    DropdownMenuItem(value: 'offre',    child: Text('Offre')),
                    DropdownMenuItem(value: 'actif',    child: Text('Actif')),
                    DropdownMenuItem(value: 'rate',     child: Text('Raté')),
                  ],
                  onChanged: (v) =>
                      c.revendeurStatut.text = v ?? 'prospect',
                ),
              ),
              _field(
                theme: theme,
                title: 'Adresse revendeur',
                controller: c.adresseRevendeur,
                validator: (v) => c.requiredValidator(v, 'Adresse'),
              ),
            ],
            if (type == 'applicateur') ...[
              _sectionTitle('Applicateur Details', Icons.engineering_rounded),
              const SizedBox(height: 12),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                  theme: theme,
                  title: 'Dallagiste',
                  controller: c.dallagiste,
                  validator: (v) => c.requiredValidator(v, 'Dallagiste'),
                ),
                right: _field(
                  theme: theme,
                  title: 'Téléphone Dallagiste',
                  controller: c.telephoneDallagiste,
                  validator: (v) => c.phoneValidator(v, 'Téléphone'),
                ),
              ),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                    theme: theme,
                    title: 'Email Dallagiste',
                    controller: c.emailDallagiste),
                right: _field(
                    theme: theme,
                    title: 'Service Technique',
                    controller: c.serviceTechnique),
              ),
              _twoCols(
                isMobile: isMobile,
                left: _field(
                  theme: theme,
                  title: 'Matricule fiscale',
                  controller: c.matriculeFiscale,
                  validator: (v) =>
                      c.requiredValidator(v, 'Matricule'),
                ),
                right: _field(
                  theme: theme,
                  title: 'Registre de commerce',
                  controller: c.registreCommerce,
                  validator: (v) =>
                      c.requiredValidator(v, 'Registre'),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: Contacts
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3(ThemeData theme, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.isProject) ...[
            _sectionTitle('Company', Icons.business_rounded),
            const SizedBox(height: 12),
            Obx(() => Column(children: [
                  DropdownButtonFormField<String?>(
                    value: c.selectedCompanyId.value,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select company'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      ...c.companies.map((co) => DropdownMenuItem(
                            value: co.id,
                            child: Text(co.name),
                          )),
                      const DropdownMenuItem(
                          value: 'other', child: Text('Other')),
                    ],
                    onChanged: c.setSelectedCompany,
                  ),
                  if (c.selectedCompanyId.value == 'other')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _field(
                        theme: theme,
                        title: 'Company name',
                        controller: c.entreprise,
                      ),
                    ),
                ])),
            const SizedBox(height: 20),
            _sectionTitle('Engineer', Icons.engineering_rounded),
            const SizedBox(height: 12),
            Obx(() => Column(children: [
                  DropdownButtonFormField<String?>(
                    value: c.selectedEngineerId.value,
                    decoration: const InputDecoration(
                      labelText: 'Engineer',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select engineer'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      ...c.engineers.map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          )),
                      const DropdownMenuItem(
                          value: 'other', child: Text('Other')),
                    ],
                    onChanged: c.setSelectedEngineer,
                  ),
                  if (c.selectedEngineerId.value == 'other')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _field(
                        theme: theme,
                        title: 'Engineer name',
                        controller: c.ingenieurResponsable,
                      ),
                    ),
                ])),
            const SizedBox(height: 8),
            _twoCols(
              isMobile: isMobile,
              left: _field(
                  theme: theme,
                  title: 'Engineer Phone',
                  controller: c.telephoneIngenieur,
                  keyboardType: TextInputType.phone),
              right: _field(
                  theme: theme,
                  title: 'Engineer Email',
                  controller: c.emailIngenieur,
                  keyboardType: TextInputType.emailAddress),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Architect', Icons.architecture_rounded),
            const SizedBox(height: 12),
            Obx(() => Column(children: [
                  DropdownButtonFormField<String?>(
                    value: c.selectedArchitectId.value,
                    decoration: const InputDecoration(
                      labelText: 'Architect',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select architect'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      ...c.architects.map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          )),
                      const DropdownMenuItem(
                          value: 'other', child: Text('Other')),
                    ],
                    onChanged: c.setSelectedArchitect,
                  ),
                  if (c.selectedArchitectId.value == 'other')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _field(
                        theme: theme,
                        title: 'Architect name',
                        controller: c.architecte,
                      ),
                    ),
                ])),
            const SizedBox(height: 8),
            _twoCols(
              isMobile: isMobile,
              left: _field(
                  theme: theme,
                  title: 'Architect Phone',
                  controller: c.telephoneArchitecte,
                  keyboardType: TextInputType.phone),
              right: _field(
                  theme: theme,
                  title: 'Architect Email',
                  controller: c.emailArchitecte,
                  keyboardType: TextInputType.emailAddress),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4: Location
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep4(ThemeData theme, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.isProject) ...[
            _sectionTitle('Location', Icons.location_on_rounded),
            const SizedBox(height: 12),
            // Free-text address
            TextFormField(
              controller: c.localisationAdresse,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [],
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.text,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              onChanged: _onLocationFieldChanged,
              validator: (v) {
                final hasAddress = v != null && v.trim().isNotEmpty;
                final hasCoords  = c.latitude.value != null &&
                    c.longitude.value != null;
                if (!hasAddress && !hasCoords) {
                  return 'Location is required';
                }
                return null;
              },
              decoration: inputDecoration(context,
                  hintText:
                      'Type address or use the map below'),
            ),
            if (_showAddrSuggestions)
              _buildAddrSuggestionsDropdown(theme),
            const SizedBox(height: 16),
            // Map
            Obx(() {
              final lat = c.latitude.value;
              final lng = c.longitude.value;
              return MapPickerWidget(
                initialLocation:
                    (lat != null && lng != null) ? LatLng(lat, lng) : null,
                initialAddress:
                    c.localisationAdresse.text.trim().isEmpty
                        ? null
                        : c.localisationAdresse.text.trim(),
                onLocationSelected: (location, address) {
                  final fieldIsEmpty =
                      c.localisationAdresse.text.trim().isEmpty;
                  c.setLocation(
                    lat: location.latitude,
                    lng: location.longitude,
                    address: fieldIsEmpty ? address : null,
                    forceAddressUpdate: false,
                  );
                },
                height: 360,
                showSearchBar: true,
                showCurrentLocationButton: true,
                showFullscreenButton: true,
              );
            }),
            const SizedBox(height: 12),
            // Coordinates status
            Obx(() {
              final lat = c.latitude.value;
              final lng = c.longitude.value;
              final hasLoc = lat != null && lng != null;
              if (!hasLoc) {
                return _statusBanner(
                  color: Colors.orange,
                  icon: Icons.info_outline,
                  text: 'Tap the map, use GPS, or search to select a location',
                );
              }
              return _statusBanner(
                color: Colors.green,
                icon: Icons.check_circle,
                text:
                    'Location selected: ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                trailing: InkWell(
                  onTap: () async {
                    final url =
                        'https://www.google.com/maps?q=$lat,$lng';
                    await launchUrl(Uri.parse(url));
                  },
                  child: const Text('View on Maps',
                      style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          fontSize: 12)),
                ),
              );
            }),
            Obx(() {
              if (c.locationError.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return _statusBanner(
                color: Colors.red,
                icon: Icons.error_outline,
                text: c.locationError.value,
              );
            }),
          ] else if (c.isApplicateur) ...[
            _sectionTitle('Adresse', Icons.location_on_rounded),
            const SizedBox(height: 12),
            _field(
              theme: theme,
              title: 'Adresse applicateur',
              controller: c.localisationAdresse,
              validator: (v) => c.requiredValidator(v, 'Adresse'),
            ),
          ] else ...[
            // Revendeur
            _sectionTitle('Adresse', Icons.location_on_rounded),
            const SizedBox(height: 12),
            _field(
              theme: theme,
              title: 'Adresse revendeur',
              controller: c.adresseRevendeur,
              validator: (v) => c.requiredValidator(v, 'Adresse'),
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('Notes', Icons.comment_outlined),
          const SizedBox(height: 12),
          _field(
            theme: theme,
            title: 'Comments (optional)',
            controller: c.commentaireCtrl,
            keyboardType: TextInputType.multiline,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5: Action & Submit
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep5(ThemeData theme, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Next Action', Icons.send_rounded),
          const SizedBox(height: 12),
          // Action dropdown
          Obx(() => DropdownButtonFormField<String>(
                value: _getValidAction(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Next Action is required' : null,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Next Action'),
                items: actionLabels.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(children: [
                            Icon(kActionIcon(e.key),
                                size: 16,
                                color: kActionColor(e.key)),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) =>
                    c.selectedAction.value = v,
              )),
          // File attachment
          Obx(() {
            if (c.selectedAction.value == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attachment (optional)',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kCrmText)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickActionFile,
                    icon: const Icon(Icons.attach_file_rounded,
                        size: 16),
                    label: Text(actionFileName ?? 'Choose file',
                        style: GoogleFonts.inter(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kCrmPrimary,
                        side: const BorderSide(
                            color: kCrmPrimary, width: 1.2)),
                  ),
                  if (actionFileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: kCrmSuccess),
                        const SizedBox(width: 4),
                        Text(actionFileName!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: kCrmSuccess)),
                      ]),
                    ),
                ],
              ),
            );
          }),
          // Devis + BC sections (edit mode only)
          if (_projectId != null) ...[
            const SizedBox(height: 24),
            _sectionTitle('Quotation', Icons.description_rounded),
            const SizedBox(height: 12),
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
              onUploaded: _refreshCardColors,
            ),
            const SizedBox(height: 16),
            _sectionTitle('Purchase Order', Icons.shopping_cart_rounded),
            const SizedBox(height: 12),
            BonDeCommandeFormSection(
              projectId: _projectId!,
              devisIsValid: _devisIsValid,
              onUploaded: _refreshCardColors,
            ),
            const SizedBox(height: 16),
            // CRM Timeline shortcut
            OutlinedButton.icon(
              onPressed: () =>
                  context.go('/forms/project-timeline?projectId=$_projectId'),
              icon: const Icon(Icons.timeline_rounded, size: 16),
              label: Text('View CRM Timeline',
                  style: GoogleFonts.inter(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: kCrmPrimary,
                  side: const BorderSide(color: kCrmPrimary)),
            ),
          ],
          const SizedBox(height: 32),
          // Summary card
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kCrmPrimary.withOpacity(0.06),
            kCrmSecondary.withOpacity(0.04)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmPrimary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.summarize_rounded,
              size: 16, color: kCrmPrimary),
          const SizedBox(width: 8),
          Text('Summary',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kCrmPrimary)),
        ]),
        const SizedBox(height: 10),
        Obx(() {
          final nom  = c.nomProjet.text.trim();
          final type = c.projectModele.value;
          final action = c.selectedAction.value ?? '—';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('Project', nom.isEmpty ? '(not set)' : nom),
              _summaryRow('Type', type),
              _summaryRow('Next Action', action),
              if (_projectId != null)
                _summaryRow('Mode', 'Editing existing project'),
            ],
          );
        }),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text('$label:',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kCrmTextSub))),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kCrmText))),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // UI HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _typeChip(
      String label, String value, IconData icon, Color color) {
    return Obx(() {
      final selected = c.projectModele.value == value;
      return GestureDetector(
        onTap: () {
          c.onProjectModeleChanged(value);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : kCrmSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? color : kCrmBorder,
                width: selected ? 1.5 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: selected ? color : kCrmTextSub),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selected ? color : kCrmTextSub)),
          ]),
        ),
      );
    });
  }

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kCrmPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: kCrmPrimary),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kCrmText)),
      ]);

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _requiredTitle(theme, title, required: validator != null),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: inputDecoration(context, hintText: title),
        ),
      ]),
    );
  }

  Widget _dateField({
    required ThemeData theme,
    required String title,
    required TextEditingController controller,
    String? Function(String?)? validator,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _requiredTitle(theme, title, required: validator != null),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          readOnly: true,
          onTap: onTap,
          decoration: inputDecoration(context, hintText: 'Select date')
              .copyWith(
            suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: onTap),
          ),
        ),
      ]),
    );
  }

  Widget _datePickerField({
    required ThemeData theme,
    required String title,
    required TextEditingController controller,
    bool required = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _requiredTitle(theme, title, required: required),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: required
              ? (v) => c.requiredValidator(v, title)
              : null,
          readOnly: true,
          onTap: onTap,
          decoration: inputDecoration(context, hintText: 'Select date')
              .copyWith(
            suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: onTap),
          ),
        ),
      ]),
    );
  }

  Widget _statusDropdown(ThemeData theme) {
    final currentApiValue = c.statut.text.trim();
    final currentItem = _statusOptions.firstWhere(
        (e) => e['value'] == currentApiValue,
        orElse: () => _statusOptions.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _requiredTitle(theme, 'Project Status', required: true),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: currentItem['value'],
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Status is required' : null,
          decoration:
              inputDecoration(context, hintText: 'Choose a status'),
          items: _statusOptions
              .map((s) =>
                  DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
              .toList(),
          onChanged: (val) {
            c.statut.text = val ?? '';
            if (mounted) setState(() {});
          },
        ),
      ]),
    );
  }

  Widget _validationDropdown(ThemeData theme) {
    final currentApiValue = c.validationStatut.text.trim();
    final currentItem = _validationOptions.firstWhere(
        (e) => e['value'] == currentApiValue,
        orElse: () => _validationOptions.last);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _requiredTitle(theme, 'Validation Status', required: false),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: currentItem['value'],
          decoration: inputDecoration(context, hintText: 'Choose'),
          items: _validationOptions
              .map((s) =>
                  DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
              .toList(),
          onChanged: (val) {
            c.validationStatut.text = val ?? 'Non validé';
            if (mounted) setState(() {});
          },
        ),
      ]),
    );
  }

  Widget _requiredTitle(ThemeData theme, String title,
      {required bool required}) {
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700),
        children: [
          TextSpan(text: title),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _twoCols(
      {required bool isMobile,
      required Widget left,
      required Widget right}) {
    if (isMobile) return Column(children: [left, right]);
    return Row(children: [
      Expanded(child: left),
      const SizedBox(width: 10),
      Expanded(child: right),
    ]);
  }

  Widget _statusBanner({
    required Color color,
    required IconData icon,
    required String text,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
          if (trailing != null) ...[
            const SizedBox(height: 4),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildAddrSuggestionsDropdown(ThemeData theme) {
    final bg = Colors.white;
    Widget content;

    if (_addrSearching) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_addrSearchError != null) {
      content = Padding(
        padding: const EdgeInsets.all(14),
        child: Text(_addrSearchError!,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.black54)),
      );
    } else if (_addrSuggestions.isEmpty) {
      return const SizedBox.shrink();
    } else {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _addrSuggestions.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey[200]),
          itemBuilder: (_, i) {
            final r = _addrSuggestions[i];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.location_on, size: 18),
              title: Text(r.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
              onTap: () => _selectAddrSuggestion(r),
            );
          },
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: content,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIZARD HEADER — step indicators
// ══════════════════════════════════════════════════════════════════════════════
class _WizardHeader extends StatelessWidget {
  final List<_WizardStep> steps;
  final int currentStep;
  final String? projectId;

  const _WizardHeader({
    required this.steps,
    required this.currentStep,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCrmSurface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(children: [
            // Back to list
            InkWell(
              onTap: () => context.go('/pipeline'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  border: Border.all(color: kCrmBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 16, color: kCrmTextSub),
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                projectId == null ? 'New Project' : 'Edit Project',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kCrmText),
              ),
              Text(
                'Step ${currentStep + 1} of ${steps.length} — '
                '${steps[currentStep].title}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: kCrmTextSub),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // Step indicator strip
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: steps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 0),
            itemBuilder: (_, i) {
              final step     = steps[i];
              final done     = i < currentStep;
              final current  = i == currentStep;
              final color    = current
                  ? kCrmPrimary
                  : done
                      ? kCrmSuccess
                      : kCrmBorder;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 110,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: current
                                ? kCrmPrimary
                                : done
                                    ? kCrmSuccess
                                    : kCrmBorder.withOpacity(0.5),
                            shape: BoxShape.circle,
                            boxShadow: (current || done)
                                ? [
                                    BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: Icon(
                            done
                                ? Icons.check_rounded
                                : step.icon,
                            size: 16,
                            color: (current || done)
                                ? Colors.white
                                : kCrmTextSub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.title,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: current
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: current
                                ? kCrmPrimary
                                : done
                                    ? kCrmSuccess
                                    : kCrmTextSub,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Connector line
                  if (i < steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 20,
                        height: 2,
                        color: i < currentStep
                            ? kCrmSuccess
                            : kCrmBorder,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Container(height: 1, color: kCrmBorder),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIZARD NAV BAR — prev / next / submit
// ══════════════════════════════════════════════════════════════════════════════
class _WizardNavBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final VoidCallback onSubmitBack;
  final String? projectId;

  const _WizardNavBar({
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    required this.onSubmitBack,
    required this.projectId,
  });

  bool get _isLast => currentStep == totalSteps - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: kCrmSurface,
        border:
            const Border(top: BorderSide(color: kCrmBorder)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(children: [
        // Progress indicator
        Text(
          '${currentStep + 1} / $totalSteps',
          style: GoogleFonts.inter(
              fontSize: 12, color: kCrmTextSub),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              backgroundColor: kCrmBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(kCrmPrimary),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Back
        if (currentStep > 0) ...[
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: Text('Back',
                style: GoogleFonts.inter(fontSize: 13)),
            style: OutlinedButton.styleFrom(
                foregroundColor: kCrmTextSub,
                side: const BorderSide(color: kCrmBorder),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10)),
          ),
          const SizedBox(width: 10),
        ],
        // Next or Submit
        if (!_isLast)
          _gradientBtn(
              'Next', Icons.arrow_forward_rounded, onNext)
        else ...[
          _gradientBtn(
              projectId == null ? 'Create' : 'Update',
              Icons.check_rounded,
              onSubmit),
          if (projectId != null) ...[
            const SizedBox(width: 10),
            _gradientBtn('Update & Back',
                Icons.check_circle_outline_rounded, onSubmitBack,
                secondary: true),
          ],
        ],
      ]),
    );
  }

  Widget _gradientBtn(
      String label, IconData icon, VoidCallback onTap,
      {bool secondary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: secondary
              ? LinearGradient(colors: [
                  kCrmTextSub.withOpacity(0.15),
                  kCrmTextSub.withOpacity(0.08)
                ])
              : const LinearGradient(
                  colors: [kCrmPrimary, kCrmSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
          boxShadow: secondary
              ? null
              : [
                  BoxShadow(
                      color: kCrmPrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: secondary ? kCrmTextSub : Colors.white,
              size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: secondary ? kCrmTextSub : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}
