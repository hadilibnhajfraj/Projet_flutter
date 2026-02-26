
import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';



import 'package:responsive_framework/responsive_framework.dart' as rf;
import 'package:intl/intl.dart';

class CalendarHeader extends StatefulWidget {
  const CalendarHeader({
    super.key,
  });

  @override
  State<CalendarHeader> createState() => _CalendarHeaderState();
}

class _CalendarHeaderState extends State<CalendarHeader> {
  final CalendarControllerX controller = Get.find();
void createNewTaskDialog(ThemeData theme, BuildContext context) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String fmtTime(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Ajouter un suivi (Task)",
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text("Title", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      hintText: "Enter Title",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Start Date & Start Time (NO END)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Start Date",
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate ?? now,
                                  firstDate: DateTime(now.year - 1),
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (picked != null) {
                                  setStateDialog(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: "Select Start Date",
                                ),
                                child: Text(
                                  selectedDate == null ? "Select Start Date" : fmtDate(selectedDate!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Start Time",
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: selectedTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setStateDialog(() => selectedTime = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: "Select Start Time",
                                ),
                                child: Text(
                                  selectedTime == null ? "Select Start Time" : fmtTime(selectedTime!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text("Description",
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Enter here",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrimary100,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Title est obligatoire")),
                              );
                              return;
                            }
                            if (selectedDate == null || selectedTime == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Start Date + Start Time sont obligatoires")),
                              );
                              return;
                            }

                            final start = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );

                            controller.addTask(
                              title: title,
                              start: start,
                              description: descCtrl.text.trim(),
                            );

                            Navigator.pop(ctx);
                          },
                          child: const Text("Save"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    var lang = AppLocalizations.of(context);
    final isMobile = rf.ResponsiveValue<bool>(
      context,
      conditionalValues: const [
        rf.Condition.between(start: 0, end: 768, value: true),
      ],
      defaultValue: false,
    ).value;

    return Obx(() => Padding(
          padding: EdgeInsets.all(isMobile ? 0 : 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: isMobile
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (!isMobile) _buildDateSelector(),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: isMobile
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.end,
                      children: [
                        // Calendar View Toggle Buttons
                        CalendarToggleButtons(
                          isMobile: isMobile,
                          currentView: controller.currentView.value,
                          onViewChanged: (newView) =>
                              controller.changeView(newView),
                        ),

                        if (!isMobile) const SizedBox(width: 15),

                        Flexible(
                          child: _buildAddTaskButton(theme, lang),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isMobile) const SizedBox(height: 15),
              if (isMobile) _buildDateSelector(),
            ],
          ),
        ));
  }

  /// Date Navigator (Previous, Current, Next)
  Widget _buildDateSelector() {
    return Obx(() => DateNavigator(
          onPrevious: controller.goToPrevious,
          onNext: controller.goToNext,
          currentDate: controller.selectedDate.value,
          viewMode: controller.currentView.value == CalendarView.day
              ? "Day"
              : "Month",
        ));
  }

  /// "Add New Task" Button
  Widget _buildAddTaskButton(ThemeData theme, AppLocalizations lang) {
    return IntrinsicWidth(
      child: CommonButtonWithIcon(
        backgroundColor: colorPrimary100,
        onPressed: () {
          createNewTaskDialog(theme, context);
        },
        text: lang.translate('addNewTask'),
      ),
    );
  }
}
