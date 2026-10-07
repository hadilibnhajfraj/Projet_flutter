// lib/quality_control/view/quality_control_export.dart
//
// Bouton « Exporter » (Excel / PDF / CSV) du module Contrôle Qualité :
// fichier généré par le BACKEND avec les filtres de l'écran, puis
// téléchargé (navigateur).

import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../model/quality_control_comparison.dart';
import '../service/qc_file_saver.dart';
import 'quality_control_widgets.dart';
import '../quality_control_i18n.dart';

const kQcExportFormats = <(String, String, IconData)>[
  ('xlsx', 'Excel (.xlsx)', Icons.table_chart_outlined),
  ('pdf', 'PDF (A4)', Icons.picture_as_pdf_outlined),
  ('csv', 'CSV (;)', Icons.description_outlined),
];

class QcExportButton extends StatelessWidget {
  final String label;
  final List<String> formats;
  final bool busy;
  final bool enabled;
  final void Function(String format) onSelected;

  const QcExportButton({
    super.key,
    this.label = 'Exporter',
    this.formats = const ['xlsx', 'pdf', 'csv'],
    this.busy = false,
    this.enabled = true,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final active = enabled && !busy;
    return PopupMenuButton<String>(
      tooltip: qcT(label),
      enabled: active,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (value, text, icon) in kQcExportFormats)
          if (formats.contains(value))
            PopupMenuItem(
              value: value,
              height: 40,
              child: Row(children: [
                Icon(icon, size: 18, color: kCrmTextSub),
                const SizedBox(width: 10),
                Text(text, style: tInter(fontSize: 13, color: kCrmText)),
              ]),
            ),
      ],
      child: IgnorePointer(
        child: FilledButton.icon(
          onPressed: active ? () {} : null,
          style: FilledButton.styleFrom(backgroundColor: kQualityControlColor),
          icon: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(busy ? 'Export…' : label),
        ),
      ),
    );
  }
}

/// Génère (backend) puis enregistre le fichier ; message d'erreur sinon.
Future<void> runQcExport(
  BuildContext context, {
  required Future<Uint8List> Function() fetch,
  required String fileName,
  required String format,
}) async {
  try {
    final bytes = await fetch();
    await saveQcFile(bytes, fileName, kQcExportMime[format] ?? 'application/octet-stream');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export généré : $fileName'), backgroundColor: kCrmSuccess));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export impossible : $e'), backgroundColor: kCrmDanger));
    }
  }
}
