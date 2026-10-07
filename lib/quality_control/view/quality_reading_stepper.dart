// lib/quality_control/view/quality_reading_stepper.dart
//
// CONTRÔLE QUALITÉ — stepper HORIZONTAL des PRÉLÈVEMENTS (étapes) d'une fiche.
//
//   [ ✓ ① 08:00 ] ─── [ ✓ ② 11:00 ] ─── [ ③ 14:00 ● ] ─── [ ＋ Nouveau prélèvement ]
//
// Le stepper est UNIQUEMENT une navigation entre prélèvements : chaque étape est
// une carte compacte (numéro, heure, statut / résultat, paramètres
// contrôlés, non-conformités) — jamais un paramètre physique. Une seule
// étape est active (mise en évidence) : ses paramètres sont affichés sous le
// stepper par la fiche. La dernière carte est « + Nouveau prélèvement ». Défile
// horizontalement quand les étapes dépassent la largeur (tablette, mobile).
// Composant d'affichage pur : la fiche (écran) décide de ce qui se passe au
// clic.

import 'package:flutter/material.dart' hide Text;

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../model/quality_control_model.dart';
import 'quality_control_widgets.dart';
import '../quality_control_i18n.dart';

class QualityReadingStepper extends StatefulWidget {
  /// Prélèvements ENREGISTRÉS de la fiche, dans l'ordre des étapes.
  final List<QualityReading> readings;

  /// Prélèvement actif (null : l'étape non enregistrée).
  final String? selectedId;

  /// Heure de l'étape en cours de saisie, pas encore enregistrée (première
  /// étape d'une nouvelle fiche) — null s'il n'y en a pas.
  final String? pendingTime;

  /// Nombre de paramètres d'un prélèvement (étape non enregistrée).
  final int parameterCount;

  /// Couleur de la ligne (PROMESH bleu / PROBAR orange).
  final Color color;
  final bool busy;
  final ValueChanged<QualityReading> onOpen;

  /// null : aucun nouveau prélèvement possible (lecture seule) ; la carte
  /// « Nouveau prélèvement » est alors masquée. [newHint] : heure proposée, ou
  /// raison d'une carte désactivée.
  final VoidCallback? onNew;
  final bool newEnabled;
  final String? newHint;

  const QualityReadingStepper({
    super.key,
    required this.readings,
    required this.selectedId,
    required this.color,
    required this.onOpen,
    this.pendingTime,
    this.parameterCount = 0,
    this.busy = false,
    this.onNew,
    this.newEnabled = true,
    this.newHint,
  });

  @override
  State<QualityReadingStepper> createState() => _QualityReadingStepperState();
}

class _QualityReadingStepperState extends State<QualityReadingStepper> {
  static const _cardWidth = 156.0;
  static const _linkWidth = 30.0;

  final _scroll = ScrollController();

  @override
  void didUpdateWidget(QualityReadingStepper old) {
    super.didUpdateWidget(old);
    // Une étape vient d'être ajoutée : elle est amenée à l'écran.
    if (widget.readings.length > old.readings.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final w = widget;
    final cards = <Widget>[
      for (final r in w.readings)
        _StepCard(
          key: ValueKey('qc-reading-${r.id}'),
          number: r.step,
          time: r.readingTime,
          badge: r.badge,
          done: r.isValidated,
          controlled: r.controlledCount,
          total: r.totalCount,
          nonConform: r.nonConformCount,
          active: r.id == w.selectedId,
          color: w.color,
          width: _cardWidth,
          onTap: w.busy || r.id == w.selectedId ? null : () => w.onOpen(r),
        ),
      if (w.pendingTime != null)
        _StepCard(
          key: const ValueKey('qc-reading-new'),
          number: w.readings.length + 1,
          time: w.pendingTime!,
          badge: 'BROUILLON',
          done: false,
          controlled: 0,
          total: w.parameterCount,
          nonConform: 0,
          active: true,
          color: w.color,
          width: _cardWidth,
          note: 'Non enregistré',
        ),
      if (w.onNew != null) _newCard(),
    ];
    if (cards.isEmpty) return const QcEmptyState('Aucun prélèvement.', icon: Icons.schedule_rounded);

    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0)
                // Trait de liaison entre deux étapes.
                SizedBox(width: _linkWidth, child: Center(child: Container(height: 2, color: kCrmBorder))),
              cards[i],
            ],
          ]),
        ),
      ),
    );
  }

  /// Dernier élément du stepper : « + Nouveau prélèvement ».
  Widget _newCard() {
    final w = widget;
    final enabled = w.newEnabled && !w.busy;
    final tone = enabled ? w.color : kCrmTextSub;
    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('qc-new-reading'),
          onTap: enabled ? w.onNew : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: enabled ? w.color.withValues(alpha: 0.04) : kCrmBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: enabled ? w.color.withValues(alpha: 0.55) : kCrmBorder, width: 1.2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? w.color : kCrmBorder),
                child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text('Nouveau prélèvement',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: enabled ? kCrmText : kCrmTextSub)),
              if (w.newHint != null) ...[
                const SizedBox(height: 3),
                Text(w.newHint!,
                    maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tInter(fontSize: 11, fontWeight: FontWeight.w600, color: tone)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Carte compacte d'une étape : numéro (✓ une fois validée), heure, statut /
/// résultat, paramètres contrôlés, non-conformités.
class _StepCard extends StatelessWidget {
  final int number;
  final String time;
  final String badge;
  final bool done;
  final int controlled;
  final int total;
  final int nonConform;
  final bool active;
  final Color color;
  final double width;
  final String? note;
  final VoidCallback? onTap;

  const _StepCard({
    super.key,
    required this.number,
    required this.time,
    required this.badge,
    required this.done,
    required this.controlled,
    required this.total,
    required this.nonConform,
    required this.active,
    required this.color,
    required this.width,
    this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final (_, statusColor, _, _) = qcStatusStyle(badge);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.07) : kCrmSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? color : kCrmBorder, width: active ? 1.8 : 1),
              boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))] : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Pastille : numéro de l'étape, cochée une fois le prélèvement validé.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? color : (done ? statusColor.withValues(alpha: 0.14) : kCrmBg),
                    border: Border.all(color: active ? color : (done ? statusColor : kCrmBorder), width: 1.4),
                  ),
                  child: Text('$number', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: active ? Colors.white : kCrmText)),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text('ÉTAPE $number',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: active ? color : kCrmTextSub, letterSpacing: 0.6)),
                ),
                if (done) Icon(Icons.check_circle_rounded, size: 16, color: statusColor) else if (active) Icon(Icons.radio_button_checked_rounded, size: 15, color: color),
              ]),
              const SizedBox(height: 8),
              Text(time, style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 6),
              QcStatusBadge(badge, dense: true),
              const SizedBox(height: 6),
              Text('$controlled/$total contrôlés', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
              if (nonConform > 0)
                Text('$nonConform non conforme${nonConform > 1 ? 's' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kQcNonConformeText)),
              if (note != null)
                Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: kQcAVerifierText)),
            ]),
          ),
        ),
      ),
    );
  }
}
