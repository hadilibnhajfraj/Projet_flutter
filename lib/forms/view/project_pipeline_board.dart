// lib/forms/view/project_pipeline_board.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/pipeline_provider.dart';
import 'pipeline_theme.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Safe project ID: MongoDB may return `_id` instead of `id`.
String _projectId(Map<String, dynamic> p) =>
    (p['id'] ?? p['_id'] ?? '').toString();

// ── Board helpers ─────────────────────────────────────────────────────────────
// These read the canonical keys that ProjectPipelineModel.normalizeIntoMap()
// writes at load time. Each has a safe inline fallback in case normalization
// hasn't run (e.g. during an optimistic drag-drop update).

String _cardNom(Map<String, dynamic> p) {
  // normalizeIntoMap writes 'nomProjet'; fall through all raw variants too.
  for (final k in ['nomProjet', 'name', 'title', 'projectName']) {
    final v = p[k]?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return 'Sans nom';
}

String _cardOwner(Map<String, dynamic> p) {
  final name = p['ownerName']?.toString().trim() ?? '';
  if (name.isNotEmpty) return name;
  // Inline fallback if normalizeIntoMap hasn't run yet.
  final userNom = p['user_nom']?.toString().trim() ?? '';
  if (userNom.isNotEmpty) return userNom;
  final email = p['ownerEmail']?.toString().trim() ?? '';
  if (email.isNotEmpty) return email;
  return '';
}

String _cardOwnerEmail(Map<String, dynamic> p) =>
    p['ownerEmail']?.toString().trim() ?? '';

String _cardOwnerAvatar(Map<String, dynamic> p) =>
    p['ownerAvatar']?.toString().trim() ?? '';

/// Current CRM action stage label for the badge.
String _cardCurrentAction(Map<String, dynamic> p) {
  final a = p['currentAction']?.toString().trim() ?? '';
  if (a.isNotEmpty) return a;
  final s = p['computedStage']?.toString().trim() ?? '';
  return s;
}

// Keep the public name for backward compatibility (used in _DetailSheet).
String resolveProjectOwner(Map<String, dynamic> p) => _cardOwner(p);

// ══════════════════════════════════════════════════════════════════════════════
// BOARD — horizontal kanban layout
// ══════════════════════════════════════════════════════════════════════════════
class PipelineBoard extends StatelessWidget {
  final PipelineProvider provider;
  final Future<void> Function(Map<String, dynamic>, String) onMove;

  const PipelineBoard({
    super.key,
    required this.provider,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data   = provider.filtered;
      final stages = provider.stages;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...stages.map((stage) => _StageColumn(
                  stage: stage,
                  projects: data[stage.id] ?? [],
                  onMove: onMove,
                  provider: provider,
                )),
            // + Add Stage column
            Align(
              alignment: Alignment.topCenter,
              child: _AddStageButton(provider: provider),
            ),
          ],
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAGE COLUMN
// ══════════════════════════════════════════════════════════════════════════════
class _StageColumn extends StatefulWidget {
  final PipelineStage stage;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function(Map<String, dynamic>, String) onMove;
  final PipelineProvider provider;

  const _StageColumn({
    required this.stage,
    required this.projects,
    required this.onMove,
    required this.provider,
  });

  @override
  State<_StageColumn> createState() => _StageColumnState();
}

class _StageColumnState extends State<_StageColumn> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.stage.color;
    final count = widget.projects.length;

    return Container(
      width: 308,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Stage header ──────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: kCrmSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.28)),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(widget.stage.icon, color: color, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stage.label,
                        style: tInter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kCrmText),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$count project${count == 1 ? '' : 's'}',
                        style: tInter(
                            fontSize: 10, color: kCrmTextSub),
                      ),
                    ],
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '$count',
                    style: tInter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ),
                const SizedBox(width: 4),
                // Stage options menu
                _StageMenu(stage: widget.stage, provider: widget.provider),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Drop target ───────────────────────────────────────────────────
          Expanded(
            child: DragTarget<Map<String, dynamic>>(
              onWillAcceptWithDetails: (d) {
                if (d.data['computedStage'] == widget.stage.id) return false;
                setState(() => _dragOver = true);
                return true;
              },
              onAcceptWithDetails: (d) {
                setState(() => _dragOver = false);
                widget.onMove(d.data, widget.stage.id);
              },
              onLeave: (_) => setState(() => _dragOver = false),
              builder: (ctx, candidates, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(_dragOver ? 6 : 0),
                decoration: BoxDecoration(
                  color: _dragOver
                      ? color.withOpacity(0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: _dragOver
                      ? Border.all(color: color.withOpacity(0.5), width: 2)
                      : null,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ...widget.projects.map((p) => _DraggableCard(
                            project: p,
                            stageColor: color,
                          )),
                      if (widget.projects.isEmpty && !_dragOver)
                        _EmptyColumn(stage: widget.stage, color: color),
                      if (_dragOver) _DropIndicator(color: color),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAGE CONTEXT MENU
// ══════════════════════════════════════════════════════════════════════════════
class _StageMenu extends StatelessWidget {
  final PipelineStage stage;
  final PipelineProvider provider;

  const _StageMenu({required this.stage, required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: const Icon(Icons.more_vert_rounded,
          size: 16, color: kCrmTextSub),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      onSelected: (v) async {
        switch (v) {
          case 'rename':
            await _renameDialog(context);
            break;
          case 'color':
            await _colorDialog(context);
            break;
          case 'delete':
            await provider.removeStage(stage.id);
            break;
        }
      },
      itemBuilder: (_) => [
        _item('rename', Icons.edit_rounded, 'Rename'),
        _item('color', Icons.palette_rounded, 'Change Color'),
        if (!stage.isSystem) ...[
          const PopupMenuDivider(),
          _item('delete', Icons.delete_outline_rounded, 'Delete',
              color: kCrmDanger),
        ],
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
      value: v,
      child: Row(children: [
        Icon(icon, size: 15, color: color ?? kCrmTextSub),
        const SizedBox(width: 10),
        Text(label,
            style: tInter(
                fontSize: 13, color: color ?? kCrmText)),
      ]),
    );
  }

  Future<void> _renameDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: stage.label);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Stage',
            style: tInter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Stage name',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kCrmPrimary),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await provider.renameStage(stage.id, result);
    }
  }

  Future<void> _colorDialog(BuildContext context) async {
    Color picked = stage.color;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Choose Color',
              style: tInter(fontWeight: FontWeight.w700)),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: kStagePalette
                .map((c) => GestureDetector(
                      onTap: () => setS(() => picked = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: picked == c
                              ? Border.all(
                                  color: Colors.white, width: 3)
                              : null,
                          boxShadow: picked == c
                              ? [
                                  BoxShadow(
                                      color: c.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1)
                                ]
                              : null,
                        ),
                        child: picked == c
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kCrmPrimary),
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.recolorStage(stage.id, picked);
              },
              child: const Text('Apply',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD STAGE BUTTON (last column)
// ══════════════════════════════════════════════════════════════════════════════
class _AddStageButton extends StatelessWidget {
  final PipelineProvider provider;
  const _AddStageButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Container(
        width: 180,
        height: 56,
        margin: const EdgeInsets.only(top: 0),
        decoration: BoxDecoration(
          color: kCrmPrimary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: kCrmPrimary.withOpacity(0.3),
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: kCrmPrimary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: kCrmPrimary, size: 16),
            ),
            const SizedBox(width: 8),
            Text('Add Stage',
                style: tInter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kCrmPrimary)),
          ],
        ),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    Color selectedColor = const Color(0xFF6366F1);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kCrmPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_box_rounded,
                  color: kCrmPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Add New Stage',
                style: tInter(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Stage Name',
                  hintText: 'e.g. Qualification',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: kCrmPrimary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Stage Color',
                  style: tInter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kStagePalette
                    .map((c) => GestureDetector(
                          onTap: () => setS(() => selectedColor = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selectedColor == c
                                  ? Border.all(
                                      color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selectedColor == c
                                  ? [
                                      BoxShadow(
                                          color: c.withOpacity(0.5),
                                          blurRadius: 8)
                                    ]
                                  : null,
                            ),
                            child: selectedColor == c
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              // Preview
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selectedColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selectedColor.withOpacity(0.4)),
                ),
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                      valueListenable: nameCtrl,
                      builder: (_, val, __) => Text(
                        val.text.isEmpty ? 'Stage name preview' : val.text,
                        style: tInter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selectedColor),
                      )),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: tInter(color: kCrmTextSub))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kCrmPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await provider.addStage(
                    id: name,
                    label: name,
                    color: selectedColor);
              },
              child: Text('Add Stage',
                  style: tInter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DRAGGABLE WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class _DraggableCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final Color stageColor;

  const _DraggableCard({
    required this.project,
    required this.stageColor,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: project,
      delay: const Duration(milliseconds: 350),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 288,
          child: Transform.rotate(
            angle: 0.018,
            child: Opacity(
              opacity: 0.93,
              child: _ProjectCard(
                  project: project,
                  stageColor: stageColor,
                  isDragging: true),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
          opacity: 0.20,
          child: _ProjectCard(project: project, stageColor: stageColor)),
      child: _ProjectCard(project: project, stageColor: stageColor),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROJECT CARD  (modern, glassmorphism-style)
// ══════════════════════════════════════════════════════════════════════════════
class _ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final Color stageColor;
  final bool isDragging;

  const _ProjectCard({
    required this.project,
    required this.stageColor,
    this.isDragging = false,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _fmtShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('dd MMM').format(DateTime.parse(iso));
    } catch (_) {
      return iso.length > 10 ? iso.substring(0, 10) : iso;
    }
  }

  String _fmtFull(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p          = widget.project;
    final color      = widget.stageColor;
    final stage      = (p['computedStage'] ?? 'Visite') as String;
    final stageLabel = kCrmStageLabels[stage] ?? stage;
    final nom        = _cardNom(p);
    final cie        = (p['entreprise'] ?? '').toString();

    // Owner — values are guaranteed by normalizeIntoMap() at load time.
    final ownerName   = _cardOwner(p);
    final ownerEmail  = _cardOwnerEmail(p);
    final ownerAvatar = _cardOwnerAvatar(p);
    final actionBadge = _cardCurrentAction(p);

    // Success rate
    final pctRaw = p['pourcentageReussite'];
    final pct    = pctRaw is num
        ? pctRaw.toDouble()
        : double.tryParse(pctRaw?.toString() ?? '') ?? 0.0;

    // Actions
    final lastAction = p['lastAction'] as Map<String, dynamic>?;
    final allActions = (p['allActions'] as List? ?? []);
    final lastDate   = lastAction?['dateAction'] as String?;
    final lastType   = (lastAction?['typeAction'] ?? '').toString();
    final lastComment = (lastAction?['commentaire'] ?? '').toString();
    final createdAt  = (p['createdAt'] ?? p['dateCreation'] ?? '').toString();

    return GestureDetector(
      onTap: () => _showDetail(context, p),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: kCrmSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? color.withOpacity(0.5) : kCrmBorder,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? color.withOpacity(0.14)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _hovered ? 20 : 6,
                offset: Offset(0, _hovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top accent stripe ────────────────────────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.3)]),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title + popup menu ───────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nom,
                            style: tInter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kCrmText,
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: const Icon(Icons.more_vert_rounded,
                              size: 17, color: kCrmTextSub),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 8,
                          itemBuilder: (_) => [
                            _menuItem('edit',     Icons.edit_rounded,     'Edit Project'),
                            _menuItem('timeline', Icons.timeline_rounded,  'Timeline'),
                            const PopupMenuDivider(),
                            _menuItem('delete',   Icons.delete_outline_rounded,
                                'Delete', color: kCrmDanger),
                          ],
                          onSelected: (v) {
                            final pid = _projectId(p);
                            if (v == 'edit') {
                              context.go('/forms/project?id=$pid');
                            } else if (v == 'timeline') {
                              context.go(
                                  '/forms/project-timeline?projectId=$pid');
                            }
                          },
                        ),
                      ],
                    ),
                    // ── Company ──────────────────────────────────────────
                    if (cie.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.business_rounded,
                            size: 11, color: kCrmTextSub),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(cie,
                              style: tInter(
                                  fontSize: 11, color: kCrmTextSub),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    // ── Stage badge ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(kActionIcon(actionBadge.isNotEmpty ? actionBadge : stage),
                              size: 9, color: color),
                          const SizedBox(width: 4),
                          Text(
                            actionBadge.isNotEmpty
                                ? (kCrmStageLabels[actionBadge] ?? actionBadge)
                                : stageLabel,
                            style: tInter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color),
                          ),
                        ],
                      ),
                    ),
                    // ── Latest action ────────────────────────────────────
                    if (lastAction != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: kCrmBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kCrmBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: kActionColor(lastType)
                                        .withOpacity(0.12),
                                    borderRadius:
                                        BorderRadius.circular(5),
                                  ),
                                  child: Icon(
                                    kActionIcon(lastType),
                                    size: 10,
                                    color: kActionColor(lastType),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    lastType,
                                    style: tInter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: kActionColor(lastType)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _fmtShort(lastDate),
                                  style: tInter(
                                      fontSize: 9,
                                      color: kCrmTextSub),
                                ),
                              ],
                            ),
                            if (lastComment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                lastComment,
                                style: tInter(
                                    fontSize: 11,
                                    color: kCrmTextSub,
                                    height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    // ── Success rate ─────────────────────────────────────
                    if (pct > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Success Rate',
                              style: tInter(
                                  fontSize: 10, color: kCrmTextSub)),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: tInter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          backgroundColor: kCrmBorder,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                          minHeight: 5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // ── Owner + creation date ────────────────────────────
                    Row(
                      children: [
                        _ownerAvatar(ownerName, ownerAvatar, color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ownerName.isNotEmpty
                                    ? ownerName
                                    : ownerEmail.isNotEmpty
                                        ? ownerEmail
                                        : 'Utilisateur',
                                style: tInter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: (ownerName.isNotEmpty || ownerEmail.isNotEmpty)
                                        ? kCrmText
                                        : kCrmTextSub),
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Show email as secondary line only when we have
                              // a full name to show in the primary line.
                              if (ownerName.isNotEmpty && ownerEmail.isNotEmpty)
                                Text(
                                  ownerEmail,
                                  style: tInter(
                                      fontSize: 9,
                                      color: kCrmTextSub),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (createdAt.isNotEmpty) ...[
                          const Icon(Icons.calendar_today_rounded,
                              size: 10, color: kCrmTextSub),
                          const SizedBox(width: 3),
                          Text(_fmtFull(createdAt),
                              style: tInter(
                                  fontSize: 9, color: kCrmTextSub)),
                        ],
                      ],
                    ),
                    // ── Action counters ──────────────────────────────────
                    if (allActions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(height: 1, color: kCrmBorder),
                      const SizedBox(height: 8),
                      Row(children: [
                        _counter(Icons.bolt_rounded,
                            '${allActions.length} actions', kCrmPrimary),
                        const Spacer(),
                        // Online status dot (decorative)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: kCrmSuccess,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: kCrmSuccess.withOpacity(0.4),
                                    blurRadius: 4)
                              ]),
                        ),
                        const SizedBox(width: 4),
                        Text('Active',
                            style: tInter(
                                fontSize: 9, color: kCrmTextSub)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerAvatar(String name, String avatarUrl, Color fallbackColor) {
    if (avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              _initialsAvatar(name, fallbackColor),
          placeholder: (_, __) =>
              _initialsAvatar(name, fallbackColor),
        ),
      );
    }
    return _initialsAvatar(name, fallbackColor);
  }

  Widget _initialsAvatar(String name, Color color) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '?' : _initials(name),
          style: tInter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white),
        ),
      );

  Widget _counter(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.withOpacity(0.8)),
          const SizedBox(width: 3),
          Text(label,
              style:
                  tInter(fontSize: 10, color: kCrmTextSub)),
        ],
      );

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 15, color: color ?? kCrmTextSub),
        const SizedBox(width: 10),
        Text(label,
            style: tInter(
                fontSize: 13, color: color ?? kCrmText)),
      ]),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(project: p),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY COLUMN
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyColumn extends StatelessWidget {
  final PipelineStage stage;
  final Color color;

  const _EmptyColumn({required this.stage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withOpacity(0.14),
            style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 40, color: color.withOpacity(0.22)),
          const SizedBox(height: 10),
          Text(
            'No Projects Yet',
            style: tInter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.45)),
          ),
          const SizedBox(height: 4),
          Text('Drag a card here to move it',
              style: tInter(
                  fontSize: 10, color: kCrmTextSub)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DROP INDICATOR
// ══════════════════════════════════════════════════════════════════════════════
class _DropIndicator extends StatelessWidget {
  final Color color;
  const _DropIndicator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Text('Drop here',
                style: tInter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DETAIL BOTTOM SHEET  — Odoo-style activity timeline
// ══════════════════════════════════════════════════════════════════════════════
class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> project;
  const _DetailSheet({required this.project});

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy · HH:mm')
          .format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p          = project;
    final stage      = (p['computedStage'] ?? 'Visite') as String;
    final color      = kCrmStageColors[stage] ?? kCrmPrimary;
    final stageIcon  = kCrmStageIcons[stage] ?? Icons.folder_rounded;
    final nom        = _cardNom(p);
    final cie        = (p['entreprise'] ?? '').toString();
    // Owner — values guaranteed by normalizeIntoMap() at load time.
    final ownerName   = _cardOwner(p);
    final ownerAvatar = _cardOwnerAvatar(p);

    final pctRaw = p['pourcentageReussite'];
    final pct    = pctRaw is num
        ? pctRaw.toDouble()
        : double.tryParse(pctRaw?.toString() ?? '') ?? 0.0;

    final allActions = (p['allActions'] as List? ?? []);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: kCrmBorder,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(stageIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom,
                        style: tInter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: kCrmText)),
                    if (cie.isNotEmpty)
                      Text(cie,
                          style: tInter(
                              fontSize: 12, color: kCrmTextSub)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  final pid = _projectId(p);
                  Navigator.pop(context);
                  context.go('/forms/project-timeline?projectId=$pid');
                },
                icon: const Icon(Icons.timeline_rounded, size: 13),
                label: Text('Timeline', style: tInter(fontSize: 13)),
                style: TextButton.styleFrom(
                    foregroundColor: kCrmPrimary),
              ),
              TextButton.icon(
                onPressed: () {
                  final pid = _projectId(p);
                  Navigator.pop(context);
                  context.go('/forms/project?id=$pid');
                },
                icon: const Icon(Icons.edit_rounded, size: 13),
                label: Text('Edit', style: tInter(fontSize: 13)),
                style: TextButton.styleFrom(
                    foregroundColor: kCrmPrimary),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: kCrmTextSub),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Owner row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            if (ownerAvatar.isNotEmpty)
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: ownerAvatar,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      _fallbackAvatar(ownerName, color),
                ),
              )
            else
              _fallbackAvatar(ownerName, color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerName.isNotEmpty
                      ? ownerName
                      : _cardOwnerEmail(p).isNotEmpty
                          ? _cardOwnerEmail(p)
                          : 'Utilisateur',
                  style: tInter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (ownerName.isNotEmpty || _cardOwnerEmail(p).isNotEmpty)
                          ? kCrmText
                          : kCrmTextSub),
                ),
                if (ownerName.isNotEmpty && _cardOwnerEmail(p).isNotEmpty)
                  Text(
                    _cardOwnerEmail(p),
                    style: tInter(fontSize: 10, color: kCrmTextSub),
                  ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // Badges
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            _pill(kCrmStageLabels[stage] ?? stage, color),
            if (pct > 0)
              _pill('${pct.toStringAsFixed(0)}% success', kCrmSuccess),
            _pill('${allActions.length} actions', kCrmPrimary),
          ]),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(height: 1, color: kCrmBorder),
        ),
        // Timeline header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
          child: Row(children: [
            const Icon(Icons.timeline_rounded,
                size: 16, color: kCrmPrimary),
            const SizedBox(width: 8),
            Text('Activity Timeline',
                style: tInter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kCrmText)),
            const Spacer(),
            Text('${allActions.length} events',
                style: tInter(
                    fontSize: 11, color: kCrmTextSub)),
          ]),
        ),
        // Timeline list
        Expanded(
          child: allActions.isEmpty
              ? _emptyTimeline()
              : ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: allActions.length,
                  itemBuilder: (_, i) {
                    final a      = allActions[i] as Map<String, dynamic>;
                    final type   = (a['typeAction']   ?? '').toString();
                    final comment= (a['commentaire']  ?? '').toString();
                    final date   = _fmt(a['dateAction'] as String?);
                    final aColor = kActionColor(type);
                    final isLast = i == allActions.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // Spine
                          SizedBox(
                            width: 40,
                            child: Column(children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: aColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          aColor.withOpacity(0.3),
                                      width: 1.5),
                                ),
                                child: Icon(kActionIcon(type),
                                    size: 15, color: aColor),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                      width: 2,
                                      color: kCrmBorder),
                                ),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                  bottom: isLast ? 0 : 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kCrmBg,
                                borderRadius:
                                    BorderRadius.circular(12),
                                border:
                                    Border.all(color: kCrmBorder),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                              horizontal: 7,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: aColor
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(
                                                6),
                                      ),
                                      child: Text(type,
                                          style: tInter(
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: aColor)),
                                    ),
                                    const Spacer(),
                                    Icon(
                                        Icons.access_time_rounded,
                                        size: 10,
                                        color: kCrmTextSub),
                                    const SizedBox(width: 3),
                                    Text(date,
                                        style: tInter(
                                            fontSize: 10,
                                            color: kCrmTextSub)),
                                  ]),
                                  if (comment.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(comment,
                                        style: tInter(
                                            fontSize: 12,
                                            color: kCrmText,
                                            height: 1.45)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _fallbackAvatar(String name, Color color) {
    String initials = '?';
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: tInter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white)),
    );
  }

  Widget _pill(String label, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: tInter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      );

  Widget _emptyTimeline() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 52, color: kCrmBorder),
            const SizedBox(height: 14),
            Text('No activity yet',
                style: tInter(
                    fontSize: 15,
                    color: kCrmTextSub,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Actions will appear here',
                style: tInter(
                    fontSize: 12, color: kCrmBorder)),
          ],
        ),
      );
}
