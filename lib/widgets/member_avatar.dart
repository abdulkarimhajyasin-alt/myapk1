import 'dart:io';

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../utils/avatar_utils.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    required this.member,
    this.radius = 20,
    super.key,
  });

  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = member.avatarImageUrl;
    final imagePath = member.avatarImagePath;
    final ImageProvider? backgroundImage = imageUrl?.isNotEmpty == true
        ? NetworkImage(imageUrl!)
        : imagePath?.isNotEmpty == true
            ? FileImage(File(imagePath!))
            : null;
    final foreground = ThemeData.estimateBrightnessForColor(
              AvatarUtils.colorFromHex(member.avatarColor),
            ) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AvatarUtils.colorFromHex(member.avatarColor),
      foregroundColor: foreground,
      backgroundImage: backgroundImage,
      child: imageUrl?.isNotEmpty == true || imagePath?.isNotEmpty == true
          ? null
          : Text(
              member.avatarInitials,
              style: TextStyle(
                fontSize: radius * 0.72,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
