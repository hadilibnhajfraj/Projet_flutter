import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';


import 'package:responsive_framework/responsive_framework.dart' as rf;

class CalendarViewScreen extends StatelessWidget {
  final CalendarControllerX controller = Get.put(CalendarControllerX());

  CalendarViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeData theme = Theme.of(context);
    ThemeController themeController = Get.put(ThemeController());
    return Scaffold(
      body: Container(
        margin: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: [
              const rf.Condition.between(
                start: 0,
                end: 340,
                value: 10,
              ),
              const rf.Condition.between(
                start: 341,
                end: 992,
                value: 16,
              ),
            ],
            defaultValue: 24,
          ).value,
        ),
        constraints: BoxConstraints.tight(
          Size(
            double.maxFinite,
            MediaQuery.of(context).size.height * 0.80,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: themeController.isDarkMode ? colorGrey900 : colorWhite,
          borderRadius: BorderRadius.circular(10),
          border: rf.ResponsiveBreakpoints.of(context)
                  .largerThan(BreakpointName.MD.name)
              ? Border.all(
                  color:
                      themeController.isDarkMode ? colorGrey500 : colorGrey400,
                  strokeAlign: BorderSide.strokeAlignInside,
                  width: 1,
                )
              : null,
        ),
        child: Column(
          children: [
            // Calendar Header with navigation and view mode
            CalendarHeader(),
            Expanded(
              child: SfCalendar(
                headerHeight: 0,
                controller: controller.calendarController,
                // view: controller.calendarView.value, // View updates dynamically
                // view: CalendarView.week,
                dataSource: _getCalendarDataSource(),
                timeSlotViewSettings: TimeSlotViewSettings(
                  startHour: 5,
                  endHour: 18,
                  timeIntervalHeight: 60,
                ),
                allowedViews: [
                  CalendarView.day,
                  CalendarView.week,
                  CalendarView.month,
                ],
                showNavigationArrow: true,
                onViewChanged: (viewChangedDetails) {
                  // Handle view change logic if needed
                },
                todayHighlightColor: Colors.red,
                showCurrentTimeIndicator: true,
                initialDisplayDate: DateTime.now(),

                // headerStyle: CalendarHeaderStyle(),
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
