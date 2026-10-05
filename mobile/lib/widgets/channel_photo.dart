import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backend.dart';
import '../theme.dart';
import 'common.dart';

/// Lets a channel's creator pick a new channel photo (DP) and saves it.
/// Returns true when the photo was changed.
Future<bool> changeChannelPhoto(BuildContext context, Channel channel) async {
  final f = await FilePicker.pickFile(type: FileType.image);
  if (f == null || !context.mounted) return false;
  if (await fileSize(f) > 5 * 1024 * 1024) {
    if (context.mounted) {
      showSnack(context, 'Please choose an image under 5 MB.');
    }
    return false;
  }
  final bytes = await f.readAsBytes();
  final ext = (f.extension ?? 'jpg').toLowerCase();
  final mime = ext == 'png'
      ? 'image/png'
      : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
  if (!context.mounted) return false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final url = await Backend.uploadChannelIcon(bytes, ext, mime);
    await Backend.updateChannelIcon(channel.id, url);
    if (context.mounted) {
      Navigator.of(context).pop();
      showSnack(context, 'Channel photo updated.');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      showSnack(context, friendlyError(e));
    }
    return false;
  }
}

/// Channel avatar with a small camera badge; tapping it changes the photo.
class EditableChannelAvatar extends StatelessWidget {
  final Channel channel;
  final double size;
  final VoidCallback onChanged;
  const EditableChannelAvatar({
    super.key,
    required this.channel,
    required this.onChanged,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change channel photo',
      child: GestureDetector(
        onTap: () async {
          if (await changeChannelPhoto(context, channel)) onChanged();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ChannelAvatar(url: channel.iconUrl, name: channel.name, size: size),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: size * 0.28,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
