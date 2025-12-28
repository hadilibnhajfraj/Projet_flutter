
import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    this.onPrevious,
    this.onNext,
    this.currentDate,
    this.viewMode = 'Day',
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final DateTime? currentDate;
  final String viewMode;

  @override
  Widget build(BuildContext context) {
    ThemeController themeController = Get.put(ThemeController());
    final bool isMobile = rf.ResponsiveValue<bool>(
      context,
      conditionalValues: const [
        rf.Condition.between(start: 0, end: 675, value: true),
      ],
      defaultValue: false,
    ).value;

    final theme = Theme.of(context);
    final formattedDate = DateFormat(
      viewMode.trim().toLowerCase() == "day" ? 'dd MMM, yyyy' : 'MMM, yyyy',
    ).format(currentDate ?? DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // Previous Button
        IconButton.outlined(
          onPressed: onPrevious,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: isMobile ? BorderSide.none : BorderSide(color: themeController.isDarkMode ? colorGrey700 : colorGrey100),
            padding: EdgeInsets.zero,
          ),
          icon:  Icon(Icons.chevron_left_outlined,color: themeController.isDarkMode ? colorWhite : colorGrey900,),
        ),

        // Selected Date
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            formattedDate,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isMobile ? 18 : null,
              fontWeight: isMobile ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),

        // Next Button
        IconButton.outlined(
          onPressed: onNext,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: isMobile ? BorderSide.none : BorderSide(color: themeController.isDarkMode ? colorGrey700 : colorGrey100),
            padding: EdgeInsets.zero,
          ),
          icon:  Icon(Icons.chevron_right_outlined,color: themeController.isDarkMode ? colorWhite : colorGrey900,),
        ),
      ],
    );
  }
}
