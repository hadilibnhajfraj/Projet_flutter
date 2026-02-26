import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

class CalendarViewScreen extends StatelessWidget {
  final CalendarControllerX controller = Get.put(CalendarControllerX());

  CalendarViewScreen({super.key});

  // ✅ Background card (light)
  static const Color kCalendarCardBg = Color(0xFFF3F6FF); // bleu très clair
  static const Color kCalendarBg = Color(0xFFEFF4FF);     // fond interne calendrier

  @override
  Widget build(BuildContext context) {
    ThemeController themeController = Get.put(ThemeController());

    return Scaffold(
      body: Container(
        margin: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: const [
              rf.Condition.between(start: 0, end: 340, value: 10),
              rf.Condition.between(start: 341, end: 992, value: 16),
            ],
            defaultValue: 24,
          ).value,
        ),
        constraints: BoxConstraints.tight(
          Size(double.maxFinite, MediaQuery.of(context).size.height * 0.80),
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // ✅ card background (pas blanc)
          color: themeController.isDarkMode ? colorGrey900 : kCalendarCardBg,
          borderRadius: BorderRadius.circular(10),
          border: rf.ResponsiveBreakpoints.of(context).largerThan(BreakpointName.MD.name)
              ? Border.all(
                  color: themeController.isDarkMode ? colorGrey500 : colorGrey400,
                  strokeAlign: BorderSide.strokeAlignInside,
                  width: 1,
                )
              : null,
        ),
        child: Column(
          children: [
            CalendarHeader(),
            Expanded(
              child: SfCalendar(
                headerHeight: 0,
                controller: controller.calendarController,
                dataSource: _getCalendarDataSource(),

                // ✅ Fond interne du calendrier (pas blanc)
                backgroundColor: themeController.isDarkMode ? colorGrey900 : kCalendarBg,

                timeSlotViewSettings: const TimeSlotViewSettings(
                  startHour: 5,
                  endHour: 18,
                  timeIntervalHeight: 60,
                ),

                allowedViews: const [
                  CalendarView.day,
                  CalendarView.week,
                  CalendarView.month,
                ],

                showNavigationArrow: true,
                todayHighlightColor: Colors.red,
                showCurrentTimeIndicator: true,
                initialDisplayDate: DateTime.now(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _AppointmentDataSource _getCalendarDataSource() {
    return _AppointmentDataSource(controller.appointments);
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}