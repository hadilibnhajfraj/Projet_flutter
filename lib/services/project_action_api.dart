// lib/services/project_action_api.dart
//
// Sends a project action to POST /projects/:id/actions.
//
// Content-Type is NOT set manually — ApiClient's interceptor strips any
// stale Content-Type header when the data is FormData, letting Dio generate
// the correct "multipart/form-data; boundary=<uuid>" automatically.
//
// Fields are added via fd.fields.addAll() (MapEntry<String,String>) so
// every field arrives as a proper multipart text part — no null ambiguity.

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart' as dio;

import '../providers/api_client.dart';

class ProjectActionApi {
  static final ProjectActionApi instance = ProjectActionApi._();
  ProjectActionApi._();

  Future<dynamic> createAction({
    required String projectId,
    required String type,
    String? commentaire,
    // ISO-8601 string; must represent a datetime strictly after now.
    String? dateRelance,
    dynamic file, // PlatformFile (web) or File (native)
  }) async {
    dio.MultipartFile? multipartFile;

    if (file != null) {
      if (kIsWeb) {
        if (file.bytes == null) throw Exception('File bytes is null (Web)');
        multipartFile = dio.MultipartFile.fromBytes(
          file.bytes as List<int>,
          filename: file.name as String,
        );
      } else {
        multipartFile = await dio.MultipartFile.fromFile(
          file.path as String,
          filename: (file.path as String).split('/').last,
        );
      }
    }

    // Build FormData with explicit field entries — no FormData.fromMap() so
    // null values can never silently become missing multipart parts.
    final fd = dio.FormData();
    fd.fields.addAll([
      MapEntry('typeAction',        type),
      MapEntry('typeAction_legacy', type),
      MapEntry('firstAction',       type),
      MapEntry('commentaire',       commentaire ?? ''),
      if (dateRelance != null)
        MapEntry('dateRelance',     dateRelance),
    ]);
    if (multipartFile != null) {
      fd.files.add(MapEntry('file', multipartFile));
    }

    // Do NOT pass Options(headers: {'Content-Type': ...}) — the global
    // ApiClient interceptor already handles this correctly for FormData.
    final response = await ApiClient.instance.dio.post(
      '/projects/$projectId/actions',
      data: fd,
    );

    return response.data;
  }
}
