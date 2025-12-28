import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';

class CalendarControllerX extends GetxController {
  var selectedDate = DateTime.now().obs;

  // var calendarView = CalendarView.week.obs;

  final calendarController = CalendarController();
  var currentView = CalendarView.week.obs; // Observable view state

  var appointments = <Appointment>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadAppointments();
    // Listen for displayDate changes safely
    calendarController.addPropertyChangedListener((String property) {
      if (property == 'displayDate') {
        Future.microtask(() {
          selectedDate.value = calendarController.displayDate ?? DateTime.now();
        });
      }
    });
    calendarController.view = CalendarView.week; // Ensure it's set
  }

  void changeView(CalendarView view) {
    calendarController.view = view;
    currentView.value = view; // Update the observable
  }

  void goToPrevious() {
    calendarController.backward?.call();
  }

  void goToNext() {
    calendarController.forward?.call();
  }

  void loadAppointments() {
    DateTime today = DateTime.now();
    DateTime previousDay = today.subtract(Duration(days: 1));
    DateTime nextDay = today.add(Duration(days: 1));

    appointments.assignAll([
      // Today's Appointments
      Appointment(
        startTime: DateTime(today.year, today.month, today.day, 9, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 0),
        subject: 'Daily Sync',
        color: Colors.green,
      ),
      Appointment(
        startTime: DateTime(today.year, today.month, today.day, 5, 0),
        endTime: DateTime(today.year, today.month, today.day, 7, 0),
        subject: 'Research',
        color: Colors.blue,
      ),

      // Previous Day Appointments
      Appointment(
        startTime: DateTime(
            previousDay.year, previousDay.month, previousDay.day, 8, 0),
        endTime: DateTime(
            previousDay.year, previousDay.month, previousDay.day, 9, 0),
        subject: 'Day Design Assets',
        color: Colors.purple,
      ),
      Appointment(
        startTime: DateTime(
            previousDay.year, previousDay.month, previousDay.day, 10, 0),
        endTime: DateTime(
            previousDay.year, previousDay.month, previousDay.day, 11, 0),
        subject: 'UX Wireframes',
        color: Colors.orange,
      ),

      // Next Day Appointments
      Appointment(
        startTime: DateTime(nextDay.year, nextDay.month, nextDay.day, 11, 0),
        endTime: DateTime(nextDay.year, nextDay.month, nextDay.day, 12, 0),
        subject: 'Report',
        color: Colors.cyan,
      ),
      Appointment(
        startTime: DateTime(nextDay.year, nextDay.month, nextDay.day, 7, 0),
        endTime: DateTime(nextDay.year, nextDay.month, nextDay.day, 8, 0),
        subject: 'User Flow',
        color: Colors.amber,
      ),
    ]);
  }
}
