import 'package:dash_master_toolkit/application/users/users_imports.dart';

import 'package:responsive_framework/responsive_framework.dart' as rf;

class UserGridScreen extends StatefulWidget {
  const UserGridScreen({super.key});

  @override
  State<UserGridScreen> createState() => _UserGridScreenState();
}

class _UserGridScreenState extends State<UserGridScreen> {
  final UserGridController controller = Get.put(UserGridController());
  ThemeController themeController = Get.put(ThemeController());

  @override
  Widget build(BuildContext context) {
    AppLocalizations lang = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    // double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: [
              const rf.Condition.between(start: 0, end: 340, value: 10),
              const rf.Condition.between(start: 341, end: 992, value: 10),
            ],
            defaultValue: 10,
          ).value,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:  EdgeInsetsDirectional.only(start: 10.0,end: 10.0),
              child: CommonSearchField(
                controller: controller.searchController,
                focusNode: controller.f1,
                isDarkMode: themeController.isDarkMode,
                onChanged: (query) {
                  controller.searchUser(query);
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
              height: 15,
            ),
            Obx(
              () {
                return ResponsiveGridRow(
                  // crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(
                    controller.filteredUsersList.length,
                    (index) {
                      return ResponsiveGridCol(
                        lg: 4,
                        xl: 4,
                        md: 4,
                        xs: 12,
                        child: Padding(
                          padding:  EdgeInsetsDirectional.only(top: 20.0,start: 10.0,end: 10.0),
                          child: _buildUserCard(controller.filteredUsersList[index], theme),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(
              height: 15,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserGridData user, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeController.isDarkMode ? colorDark : colorWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Star Rating
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text("${user.rating}",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),),
                    const SizedBox(width: 5),
                    Icon(Icons.star, color: Colors.orange, size: 16),
                  ],
                ),
              ),
              Spacer(),
              Icon(Icons.more_vert),
            ],
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(user.imageUrl),
          ),
          const SizedBox(height: 8),
          Text(
            user.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            user.email,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorGrey500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text("Category",
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: colorGrey500, fontWeight: FontWeight.w500),),
                  Text(user.category,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.blue,fontWeight: FontWeight.w500),),
                ],
              ),
              Column(
                children: [
                  Text("Amount",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorGrey500,fontWeight: FontWeight.w500)),
                  Text("\$${user.amount}",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.green,fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.email, size: 16,color: themeController.isDarkMode ? colorWhite : colorGrey900,),
                label: Text("Email",style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500,
                ),),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.call, size: 16),
                label: Text("Call",style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500,color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary100,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
