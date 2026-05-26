// lib/forms/view/add_project_action_screen.dart
//
// Stand-alone "Add CRM Action" sheet.
// Uses the CRM design system (pipeline_theme.dart / crm_widgets.dart).
// All date validation is done client-side BEFORE the API call.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/services/project_action_api.dart';

class AddProjectActionScreen extends StatefulWidget {
  final String projectId;
  final String initialType;

  const AddProjectActionScreen({
    super.key,
    required this.projectId,
    required this.initialType,
  });

  @override
  State<AddProjectActionScreen> createState() =>
      _AddProjectActionScreenState();
}

class _AddProjectActionScreenState extends State<AddProjectActionScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  late String _type;
  final _commentaire = TextEditingController();
  DateTime? _relance;
  dynamic _selectedFile; // PlatformFile (web) or File (native)
  String? _fileName;

  bool _submitting = false;

  // ── Action types available in the CRM pipeline ────────────────────────────
  static const _actionTypes = [
    'Visite',
    'Plan technique',
    'Echantillonnage',
    'Devis envoyé',
    'Negociation',
    'Relance',
    'Commande gagnée',
    'Commande perdue',
    'Fidelisation',
  ];

  @override
  void initState() {
    super.initState();
    _type = _actionTypes.contains(widget.initialType)
        ? widget.initialType
        : _actionTypes.first;
  }

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  // ── Date picker — only future dates are selectable ────────────────────────
  Future<void> _pickDate() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      // Earliest selectable day is tomorrow — today/past are greyed out.
      firstDate: tomorrow,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      initialDate: _relance ?? tomorrow,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kCrmPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _relance = picked);
  }

  // ── File picker ───────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (result == null) return;
    setState(() {
      _fileName = result.files.first.name;
      _selectedFile = kIsWeb ? result.files.first : result.files.first;
    });
  }

  // ── Validation + submit ───────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_submitting) return;

    // Frontend validation — catches bad input before any network call.
    if (_relance == null) {
      _snack('Please select a follow-up date', error: false);
      return;
    }
    if (!_relance!.isAfter(DateTime.now())) {
      _snack('Follow-up date must be in the future', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ProjectActionApi.instance.createAction(
        projectId: widget.projectId,
        type: _type,
        commentaire: _commentaire.text.trim(),
        // Send ISO-8601 with time component — backend datetime comparison is
        // unambiguous: tomorrow at midnight local time is always > now.
        dateRelance: _relance!.toIso8601String(),
        file: _selectedFile,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Exception catch (e) {
      if (!mounted) return;
      _snack(_parseError(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: tInter(fontSize: 13, color: Colors.white)),
      backgroundColor: error ? kCrmDanger : kCrmPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _parseError(Object e) {
    final s = e.toString();
    // Try to surface the backend "message" from a DioException string.
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(s);
    return match?.group(1) ?? s;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: kCrmBg,
      appBar: AppBar(
        backgroundColor: kCrmSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: kCrmTextSub),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text('Add CRM Action',
            style: tInter(
                fontSize: 16, fontWeight: FontWeight.w700, color: kCrmText)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kCrmBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Action type ─────────────────────────────────────────────────
          _Label('Action Type', required: true),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: _inputDec('Select action type'),
            items: _actionTypes
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Row(children: [
                        Icon(kActionIcon(v),
                            size: 15, color: kActionColor(v)),
                        const SizedBox(width: 8),
                        Text(v, style: tInter(fontSize: 13, color: kCrmText)),
                        if (v == widget.initialType) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kCrmSuccess.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Suggested',
                                style: tInter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: kCrmSuccess)),
                          ),
                        ],
                      ]),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),

          const SizedBox(height: 20),

          // ── Commentaire ─────────────────────────────────────────────────
          _Label('Comment'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _commentaire,
            maxLines: 3,
            style: tInter(fontSize: 13, color: kCrmText),
            decoration: _inputDec('Add a note…'),
          ),

          const SizedBox(height: 20),

          // ── Follow-up date ──────────────────────────────────────────────
          _Label('Follow-up Date', required: true),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _relance != null ? kCrmPrimary : kCrmBorder),
                borderRadius: BorderRadius.circular(10),
                color: kCrmSurface,
              ),
              child: Row(children: [
                Icon(Icons.calendar_month_outlined,
                    size: 16,
                    color: _relance != null ? kCrmPrimary : kCrmTextSub),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _relance == null
                        ? 'Select a future date (earliest: ${DateFormat('dd/MM/yyyy').format(tomorrow)})'
                        : DateFormat('EEEE, dd MMM yyyy').format(_relance!),
                    style: tInter(
                        fontSize: 13,
                        color: _relance != null ? kCrmText : kCrmTextSub),
                  ),
                ),
                if (_relance != null)
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: kCrmSuccess),
              ]),
            ),
          ),
          // Validation hint shown when no date is selected.
          if (_relance == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: kCrmTextSub),
                const SizedBox(width: 4),
                Text('Must be tomorrow or later',
                    style: tInter(fontSize: 11, color: kCrmTextSub)),
              ]),
            ),

          const SizedBox(height: 20),

          // ── File attachment ─────────────────────────────────────────────
          _Label('Attachment (optional)'),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file_rounded, size: 16),
            label: Text(
              _fileName ?? 'Choose file (PDF, image…)',
              style: tInter(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCrmPrimary,
              side: const BorderSide(color: kCrmPrimary, width: 1.2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: kCrmSuccess),
                const SizedBox(width: 4),
                Flexible(
                    child: Text(_fileName!,
                        style:
                            tInter(fontSize: 12, color: kCrmSuccess))),
              ]),
            ),

          const SizedBox(height: 32),

          // ── Submit ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: _submitting
                ? const Center(
                    child: CircularProgressIndicator(color: kCrmPrimary))
                : FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text('Save Action',
                        style: tInter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    style: FilledButton.styleFrom(
                      backgroundColor: kCrmPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  // ── Shared decoration ─────────────────────────────────────────────────────
  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: tInter(fontSize: 13, color: kCrmTextSub),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kCrmBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kCrmBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kCrmPrimary, width: 1.5),
        ),
        filled: true,
        fillColor: kCrmSurface,
      );
}

// ── Field label ───────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final bool required;

  const _Label(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: tInter(
              fontSize: 12, fontWeight: FontWeight.w600, color: kCrmText),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                  text: ' *',
                  style: TextStyle(
                      color: kCrmDanger, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
