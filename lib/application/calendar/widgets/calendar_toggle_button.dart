import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';

class CalendarToggleButtons extends StatefulWidget {
  final CalendarView currentView;
  final Function(CalendarView) onViewChanged;
  final bool isMobile;

  const CalendarToggleButtons({
    super.key,
    required this.currentView,
    required this.onViewChanged,
    required this.isMobile,
  });

  @override
  State<CalendarToggleButtons> createState() => _CalendarToggleButtonsState();
}

class _CalendarToggleButtonsState extends State<CalendarToggleButtons> {
  late CalendarView _selectedView;
  final List<CalendarView> _views = [
    CalendarView.day,
    CalendarView.week,
    CalendarView.month
  ];

  @override
  void initState() {
    super.initState();
    _selectedView = widget.currentView;
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    ThemeController themeController = Get.put(ThemeController());
    return Row(
      mainAxisSize: MainAxisSize.min, // Prevent full width
      children: [
        ToggleButtons(
          isSelected: _views.map((view) => view == _selectedView).toList(),
          onPressed: (index) {
            setState(() {
              _selectedView = _views[index];
            });
            widget.onViewChanged(_selectedView);
          },
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          color: themeController.isDarkMode ? Colors.white : colorGrey900,
          fillColor: colorPrimary200,
          borderColor: colorPrimary100,
          selectedBorderColor: colorPrimary100,
          textStyle:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          constraints: BoxConstraints(minWidth: widget.isMobile ? 45 : 75),
          // Fixed button width
          children: _views.map((view) {
            final isSelected = view == _selectedView;
            return Padding(
              padding:  EdgeInsets.symmetric(vertical: widget.isMobile ? 10:8, horizontal: 5),
              child: Text(
                _getViewLabel(view, lang),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white // Selected text color
                      : (themeController.isDarkMode
                          ? Colors.white70
                          : colorGrey900),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getViewLabel(CalendarView view, AppLocalizations lang) {
    switch (view) {
      case CalendarView.day:
        return lang.translate('Daily');
      case CalendarView.week:
        return lang.translate('Weekly');
      case CalendarView.month:
        return lang.translate('Monthly');
      default:
        return 'View';
    }
  }
}
