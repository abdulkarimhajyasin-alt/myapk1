import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberAvatarPhoto {
  const MemberAvatarPhoto({
    required this.storagePath,
    required this.publicUrl,
  });

  final String storagePath;
  final String publicUrl;
}

class MemberAvatarPhotoException implements Exception {
  const MemberAvatarPhotoException(this.code, {this.technicalReason});

  final String code;
  final String? technicalReason;
}

abstract class MemberAvatarPhotoService {
  Future<MemberAvatarPhoto?> pickAndUpload({
    required String networkId,
    required String memberId,
    bool restorationComplete = false,
  });
}

class SupabaseMemberAvatarPhotoService implements MemberAvatarPhotoService {
  SupabaseMemberAvatarPhotoService({
    required SupabaseClient client,
    ImagePicker? picker,
  })  : _client = client,
        _picker = picker ?? ImagePicker();

  SupabaseMemberAvatarPhotoService.active()
      : _client = Supabase.instance.client,
        _picker = ImagePicker();

  static const bucketName = 'member-avatars';
  static const _memberIdKey = 'maskan_member_id';
  static const _maxFileSizeBytes = 1048576;

  final SupabaseClient _client;
  final ImagePicker _picker;

  @override
  Future<MemberAvatarPhoto?> pickAndUpload({
    required String networkId,
    required String memberId,
    bool restorationComplete = false,
  }) async {
    _log(
      'upload requested memberId=$memberId restorationComplete=$restorationComplete '
      'sessionExists=${_client.auth.currentSession != null} '
      'currentUserExists=${_client.auth.currentUser != null}',
    );
    final XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 78,
      );
    } on PlatformException catch (error) {
      if (_isPermissionDenied(error)) {
        throw const MemberAvatarPhotoException(
            'avatar_photo_permission_denied');
      }
      throw const MemberAvatarPhotoException('avatar_photo_pick_failed');
    } catch (_) {
      throw const MemberAvatarPhotoException('avatar_photo_pick_failed');
    }

    _log('picker result path=${image?.path ?? '<none>'}');
    if (image == null) throw _failure('avatar_photo_missing', 'no image');

    try {
      final bytes = await image.readAsBytes();
      final contentType = _contentTypeFor(image, bytes);
      final extension = _extensionFor(contentType);
      _log(
        'selected file path=${image.path} contentType=$contentType '
        'extension=$extension sizeBytes=${bytes.length} bucket=$bucketName',
      );
      if (bytes.isEmpty) {
        throw _failure('avatar_photo_missing', 'empty image bytes');
      }
      if (bytes.length > _maxFileSizeBytes) {
        throw _failure(
          'avatar_photo_too_large',
          'image is ${bytes.length} bytes; bucket limit is $_maxFileSizeBytes',
        );
      }

      _verifyExistingAuth(memberId);
      final version = DateTime.now().toUtc().millisecondsSinceEpoch;
      final storagePath =
          '${_safePathSegment(networkId)}/${_safePathSegment(memberId)}/'
          '$version.$extension';
      _log(
        'upload target bucket=$bucketName storagePath=$storagePath '
        'authUserId=${_client.auth.currentUser?.id ?? '<none>'} '
        'sessionExists=${_client.auth.currentSession != null}',
      );
      await _client.storage.from(bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: contentType,
              upsert: false,
            ),
          );
      return MemberAvatarPhoto(
        storagePath: storagePath,
        publicUrl: _client.storage.from(bucketName).getPublicUrl(storagePath),
      );
    } on MemberAvatarPhotoException {
      rethrow;
    } on StorageException catch (error, stackTrace) {
      _logSupabaseError('storage upload failed', error, stackTrace);
      throw _failure(_storageFailureCode(error), _storageReason(error));
    } on AuthException catch (error, stackTrace) {
      _logSupabaseError('auth metadata failed', error, stackTrace);
      throw _failure(
        'avatar_photo_upload_failed',
        _authReason(error),
      );
    } catch (error, stackTrace) {
      _logSupabaseError('avatar upload failed', error, stackTrace);
      throw _failure('avatar_photo_upload_failed', error.toString());
    }
  }

  void _verifyExistingAuth(String memberId) {
    _log(
      'auth before metadata authUserId=${_client.auth.currentUser?.id ?? '<none>'} '
      'sessionExists=${_client.auth.currentSession != null}',
    );
    if (_client.auth.currentSession == null ||
        _client.auth.currentUser == null) {
      throw _failure(
        'avatar_photo_auth_required',
        'missing existing Supabase session/user before avatar upload',
      );
    }
    final session = _client.auth.currentSession;
    final jwtMemberId = _jwtMetadataMemberId(session?.accessToken);
    _log(
      'auth verified authUserId=${_client.auth.currentUser?.id ?? '<none>'} '
      'sessionExists=${session != null} jwtMemberId=${jwtMemberId ?? '<none>'}',
    );
    if (jwtMemberId != memberId) {
      throw _failure(
        'avatar_photo_storage_permission_denied',
        'JWT $_memberIdKey is ${jwtMemberId ?? '<missing>'}',
      );
    }
  }

  static bool _isPermissionDenied(PlatformException error) {
    final code = error.code.toLowerCase();
    return code.contains('denied') ||
        code.contains('restricted') ||
        code.contains('permission');
  }

  static String _contentTypeFor(XFile image, Uint8List bytes) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType == 'image/png') return 'image/png';
    if (mimeType == 'image/webp') return 'image/webp';
    if (mimeType == 'image/jpg' || mimeType == 'image/jpeg') {
      return 'image/jpeg';
    }
    final nameParts = image.name.split('.');
    final extension =
        nameParts.length > 1 ? nameParts.last.toLowerCase() : null;
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    if (extension == 'jpg' || extension == 'jpeg') return 'image/jpeg';
    if (_looksLikePng(bytes)) return 'image/png';
    if (_looksLikeWebp(bytes)) return 'image/webp';
    if (_looksLikeJpeg(bytes)) return 'image/jpeg';
    return 'image/jpeg';
  }

  static String _extensionFor(String contentType) {
    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  static String _safePathSegment(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  static bool _looksLikeJpeg(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }

  static bool _looksLikePng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
  }

  static bool _looksLikeWebp(Uint8List bytes) {
    return bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  }

  static String? _jwtMetadataMemberId(String? accessToken) {
    if (accessToken == null) return null;
    final parts = accessToken.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final metadata = data['user_metadata'] as Map<String, dynamic>?;
      return metadata?[_memberIdKey] as String?;
    } catch (_) {
      return null;
    }
  }

  static MemberAvatarPhotoException _failure(
    String code,
    String technicalReason,
  ) {
    _log('failure code=$code reason=$technicalReason');
    return MemberAvatarPhotoException(code, technicalReason: technicalReason);
  }

  static String _storageFailureCode(StorageException error) {
    final reason = _storageReason(error).toLowerCase();
    if (error.statusCode == '404' ||
        reason.contains('bucket not found') ||
        reason.contains('not found')) {
      return 'avatar_photo_storage_not_configured';
    }
    if (error.statusCode == '401' ||
        error.statusCode == '403' ||
        reason.contains('row-level security') ||
        reason.contains('violates row-level security') ||
        reason.contains('unauthorized') ||
        reason.contains('forbidden')) {
      return 'avatar_photo_storage_permission_denied';
    }
    return 'avatar_photo_upload_failed';
  }

  static String _storageReason(StorageException error) {
    return [
      'message=${error.message}',
      if (error.error != null) 'code=${error.error}',
      if (error.statusCode != null) 'status=${error.statusCode}',
    ].join(' ');
  }

  static String _authReason(AuthException error) {
    return [
      'message=${error.message}',
      if (error.code != null) 'code=${error.code}',
      if (error.statusCode != null) 'status=${error.statusCode}',
    ].join(' ');
  }

  static void _log(String message) {
    developer.log(message, name: 'maskan.avatar');
  }

  static void _logSupabaseError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      '$message ${_supabaseErrorDetails(error)}',
      name: 'maskan.avatar',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _supabaseErrorDetails(Object error) {
    if (error is StorageException) {
      return 'message=${error.message} code=${error.error} '
          'details=null hint=null status=${error.statusCode}';
    }
    if (error is PostgrestException) {
      return 'message=${error.message} code=${error.code} '
          'details=${error.details} hint=${error.hint}';
    }
    if (error is AuthException) {
      return 'message=${error.message} code=${error.code} '
          'details=null hint=null status=${error.statusCode}';
    }
    return 'message=$error code=null details=null hint=null';
  }
}
