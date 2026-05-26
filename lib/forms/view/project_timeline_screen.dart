// lib/forms/view/project_timeline_screen.dart
//
// CRM Project Timeline — displays actions in reverse-chronological order.
// GetX controller owns the list; the screen uses Obx for reactive rendering.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dash_master_toolkit/core/config/api_config.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';

import '../controller/project_timeline_controller.dart';
import 'add_project_action_screen.dart';

class ProjectTimelineScreen extends StatefulWidget {
  final String projectId;

  const ProjectTimelineScreen({super.key, required this.projectId});

  @override
  State<ProjectTimelineScreen> createState() => _ProjectTimelineScreenState();
}

class _ProjectTimelineScreenState extends State<ProjectTimelineScreen> {
  // One controller per screen instance — deleted in dispose.
  late final ProjectTimelineController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<ProjectTimelineController>()
        ? Get.find<ProjectTimelineController>()
        : Get.put(ProjectTimelineController());
    _ctrl.loadActions(widget.projectId);
  }

  @override
  void dispose() {
    if (Get.isRegistered<ProjectTimelineController>()) {
      Get.delete<ProjectTimelineController>();
    }
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  Future<void> _openAddAction() async {
    // Suggest the next logical stage based on the latest action.
    String suggested = 'Visite';
    if (_ctrl.actions.isNotEmpty) {
      suggested = _nextAction(_ctrl.actions.first.typeAction) ??
          _ctrl.actions.first.typeAction;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectActionScreen(
          projectId: widget.projectId,
          initialType: suggested,
        ),
      ),
    );

    if (result == true) await _ctrl.loadActions(widget.projectId);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _deleteAction(String actionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete action',
            style: tInter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('This action cannot be undone.',
            style: tInter(fontSize: 13, color: kCrmTextSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: tInter(color: kCrmTextSub)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: tInter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiClient.instance.dio.delete('/projects/actions/$actionId');
      await _ctrl.loadActions(widget.projectId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete action')));
    }
  }

  // ── Reminder ───────────────────────────────────────────────────────────────
  Future<void> _openReminder(String actionId) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kCrmPrimary)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final msgCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Set Follow-up',
            style: tInter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.calendar_month_outlined,
                size: 16, color: kCrmPrimary),
            const SizedBox(width: 6),
            Text(DateFormat('EEEE, dd MMM yyyy').format(date),
                style: tInter(fontSize: 13, color: kCrmPrimary,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: msgCtrl,
            decoration: InputDecoration(
              hintText: 'Reminder note (optional)',
              hintStyle: tInter(fontSize: 13, color: kCrmTextSub),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: tInter(color: kCrmTextSub)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kCrmPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save', style: tInter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (saved != true) return;

    try {
      await ApiClient.instance.dio.post(
        '/projects/actions/$actionId/reminders',
        data: {
          'dateRelance': date.toIso8601String(),
          'message': msgCtrl.text.trim(),
        },
      );
      await _ctrl.loadActions(widget.projectId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save reminder')));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      appBar: AppBar(
        backgroundColor: kCrmSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kCrmTextSub),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/pipeline'),
        ),
        title: Text('CRM Timeline',
            style: tInter(
                fontSize: 16, fontWeight: FontWeight.w700, color: kCrmText)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/pipeline'),
              icon: const Icon(Icons.view_kanban_rounded, size: 15),
              label: Text('Pipeline', style: tInter(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kCrmPrimary,
                side: const BorderSide(color: kCrmPrimary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kCrmBorder),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAction,
        backgroundColor: kCrmPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Action',
            style: tInter(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Obx(() {
        if (_ctrl.loading.value) {
          return const Center(
              child: CircularProgressIndicator(color: kCrmPrimary));
        }

        if (_ctrl.error.value != null) {
          return _ErrorState(
            message: _ctrl.error.value!,
            onRetry: () => _ctrl.loadActions(widget.projectId),
          );
        }

        if (_ctrl.actions.isEmpty) {
          return _EmptyState(onAdd: _openAddAction);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: _ctrl.actions.length,
          itemBuilder: (_, i) => _ActionCard(
            action: _ctrl.actions[i],
            isFirst: i == 0,
            isLast: i == _ctrl.actions.length - 1,
            onDelete: () => _deleteAction(_ctrl.actions[i].id),
            onReminder: () => _openReminder(_ctrl.actions[i].id),
          ),
        );
      }),
    );
  }

  // ── Pipeline next-stage logic ──────────────────────────────────────────────
  static String? _nextAction(String current) {
    const map = {
      'Visite'         : 'Plan technique',
      'Plan technique' : 'Echantillonnage',
      'Echantillonnage': 'Devis envoyé',
      'Devis envoyé'   : 'Negociation',
      'Negociation'    : 'Commande gagnée',
      'Commande gagnée': 'Fidelisation',
    };
    return map[current];
  }
}

// ── Action card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final ProjectActionModel action;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onDelete;
  final VoidCallback onReminder;

  const _ActionCard({
    required this.action,
    required this.isFirst,
    required this.isLast,
    required this.onDelete,
    required this.onReminder,
  });

  @override
  Widget build(BuildContext context) {
    final color = kActionColor(action.typeAction);
    final date = _parseDate(action.dateAction);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Timeline rail ────────────────────────────────────────────────
        SizedBox(
          width: 48,
          child: Column(children: [
            Container(
              width: 2,
              height: isFirst ? 20 : null,
              color: isFirst ? Colors.transparent : kCrmBorder,
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(kActionIcon(action.typeAction),
                  size: 14, color: color),
            ),
            Expanded(
              child: Container(
                width: 2,
                color: isLast ? Colors.transparent : kCrmBorder,
              ),
            ),
          ]),
        ),

        // ── Card body ────────────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: kCrmSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kCrmBorder),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(action.typeAction,
                          style: tInter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kCrmText)),
                      const SizedBox(height: 2),
                      Text(
                        date != null
                            ? DateFormat('dd MMM yyyy • HH:mm').format(date)
                            : '—',
                        style:
                            tInter(fontSize: 11, color: kCrmTextSub),
                      ),
                    ]),
                  ),
                  // Status badge
                  if (action.statut != null)
                    _StatusBadge(action.statut!),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: kCrmTextSub),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                ]),
              ),

              // Comment
              if (action.commentaire != null &&
                  action.commentaire!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Text(action.commentaire!,
                      style: tInter(fontSize: 13, color: kCrmTextSub)),
                ),

              // File attachment
              if (action.fileUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: InkWell(
                    onTap: () => _openFile(context, action.fileUrl!),
                    borderRadius: BorderRadius.circular(6),
                    child: Row(children: [
                      Icon(
                        action.fileUrl!.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        size: 15,
                        color: kCrmPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text('View attachment',
                          style: tInter(
                              fontSize: 12,
                              color: kCrmPrimary,
                              decoration: TextDecoration.underline)),
                    ]),
                  ),
                ),

              // Reminders
              if (action.reminders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                    children: action.reminders
                        .map((r) => _ReminderChip(r))
                        .toList(),
                  ),
                ),

              // Actions row
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: OutlinedButton.icon(
                  onPressed: onReminder,
                  icon: const Icon(Icons.alarm_add_rounded, size: 14),
                  label: Text('Follow-up',
                      style: tInter(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCrmWarning,
                    side: BorderSide(
                        color: kCrmWarning.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _openFile(BuildContext context, String fileUrl) async {
    final url = fileUrl.startsWith('http')
        ? fileUrl
        : '${ApiConfig.baseUrl}$fileUrl';
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot open file')));
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid file URL')));
      }
    }
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String statut;

  const _StatusBadge(this.statut);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (statut) {
      case 'Fait':
        color = kCrmSuccess;
      case 'En cours':
        color = kCrmInfo;
      case 'Annulé':
        color = kCrmDanger;
      default:
        color = kCrmWarning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(statut,
          style: tInter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

// ── Reminder chip ─────────────────────────────────────────────────────────────

class _ReminderChip extends StatelessWidget {
  final ReminderModel reminder;

  const _ReminderChip(this.reminder);

  @override
  Widget build(BuildContext context) {
    DateTime? date;
    try {
      date = reminder.dateRelance.isNotEmpty
          ? DateTime.parse(reminder.dateRelance).toLocal()
          : null;
    } catch (_) {}

    final isPast = date != null && date.isBefore(DateTime.now());
    final isSoon = !isPast &&
        date != null &&
        date.difference(DateTime.now()).inHours <= 48;
    final color = isPast ? kCrmDanger : (isSoon ? kCrmWarning : kCrmSuccess);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.notifications_active_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              date != null
                  ? 'Follow-up: ${DateFormat('dd MMM yyyy').format(date)}'
                  : 'Follow-up: ${reminder.dateRelance}',
              style: tInter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
            if (reminder.message != null && reminder.message!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(reminder.message!,
                    style: tInter(fontSize: 11, color: kCrmTextSub)),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
          child: Text(
            isPast ? 'Overdue' : (isSoon ? 'Soon' : 'Upcoming'),
            style: tInter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCrmPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timeline_rounded,
                size: 40, color: kCrmPrimary),
          ),
          const SizedBox(height: 20),
          Text('No actions yet',
              style: tInter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kCrmText)),
          const SizedBox(height: 8),
          Text(
            'Start tracking this project by adding your first CRM action.',
            textAlign: TextAlign.center,
            style: tInter(fontSize: 13, color: kCrmTextSub),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Add First Action',
                style: tInter(
                    fontWeight: FontWeight.w600, color: Colors.white)),
            style: FilledButton.styleFrom(
              backgroundColor: kCrmPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              size: 40, color: kCrmDanger),
          const SizedBox(height: 16),
          Text('Failed to load timeline',
              style: tInter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kCrmText)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: tInter(fontSize: 12, color: kCrmTextSub)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: Text('Retry', style: tInter(fontSize: 13)),
            style: OutlinedButton.styleFrom(
                foregroundColor: kCrmPrimary,
                side: const BorderSide(color: kCrmPrimary)),
          ),
        ]),
      ),
    );
  }
}
