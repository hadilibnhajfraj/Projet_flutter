import 'package:dash_master_toolkit/application/users/users_imports.dart';

class UserProfileController extends GetxController {
  TextEditingController searchController = TextEditingController();
  FocusNode f1 = FocusNode();

  Rx<ProfileModel?> profile = Rx<ProfileModel?>(null);

  @override
  void onInit() {
    super.onInit();

    loadProfile();
  }

  void loadProfile() {
    profile.value = ProfileModel(
      name: 'Sara Smith GC',
      designation: 'Software Developer',
      email: 'sarasmith@wave.com',
      birthday: '18 Aug 1990',
      phone: '+13456789012',
      country: 'United States of America',
      state: 'West Virginia',
      address: 'Baker Street No.6',
      occupationType: [
        OccupationModel(
            icon: 'https://i.ibb.co/nNbQfC1Z/clock.png', type: 'Full-Time'),
        OccupationModel(
            icon: 'https://i.ibb.co/934cZDqB/code.png', type: 'Engineering'),
        OccupationModel(
            icon: 'https://i.ibb.co/gZV86Qdt/global-search.png',
            type: 'Seattle, WA'),
        OccupationModel(
            icon: 'https://i.ibb.co/1Yc2cpgN/coding-2.png', type: 'Engineering')
      ],
      department: 'Engineering',
      location: 'Seattle, WA',
      about:
          'Presentations about company initiatives product launches, and employee successes. You can also find information about upcoming events training opportunities and resource for your work.',
      activities: [
        ActivityModel(
            deviceName: 'MacOS',
            status: 'Active now',
            imei: '324123543126',
            icon: "https://i.ibb.co/Zv7bhP3/shop.png",
            isActive: false),
        ActivityModel(
            deviceName: 'iPhone 14pro max',
            status: 'Active now',
            imei: '324123543126',
            icon: "https://i.ibb.co/Zv7bhP3/shop.png",
            isActive: true),
        ActivityModel(
            deviceName: 'iPhone 14pro max',
            status: 'Active now',
            imei: '324123543126',
            icon: "https://i.ibb.co/Zv7bhP3/shop.png",
            isActive: true),
        ActivityModel(
            deviceName: 'iPhone 14pro max',
            status: 'Active now',
            icon: "https://i.ibb.co/Zv7bhP3/shop.png",
            imei: '324123543126',
            isActive: true),
        ActivityModel(
            deviceName: 'iPhone 14pro max',
            status: 'Active now',
            imei: '324123543126',
            icon: "https://i.ibb.co/Zv7bhP3/shop.png",
            isActive: true),
        ActivityModel(
            deviceName: 'iPhone 14pro max',
            status: 'Active now',
            imei: '324123543126',
            icon: "https://i.ibb.co/Zv7bhP3/shop.png",
            isActive: true),
        ActivityModel(
            deviceName: 'iPhone 14pro max',
            status: 'Active now',
            imei: '324123543126',
            icon: "https://i.ibb.co/Zv7bhP3/shop.png",
            isActive: true),
      ],
      experiences: [
        ExperienceModel(
            company: 'Trendyol.com',
            position: 'Front-End Developer',
            duration: '2 years',
            type: 'Fulltime',
            icon: 'https://i.ibb.co/qMbDkcJR/netflix-1.png'),
        ExperienceModel(
            company: 'TiklaGelsin',
            position: 'Front-End Developer',
            duration: '2 years',
            type: 'Internship',
            icon: 'https://i.ibb.co/qMbDkcJR/netflix-1.png'),
        ExperienceModel(
            company: 'TiklaGelsin',
            position: 'Front-End Developer',
            duration: '2 years',
            type: 'Internship',
            icon: 'https://i.ibb.co/qMbDkcJR/netflix-1.png'),
      ],
    );
  }
}
