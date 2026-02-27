import 'dart:convert';
import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';
import 'package:dash_master_toolkit/services/task_api.dart';
import 'package:dash_master_toolkit/application/calendar/model/task_model.dart';

class CalendarControllerX extends GetxController {
  var selectedDate = DateTime.now().obs;

  final calendarController = CalendarController();
  var currentView = CalendarView.week.obs;

  var appointments = <Appointment>[].obs;

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
      final List<TaskModel> tasks = await TaskApi.instance.listTasks();

      appointments.assignAll(
        tasks.map((t) {
          final startLocal = t.startAt.toLocal();
          final endLocal = startLocal.add(const Duration(minutes: 30));

          // ✅ notes = json (propre)
          final notes = jsonEncode({
            "desc": t.description,
            "creatorEmail": t.creatorEmail ?? "",
          });

          return Appointment(
            startTime: startLocal,
            endTime: endLocal,
            subject: t.title,       // ✅ seulement le titre
            notes: notes,           // ✅ meta pour UI
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
    await fetchTasksAndBuildCalendar();
  }

  void changeView(CalendarView view) {
    calendarController.view = view;
    currentView.value = view;
  }

  void goToPrevious() => calendarController.backward?.call();
  void goToNext() => calendarController.forward?.call();
}