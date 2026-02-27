import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';
import 'package:dash_master_toolkit/services/task_api.dart';
import 'package:dash_master_toolkit/application/calendar/model/task_model.dart';

class CalendarControllerX extends GetxController {
  final selectedDate = DateTime.now().obs;

  final calendarController = CalendarController();
  final currentView = CalendarView.week.obs;

  final appointments = <Appointment>[].obs;
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();

    fetchTasksAndBuildCalendar();

    calendarController.addPropertyChangedListener((String property) {
      if (property == 'displayDate') {
        Future.microtask(() {
          selectedDate.value = calendarController.displayDate ?? DateTime.now();
        });
      }
    });

    calendarController.view = CalendarView.week;
  }

Future<void> fetchTasksAndBuildCalendar() async {
  try {
    final tasks = await TaskApi.instance.listTasks();

appointments.assignAll(
  tasks.map((t) {
    final startLocal = t.startAt.toLocal();
    final createdByLabel = (t.creatorEmail != null && t.creatorEmail!.isNotEmpty)
        ? "\n👤 ${t.creatorEmail}"
        : "";

    return Appointment(
      startTime: startLocal,
      endTime: startLocal.add(const Duration(minutes: 30)),
      subject: (t.description.trim().isEmpty ? t.title : "${t.title}\n${t.description}") + createdByLabel,
      color: colorPrimary100,
    );
  }).toList(),
);
  } catch (_) {
    appointments.clear();
  }
}

  Future<void> addTask({
    required String title,
    required DateTime start,
    String description = "",
  }) async {
    await TaskApi.instance.createTask(
      title: title,
      startAt: start,
      description: description,
    );

    // ✅ recharge depuis la DB => persistant même après relog
    await fetchTasksAndBuildCalendar();
  }

  void changeView(CalendarView view) {
    calendarController.view = view;
    currentView.value = view;
  }

  void goToPrevious() => calendarController.backward?.call();
  void goToNext() => calendarController.forward?.call();
}