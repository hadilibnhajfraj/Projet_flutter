// lib/forms/finance/view/widgets/finance_dashboard_filters.dart
//
// Filtres du Finance Dashboard (§MODIFICATION — DASHBOARD FINANCE
// PROFESSIONNEL, §11) : Date range (Today/This week/This month/This year/
// Custom), Customer, Payment method, Document type. Widget purement
// contrôlé — tout l'état (preset actif, dates custom, valeurs sélectionnées)
// vit dans l'écran parent, qui déclenche le rechargement des KPI/graphique/
// listes à chaque changement (§11 : "les KPI et graphiques doivent être
// actualisés").

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

enum FinanceDateRangePreset { all, today, thisWeek, thisMonth, thisYear, custom }

// Mêmes 4 valeurs canoniques que le dropdown "Register payment"
// (finance_invoice_detail_dialog.dart#kFinancePaymentMethods) — jamais une
// autre liste, pour rester cohérent avec les données réellement stockées.
const List<String> kFinanceDashboardPaymentMethods = ['Virement', 'Versement', 'Chèque', 'Traite'];
const List<String> kFinanceDashboardDocumentTypes = ['pdf', 'image', 'excel', 'word'];

class FinanceDashboardFilters extends StatelessWidget {
  final FinanceDateRangePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? customer;
  final String? paymentMethod;
  final String? documentType;
  final ValueChanged<FinanceDateRangePreset> onPresetChanged;
  final ValueChanged<DateTime> onCustomStartChanged;
  final ValueChanged<DateTime> onCustomEndChanged;
  final ValueChanged<String> onCustomerChanged;
  final ValueChanged<String?> onPaymentMethodChanged;
  final ValueChanged<String?> onDocumentTypeChanged;
  final VoidCallback onReset;

  const FinanceDashboardFilters({
    super.key,
    required this.preset,
    this.customStart,
    this.customEnd,
    this.customer,
    this.paymentMethod,
    this.documentType,
    required this.onPresetChanged,
    required this.onCustomStartChanged,
    required this.onCustomEndChanged,
    required this.onCustomerChanged,
    required this.onPaymentMethodChanged,
    required this.onDocumentTypeChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const presetLabels = {
      FinanceDateRangePreset.all: 'All time',
      FinanceDateRangePreset.today: 'Today',
      FinanceDateRangePreset.thisWeek: 'This week',
      FinanceDateRangePreset.thisMonth: 'This month',
      FinanceDateRangePreset.thisYear: 'This year',
      FinanceDateRangePreset.custom: 'Custom',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _dropdown<FinanceDateRangePreset>(
          value: preset,
          items: FinanceDateRangePreset.values.map((p) => (p, t.translate(presetLabels[p]!))).toList(),
          onChanged: (v) {
            if (v != null) onPresetChanged(v);
          },
        ),
        if (preset == FinanceDateRangePreset.custom) ...[
          _datePickerChip(context, label: t.translate('Date début'), value: customStart, onPicked: onCustomStartChanged),
          _datePickerChip(context, label: t.translate('Date fin'), value: customEnd, onPicked: onCustomEndChanged),
        ],
        SizedBox(
          width: 200,
          // Volontairement SANS `controller:` lié à `customer` — un
          // TextField non contrôlé gère son propre état interne, qui
          // survit aux rebuilds du parent déclenchés par `onCustomerChanged`
          // (setState → refetch) sans perdre le focus ni la position du
          // curseur en cours de frappe (même convention que les autres
          // champs de recherche Finance, ex. finance_inflow_raw_materials_screen.dart).
          child: TextField(
            onChanged: onCustomerChanged,
            style: tInter(fontSize: 13, color: kCrmText),
            decoration: InputDecoration(
              hintText: t.translate('Customer'),
              hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: kCrmTextSub),
              isDense: true,
              filled: true,
              fillColor: kCrmBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
            ),
          ),
        ),
        _dropdown<String?>(
          value: paymentMethod,
          hint: t.translate('Payment method'),
          items: [
            (null, t.translate('Payment method')),
            for (final m in kFinanceDashboardPaymentMethods) (m, m),
          ],
          onChanged: onPaymentMethodChanged,
        ),
        _dropdown<String?>(
          value: documentType,
          hint: t.translate('Document type'),
          items: [
            (null, t.translate('Document type')),
            for (final d in kFinanceDashboardDocumentTypes) (d, d.toUpperCase()),
          ],
          onChanged: onDocumentTypeChanged,
        ),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded, size: 16, color: kCrmTextSub),
          label: Text(t.translate('Réinitialiser'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
        ),
      ]),
    );
  }

  Widget _dropdown<T>({required T value, String? hint, required List<(T, String)> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: kCrmTextSub),
          style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText),
          items: [for (final item in items) DropdownMenuItem<T>(value: item.$1, child: Text(item.$2))],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePickerChip(BuildContext context, {required String label, required DateTime? value, required ValueChanged<DateTime> onPicked}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(value == null ? label : DateFormat('dd/MM/yyyy').format(value), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
        ]),
      ),
    );
  }
}
