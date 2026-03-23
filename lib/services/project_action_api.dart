import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart' as dio;
import '../../../providers/api_client.dart';

class ProjectActionApi {

  static final ProjectActionApi instance = ProjectActionApi();

  Future createAction({
    required String projectId,
    required String type,
    String? commentaire,
    String? dateRelance,
    dynamic file,
  }) async {

    dio.MultipartFile? multipartFile;

    try {

      /// =========================
      /// FILE HANDLING
      /// =========================
      if (file != null) {

        /// WEB
        if (kIsWeb) {

          if (file.bytes == null) {
            throw Exception("File bytes is null (Web)");
          }

          print("🌐 WEB FILE => ${file.name}");
          print("📦 BYTES => ${file.bytes.length}");

          multipartFile = dio.MultipartFile.fromBytes(
            file.bytes,
            filename: file.name,
          );

        } else {

          /// MOBILE / DESKTOP
          print("📱 FILE PATH => ${file.path}");

          multipartFile = await dio.MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          );
        }
      }

      /// =========================
      /// FORM DATA
      /// =========================
      final formData = dio.FormData.fromMap({

        "typeAction": type,
        "commentaire": commentaire ?? "",
        "dateRelance": dateRelance,

        if (multipartFile != null)
          "file": multipartFile,

      });

      print("🚀 SEND ACTION...");
      print("typeAction => $type");
      print("commentaire => $commentaire");
      print("dateRelance => $dateRelance");

      /// =========================
      /// API CALL
      /// =========================
      final response = await ApiClient.instance.dio.post(
        "/projects/$projectId/actions",
        data: formData,
        options: dio.Options(
          headers: {
            "Content-Type": "multipart/form-data",
          },
        ),
      );

      print("✅ ACTION CREATED => ${response.data}");

      return response.data;

    } catch (e) {

      print("❌ CREATE ACTION ERROR => $e");

      rethrow;
    }
  }
}