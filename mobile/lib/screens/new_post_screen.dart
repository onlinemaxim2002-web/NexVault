import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';

import '../config.dart';
import '../models.dart';
import '../services/backend.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Creator posts videos/images to their approved channel.
class NewPostScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  const NewPostScreen({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _Picked {
  final PlatformFile file;
  final bool isVideo;
  Uint8List? thumbnail;
  PlatformFile?
  trailer; // optional short clip shown to ads users before they buy
  _Picked(this.file, this.isVideo);
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final List<_Picked> _files = [];
  List<Folder> _folders = [];
  String? _folderId;
  bool _posting = false;
  String? _progress;

  static const _videoExt = {'mp4', 'mov', 'm4v', 'webm', '3gp', 'mkv'};

  @override
  void initState() {
    super.initState();
    Backend.folders(widget.channelId).then((f) {
      if (mounted) setState(() => _folders = f);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.pickFiles(type: FileType.media);
    if (res.isEmpty) return;
    var tooBig = 0;
    for (final f in res) {
      final size = await fileSize(f);
      if (size > Config.maxUploadBytes) {
        tooBig++;
        continue;
      }
      final picked = _Picked(
        f,
        _videoExt.contains((f.extension ?? '').toLowerCase()),
      );
      // Images double as their own thumbnail (public bucket allows up to 10 MB).
      picked.thumbnail = picked.isVideo
          ? await _videoThumb(f)
          : (size <= 9 * 1024 * 1024 ? await f.readAsBytes() : null);
      _files.add(picked);
    }
    setState(() {});
    if (tooBig > 0 && mounted) {
      showSnack(context, '$tooBig file(s) skipped: larger than 50 MB.');
    }
  }

  Future<Uint8List?> _videoThumb(PlatformFile f) async {
    if (kIsWeb) return null;
    try {
      final usePath = f.path != null;
      return await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: usePath ? f.path! : f.uri.toString(),
        srcFileUri: !usePath,
        width: 480,
        height: 480,
        format: 'jpeg',
        quality: 75,
      );
    } catch (_) {
      return null; // The post still works without a thumbnail.
    }
  }

  Future<void> _pickTrailer(_Picked p) async {
    final f = await FilePicker.pickFile(type: FileType.video);
    if (f == null) return;
    if (await fileSize(f) > Config.maxUploadBytes) {
      if (mounted) showSnack(context, 'Trailer must be under 50 MB.');
      return;
    }
    setState(() => p.trailer = f);
  }

  Future<void> _newFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final folder = await Backend.createChannelFolder(
        widget.channelId,
        name,
        _folders.length,
      );
      setState(() {
        _folders = [..._folders, folder];
        _folderId = folder.id;
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  String _mime(PlatformFile f, bool isVideo) {
    final ext = (f.extension ?? '').toLowerCase();
    if (isVideo) {
      return ext == 'webm'
          ? 'video/webm'
          : (ext == 'mov' ? 'video/quicktime' : 'video/mp4');
    }
    return ext == 'png'
        ? 'image/png'
        : (ext == 'webp'
              ? 'image/webp'
              : (ext == 'gif' ? 'image/gif' : 'image/jpeg'));
  }

  Future<void> _post() async {
    if (_title.text.trim().isEmpty) {
      showSnack(context, 'Add a title.');
      return;
    }
    if (_files.isEmpty) {
      showSnack(context, 'Add at least one video or image.');
      return;
    }
    setState(() => _posting = true);
    try {
      final postId = await Backend.createPost(
        widget.channelId,
        _title.text.trim(),
        _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        folderId: _folderId,
      );
      for (var i = 0; i < _files.length; i++) {
        setState(() => _progress = 'Uploading ${i + 1} of ${_files.length}…');
        final p = _files[i];
        await Backend.addPostItem(
          postId: postId,
          position: i,
          kind: p.isVideo ? 'video' : 'image',
          bytes: await p.file.readAsBytes(),
          ext: (p.file.extension ?? (p.isVideo ? 'mp4' : 'jpg')).toLowerCase(),
          mime: _mime(p.file, p.isVideo),
          thumbnail: p.thumbnail,
          trailerBytes: p.trailer == null
              ? null
              : await p.trailer!.readAsBytes(),
          trailerExt: p.trailer?.extension?.toLowerCase(),
          trailerMime: p.trailer == null ? null : _mime(p.trailer!, true),
        );
      }
      if (!mounted) return;
      showSnack(context, 'Posted to ${widget.channelName}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.barGradient),
          child: SizedBox.expand(),
        ),
        title: const Text('New post'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
            maxLength: 120,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            decoration: const InputDecoration(
              labelText: 'Caption (emojis and #hashtags welcome)',
            ),
            maxLines: 3,
            maxLength: 1000,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _folderId,
                  decoration: const InputDecoration(labelText: 'Folder'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No folder'),
                    ),
                    for (final f in _folders)
                      DropdownMenuItem(value: f.id, child: Text(f.name)),
                  ],
                  onChanged: (v) => setState(() => _folderId = v),
                ),
              ),
              IconButton(
                tooltip: 'New folder',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: _newFolder,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _files)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 96,
                            height: 96,
                            child: p.thumbnail != null
                                ? Image.memory(p.thumbnail!, fit: BoxFit.cover)
                                : Container(
                                    color: const Color(0xFFEDEDED),
                                    child: Icon(
                                      p.isVideo ? Icons.videocam : Icons.image,
                                      color: Colors.black38,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkResponse(
                            onTap: _posting
                                ? null
                                : () => setState(() => _files.remove(p)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (p.isVideo)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(96, 32),
                        ),
                        onPressed: _posting ? null : () => _pickTrailer(p),
                        icon: Icon(
                          p.trailer == null ? Icons.add : Icons.check_circle,
                          size: 16,
                        ),
                        label: Text(
                          p.trailer == null ? 'Trailer' : 'Trailer ✓',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              InkWell(
                onTap: _posting ? null : _pick,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.primary,
                      ),
                      Text('Add', style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Videos (MP4) and images up to 50 MB each.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _posting ? null : _post,
            child: Text(_progress ?? (_posting ? 'Posting…' : 'Post')),
          ),
        ],
      ),
    );
  }
}
