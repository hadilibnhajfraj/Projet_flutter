// lib/core/config/logistics_managers.dart
//
// Responsables (logistique et production) : SOURCE UNIQUE côté application
// des comptes qui disposent de l'interface et des droits du responsable
// logistique (validation des fiches de production, matières premières,
// demandes Production, demandes de maintenance). Même liste que le backend
// (src/config/logisticsManagers.js), qui reste l'autorité sur chaque route.
//
// Par email et non par rôle : ces comptes partagent le rôle
// `responsable_logistique_achat` avec production_1..5.

const Set<String> kLogisticsManagerEmails = {
  'responsable_logistique@cbi-tunisia.com',
  'responsable_production@cbi-tunisia.com',
};

bool isLogisticsManagerEmail(String? email) => kLogisticsManagerEmails.contains((email ?? '').toLowerCase().trim());
