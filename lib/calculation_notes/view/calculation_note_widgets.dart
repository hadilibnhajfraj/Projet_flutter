// Module « Notes de calcul » — composants partagés (liste, détail, formulaire,
// section du formulaire projet).

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/calculation_note.dart';
import '../service/calculation_note_service.dart';

/// Traduction (clé française → anglais via assets/lang/en.json) ; la clé
/// elle-même si les traductions ne sont pas chargées.
String nt(BuildContext context, String key) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations)?.translate(key) ?? key;

void showNoteSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? Colors.red.shade700 : kCrmSuccess,
  ));
}

/// Sélection de documents (PDF, DOC, DOCX, XLS, XLSX) — le serveur revérifie
/// le contenu réel de chaque fichier.
Future<List<PendingNoteDocument>> pickNoteDocuments() async {
  final r = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.custom,
    allowedExtensions: kNoteAllowedExtensions,
  );
  if (r == null) return const [];
  return r.files
      .where((f) => f.bytes != null && kNoteAllowedExtensions.contains((f.extension ?? '').toLowerCase()))
      .map((f) => PendingNoteDocument(name: f.name, bytes: f.bytes!))
      .toList();
}

class NoteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const NoteCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: kCrmSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCrmBorder),
        ),
        child: child,
      );
}

class NoteSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const NoteSectionTitle({super.key, required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: kCrmPrimary),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText))),
        if (trailing != null) trailing!,
      ]);
}

class NoteFileIcon extends StatelessWidget {
  final String extension;
  final double size;
  const NoteFileIcon({super.key, required this.extension, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final v = noteFileVisual(extension);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: v.color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Icon(v.icon, color: v.color, size: size * 0.55),
    );
  }
}

/// Document enregistré : nom, taille, date, auteur, commentaire, actions.
class NoteDocumentTile extends StatelessWidget {
  final NoteDocument doc;
  final VoidCallback? onEditComment;
  const NoteDocumentTile({super.key, required this.doc, this.onEditComment});

  @override
  Widget build(BuildContext context) {
    final meta = [
      doc.extension.toUpperCase(),
      formatNoteFileSize(doc.sizeBytes),
      formatNoteDate(doc.createdAt, withTime: true),
      if (doc.uploadedBy != null) doc.uploadedBy!.name,
    ].join(' · ');
    return Container(
      key: ValueKey('note-doc-${doc.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NoteFileIcon(extension: doc.extension),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(doc.originalName, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w700, color: kCrmText)),
              NoteTypeChip(type: doc.documentType),
              if (doc.isComplementary) const NoteOriginChip(),
            ]),
            const SizedBox(height: 2),
            Text(meta, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
            const SizedBox(height: 6),
            Text(
              doc.commentaire ?? nt(context, 'Aucun commentaire'),
              style: tInter(fontSize: 12.5, color: doc.commentaire == null ? kCrmTextSub : kCrmText, fontStyle: doc.commentaire == null ? FontStyle.italic : null),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Wrap(spacing: 2, children: [
          IconButton(
            key: ValueKey('note-doc-view-${doc.id}'),
            tooltip: nt(context, 'Consulter'),
            icon: const Icon(Icons.visibility_outlined, size: 19, color: kCrmPrimary),
            onPressed: () => showNoteDocumentPreview(context, doc),
          ),
          IconButton(
            key: ValueKey('note-doc-download-${doc.id}'),
            tooltip: nt(context, 'Télécharger'),
            icon: const Icon(Icons.download_rounded, size: 19, color: kCrmSuccess),
            onPressed: () => downloadNoteDocument(context, doc),
          ),
          if (onEditComment != null)
            IconButton(
              key: ValueKey('note-doc-comment-${doc.id}'),
              tooltip: nt(context, 'Modifier le document'),
              icon: const Icon(Icons.edit_note_rounded, size: 20, color: kCrmInfo),
              onPressed: onEditComment,
            ),
        ]),
      ]),
    );
  }
}

Future<void> downloadNoteDocument(BuildContext context, NoteDocument doc) async {
  try {
    await CalculationNoteService.instance.download(doc);
  } catch (e) {
    if (context.mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
  }
}

/// Aperçu : PDF affiché dans l'application ; Word / Excel → téléchargement
/// (le navigateur ne sait pas les afficher).
Future<void> showNoteDocumentPreview(BuildContext context, NoteDocument doc) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              NoteFileIcon(extension: doc.extension, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(doc.originalName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText))),
              TextButton.icon(
                onPressed: () => downloadNoteDocument(ctx, doc),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(nt(ctx, 'Télécharger')),
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: doc.isPdf
                ? FutureBuilder<Uint8List>(
                    future: CalculationNoteService.instance.fetchBytes(doc, inline: true),
                    builder: (c, s) {
                      if (s.hasError) return Padding(padding: const EdgeInsets.all(32), child: Text(noteErrorMessage(s.error!)));
                      if (!s.hasData) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
                      return SizedBox(
                        height: 640,
                        child: PdfPreview(
                          build: (_) async => s.data!,
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                          allowSharing: false,
                          pdfFileName: doc.originalName,
                        ),
                      );
                    },
                  )
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      NoteFileIcon(extension: doc.extension, size: 64),
                      const SizedBox(height: 14),
                      Text('${doc.extension.toUpperCase()} · ${formatNoteFileSize(doc.sizeBytes)}', style: tInter(fontSize: 13, color: kCrmTextSub)),
                      const SizedBox(height: 8),
                      Text(nt(ctx, 'Aperçu disponible pour les PDF uniquement. Téléchargez le document pour l’ouvrir.'), textAlign: TextAlign.center, style: tInter(fontSize: 13, color: kCrmTextSub)),
                      if (doc.commentaire != null) ...[
                        const SizedBox(height: 14),
                        Text(doc.commentaire!, textAlign: TextAlign.center, style: tInter(fontSize: 13, color: kCrmText)),
                      ],
                    ]),
                  ),
          ),
        ]),
      ),
    ),
  );
}

class NoteTypeChip extends StatelessWidget {
  final String? type;
  const NoteTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == null ? kCrmTextSub : kCrmPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(nt(context, type == null ? 'Non précisé' : kNoteDocumentTypes[type] ?? type!), style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Badge « Complémentaire » (document déposé par l'utilisateur affecté).
class NoteOriginChip extends StatelessWidget {
  const NoteOriginChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: kCrmInfo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(nt(context, 'Complémentaire'), style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0E7490))),
      );
}

/// Aperçu d'un PDF pas encore envoyé (octets locaux).
Future<void> showPendingNotePreview(BuildContext context, PendingNoteDocument doc) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              NoteFileIcon(extension: doc.extension, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
            ]),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 640,
            child: PdfPreview(
              build: (_) async => Uint8List.fromList(doc.bytes),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowSharing: false,
              pdfFileName: doc.name,
            ),
          ),
        ]),
      ),
    ),
  );
}

/// Libellé visible au-dessus d'un champ (étoile rouge si obligatoire).
class NoteFieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;
  const NoteFieldLabel({super.key, required this.label, required this.child, this.required = false});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: label, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
          if (required) TextSpan(text: ' *', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmDanger)),
        ])),
        const SizedBox(height: 6),
        child,
      ]);
}

/// Décoration compacte des champs du module (libellé porté par NoteFieldLabel).
InputDecoration noteInputDecoration({String? hint, Widget? prefixIcon, Widget? suffixIcon, bool readOnly = false, String? errorText}) => InputDecoration(
      hintText: hint,
      hintStyle: tInter(fontSize: 13, color: kCrmTextSub),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorText: errorText,
      isDense: true,
      filled: true,
      fillColor: readOnly ? kCrmBg : kCrmSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCrmBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCrmBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCrmPrimary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCrmDanger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCrmDanger, width: 1.5)),
    );

/// Option d'une liste avec recherche.
class NoteSelectOption {
  final String id;
  final String label;
  final String? subtitle;
  const NoteSelectOption({required this.id, required this.label, this.subtitle});
}

/// Liste déroulante avec recherche (ouvre une fenêtre de sélection filtrable).
/// [actionLabel] : action supplémentaire en tête de liste (ex. « + Créer un
/// nouveau projet ») ; le champ renvoie alors [onAction].
class NoteSearchSelectField extends FormField<String> {
  NoteSearchSelectField({
    super.key,
    required String title,
    required List<NoteSelectOption> options,
    required ValueChanged<String> onChanged,
    String? value,
    String hint = '',
    IconData icon = Icons.search_rounded,
    bool enabled = true,
    String? requiredMessage,
    String? actionLabel,
    VoidCallback? onAction,
    // Retrait de la sélection (ex. « Affecter à ») — bouton × dans le champ.
    VoidCallback? onClear,
    String clearTooltip = 'Retirer',
  }) : super(
          initialValue: value,
          enabled: enabled,
          validator: (v) => requiredMessage != null && (v == null || v.isEmpty) ? requiredMessage : null,
          builder: (state) {
            final selected = options.where((o) => o.id == value).firstOrNull;
            Future<void> open() async {
              final r = await showDialog<String>(
                context: state.context,
                builder: (_) => _NoteSearchDialog(title: title, options: options, selectedId: value, actionLabel: actionLabel),
              );
              if (r == _kNoteSelectAction) {
                onAction?.call();
              } else if (r != null) {
                state.didChange(r);
                onChanged(r);
              }
            }

            return InkWell(
              onTap: enabled ? open : null,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                isEmpty: selected == null,
                decoration: noteInputDecoration(
                  hint: hint,
                  readOnly: !enabled,
                  prefixIcon: Icon(icon, size: 18, color: kCrmTextSub),
                  suffixIcon: onClear != null && selected != null && enabled
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            key: const ValueKey('note-select-clear'),
                            tooltip: clearTooltip,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18, color: kCrmTextSub),
                            onPressed: () {
                              state.didChange(null);
                              onClear();
                            },
                          ),
                          const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.expand_more_rounded, color: kCrmText)),
                        ])
                      : Icon(Icons.expand_more_rounded, color: enabled ? kCrmText : kCrmTextSub),
                  errorText: state.errorText,
                ),
                child: selected == null
                    ? null
                    : Text(selected.subtitle == null ? selected.label : '${selected.label} — ${selected.subtitle}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13.5, color: enabled ? kCrmText : kCrmTextSub)),
              ),
            );
          },
        );

  @override
  FormFieldState<String> createState() => _NoteSearchSelectState();
}

class _NoteSearchSelectState extends FormFieldState<String> {
  @override
  void didUpdateWidget(covariant NoteSearchSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Valeur imposée par le parent (ex. projet créé puis sélectionné).
    if (widget.initialValue != value) setValue(widget.initialValue);
  }
}

const _kNoteSelectAction = '__action__';

class _NoteSearchDialog extends StatefulWidget {
  final String title;
  final List<NoteSelectOption> options;
  final String? selectedId;
  final String? actionLabel;
  const _NoteSearchDialog({required this.title, required this.options, this.selectedId, this.actionLabel});

  @override
  State<_NoteSearchDialog> createState() => _NoteSearchDialogState();
}

class _NoteSearchDialogState extends State<_NoteSearchDialog> {
  String _q = '';

  static String _norm(String s) {
    const from = 'àâäáãçéèêëíìîïñóòôöõúùûüÿ';
    const to = 'aaaaaceeeeiiiinooooouuuuy';
    final l = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in l.split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final q = _norm(_q.trim());
    final list = q.isEmpty ? widget.options : widget.options.where((o) => _norm('${o.label} ${o.subtitle ?? ''}').contains(q)).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('note-select-search'),
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: noteInputDecoration(hint: nt(context, 'Rechercher…'), prefixIcon: const Icon(Icons.search_rounded, size: 18)),
            ),
          ),
          if (widget.actionLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: OutlinedButton.icon(
                key: const ValueKey('note-select-action'),
                onPressed: () => Navigator.of(context).pop(_kNoteSelectAction),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(widget.actionLabel!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCrmPrimary,
                  side: const BorderSide(color: kCrmPrimary),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Flexible(
            child: list.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Text(nt(context, 'Aucun résultat'), textAlign: TextAlign.center, style: tInter(color: kCrmTextSub)))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final o = list[i];
                      final sel = o.id == widget.selectedId;
                      return ListTile(
                        key: ValueKey('note-select-option-${o.id}'),
                        dense: true,
                        selected: sel,
                        selectedTileColor: kCrmPrimary.withValues(alpha: 0.06),
                        title: Text(o.label, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w600, color: kCrmText)),
                        subtitle: o.subtitle == null ? null : Text(o.subtitle!, style: tInter(fontSize: 12, color: kCrmTextSub)),
                        trailing: sel ? const Icon(Icons.check_rounded, color: kCrmPrimary, size: 18) : null,
                        onTap: () => Navigator.of(context).pop(o.id),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// Documents choisis mais pas encore envoyés : petites cartes (icône, nom
/// réel du fichier, format et taille, aperçu PDF, suppression) avec le type
/// et le commentaire propres à chaque document.
/// [showAddTile] : tuile « Ajouter un document » (sélecteur de fichiers) —
/// désactivée quand une zone de dépôt alimente déjà la liste.
class PendingNoteDocumentsEditor extends StatelessWidget {
  final List<PendingNoteDocument> documents;
  final VoidCallback onChanged;
  final bool enabled;
  final bool showAddTile;
  const PendingNoteDocumentsEditor({super.key, required this.documents, required this.onChanged, this.enabled = true, this.showAddTile = true});

  Future<void> _add() async {
    final picked = await pickNoteDocuments();
    if (picked.isEmpty) return;
    documents.addAll(picked);
    onChanged();
  }

  Widget _card(BuildContext context, int i) {
    final d = documents[i];
    final type = NoteFieldLabel(
      label: nt(context, 'Type de document'),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('pending-doc-type-$i-${d.name}'),
        initialValue: d.documentType,
        isExpanded: true,
        decoration: noteInputDecoration(),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(nt(context, 'Non précisé'), style: tInter(fontSize: 13.5, color: kCrmTextSub))),
          for (final e in kNoteDocumentTypes.entries) DropdownMenuItem<String?>(value: e.key, child: Text(nt(context, e.value), style: tInter(fontSize: 13.5))),
        ],
        onChanged: enabled ? (v) => d.documentType = v : null,
      ),
    );
    final comment = NoteFieldLabel(
      label: nt(context, 'Commentaire'),
      child: TextField(
        key: ValueKey('pending-doc-comment-$i'),
        controller: d.comment,
        enabled: enabled,
        minLines: 2,
        maxLines: 4,
        maxLength: 4000,
        decoration: noteInputDecoration(hint: nt(context, 'Observations, explications ou informations relatives au document (facultatif)')).copyWith(counterText: ''),
      ),
    );
    return Container(
      key: ValueKey('pending-doc-$i'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          NoteFileIcon(extension: d.extension, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText)),
              Text('${d.extension.toUpperCase()} · ${formatNoteFileSize(d.bytes.length)}', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
            ]),
          ),
          if (d.extension == 'pdf')
            IconButton(
              key: ValueKey('pending-doc-preview-$i'),
              tooltip: nt(context, 'Aperçu'),
              icon: const Icon(Icons.visibility_outlined, size: 19, color: kCrmPrimary),
              onPressed: () => showPendingNotePreview(context, d),
            ),
          if (enabled)
            IconButton(
              key: ValueKey('pending-doc-remove-$i'),
              tooltip: nt(context, 'Retirer ce document'),
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: kCrmDanger),
              onPressed: () {
                documents.removeAt(i);
                onChanged();
              },
            ),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 520
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: type), const SizedBox(width: 12), Expanded(flex: 3, child: comment)])
              : Column(children: [type, const SizedBox(height: 10), comment]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < documents.length; i++) ...[_card(context, i), const SizedBox(height: 10)],
      if (showAddTile)
        InkWell(
          key: const ValueKey('pending-doc-add'),
          onTap: enabled ? _add : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: kCrmPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kCrmPrimary.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              const Icon(Icons.upload_file_rounded, color: kCrmPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(documents.isEmpty ? nt(context, 'Ajouter un document') : nt(context, 'Ajouter un autre document'),
                      style: tInter(fontSize: 13.5, fontWeight: FontWeight.w700, color: kCrmPrimary)),
                  Text(nt(context, 'Formats acceptés : PDF, DOC, DOCX, XLS, XLSX.'), style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}

// ── Validation ───────────────────────────────────────────────────────────

/// Couleur d'un statut : orange (en attente), vert (validée), rouge
/// (refusée), gris (annulée).
Color noteStatusColor(String status) {
  switch (status) {
    case kNoteStatusValidated:
      return const Color(0xFF16A34A);
    case kNoteStatusRejected:
      return const Color(0xFFDC2626);
    case kNoteStatusCancelled:
      return const Color(0xFF64748B);
    default:
      return const Color(0xFFEA580C);
  }
}

IconData noteStatusIcon(String status) {
  switch (status) {
    case kNoteStatusValidated:
      return Icons.verified_rounded;
    case kNoteStatusRejected:
      return Icons.cancel_rounded;
    case kNoteStatusCancelled:
      return Icons.block_rounded;
    default:
      return Icons.hourglass_top_rounded;
  }
}

class NoteStatusBadge extends StatelessWidget {
  final String status;
  final bool dense;
  const NoteStatusBadge({super.key, required this.status, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final c = noteStatusColor(status);
    return Container(
      key: ValueKey('note-status-$status'),
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(noteStatusIcon(status), size: dense ? 12 : 14, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(nt(context, kNoteStatusLabels[status] ?? status),
              overflow: TextOverflow.ellipsis, style: tInter(fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700, color: c)),
        ),
      ]),
    );
  }
}

/// Confirmation avant validation.
Future<bool> confirmNoteValidation(BuildContext context, String reference) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 36),
      title: Text(nt(ctx, 'Valider la note')),
      content: Text('${nt(ctx, 'Confirmez-vous la validation de la note')} $reference ? ${nt(ctx, 'Le créateur et le demandeur seront notifiés. Cette décision est définitive.')}'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(nt(ctx, 'Annuler'))),
        ElevatedButton.icon(
          key: const ValueKey('note-validate-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(nt(ctx, 'Valider la note')),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Motif obligatoire (refus, annulation) : le bouton de confirmation reste
/// inactif tant que le motif est vide (le backend le revérifie).
Future<String?> askNoteReason(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  required Color color,
  required String keyPrefix,
  String? intro,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final text = ctrl.text.trim();
        final valid = text.length >= 3;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (intro != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(intro, style: tInter(fontSize: 13, color: kCrmTextSub))),
              NoteFieldLabel(
                label: label,
                required: true,
                child: TextField(
                  key: ValueKey('$keyPrefix-reason'),
                  controller: ctrl,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 4000,
                  onChanged: (_) => setD(() {}),
                  decoration: noteInputDecoration(
                    hint: nt(ctx, 'Expliquez le problème ou le motif…'),
                    errorText: text.isEmpty ? nt(ctx, 'Le motif est obligatoire.') : (!valid ? nt(ctx, 'Motif trop court.') : null),
                  ).copyWith(counterText: ''),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(nt(ctx, 'Annuler'))),
            ElevatedButton(
              key: ValueKey('$keyPrefix-confirm'),
              onPressed: valid ? () => Navigator.of(ctx).pop(text) : null,
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}

/// Libellé d'une entrée d'historique.
String noteHistoryLabel(BuildContext context, NoteHistoryEntry h) {
  switch (h.action) {
    case 'NOTE_CREATED':
      return nt(context, 'Note créée');
    case 'NOTE_UPDATED':
      return nt(context, 'Informations modifiées');
    case 'NOTE_ASSIGNED':
      return '${nt(context, 'Affectée à')} ${h.details['toEmail'] ?? ''}';
    case 'ASSIGNMENT_CHANGED':
      return '${nt(context, 'Affectation modifiée')} : ${h.details['fromEmail'] ?? '—'} → ${h.details['toEmail'] ?? '—'}';
    case 'ASSIGNMENT_REMOVED':
      return '${nt(context, 'Affectation retirée')} : ${h.details['fromEmail'] ?? ''}';
    case 'NOTE_SUBMITTED':
      return '${nt(context, 'Transmise pour validation à')} ${h.details['validatorEmail'] ?? ''}';
    case 'NOTE_RESUBMITTED':
      return '${nt(context, 'Soumise de nouveau à')} ${h.details['validatorEmail'] ?? ''}';
    case 'NOTE_VALIDATED':
      final c = h.details['commentaire'];
      return c == null ? nt(context, 'Note validée') : '${nt(context, 'Note validée')} : $c';
    case 'NOTE_REJECTED':
      return '${nt(context, 'Note refusée')} : ${h.details['commentaire'] ?? ''}';
    case 'NOTE_CANCELLED':
      return '${nt(context, 'Note annulée')} : ${h.details['motif'] ?? ''}';
    case 'DOCUMENT_ADDED':
      return '${nt(context, h.details['origin'] == kNoteDocOriginComplementary ? 'Document complémentaire ajouté' : 'Document ajouté')} : ${h.details['originalName'] ?? ''}';
    case 'COMPLEMENTARY_DOCUMENTS_ADDED':
      return '${nt(context, 'Documents complémentaires déposés par l’utilisateur affecté')} (${h.details['count'] ?? ''})';
    case 'DOCUMENT_COMMENT_UPDATED':
      return '${nt(context, 'Commentaire modifié')} : ${h.details['originalName'] ?? ''}';
    case 'DOCUMENT_UPDATED':
      return '${nt(context, 'Document modifié')} : ${h.details['originalName'] ?? ''}';
    default:
      return h.action;
  }
}
