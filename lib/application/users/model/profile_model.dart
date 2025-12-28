import '../users_imports.dart';

class ProfileModel {
  final String name;
  final String designation;
  final String email;
  final String birthday;
  final String phone;
  final String country;
  final String state;
  final String address;
  final List<OccupationModel> occupationType;
  final String department;
  final String location;
  final String about;
  final List<ActivityModel> activities;
  final List<ExperienceModel> experiences;

  ProfileModel({
    required this.name,
    required this.designation,
    required this.email,
    required this.birthday,
    required this.phone,
    required this.country,
    required this.state,
    required this.address,
    required this.occupationType,
    required this.department,
    required this.location,
    required this.about,
    required this.activities,
    required this.experiences,
  });
}

class ActivityModel {
  final String deviceName;
  final String status;
  final String imei;
  final String icon;
  RxBool isActive = false.obs;

  ActivityModel(
      {required this.deviceName,
      required this.status,
      required this.imei,
      required this.icon,
      bool isActive = false})
      : isActive = isActive.obs;
}

class ExperienceModel {
  final String company;
  final String position;
  final String duration;
  final String type;
  final String icon;

  ExperienceModel({
    required this.company,
    required this.position,
    required this.duration,
    required this.type,
    required this.icon,
  });
}

class OccupationModel {
  final String icon;
  final String type;

  OccupationModel({
    required this.icon,
    required this.type,
  });
}
