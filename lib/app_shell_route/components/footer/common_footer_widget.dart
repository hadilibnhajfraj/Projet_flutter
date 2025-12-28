import 'package:responsive_framework/responsive_framework.dart' as rf;

import '../common_imports.dart';

class CommonFooterWidget extends StatelessWidget {
  const CommonFooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ThemeController themeController = Get.put(ThemeController());
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: rf.ResponsiveValue<double?>(
        context,
        conditionalValues: const [
          rf.Condition.between(start: 0, end: 290, value: 11),
          rf.Condition.between(start: 291, end: 340, value: 12),
        ],
      ).value,
    );

    return LayoutBuilder(
      builder: (context, constraints) => Container(
        padding: rf.ResponsiveValue<EdgeInsetsGeometry?>(
          context,
          conditionalValues: [
            rf.Condition.smallerThan(
              name: BreakpointName.LG.name,
              value: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ],
          defaultValue: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 18,
          ),
        ).value,
        color: themeController.isDarkMode ? colorGrey900 : colorWhite,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${AppLocalizations.of(context).translate('COPYRIGHT')} © ${AppLocalizations.of(context).translate("year")}',
                style: textStyle,
              ),
            ),
            Builder(
              builder: (context) {
                final translatedLang =
                    AppLocalizations.of(context).translate("madeWithFooter");

                const heart = '❤';
                final List<String> parts =
                    translatedLang.split(RegExp(r'(?=\s)|(?<=\s)'));

                return Text.rich(
                  TextSpan(
                    children: parts.map((e) {
                      final trimmedText = e.trim();

                      return TextSpan(
                        text: e,
                        style: TextStyle(
                          color: switch (trimmedText) {
                            heart => Colors.red,
                            organizationName => colorPrimary100,
                            _ => null,
                          },
                          fontWeight: switch (trimmedText) {
                            organizationName => FontWeight.w500,
                            _ => null,
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  style: textStyle,
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
