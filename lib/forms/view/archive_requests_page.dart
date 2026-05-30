// lib/forms/view/archive_requests_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/providers/archive_request_provider.dart';
import 'package:dash_master_toolkit/models/archive_request_model.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PAGE
// ══════════════════════════════════════════════════════════════════════════════
class ArchiveRequestsPage extends StatelessWidget {
  const ArchiveRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = ArchiveRequestProvider.to;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(provider),
      body: Obx(() {
        if (provider.loading.value) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (provider.requests.isEmpty) {
          return _EmptyState();
        }
        return _Body(provider: provider);
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(ArchiveRequestProvider provider) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 20,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kCrmPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.forum_rounded, size: 20, color: kCrmPrimary),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Demandes de désarchivage',
              style: tInter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kCrmText)),
          Obx(() => Text(
                '${provider.pendingCount} en attente · ${provider.requests.length} au total',
                style: tInter(fontSize: 11, color: kCrmTextSub),
              )),
        ]),
      ]),
      actions: [
        Obx(() {
          final pending = provider.pendingCount;
          if (pending == 0) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'En attente : $pending',
              style: tInter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          );
        }),
        Obx(() => provider.loading.value
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Rafraîchir',
                onPressed: provider.loadArchiveRequests,
              )),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.grey.shade200),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BODY — scrollable card list
// ══════════════════════════════════════════════════════════════════════════════
class _Body extends StatelessWidget {
  final ArchiveRequestProvider provider;
  const _Body({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = provider.requests;
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: list.length,
        itemBuilder: (_, i) => _RequestCard(
          request: list[i],
          provider: provider,
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REQUEST CARD
// ══════════════════════════════════════════════════════════════════════════════
class _RequestCard extends StatelessWidget {
  final ArchiveRequest request;
  final ArchiveRequestProvider provider;

  const _RequestCard({required this.request, required this.provider});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    final statusLabel = _statusLabel(request.status);
    final statusIcon  = _statusIcon(request.status);
    final isPending   = request.status == 'pending';
    final initials    = _initials(request.userEmail.isNotEmpty
        ? request.userEmail
        : request.userName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFD97706).withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card header ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.04),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
                bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kCrmPrimary.withValues(alpha: 0.8),
                    kCrmPrimary
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(initials,
                  style: tInter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            const SizedBox(width: 12),
            // User + project info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.projectName,
                      style: tInter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kCrmText),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.userEmail.isNotEmpty
                          ? request.userEmail
                          : request.userName,
                      style: tInter(fontSize: 11, color: kCrmTextSub),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(statusLabel,
                    style: tInter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ]),
            ),
          ]),
        ),

        // ── Card body ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject
                _field('Sujet', request.subject),
                const SizedBox(height: 12),
                // Message
                _field('Message', request.message, multiline: true),
                const SizedBox(height: 12),
                // Date
                Row(children: [
                  Icon(Icons.access_time_rounded,
                      size: 13, color: kCrmTextSub),
                  const SizedBox(width: 5),
                  Text(
                    _fmtDate(request.createdAt),
                    style: tInter(fontSize: 11, color: kCrmTextSub),
                  ),
                ]),
              ]),
        ),

        // ── Actions (admin only, pending only) ───────────────────────────
        if (provider.isAdmin)
          Container(
            padding:
                const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              // Discussion button (always visible)
              _outlinedBtn(
                icon: Icons.forum_outlined,
                label: 'Discussion',
                color: kCrmPrimary,
                onTap: () {
                  provider.selectRequest(request.id);
                  context.go('/forms/archive-requests/chat');
                },
              ),
              if (isPending) ...[
                const SizedBox(width: 8),
                _outlinedBtn(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Approuver',
                  color: const Color(0xFF16A34A),
                  onTap: () => _confirmApprove(context, request, provider),
                ),
                const SizedBox(width: 8),
                _outlinedBtn(
                  icon: Icons.cancel_outlined,
                  label: 'Refuser',
                  color: const Color(0xFFDC2626),
                  onTap: () => _confirmReject(context, request, provider),
                ),
              ],
            ]),
          ),

        // ── Non-admin: Discussion button ─────────────────────────────────
        if (!provider.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _outlinedBtn(
              icon: Icons.forum_outlined,
              label: 'Ouvrir la discussion',
              color: kCrmPrimary,
              onTap: () {
                provider.selectRequest(request.id);
                context.go('/forms/archive-requests/chat');
              },
            ),
          ),
      ]),
    );
  }

  // ── Confirm dialogs ────────────────────────────────────────────────────────
  void _confirmApprove(BuildContext ctx, ArchiveRequest req,
      ArchiveRequestProvider provider) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Approuver la demande',
          style: tInter(fontSize: 15, fontWeight: FontWeight.w700)),
      content: Text(
        'Désarchiver le projet "${req.projectName}" ?',
        style: tInter(fontSize: 13, color: kCrmTextSub),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('Annuler', style: tInter(color: kCrmTextSub)),
        ),
        ElevatedButton(
          onPressed: () {
            Get.back();
            provider.approveRequest(req.id);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Approuver',
              style: tInter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }

  void _confirmReject(BuildContext ctx, ArchiveRequest req,
      ArchiveRequestProvider provider) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Refuser la demande',
          style: tInter(fontSize: 15, fontWeight: FontWeight.w700)),
      content: Text(
        'Refuser la demande pour "${req.projectName}" ?',
        style: tInter(fontSize: 13, color: kCrmTextSub),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('Annuler', style: tInter(color: kCrmTextSub)),
        ),
        ElevatedButton(
          onPressed: () {
            Get.back();
            provider.rejectRequest(req.id);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Refuser',
              style: tInter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────
  Widget _field(String label, String value, {bool multiline = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: tInter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: kCrmTextSub,
              letterSpacing: 0.4)),
      const SizedBox(height: 4),
      Text(
        value.isEmpty ? '—' : value,
        style: tInter(
            fontSize: 13,
            color: kCrmText,
            fontWeight: FontWeight.w500),
        maxLines: multiline ? 4 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    ]);
  }

  Widget _outlinedBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: tInter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: kCrmPrimary.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.archive_outlined,
              size: 44, color: kCrmPrimary.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 18),
        Text('Aucune demande de désarchivage',
            style: tInter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kCrmText)),
        const SizedBox(height: 6),
        Text(
          'Les demandes apparaîtront ici.',
          style: tInter(fontSize: 13, color: kCrmTextSub),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status) {
    case 'approved': return const Color(0xFF16A34A);
    case 'rejected': return const Color(0xFFDC2626);
    default:         return const Color(0xFFD97706);
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'approved': return 'Approuvé';
    case 'rejected': return 'Rejeté';
    default:         return 'En attente';
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'approved': return Icons.check_circle_outline_rounded;
    case 'rejected': return Icons.cancel_outlined;
    default:         return Icons.schedule_rounded;
  }
}

String _fmtDate(DateTime dt) {
  try {
    return DateFormat('dd/MM/yyyy à HH:mm').format(dt);
  } catch (_) {
    return '';
  }
}

String _initials(String value) {
  if (value.isEmpty) return '?';
  final parts = value.split(RegExp(r'[\s@._-]'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return value[0].toUpperCase();
}
