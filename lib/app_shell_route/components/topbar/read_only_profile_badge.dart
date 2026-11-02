// lib/app_shell_route/components/topbar/read_only_profile_badge.dart
//
// Profil du compte back-office en consultation seule, toujours visible dans
// la barre supérieure : « Back-office — Consultation uniquement ».

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/core/config/read_only_access.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

class ReadOnlyProfileBadge extends StatelessWidget {
  const ReadOnlyProfileBadge({super.key});

  @override
  Widget build(BuildContext context) {
    String t(String k) => Localizations.of<AppLocalizations>(context, AppLocalizations)?.translate(k) ?? k;
    final reference = AuthService().readOnlyReferenceEmail;
    final compact = MediaQuery.sizeOf(context).width < 700;
    const color = Color(0xFF0E7490);
    return Tooltip(
      message: [
        t('Aucune création, modification ou suppression.'),
        if (reference != null) '${t('Visibilité de')} $reference',
      ].join('\n'),
      child: Container(
        key: const ValueKey('read-only-profile-badge'),
        margin: const EdgeInsetsDirectional.only(end: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.visibility_outlined, size: 15, color: color),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(t(kBackofficeReadOnlyLabel), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ]),
      ),
    );
  }
}
