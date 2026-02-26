import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();

  final _startDateCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();

  DateTime? _startDate;
  TimeOfDay? _startTime;

  // ✅ Couleur principale (remplace par ton colorPrimary100 si tu veux)
  static const Color kPrimary = Color(0xFF1976D2); // bleu
  static const Color kFieldBg = Color(0xFFF2F6FF); // bleu très clair

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _startDateCtrl.dispose();
    _startTimeCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: kFieldBg, // ✅ pas blanc
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: kPrimary.withOpacity(.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: Colors.grey.shade700),
      suffixIcon: Icon(icon, color: kPrimary),
    );
  }

ThemeData _pickerTheme(BuildContext context) {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: kPrimary,
      onPrimary: Colors.white,
      surface: const Color(0xFFEEF3FF),
      onSurface: Colors.black87,
    ),
    dialogBackgroundColor: const Color(0xFFEEF3FF),

    timePickerTheme: TimePickerThemeData(
      backgroundColor: const Color(0xFFEEF3FF),

      // ✅ cadran
      dialBackgroundColor: Colors.white,
      dialTextColor: kPrimary,         // chiffres non sélectionnés
      dialHandColor: kPrimary,
      dialTextStyle: const TextStyle(fontWeight: FontWeight.w700),

      // ✅ heure/minute (le gros texte)
      hourMinuteColor: Colors.white,
      hourMinuteTextColor: kPrimary,   // ✅ UNE SEULE FOIS
      hourMinuteTextStyle: const TextStyle(fontWeight: FontWeight.w800),

      // ✅ AM/PM
      dayPeriodColor: Colors.white,
      dayPeriodTextColor: kPrimary,
      dayPeriodTextStyle: const TextStyle(fontWeight: FontWeight.w700),

      // ✅ "Select time"
      helpTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w700,
      ),

      entryModeIconColor: kPrimary,
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kPrimary),
    ),
  );
}

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (d == null) return;

    setState(() {
      _startDate = d;
      _startDateCtrl.text = DateFormat("yyyy-MM-dd").format(d); // ✅ s'affiche dans l'input
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (t == null) return;

    setState(() {
      _startTime = t;
      _startTimeCtrl.text = t.format(context); // ✅ s'affiche dans l'input
    });
  }

  DateTime? _buildStartDateTime() {
    if (_startDate == null || _startTime == null) return null;
    return DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFEEF3FF), // ✅ fond dialog (pas blanc)
      title: const Text("Ajouter un suivi (Task)"),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.black87),
              decoration: _dec("Title", "Enter Title", Icons.title),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startDateCtrl,
                    readOnly: true,
                    onTap: _pickDate,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                    decoration: _dec("Start Date", "Select Start Date", Icons.calendar_month_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _startTimeCtrl,
                    readOnly: true,
                    onTap: _pickTime,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                    decoration: _dec("Start Time", "Select Start Time", Icons.access_time),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 3,
              style: const TextStyle(color: Colors.black87),
              decoration: _dec("Description", "Enter here", Icons.notes),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: kPrimary,
            backgroundColor: Colors.white, // ✅ pas blanc “invisible”, vrai bouton
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: () => Navigator.pop(context, null),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          onPressed: () {
            final start = _buildStartDateTime();
            if (_title.text.trim().isEmpty || start == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Title + Start date/time sont obligatoires")),
              );
              return;
            }
            Navigator.pop(context, {
              "title": _title.text.trim(),
              "start": start,
              "description": _desc.text.trim(),
            });
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}