import 'bottom_bar_surface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../data/memo_store.dart';
import '../models/attachment.dart';
import '../theme/palette.dart';
import 'resizable_block.dart';

/// 메모 안에 놓인 첨부들. 줄 하나 바로 아래([entryId])나, 놓인 줄이 없거나
/// 지워졌다면 글 맨 끝([entryId] 가 null)에 그린다.
///
/// 사진과 동영상은 메모 안에 그대로 보이고 손잡이를 끌어 크기를 바꾼다.
/// 그 밖의 파일은 이름과 크기를 적은 한 줄짜리 카드다.
class InlineAttachments extends StatelessWidget {
  const InlineAttachments({
    super.key,
    required this.boardId,
    required this.ink,
    this.entryId,
  });

  final String boardId;
  final Color ink;
  final String? entryId;

  @override
  Widget build(BuildContext context) {
    final store = MemoStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final list = entryId == null
            ? store.attachmentsAtEnd(boardId)
            : store.attachmentsAfter(boardId, entryId!);
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in list)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: a.isMedia
                    ? _MediaBlock(key: ValueKey(a.id), attachment: a, ink: ink)
                    : _FileCard(key: ValueKey(a.id), attachment: a, ink: ink),
              ),
          ],
        );
      },
    );
  }
}

void _say(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// 첨부를 지우고, 되돌릴 길을 잠깐 남긴다.
void _removeAttachment(BuildContext context, Attachment attachment) {
  final store = MemoStore.instance;
  store.setAttachmentDeleted(attachment, true);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('첨부를 삭제했어요'),
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: () => store.setAttachmentDeleted(attachment, false),
      ),
    ),
  );
}

/// 기기의 다른 앱(사진 앱, 파일 앱 …)으로 연다.
Future<void> _openOutside(BuildContext context, Attachment attachment) async {
  try {
    final file = MemoStore.instance.attachmentFile(attachment);
    if (!await file.exists()) {
      if (context.mounted) {
        _say(context, '첨부 파일을 찾을 수 없어요. 다시 첨부해 주세요.');
      }
      return;
    }
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && context.mounted) {
      _say(context, '이 파일을 열 수 있는 앱을 찾지 못했어요.');
    }
  } catch (_) {
    if (context.mounted) _say(context, '파일을 열지 못했어요. 잠시 후 다시 시도해 주세요.');
  }
}

/// 사진을 화면 가득 펼쳐 확대해 본다.
Future<void> _openPhoto(BuildContext context, Attachment attachment) {
  final file = MemoStore.instance.attachmentFile(attachment);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(attachment.name),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: .5,
            maxScale: 5,
            child: Image.file(
              file,
              errorBuilder: (_, _, _) => TextButton.icon(
                onPressed: () => _openOutside(context, attachment),
                icon: const Icon(Icons.open_in_new),
                label: const Text('다른 앱으로 열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 사진이나 동영상 한 장. 모서리 손잡이로 크기를 바꾸고 오른쪽 위 ✕ 로 지운다.
class _MediaBlock extends StatelessWidget {
  const _MediaBlock({super.key, required this.attachment, required this.ink});

  final Attachment attachment;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final store = MemoStore.instance;
    return ResizableBlock(
      fraction: attachment.widthFraction,
      onResized: (v) => store.setAttachmentLayout(attachment, widthFraction: v),
      builder: (context, width, max) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (attachment.kind == 'image')
              _Photo(
                attachment: attachment,
                width: width,
                maxWidth: max,
                ink: ink,
              )
            else
              _Clip(attachment: attachment, width: width, ink: ink),
            Positioned(
              top: 4,
              right: 4,
              child: _RoundAction(
                icon: Icons.close_rounded,
                label: '${attachment.name} 삭제',
                onTap: () => _removeAttachment(context, attachment),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 미디어 위에 얹는 작은 동그란 단추.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xCC000000),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    ),
  );
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.attachment,
    required this.width,
    required this.maxWidth,
    required this.ink,
  });

  final Attachment attachment;
  final double width;
  final double maxWidth;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final file = MemoStore.instance.attachmentFile(attachment);
    // 끄는 내내 다시 풀지 않도록, 가장 크게 늘렸을 때의 크기로 한 번만 푼다.
    final decode = (maxWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return GestureDetector(
      onTap: () => _openPhoto(context, attachment),
      child: Image.file(
        file,
        width: width,
        fit: BoxFit.fitWidth,
        cacheWidth: decode,
        errorBuilder: (_, _, _) => _Missing(width: width, ink: ink),
      ),
    );
  }
}

/// 파일이 없거나 풀 수 없을 때의 자리.
class _Missing extends StatelessWidget {
  const _Missing({required this.width, required this.ink});

  final double width;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * .6,
    color: Colors.black.withValues(alpha: .06),
    alignment: Alignment.center,
    child: Icon(Icons.broken_image_outlined, color: ink.withValues(alpha: .6)),
  );
}

/// 메모 안에서 바로 재생하는 동영상. 누르면 재생하고 다시 누르면 멈춘다.
class _Clip extends StatefulWidget {
  const _Clip({
    required this.attachment,
    required this.width,
    required this.ink,
  });

  final Attachment attachment;
  final double width;
  final Color ink;

  @override
  State<_Clip> createState() => _ClipState();
}

class _ClipState extends State<_Clip> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final file = MemoStore.instance.attachmentFile(widget.attachment);
    try {
      if (!await file.exists()) throw StateError('missing');
      final video = VideoPlayerController.file(file);
      _video = video;
      await video.initialize();
      // 소리 없이 시작하는 것이 아니라, 누르기 전에는 첫 장면만 보인다.
      await video.setLooping(false);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    if (_failed) return _Missing(width: widget.width, ink: widget.ink);
    if (video == null || !video.value.isInitialized) {
      return Container(
        width: widget.width,
        height: widget.width * 9 / 16,
        color: Colors.black.withValues(alpha: .12),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      child: AspectRatio(
        aspectRatio: video.value.aspectRatio == 0
            ? 16 / 9
            : video.value.aspectRatio,
        child: GestureDetector(
          onTap: () {
            video.value.isPlaying ? video.pause() : video.play();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(video),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: video,
                builder: (context, v, _) => v.isPlaying
                    ? const SizedBox.shrink()
                    : Center(
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: _RoundAction(
                  icon: Icons.fullscreen_rounded,
                  label: '${widget.attachment.name} 크게 보기',
                  onTap: () => _openOutside(context, widget.attachment),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 사진·동영상이 아닌 파일. 이름과 크기를 한 줄로 보이고 누르면 연다.
class _FileCard extends StatelessWidget {
  const _FileCard({super.key, required this.attachment, required this.ink});

  final Attachment attachment;
  final Color ink;

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .35),
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _openOutside(context, attachment),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.insert_drive_file_outlined, color: ink),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: ink),
                  ),
                  Text(
                    _size(attachment.size),
                    style: TextStyle(
                      fontSize: 11,
                      color: ink.withValues(alpha: .65),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '${attachment.name} 첨부 삭제',
              onPressed: () => _removeAttachment(context, attachment),
              icon: Icon(Icons.close_rounded, size: 18, color: ink),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Fixed bottom actions, matching the library search surface.
class MemoAttachmentBar extends StatefulWidget {
  const MemoAttachmentBar({
    super.key,
    required this.boardId,
    required this.bg,
    required this.onDelete,
  });
  final String boardId;
  final BackgroundTheme bg;
  final VoidCallback onDelete;

  @override
  State<MemoAttachmentBar> createState() => _MemoAttachmentBarState();
}

class _MemoAttachmentBarState extends State<MemoAttachmentBar> {
  final store = MemoStore.instance;
  bool _busy = false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick(FileType type) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final boardId = widget.boardId;
    // 파일 고르는 창이 뜨기 전에 정한다. 창이 떠 있는 동안 줄이 바뀌어도
    // 처음 커서가 있던 줄 아래에 놓인다.
    final afterEntryId = store.entryForNewAttachment(boardId);
    setState(() => _busy = true);
    var added = 0;
    try {
      final files = await FilePicker.pickFiles(type: type);
      for (final file in files) {
        final ext = (file.extension ?? '').toLowerCase();
        final kind =
            type == FileType.image ||
                {
                  'jpg',
                  'jpeg',
                  'png',
                  'gif',
                  'webp',
                  'heic',
                  'heif',
                  'bmp',
                }.contains(ext)
            ? 'image'
            : type == FileType.video ||
                  {'mp4', 'mov', 'm4v', 'avi', 'webm', 'mkv'}.contains(ext)
            ? 'video'
            : 'file';
        await store.addAttachment(
          boardId: boardId,
          name: file.name,
          kind: kind,
          bytes: file.readAsByteStream(),
          afterEntryId: afterEntryId,
        );
        added++;
      }
    } catch (_) {
      _message(
        added == 0
            ? '첨부하지 못했어요. 파일을 다시 선택해 주세요.'
            : '$added개를 첨부했어요. 나머지 파일은 다시 선택해 주세요.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.bg;
    final ink = bg.onBackground.withValues(alpha: .75);
    Widget action(IconData icon, String label, VoidCallback onTap) =>
        IconButton(
          tooltip: label,
          onPressed: _busy ? null : onTap,
          style: IconButton.styleFrom(
            foregroundColor: ink,
            backgroundColor: bg.isDark
                ? Colors.white.withValues(alpha: .08)
                : Colors.white.withValues(alpha: .65),
            shape: const CircleBorder(),
            // 바 높이(50)에 여백이 넉넉히 남도록. 목록 검색칸의 안쪽과 같은 인상.
            fixedSize: const Size(36, 36),
          ),
          icon: Icon(icon, size: 19),
        );
    return BottomBarSurface(
      bg: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (_busy)
            const SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            action(
              Icons.photo_library_outlined,
              '사진·동영상 첨부',
              () => _pick(FileType.media),
            ),
          action(Icons.attach_file_rounded, '파일 첨부', () => _pick(FileType.any)),
          action(Icons.delete_outline_rounded, '메모 삭제', () {
            FocusManager.instance.primaryFocus?.unfocus();
            widget.onDelete();
          }),
        ],
      ),
    );
  }
}
