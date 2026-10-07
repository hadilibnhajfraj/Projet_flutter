// lib/quality_control/view/quality_control_topbar.dart
//
// Éléments ajoutés à l'en-tête global EXISTANT (TopBarWidget) pour le module
// Contrôle Qualité : recherche globale (référence QC, contrôle, machine →
// Historique filtré) et identité de l'utilisateur connecté (libellé du rôle +
// email — aucune donnée sensible). Langue, thème, notifications et menu
// profil restent ceux de l'application.

import 'package:flutter/material.dart' hide Text;
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import '../quality_control_routes.dart';
import '../quality_control_i18n.dart';

const _kSearchHint = 'Rechercher un contrôle qualité, une référence QC, une machine...';

/// Recherche globale visible : rôle controle_qualite (tout son espace) ou
/// lecteur autorisé sur une page du module.
bool qcTopbarSearchVisible(BuildContext context) {
  final auth = AuthService();
  if (!auth.canViewQualityControl) return false;
  if (auth.isControleQualite) return true;
  final path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
  return path == QcPaths.root || path.startsWith('${QcPaths.root}/');
}

void _submit(BuildContext context, String query) {
  if (query.trim().isEmpty) return;
  context.go(QcPaths.historySearch(query));
}

/// Champ de recherche (écran large) — Entrée : Historique filtré.
class QcTopbarSearch extends StatefulWidget {
  const QcTopbarSearch({super.key});

  @override
  State<QcTopbarSearch> createState() => _QcTopbarSearchState();
}

class _QcTopbarSearchState extends State<QcTopbarSearch> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: dark ? Colors.white24 : kCrmBorder),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (q) {
            _submit(context, q);
            _ctrl.clear();
          },
          style: tInter(fontSize: 13, color: dark ? Colors.white : kCrmText),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            hintText: qcT(_kSearchHint),
            hintStyle: tInter(fontSize: 13, color: dark ? Colors.white54 : kCrmTextSub),
            prefixIcon: Icon(Icons.search_rounded, size: 19, color: dark ? Colors.white60 : kCrmTextSub),
            filled: true,
            fillColor: dark ? Colors.white10 : kCrmBg,
            border: border,
            enabledBorder: border,
          ),
        ),
      ),
    );
  }
}

/// Bouton loupe (écran étroit) — ouvre la même recherche dans un dialogue.
class QcTopbarSearchButton extends StatelessWidget {
  const QcTopbarSearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return IconButton(
      tooltip: qcT('Rechercher'),
      icon: const Icon(Icons.search_rounded),
      onPressed: () async {
        final ctrl = TextEditingController();
        final q = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Recherche'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
              decoration: InputDecoration(hintText: qcT(_kSearchHint), prefixIcon: const Icon(Icons.search_rounded)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('Rechercher')),
            ],
          ),
        );
        ctrl.dispose();
        if (q != null && context.mounted) _submit(context, q);
      },
    );
  }
}

/// Identité affichée à côté de l'avatar pour le rôle controle_qualite :
/// "Contrôle Qualité" + email du compte connecté.
class QcTopbarIdentity extends StatelessWidget {
  const QcTopbarIdentity({super.key});

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final auth = AuthService();
    if (!auth.isControleQualite) return const SizedBox.shrink();
    final email = auth.userEmail ?? '';
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Contrôle Qualité', style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? Colors.white : kCrmText)),
        if (email.isNotEmpty) Text(email, style: tInter(fontSize: 11.5, color: dark ? Colors.white60 : kCrmTextSub)),
      ]),
    );
  }
}
