import 'package:dash_master_toolkit/application/users/users_imports.dart';
import 'package:dash_master_toolkit/application/users/view/add_new_user_dialog.dart';

import 'package:responsive_framework/responsive_framework.dart' as rf;

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserListController controller = Get.put(UserListController());
  ThemeController themeController = Get.put(ThemeController());
  late UserDataSource _dataSource;

  int _rowsPerPage = 10; // ✅ Track rows per page


  @override
  void initState() {
    super.initState();
    List<UserModel> users = generateUsers(50);
    _dataSource = UserDataSource(users, themeController, context, resetPage);
  }

  void resetPage() {
    setState(() {
      _rowsPerPage = (_dataSource.filteredUsers.length < 10)
          ? _dataSource.filteredUsers.length
          : 10;
    });
  }


  @override
  Widget build(BuildContext context) {
    AppLocalizations lang = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    // double screenWidth = MediaQuery.of(context).size.width;
    var borderColor = themeController.isDarkMode ? colorGrey700 : colorGrey100;

    var titleTextStyle = theme.textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w500, color: colorGrey500);

    return Scaffold(
      backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: [
              const rf.Condition.between(start: 0, end: 340, value: 10),
              const rf.Condition.between(start: 341, end: 992, value: 16),
            ],
            defaultValue: 24,
          ).value,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: CommonSearchField(
                    controller: controller.searchController,
                    focusNode: controller.f1,
                    isDarkMode: themeController.isDarkMode,
                    onChanged: (query) {
                      setState(() {
                        _dataSource = UserDataSource(
                          _dataSource.originalUsers,  // Ensure latest user list
                          themeController,
                          context,
                          resetPage,
                        );
                        _dataSource.filterData(query);
                      });
                    },
                    inputDecoration: inputDecoration(context,
                        borderColor: Colors.transparent,
                        prefixIcon: searchIcon,
                        fillColor: Colors.transparent,
                        prefixIconColor: colorGrey400,
                        hintText: lang.translate("search"),
                        borderRadius: 8,
                        topContentPadding: 0,
                        bottomContentPadding: 0),
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
                IntrinsicWidth(
                  // width: 180,
                  // height: 45,
                  child: SizedBox(
                    height: 45,
                    child: CommonButtonWithIcon(
                      onPressed: () async {
                        final result = await showDialog<UserModel?>(
                          context: context,
                          builder: (context) => const AddNewUserDialog(),
                        );

                        if (result != null) {
                        }
                      },
                      text: lang.translate('addNewUser'),
                      icon: Icons.add,
                      backgroundColor: colorPrimary100,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 15,
            ),
            _dataSource.filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      lang.translate('noDataFound'),
                      style: titleTextStyle?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorPrimary100),
                    ),
                  )
                : LayoutBuilder(builder: (context, constraints) {
                    // bool isMobile = constraints.maxWidth < 600;
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            cardTheme: CardThemeData(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                                side: BorderSide(color: borderColor),
                              ),
                              color: themeController.isDarkMode
                                  ? colorGrey800
                                  : colorWhite,
                            ),
                            dividerColor: Colors.transparent,
                            dividerTheme: DividerThemeData(
                              color: borderColor,
                              space: 0,
                              thickness: 0,
                              indent: 0,
                              endIndent: 0,
                            ),
                          ),
                          child: PaginatedDataTable(
                            key: ValueKey(_dataSource),
                            // border: TableBorder.all(color: Colors.blue),
                            dataRowMaxHeight: 65,
                            headingRowColor: WidgetStatePropertyAll(
                                themeController.isDarkMode
                                    ? colorDark
                                    : colorGrey25),
                            // columnSpacing: 20,
                            headingRowHeight: 50,
                            // header: const Text("Employee Directory"),
                            rowsPerPage: _rowsPerPage,
                            // ✅ Dynamically set rowsPerPage

                            columns: [
                              DataColumn(
                                label: Text(
                                  lang.translate("name"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("designation"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("department"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("email"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("phoneNumber"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("status"),
                                  style: titleTextStyle,
                                ),
                              ),
                            ],
                            source: _dataSource,
                          ),
                        ),
                      ),
                    );
                  }),
            SizedBox(
              height: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class UserDataSource extends DataTableSource {
  final ThemeController themeController;
  final BuildContext context;

  List<UserModel> originalUsers;
  List<UserModel> filteredUsers;

  final VoidCallback resetPage; // ✅ Callback to reset pagination


  UserDataSource(this.originalUsers, this.themeController, this.context, this.resetPage)
      : filteredUsers = List.from(originalUsers);

  void filterData(String query) {
    if (query.isEmpty) {
      filteredUsers = List.from(originalUsers);
    } else {
      filteredUsers = originalUsers.where((user) {
        return user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase()) ||
            user.designation.toLowerCase().contains(query.toLowerCase()) ||
            user.department.toLowerCase().contains(query.toLowerCase()) ||
            user.phone.contains(query);
      }).toList();
    }

    resetPage();
    notifyListeners();

  }




  @override
  DataRow getRow(int index) {
    var cellDataTextStyle = TextStyle(
        fontWeight: FontWeight.w500,
        color: themeController.isDarkMode ? colorWhite : colorGrey900);

    if (filteredUsers.isEmpty) {
      return DataRow(cells: [
        DataCell(
            Center(
              child: Text(
                AppLocalizations.of(context).translate('noDataFound'),
                style: cellDataTextStyle.copyWith(color: colorPrimary100),
              ),
            ),
            placeholder: true),
        DataCell.empty,
        DataCell.empty,
        DataCell.empty,
        DataCell.empty,
        DataCell.empty,
      ]);
    }

    // if (index >= filteredUsers.length) return const DataRow(cells: []);

    final user = filteredUsers[index];
    return DataRow(
      color: WidgetStateProperty.all(
          themeController.isDarkMode ? colorGrey800 : colorWhite),
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(backgroundImage: AssetImage(user.imageUrl),),
              const SizedBox(width: 10),
              Text(user.name,
                  style:
                      cellDataTextStyle.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        DataCell(
          Text(user.designation, style: cellDataTextStyle),
        ),
        DataCell(
          Text(user.department, style: cellDataTextStyle),
        ),
        DataCell(
          Text(user.email, style: cellDataTextStyle),
        ),
        DataCell(
          Text(user.phone, style: cellDataTextStyle),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: user.status == "Active"
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              user.status,
              style: cellDataTextStyle.copyWith(
                color: user.status == "Active" ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount =>filteredUsers.length; // ✅ Keeps "No Data Found"

  @override
  int get selectedRowCount => 0;
}
