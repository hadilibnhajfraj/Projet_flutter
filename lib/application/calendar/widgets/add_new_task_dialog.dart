



import '../calendar_imports.dart';

void createNewTaskDialog(
    ThemeData theme, BuildContext context) {
  ThemeController themeController = Get.put(ThemeController());
  TextEditingController titleController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  TextEditingController startTimeController = TextEditingController();
  TextEditingController endTimeController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  FocusNode f1 = FocusNode();
  FocusNode f2 = FocusNode();
  FocusNode f3 = FocusNode();
  FocusNode f4 = FocusNode();
  FocusNode f5 = FocusNode();
  FocusNode f6 = FocusNode();
  final titleFieldFocused = false.obs;
  final selectDateFieldFocused = false.obs;
  final endDateFieldFocused = false.obs;
  final startTimeFieldFocused = false.obs;
  final endTimeFieldFocused = false.obs;
  final descriptionFieldFocused = false.obs;
  final formKey = GlobalKey<FormState>();
  var selectedStartDate = Rxn<DateTime>();
  var selectedEndDate = Rxn<DateTime>();

  Future<void> selectStartDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate.value ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          // Customize the theme of the date picker dialog here
          data: ThemeData.light().copyWith(
            // primaryColor: colorPrimary100,
            // Change primary color
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            colorScheme: ColorScheme.light(primary: colorPrimary100),
            // Change color scheme
            dialogBackgroundColor: Colors.white, // Change background color
            // Add more customizations as needed
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      selectedStartDate.value = picked;
      startDateController.text = picked.toString().split(' ')[0];
    }
  }

  Future<void> selectEndDate(BuildContext context) async {
    if (selectedStartDate.value == null) {
      toast(
        "Error:  Please select the Start Date first",
      );
      return;
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedEndDate.value ?? selectedStartDate.value!,
      firstDate: selectedStartDate.value!,
      // Prevents selecting before start date
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          // Customize the theme of the date picker dialog here
          data: ThemeData.light().copyWith(
            // primaryColor: colorPrimary100,
            // Change primary color
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            colorScheme: ColorScheme.light(primary: colorPrimary100),
            // Change color scheme
            dialogBackgroundColor: Colors.white, // Change background color
            // Add more customizations as needed
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectedEndDate.value = picked;
      endDateController.text = picked.toString().split(' ')[0];
    }
  }

  var selectedStartTime = Rxn<TimeOfDay>();
  var selectedEndTime = Rxn<TimeOfDay>();

  Future<void> selectStartTime(BuildContext context) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime.value ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          // Customize the theme of the date picker dialog here
          data: ThemeData.light().copyWith(
            // primaryColor: colorPrimary100,
            // Change primary color
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            colorScheme: ColorScheme.light(primary: colorPrimary100),
            // Change color scheme
            dialogBackgroundColor: Colors.white, // Change background color
            // Add more customizations as needed
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectedStartTime.value = picked;
      startTimeController.text = picked.format(context);
      selectedEndTime.value = null; // Reset end time when start time changes
      endTimeController.clear();
    }
  }

  Future<void> selectEndTime(BuildContext context) async {
    if (selectedStartTime.value == null) {
      toast("Error: Please select the Start Time first");
      return;
    }

    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime.value ?? selectedStartTime.value!,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            colorScheme: ColorScheme.light(primary: colorPrimary100),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Convert TimeOfDay to minutes for easy comparison
      int startMinutes =
          selectedStartTime.value!.hour * 60 + selectedStartTime.value!.minute;
      int endMinutes = picked.hour * 60 + picked.minute;

      // Check if event spans multiple days
      bool isMultiDay = selectedEndDate.value != null &&
          selectedStartDate.value != null &&
          selectedEndDate.value!.isAfter(selectedStartDate.value!);

      if (!isMultiDay && endMinutes <= startMinutes) {
        toast("Invalid Time: End Time must be after Start Time");
        return;
      }

      selectedEndTime.value = picked;
      endTimeController.text = picked.format(context);
    }
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor:
            themeController.isDarkMode ? colorGrey800 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width,
          // 95% of screen width
          constraints: BoxConstraints(maxWidth: 500),
          // Max width for large screens

          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).translate("addNewTask"),
                          style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: themeController.isDarkMode
                                  ? colorWhite
                                  : colorGrey900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          context.pop();
                        },
                        child: SvgPicture.asset(
                          cancelIcon,
                          width: 20,
                          height: 20,
                          colorFilter:
                              ColorFilter.mode(colorGrey400, BlendMode.srcIn),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Divider(
                  height: 1,
                  color:
                      themeController.isDarkMode ? colorGrey700 : colorGrey100,
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate("title"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500, color: colorGrey500),
                      ),
                      const SizedBox(height: 5),
                      Obx(
                        () => TextFormField(
                          style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: themeController.isDarkMode
                                  ? colorWhite
                                  : colorGrey900),
                          focusNode: f1,
                          validator: (value) => validateText(
                              value,
                              AppLocalizations.of(context)
                                  .translate("titleIsRequired")),
                          onFieldSubmitted: (v) {
                            f1.unfocus();
                            FocusScope.of(context).requestFocus(f2);
                          },
                          onChanged: (value) {
                            titleFieldFocused.value = true;
                            selectDateFieldFocused.value = false;
                            endDateFieldFocused.value = false;
                            startTimeFieldFocused.value = false;
                            endTimeFieldFocused.value = false;
                            descriptionFieldFocused.value = false;
                          },
                          autovalidateMode: titleFieldFocused.value
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          controller: titleController,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.text,
                          decoration: inputDecoration(context,
                              hintText: AppLocalizations.of(context)
                                  .translate("enterTitle")),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                      .translate("startDate"),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colorGrey500),
                                ),
                                const SizedBox(height: 5),
                                Obx(
                                  () => InkWell(
                                    onTap: () {
                                      selectStartDate(context);
                                    },
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        readOnly: true,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    themeController.isDarkMode
                                                        ? colorWhite
                                                        : colorGrey900),
                                        focusNode: f2,
                                        validator: (value) => validateText(
                                            value,
                                            AppLocalizations.of(context)
                                                .translate(
                                                    "selectStartDateRequired")),
                                        onFieldSubmitted: (v) {
                                          f2.unfocus();
                                          FocusScope.of(context)
                                              .requestFocus(f3);
                                        },
                                        onChanged: (value) {
                                          titleFieldFocused.value = false;
                                          selectDateFieldFocused.value = true;
                                          endDateFieldFocused.value = false;
                                          startTimeFieldFocused.value = false;
                                          endTimeFieldFocused.value = false;
                                          descriptionFieldFocused.value = false;
                                        },
                                        autovalidateMode: selectDateFieldFocused
                                                .value
                                            ? AutovalidateMode.onUserInteraction
                                            : AutovalidateMode.disabled,
                                        controller: startDateController,
                                        textInputAction: TextInputAction.next,
                                        keyboardType: TextInputType.text,
                                        decoration: inputDecoration(context,
                                            hintText: AppLocalizations.of(
                                                    context)
                                                .translate("selectStartDate")),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                      .translate("startTime"),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colorGrey500),
                                ),
                                const SizedBox(height: 5),
                                Obx(
                                  () => InkWell(
                                    onTap: () {
                                      selectStartTime(context);
                                    },
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        readOnly: true,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    themeController.isDarkMode
                                                        ? colorWhite
                                                        : colorGrey900),
                                        focusNode: f3,
                                        validator: (value) => validateText(
                                            value,
                                            AppLocalizations.of(context)
                                                .translate(
                                                    "selectStartTimeRequired")),
                                        onFieldSubmitted: (v) {
                                          f3.unfocus();
                                          FocusScope.of(context)
                                              .requestFocus(f4);
                                        },
                                        onChanged: (value) {
                                          titleFieldFocused.value = false;
                                          selectDateFieldFocused.value = false;
                                          endDateFieldFocused.value = false;
                                          startTimeFieldFocused.value = true;
                                          endTimeFieldFocused.value = false;
                                          descriptionFieldFocused.value = false;
                                        },
                                        autovalidateMode: startTimeFieldFocused
                                                .value
                                            ? AutovalidateMode.onUserInteraction
                                            : AutovalidateMode.disabled,
                                        controller: startTimeController,
                                        textInputAction: TextInputAction.next,
                                        keyboardType: TextInputType.text,
                                        decoration: inputDecoration(context,
                                            hintText: AppLocalizations.of(
                                                    context)
                                                .translate("selectStartTime")),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                      .translate("endDate"),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colorGrey500),
                                ),
                                const SizedBox(height: 5),
                                Obx(
                                  () => InkWell(
                                    onTap: () {
                                      selectEndDate(context);
                                    },
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        readOnly: true,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    themeController.isDarkMode
                                                        ? colorWhite
                                                        : colorGrey900),
                                        focusNode: f4,
                                        validator: (value) => validateText(
                                            value,
                                            AppLocalizations.of(context)
                                                .translate(
                                                    "selectEndDateRequired")),
                                        onFieldSubmitted: (v) {
                                          f4.unfocus();
                                          FocusScope.of(context)
                                              .requestFocus(f5);
                                        },
                                        onChanged: (value) {
                                          titleFieldFocused.value = false;
                                          selectDateFieldFocused.value = false;
                                          endDateFieldFocused.value = true;
                                          startTimeFieldFocused.value = false;
                                          endTimeFieldFocused.value = false;
                                          descriptionFieldFocused.value = false;
                                        },
                                        autovalidateMode: endDateFieldFocused
                                                .value
                                            ? AutovalidateMode.onUserInteraction
                                            : AutovalidateMode.disabled,
                                        controller: endDateController,
                                        textInputAction: TextInputAction.next,
                                        keyboardType: TextInputType.text,
                                        decoration: inputDecoration(context,
                                            hintText: AppLocalizations.of(
                                                    context)
                                                .translate("selectEndDate")),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                      .translate("endTime"),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colorGrey500),
                                ),
                                const SizedBox(height: 5),
                                Obx(
                                  () => InkWell(
                                    onTap: () {
                                      selectEndTime(context);
                                    },
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        readOnly: true,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    themeController.isDarkMode
                                                        ? colorWhite
                                                        : colorGrey900),
                                        focusNode: f5,
                                        validator: (value) => validateText(
                                            value,
                                            AppLocalizations.of(context)
                                                .translate(
                                                    "selectEndTimeRequired")),
                                        onFieldSubmitted: (v) {
                                          f5.unfocus();
                                          FocusScope.of(context)
                                              .requestFocus(f6);
                                        },
                                        onChanged: (value) {
                                          titleFieldFocused.value = false;
                                          selectDateFieldFocused.value = false;
                                          endDateFieldFocused.value = false;
                                          startTimeFieldFocused.value = false;
                                          endTimeFieldFocused.value = true;
                                          descriptionFieldFocused.value = false;
                                        },
                                        autovalidateMode: endTimeFieldFocused
                                                .value
                                            ? AutovalidateMode.onUserInteraction
                                            : AutovalidateMode.disabled,
                                        controller: endTimeController,
                                        textInputAction: TextInputAction.next,
                                        keyboardType: TextInputType.text,
                                        decoration: inputDecoration(
                                          context,
                                          hintText: AppLocalizations.of(context)
                                              .translate("selectEndTime"),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        AppLocalizations.of(context).translate("description"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500, color: colorGrey500),
                      ),
                      const SizedBox(height: 5),
                      Obx(
                        () => TextFormField(
                          style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: themeController.isDarkMode
                                  ? colorWhite
                                  : colorGrey900),
                          focusNode: f6,
                          onFieldSubmitted: (v) {
                            f6.unfocus();
                          },
                          onChanged: (value) {},
                          maxLines: 3,
                          controller: descriptionController,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          decoration: inputDecoration(context,
                              hintText: AppLocalizations.of(context)
                                  .translate("enterHere")),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Divider(
                  height: 1,
                  color:
                      themeController.isDarkMode ? colorGrey700 : colorGrey100,
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: CommonButton(
                            borderColor: themeController.isDarkMode
                                ? colorGrey700
                                : colorGrey100,
                            bgColor: themeController.isDarkMode
                                ? colorGrey900
                                : colorWhite,
                            textStyle: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: themeController.isDarkMode
                                    ? colorWhite
                                    : colorGrey900),
                            onPressed: () {
                              context.pop();
                            },
                            text: AppLocalizations.of(context)
                                .translate("cancel")),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CommonButton(
                            textStyle: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500, color: colorWhite),
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                DateTime startDateTime = DateTime(
                                  selectedStartDate.value!.year,
                                  selectedStartDate.value!.month,
                                  selectedStartDate.value!.day,
                                  selectedStartTime.value!.hour,
                                  selectedStartTime.value!.minute,
                                );

                                DateTime endDateTime = DateTime(
                                  selectedEndDate.value!.year,
                                  selectedEndDate.value!.month,
                                  selectedEndDate.value!.day,
                                  selectedEndTime.value!.hour,
                                  selectedEndTime.value!.minute,
                                );

                                Appointment newAppointment = Appointment(
                                  startTime: startDateTime,
                                  endTime: endDateTime,
                                  subject: titleController.text,
                                  // You can customize this
                                  color: Colors.blue, // Change as needed
                                );
                                CalendarControllerX calController = Get.find();
                              // Add it to your existing appointment list

                                calController.appointments.add(newAppointment);
                                calController.update();
                                // print(calController.appointments.toString());
                                context.pop();
                              }
                            },
                            text:
                                AppLocalizations.of(context).translate("save")),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}
