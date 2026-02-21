import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart'; // ✅ IMPORTANT

import 'package:dash_master_toolkit/route/my_route.dart';

class CalendarHeader extends StatefulWidget {
  const CalendarHeader({super.key});

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
                        CalendarToggleButtons(
                          isMobile: isMobile,
                          currentView: controller.currentView.value,
                          onViewChanged: (newView) =>
                              controller.changeView(newView),
                        ),
                        if (!isMobile) const SizedBox(width: 15),
                        Flexible(
                          child: _buildAddTaskButton(context, theme, lang), // ✅ pass context
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

  Widget _buildDateSelector() {
    return Obx(() => DateNavigator(
          onPrevious: controller.goToPrevious,
          onNext: controller.goToNext,
          currentDate: controller.selectedDate.value,
          viewMode: controller.currentView.value == CalendarView.day ? "Day" : "Month",
        ));
  }

  Widget _buildAddTaskButton(
    BuildContext context, // ✅ ajouté
    ThemeData theme,
    AppLocalizations lang,
  ) {
    return IntrinsicWidth(
      child: CommonButtonWithIcon(
        backgroundColor: colorPrimary100,
        onPressed: () {
          // ✅ EXACTEMENT comme UserGridScreen
          context.go(MyRoute.projectFormScreen);
        },
        text: lang.translate('addNewProject'),
      ),
    );
  }
}