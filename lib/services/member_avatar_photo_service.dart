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
  const MemberAvatarPhotoException(this.code);

  final String code;
}

abstract class MemberAvatarPhotoService {
  Future<MemberAvatarPhoto?> pickAndUpload({
    required String networkId,
    required String memberId,
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

  final SupabaseClient _client;
  final ImagePicker _picker;

  @override
  Future<MemberAvatarPhoto?> pickAndUpload({
    required String networkId,
    required String memberId,
  }) async {
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
        throw const MemberAvatarPhotoException('avatar_photo_permission_denied');
      }
      throw const MemberAvatarPhotoException('avatar_photo_pick_failed');
    } catch (_) {
      throw const MemberAvatarPhotoException('avatar_photo_pick_failed');
    }

    if (image == null) return null;

    try {
      await _ensureAuthMetadata(memberId);
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        throw const MemberAvatarPhotoException('avatar_photo_upload_failed');
      }
      final contentType = _contentTypeFor(image);
      final extension = _extensionFor(contentType);
      final version = DateTime.now().toUtc().millisecondsSinceEpoch;
      final storagePath =
          '${_safePathSegment(networkId)}/${_safePathSegment(memberId)}/'
          '$version.$extension';
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
    } catch (_) {
      throw const MemberAvatarPhotoException('avatar_photo_upload_failed');
    }
  }

  Future<void> _ensureAuthMetadata(String memberId) async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
    final currentMemberId =
        _client.auth.currentUser?.userMetadata?[_memberIdKey] as String?;
    if (currentMemberId == memberId) return;
    await _client.auth.updateUser(
      UserAttributes(data: {_memberIdKey: memberId}),
    );
  }

  static bool _isPermissionDenied(PlatformException error) {
    final code = error.code.toLowerCase();
    return code.contains('denied') ||
        code.contains('restricted') ||
        code.contains('permission');
  }

  static String _contentTypeFor(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType == 'image/png') return 'image/png';
    if (mimeType == 'image/webp') return 'image/webp';
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
}
