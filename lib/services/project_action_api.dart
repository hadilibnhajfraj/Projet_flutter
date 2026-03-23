import 'dart:io';
import 'package:flutter/foundation.dart'; // IMPORTANT
import 'package:dio/dio.dart';
import '../../../providers/api_client.dart';

class ProjectActionApi {

  static final ProjectActionApi instance = ProjectActionApi();

  Future createAction({
    required String projectId,
    required String type,
    String? commentaire,
    String? dateRelance,
    dynamic file
  }) async {

    MultipartFile? multipartFile;

    if (file != null) {

      /// =========================
      /// WEB
      /// =========================
      if (kIsWeb) {

        final bytes = file.bytes; // ✅ IMPORTANT (FilePicker)

        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        );

      } else {

        /// =========================
        /// MOBILE / DESKTOP
        /// =========================
        multipartFile = await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        );
      }
    }

    final formData = FormData.fromMap({

      "typeAction": type,
      "commentaire": commentaire,
      "dateRelance": dateRelance,

      if (multipartFile != null)
        "file": multipartFile,

    });

    await ApiClient.instance.dio.post(
      "/projects/$projectId/actions",
      data: formData,
    );
  }
}