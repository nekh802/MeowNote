import 'dart:async';

import 'bottom_bar_surface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../data/memo_store.dart';
import '../l10n.dart';
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
            for (var i = 0; i < list.length; i++)
              _ReorderSlot(
                key: ValueKey('slot-${list[i].id}'),
                attachment: list[i],
                next: i + 1 < list.length ? list[i + 1] : null,
                entryId: entryId,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: list[i].isMedia
                      ? _MediaBlock(
                          key: ValueKey(list[i].id),
                          attachment: list[i],
                          ink: ink,
                        )
                      : _FileCard(
                          key: ValueKey(list[i].id),
                          attachment: list[i],
                          ink: ink,
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 첨부 하나 위에 다른 첨부를 놓으면 그 앞(위쪽 절반)이나 뒤(아래쪽 절반)로
/// 끼워 넣는다. 같은 줄 아래 여러 장의 차례를 바꾸는 자리다.
class _ReorderSlot extends StatefulWidget {
  const _ReorderSlot({
    super.key,
    required this.attachment,
    required this.next,
    required this.entryId,
    required this.child,
  });

  final Attachment attachment;
  final Attachment? next;
  final String? entryId;
  final Widget child;

  @override
  State<_ReorderSlot> createState() => _ReorderSlotState();
}

class _ReorderSlotState extends State<_ReorderSlot> {
  bool _after = false;

  /// 손가락이 이 칸의 아래쪽 절반에 있는지. 끄는 그림은 손가락이 한가운데다.
  bool _isLowerHalf(DragTargetDetails<Attachment> d) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return false;
    return box.globalToLocal(d.offset + const Offset(56, 56)).dy >
        box.size.height / 2;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DragTarget<Attachment>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (d) =>
          d.data.boardId == widget.attachment.boardId &&
          !identical(d.data, widget.attachment),
      onMove: (d) {
        final after = _isLowerHalf(d);
        if (after != _after) setState(() => _after = after);
      },
      onAcceptWithDetails: (d) => MemoStore.instance.moveAttachment(
        d.data,
        widget.entryId,
        before: _isLowerHalf(d) ? widget.next : widget.attachment,
      ),
      builder: (context, candidate, _) {
        final line = BorderSide(width: 4, color: primary);
        final active = candidate.isNotEmpty;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(
              top: active && !_after ? line : BorderSide.none,
              bottom: active && _after ? line : BorderSide.none,
            ),
          ),
          child: widget.child,
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
      content: Text(
        tr(
          context,
          '첨부를 삭제했어요',
          en: 'Attachment removed',
          zh: '已删除附件',
          fr: 'Pièce jointe supprimée',
          ja: '添付を削除しました',
        ),
      ),
      action: SnackBarAction(
        label: tr(
          context,
          '되돌리기',
          en: 'Undo',
          zh: '撤销',
          fr: 'Annuler',
          ja: '元に戻す',
        ),
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
        _say(
          context,
          tr(
            context,
            '첨부 파일을 찾을 수 없어요. 다시 첨부해 주세요.',
            en: "Couldn't find the attached file. Please attach it again.",
            zh: '找不到附件文件，请重新添加。',
            fr: 'Fichier joint introuvable. Veuillez le rajouter.',
            ja: '添付ファイルが見つかりません。もう一度添付してください。',
          ),
        );
      }
      return;
    }
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && context.mounted) {
      _say(
        context,
        tr(
          context,
          '이 파일을 열 수 있는 앱을 찾지 못했어요.',
          en: 'No app found to open this file.',
          zh: '找不到可以打开此文件的应用。',
          fr: 'Aucune app ne peut ouvrir ce fichier.',
          ja: 'このファイルを開けるアプリが見つかりませんでした。',
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      _say(
        context,
        tr(
          context,
          '파일을 열지 못했어요. 잠시 후 다시 시도해 주세요.',
          en: 'Could not open the file. Please try again shortly.',
          zh: '无法打开文件，请稍后再试。',
          fr: "Impossible d'ouvrir le fichier. Réessayez dans un instant.",
          ja: 'ファイルを開けませんでした。しばらくしてからもう一度お試しください。',
        ),
      );
    }
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
                label: Text(
                  tr(
                    context,
                    '다른 앱으로 열기',
                    en: 'Open in another app',
                    zh: '用其他应用打开',
                    fr: 'Ouvrir dans une autre app',
                    ja: '別のアプリで開く',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 첨부를 끌어다 놓을 수 있는 자리. 줄 하나와 그 아래 첨부들을 감싸, 그 위에
/// 놓으면 첨부가 이 줄 바로 아래로 옮겨 온다. [entryId] 가 null 이면 글 맨 끝이다.
class AttachmentDropZone extends StatelessWidget {
  const AttachmentDropZone({
    super.key,
    required this.boardId,
    required this.child,
    this.entryId,
  });

  final String boardId;
  final String? entryId;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<Attachment>(
    hitTestBehavior: HitTestBehavior.opaque,
    onWillAcceptWithDetails: (d) => d.data.boardId == boardId,
    onAcceptWithDetails: (d) {
      // 이미 이 줄 아래에 있으면 그대로 둔다. 차례는 사진 위에 놓아 바꾼다.
      if (d.data.afterEntryId == entryId) return;
      MemoStore.instance.moveAttachment(d.data, entryId);
    },
    builder: (context, candidate, _) => DecoratedBox(
      // 놓일 자리에는 아래쪽에 가는 줄을 그어 알린다.
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 4,
            color: candidate.isEmpty
                ? Colors.transparent
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      child: child,
    ),
  );
}

/// 사진이나 동영상 한 장. 모서리 손잡이로 크기를 바꾸고 오른쪽 위 ✕ 로 지운다.
/// 꾹 눌러 끌면 다른 줄 아래로 옮길 수 있다.
class _MediaBlock extends StatefulWidget {
  const _MediaBlock({super.key, required this.attachment, required this.ink});

  final Attachment attachment;
  final Color ink;

  @override
  State<_MediaBlock> createState() => _MediaBlockState();
}

class _MediaBlockState extends State<_MediaBlock> {
  Timer? _scroller;
  Offset? _finger;

  /// 끄는 손가락이 화면 위·아래 끝에 가까우면 글을 따라 밀어 준다.
  void _startAutoScroll() {
    _scroller?.cancel();
    _scroller = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final finger = _finger;
      if (finger == null || !mounted) return;
      final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
      final box = scrollable?.context.findRenderObject();
      if (scrollable == null || box is! RenderBox) return;
      const edge = 120.0;
      final y = box.globalToLocal(finger).dy;
      final double step;
      if (y < edge) {
        step = -(edge - y) / edge * 20;
      } else if (y > box.size.height - edge) {
        step = (y - (box.size.height - edge)) / edge * 20;
      } else {
        return;
      }
      final p = scrollable.position;
      p.jumpTo((p.pixels + step).clamp(p.minScrollExtent, p.maxScrollExtent));
    });
  }

  void _stopAutoScroll() {
    _scroller?.cancel();
    _scroller = null;
    _finger = null;
  }

  @override
  void dispose() {
    _scroller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final ink = widget.ink;
    final store = MemoStore.instance;
    return ResizableBlock(
      fraction: attachment.widthFraction,
      onResized: (v) => store.setAttachmentLayout(attachment, widthFraction: v),
      builder: (context, width, max) {
        final body = ClipRRect(
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
                  label: tr(
                    context,
                    '${attachment.name} 삭제',
                    en: 'Delete ${attachment.name}',
                    zh: '删除${attachment.name}',
                    fr: 'Supprimer ${attachment.name}',
                    ja: '${attachment.name}を削除',
                  ),
                  onTap: () => _removeAttachment(context, attachment),
                ),
              ),
            ],
          ),
        );
        const tile = 112.0;
        final primary = Theme.of(context).colorScheme.primary;
        return LongPressDraggable<Attachment>(
          data: attachment,
          // 기본 0.5초는 답답해서 조금 줄인다. 스크롤과는 여전히 구분된다.
          delay: const Duration(milliseconds: 300),
          // 큰 사진을 통째로 들면 손가락 밑이 가려져 놓을 자리가 안 보인다.
          // 작은 타일을 손가락 한가운데에 쥐고 다닌다.
          dragAnchorStrategy: (_, _, _) => const Offset(tile / 2, tile / 2),
          onDragStarted: () {
            HapticFeedback.mediumImpact();
            _startAutoScroll();
          },
          onDragUpdate: (d) => _finger = d.globalPosition,
          onDragEnd: (_) => _stopAutoScroll(),
          feedback: Material(
            color: Colors.transparent,
            elevation: 0,
            child: Container(
              width: tile,
              height: tile,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primary, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: attachment.kind == 'image'
                    ? Image.file(
                        store.attachmentFile(attachment),
                        fit: BoxFit.cover,
                        cacheWidth:
                            (tile * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (_, _, _) =>
                            _Missing(width: tile, ink: ink),
                      )
                    : const ColoredBox(
                        color: Colors.black87,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
              ),
            ),
          ),
          // 들고 있는 동안 원래 자리는 얇게 접어, 위아래 줄이 가까워져
          // 멀리 끌고 갈 필요가 없게 한다.
          childWhenDragging: Container(
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: .35)),
            ),
          ),
          child: body,
        );
      },
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
                  label: tr(
                    context,
                    '${widget.attachment.name} 크게 보기',
                    en: 'View ${widget.attachment.name} full screen',
                    zh: '全屏查看${widget.attachment.name}',
                    fr: 'Afficher ${widget.attachment.name} en plein écran',
                    ja: '${widget.attachment.name}を大きく表示',
                  ),
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
              tooltip: tr(
                context,
                '${attachment.name} 첨부 삭제',
                en: 'Remove ${attachment.name}',
                zh: '移除附件${attachment.name}',
                fr: 'Retirer ${attachment.name}',
                ja: '${attachment.name}の添付を削除',
              ),
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
      if (mounted) {
        _message(
          added == 0
              ? tr(
                  context,
                  '첨부하지 못했어요. 파일을 다시 선택해 주세요.',
                  en: 'Could not attach. Please choose the files again.',
                  zh: '添加失败，请重新选择文件。',
                  fr: 'Ajout impossible. Veuillez choisir à nouveau les fichiers.',
                  ja: '添付できませんでした。ファイルを選び直してください。',
                )
              : tr(
                  context,
                  '$added개를 첨부했어요. 나머지 파일은 다시 선택해 주세요.',
                  en: 'Attached $added. Please choose the rest again.',
                  zh: '已添加 $added 个，请重新选择其余文件。',
                  fr: '$added ajouté(s). Veuillez choisir à nouveau les autres.',
                  ja: '$added件を添付しました。残りのファイルは選び直してください。',
                ),
        );
      }
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
            // 지금 크기(36)의 80%.
            fixedSize: const Size(28.8, 28.8),
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
              tr(
                context,
                '사진·동영상 첨부',
                en: 'Add photo or video',
                zh: '添加照片/视频',
                fr: 'Ajouter une photo ou une vidéo',
                ja: '写真・動画を添付',
              ),
              () => _pick(FileType.media),
            ),
          action(
            Icons.attach_file_rounded,
            tr(
              context,
              '파일 첨부',
              en: 'Add file',
              zh: '添加文件',
              fr: 'Ajouter un fichier',
              ja: 'ファイルを添付',
            ),
            () => _pick(FileType.any),
          ),
          action(
            Icons.delete_outline_rounded,
            tr(
              context,
              '메모 삭제',
              en: 'Delete memo',
              zh: '删除备忘录',
              fr: 'Supprimer la note',
              ja: 'メモを削除',
            ),
            () {
              FocusManager.instance.primaryFocus?.unfocus();
              widget.onDelete();
            },
          ),
        ],
      ),
    );
  }
}
