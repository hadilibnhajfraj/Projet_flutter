
import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';


import 'package:responsive_framework/responsive_framework.dart' as rf;

class CalendarHeader extends StatefulWidget {
  const CalendarHeader({
    super.key,
  });

  @override
  State<CalendarHeader> createState() => _CalendarHeaderState();
}

class _CalendarHeaderState extends State<CalendarHeader> {
  final CalendarControllerX controller = Get.find();

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
