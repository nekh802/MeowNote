import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/memo_store.dart';
import '../models/memo.dart';
import '../theme/palette.dart';
import '../widgets/cat_face.dart';
import '../widgets/original_artwork.dart';

/// 컨셉아트의 손글씨 느낌 — 모서리 장식 문구에 쓴다.
TextStyle _hand(double size, Color color) => TextStyle(
  fontFamily: 'GamjaFlower',
  fontSize: size,
  color: color,
  height: 1.35,
);

/// 제목·카드 이름에 쓰는 둥근 서체.
TextStyle _round(double size, Color color) => TextStyle(
  fontFamily: 'Jua',
  fontSize: size,
  color: color,
  letterSpacing: .3,
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _store = MemoStore.instance;
  final _backup = BackupService();

  /// 방금 추가한 줄. 생기자마자 커서가 들어가도록 한 번만 쓰인다.
  String? _focusEntryId;
  String? _selectedBoardId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 물러날 때가 백업을 뜨기 가장 좋은 시점이다. 내용이 그대로면
    // backupIfChanged 안에서 해시를 비교해 조용히 건너뛴다.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      unawaited(_store.flush().then((_) => _backup.backupIfChanged()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final bg = BackgroundTheme.byKey(_store.backgroundKey);
        return Scaffold(
          body: AnimatedContainer(
            constraints: const BoxConstraints.expand(),
            duration: const Duration(milliseconds: 320),
            decoration: BoxDecoration(gradient: bg.gradient),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  const gap = 22.0;
                  final boards = _store.boards;
                  final selected =
                      boards
                          .where((b) => b.id == _selectedBoardId)
                          .firstOrNull ??
                      boards.firstOrNull;
                  final visibleBoards = boards
                      .where((b) => b.id == selected?.id)
                      .toList();
                  final wide = c.maxWidth >= 1080;
                  const cols = 1;
                  final pad = wide ? 40.0 : 20.0;
                  final cardW =
                      (c.maxWidth - pad * 2 - gap * (cols - 1)) / cols;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 4, pad, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          bg: bg,
                          showNotes: wide,
                          onPickBackground: _openBackgroundSheet,
                          onExport: _export,
                        ),
                        ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final board in boards)
                                ChoiceChip(
                                  label: Text(
                                    board.title,
                                    style: _round(
                                      14,
                                      CardPalette.byKey(board.colorKey).ink,
                                    ),
                                  ),
                                  selected: board.id == selected?.id,
                                  selectedColor: CardPalette.byKey(
                                    board.colorKey,
                                  ).bg,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: .45,
                                  ),
                                  onSelected: (_) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    setState(() {
                                      _selectedBoardId = board.id;
                                      _focusEntryId = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                        Wrap(
                          spacing: gap,
                          runSpacing: gap + 14, // 위로 튀어나온 고양이 자리
                          children: [
                            for (final board in visibleBoards)
                              SizedBox(
                                key: ValueKey(board.id),
                                width: cardW,
                                child: _BoardCard(
                                  board: board,
                                  entries: _store.entriesOf(board.id),
                                  focusEntryId: _focusEntryId,
                                  onAdd: () => _addEntry(board),
                                  onOpenSettings: () => _openBoardSheet(board),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _Footer(
                          bg: bg,
                          showNotes: wide,
                          lastBackupAt: _store.lastBackupAt,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _addEntry(Board board) {
    final entry = _store.addEntry(board.id);
    setState(() => _focusEntryId = entry.id);
  }

  Future<void> _export() async {
    try {
      await _backup.exportToShareSheet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('내보내기에 실패했어요: $e')));
    }
  }

  Future<void> _openBackgroundSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => _Sheet(
          title: '배경 고르기',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final b in BackgroundTheme.all)
                _BackgroundSwatch(
                  theme: b,
                  selected: b.key == _store.backgroundKey,
                  onTap: () => setSheet(() => _store.setBackground(b.key)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBoardSheet(Board board) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BoardSettingsSheet(board: board),
    );
  }
}

// ------------------------------------------------------------------ 머리말

class _Header extends StatelessWidget {
  const _Header({
    required this.bg,
    required this.showNotes,
    required this.onPickBackground,
    required this.onExport,
  });

  final BackgroundTheme bg;
  final bool showNotes;
  final VoidCallback onPickBackground;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showNotes) ...[
            Positioned(
              left: 4,
              top: 24,
              child: Transform.rotate(
                angle: -.05,
                child: _CornerNote(
                  '좋은 생각이\n가득하길 ♡',
                  bg: bg,
                  align: TextAlign.right,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 20,
              child: Transform.rotate(
                angle: .04,
                child: _CornerNote(
                  '작은 하루도\n소중해요 ♡',
                  bg: bg,
                  align: TextAlign.left,
                ),
              ),
            ),
          ],
          Semantics(
            label: '말랑 고양이 메모',
            header: true,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: OriginalArtwork(art: 'title', width: 558),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 2,
            child: Row(
              children: [
                _TopAction(
                  icon: Icons.palette_outlined,
                  tooltip: '배경 바꾸기',
                  bg: bg,
                  onTap: onPickBackground,
                ),
                const SizedBox(width: 6),
                _TopAction(
                  icon: Icons.ios_share,
                  tooltip: '백업 파일 내보내기',
                  bg: bg,
                  onTap: onExport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerNote extends StatelessWidget {
  const _CornerNote(this.text, {required this.bg, required this.align});

  final String text;
  final BackgroundTheme bg;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: align, style: _hand(16, bg.onBackgroundMuted));
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.tooltip,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final BackgroundTheme bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: bg.isDark
                ? Colors.white.withValues(alpha: .10)
                : Colors.white.withValues(alpha: .7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: bg.onBackground),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- 카드

class _BoardCard extends StatefulWidget {
  const _BoardCard({
    required this.board,
    required this.entries,
    required this.focusEntryId,
    required this.onAdd,
    required this.onOpenSettings,
  });

  final Board board;
  final List<Entry> entries;
  final String? focusEntryId;
  final VoidCallback onAdd;
  final VoidCallback onOpenSettings;

  @override
  State<_BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<_BoardCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final p = CardPalette.byKey(board.colorKey);
    final badge = CardBadge.byKey(board.badgeKey);
    final cat = CatSpec.byId(board.catId);
    final touch =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;

    // 고양이가 아래를 차지하면 + 버튼을 반대편으로 보낸다.
    final catOnRight = board.pose == CatPose.peekBottom;
    // 오른쪽 위에 걸터앉는 고양이는 카드 위에 덧그려져 제목 줄을 덮는다.
    // 그만큼 제목 줄을 좁혀 ⋯ 버튼이 고양이 왼쪽에 서게 한다.
    final headGap = board.pose == CatPose.peekTop
        ? _peekTopCat.width + _peekTopCat.right - 20
        : 0.0;
    final bottomGap = switch (board.pose) {
      CatPose.peekTop => 60.0,
      CatPose.none => 46.0,
      CatPose.watermark => 108.0,
      _ => 110.0,
    };
    final minRules = board.pose == CatPose.watermark ? 2 : 4;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 312),
                decoration: BoxDecoration(
                  color: p.bg.withValues(alpha: .68),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .7),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .055),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 모눈 질감
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(
                          Colors.white.withValues(alpha: .19),
                        ),
                      ),
                    ),
                    if (board.pose == CatPose.watermark)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: CatFace(
                            spec: cat,
                            width: 224,
                            opacity: 1,
                            tint: p.tint,
                          ),
                        ),
                      ),
                    if (board.pose == CatPose.peekBottom)
                      Positioned(
                        right: 16,
                        bottom: 0,
                        child: CatFace(spec: cat, width: 156),
                      ),
                    if (board.pose == CatPose.peekLeft)
                      Positioned(
                        left: 8,
                        bottom: 0,
                        child: CatFace(spec: cat, width: 148),
                      ),
                    if (board.pose == CatPose.trio)
                      const Positioned(
                        left: 4,
                        right: 4,
                        bottom: 0,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomCenter,
                          child: OriginalArtwork(art: 'trio', width: 330),
                        ),
                      ),

                    // 본문
                    Padding(
                      padding: EdgeInsets.fromLTRB(22, 18, 20, bottomGap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: headGap),
                            child: Row(
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    onTap: widget.onOpenSettings,
                                    behavior: HitTestBehavior.opaque,
                                    child:
                                        OriginalLabel.regions.containsKey(
                                          board.title,
                                        )
                                        ? FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: OriginalLabel(
                                              text: board.title,
                                              height: 31,
                                            ),
                                          )
                                        : Text(
                                            board.title,
                                            style: _round(24, p.ink),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(badge.icon, size: 17, color: badge.color),
                                const Spacer(),
                                AnimatedOpacity(
                                  opacity: _hover || touch ? 1 : 0,
                                  duration: const Duration(milliseconds: 140),
                                  child: InkWell(
                                    onTap: widget.onOpenSettings,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.more_horiz_rounded,
                                        size: 18,
                                        color: p.ink.withValues(alpha: .45),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (board.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            if (OriginalLabel.regions.containsKey(
                              board.subtitle,
                            ))
                              OriginalLabel(text: board.subtitle, height: 22)
                            else
                              Text(
                                board.subtitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: p.ink.withValues(alpha: .78),
                                ),
                              ),
                          ],
                          const SizedBox(height: 14),
                          for (final e in widget.entries)
                            _EntryRow(
                              key: ValueKey(e.id),
                              entry: e,
                              board: board,
                              palette: p,
                              autofocus: e.id == widget.focusEntryId,
                              onSubmit: widget.onAdd,
                            ),
                          // 컨셉아트처럼 빈 줄도 괘선으로 남겨 둔다.
                          for (var i = widget.entries.length; i < minRules; i++)
                            _EmptyRule(palette: p, onTap: widget.onAdd),
                        ],
                      ),
                    ),

                    // 발자국 — + 버튼 반대편 구석
                    Positioned(
                      left: catOnRight ? null : 20,
                      right: catOnRight ? 20 : null,
                      bottom: 18,
                      child: Icon(
                        Icons.pets,
                        size: 15,
                        color: p.tint.withValues(alpha: .45),
                      ),
                    ),

                    // 줄 추가
                    Positioned(
                      left: catOnRight ? 16 : null,
                      right: catOnRight ? null : 16,
                      bottom: 14,
                      child: _AddButton(palette: p, onTap: widget.onAdd),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 카드 위쪽 모서리에 걸터앉는 고양이 — 카드 밖으로 나가야 해서
          // 자르지 않는 바깥 Stack 에 둔다.
          if (board.pose == CatPose.peekTop)
            Positioned(
              top: -25,
              right: _peekTopCat.right,
              child: CatFace(spec: cat, width: _peekTopCat.width),
            ),
        ],
      ),
    );
  }
}

/// 카드 오른쪽 위 모서리에 걸터앉는 고양이 자리. 제목 줄이 그 밑으로
/// 들어가지 않도록 카드 본문에서도 같은 값을 본다.
const _peekTopCat = (width: 132.0, right: 12.0);

/// 카드 안쪽의 옅은 모눈.
class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.palette, required this.onTap});

  final CardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '줄 추가',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.tint,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.tint.withValues(alpha: .35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 21, color: Colors.white),
        ),
      ),
    );
  }
}

/// 아직 아무것도 없는 자리에 놓이는 괘선.
class _EmptyRule extends StatelessWidget {
  const _EmptyRule({required this.palette, required this.onTap});

  final CardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.line, width: 1.6)),
        ),
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.board,
    required this.palette,
    required this.autofocus,
    required this.onSubmit,
  });

  final Entry entry;
  final Board board;
  final CardPalette palette;
  final bool autofocus;
  final VoidCallback onSubmit;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  late final TextEditingController _c = TextEditingController(
    text: widget.entry.text,
  );
  bool _hover = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    MemoStore.instance.setEntryText(widget.entry.id, v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isCheck = widget.board.kind == BoardKind.checklist;
    final done = widget.entry.checked;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line, width: 1.6)),
        ),
        child: Row(
          children: [
            if (isCheck) ...[
              _CheckBox(
                checked: done,
                palette: p,
                onTap: () => MemoStore.instance.toggleEntry(widget.entry.id),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextField(
                controller: _c,
                autofocus: widget.autofocus,
                onChanged: _onChanged,
                onSubmitted: (_) {
                  MemoStore.instance.setEntryText(widget.entry.id, _c.text);
                  widget.onSubmit();
                },
                textInputAction: TextInputAction.next,
                cursorColor: p.ink,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.3,
                  color: done ? p.ink.withValues(alpha: .45) : p.ink,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: p.ink.withValues(alpha: .45),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '적어보기',
                  hintStyle: TextStyle(
                    fontSize: 17,
                    color: p.ink.withValues(alpha: .28),
                  ),
                  contentPadding: const EdgeInsets.only(bottom: 6),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: InkWell(
                onTap: () => MemoStore.instance.deleteEntry(widget.entry.id),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: p.ink.withValues(alpha: .4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({
    required this.checked,
    required this.palette,
    required this.onTap,
  });

  final bool checked;
  final CardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: checked ? palette.tint : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: checked ? palette.tint : palette.ink.withValues(alpha: .6),
            width: 2.2,
          ),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

// ------------------------------------------------------------------- 꼬리말

class _Footer extends StatelessWidget {
  const _Footer({
    required this.bg,
    required this.showNotes,
    required this.lastBackupAt,
  });

  final BackgroundTheme bg;
  final bool showNotes;
  final DateTime? lastBackupAt;

  @override
  Widget build(BuildContext context) {
    final t = lastBackupAt?.toLocal();
    final backup = t == null
        ? '아직 백업한 적이 없어요'
        : '마지막 백업 ${t.month}월 ${t.day}일 '
              '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showNotes)
          Expanded(
            child: Transform.rotate(
              angle: -.03,
              alignment: Alignment.centerLeft,
              child: _CornerNote(
                '오늘도\n말랑한 하루 ♡',
                bg: bg,
                align: TextAlign.left,
              ),
            ),
          ),
        Text(
          backup,
          style: TextStyle(fontSize: 12, color: bg.onBackgroundMuted),
        ),
        if (showNotes)
          Expanded(
            child: Transform.rotate(
              angle: .03,
              alignment: Alignment.centerRight,
              child: _CornerNote(
                '행복은\n언제나 여기 있어 ♡',
                bg: bg,
                align: TextAlign.right,
              ),
            ),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------------- 시트

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _round(19, const Color(0xFF6B4F52))),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final BackgroundTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: theme.gradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black.withValues(alpha: .12),
                width: selected ? 2.6 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 22, color: theme.onBackground)
                : null,
          ),
          const SizedBox(height: 6),
          Text(theme.label, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _BoardSettingsSheet extends StatefulWidget {
  const _BoardSettingsSheet({required this.board});

  final Board board;

  @override
  State<_BoardSettingsSheet> createState() => _BoardSettingsSheetState();
}

class _BoardSettingsSheetState extends State<_BoardSettingsSheet> {
  late final _title = TextEditingController(text: widget.board.title);
  late final _subtitle = TextEditingController(text: widget.board.subtitle);
  final _store = MemoStore.instance;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: _Sheet(
          title: '카드 꾸미기',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '제목'),
                onChanged: (v) => _store.updateBoard(board.id, title: v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: '한 줄 설명 (선택)'),
                onChanged: (v) => _store.updateBoard(board.id, subtitle: v),
              ),
              const SizedBox(height: 20),
              const _SheetLabel('카드 종류'),
              SegmentedButton<BoardKind>(
                segments: const [
                  ButtonSegment(value: BoardKind.note, label: Text('메모')),
                  ButtonSegment(
                    value: BoardKind.checklist,
                    label: Text('체크리스트'),
                  ),
                ],
                selected: {board.kind},
                onSelectionChanged: (s) =>
                    setState(() => _store.updateBoard(board.id, kind: s.first)),
              ),
              const SizedBox(height: 20),
              const _SheetLabel('카드 색'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in CardPalette.all)
                    GestureDetector(
                      onTap: () => setState(
                        () => _store.updateBoard(board.id, colorKey: p.key),
                      ),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: board.colorKey == p.key
                                ? p.ink
                                : Colors.black.withValues(alpha: .1),
                            width: board.colorKey == p.key ? 2.4 : 1,
                          ),
                        ),
                        child: board.colorKey == p.key
                            ? Icon(Icons.check_rounded, size: 18, color: p.ink)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _SheetLabel('제목 옆 표시'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in CardBadge.all)
                    GestureDetector(
                      onTap: () => setState(
                        () => _store.updateBoard(board.id, badgeKey: b.key),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: board.badgeKey == b.key
                                ? b.color
                                : Colors.black.withValues(alpha: .08),
                            width: board.badgeKey == b.key ? 2.2 : 1,
                          ),
                        ),
                        child: Icon(b.icon, size: 19, color: b.color),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _SheetLabel('고양이'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final cat in CatSpec.all)
                    GestureDetector(
                      onTap: () => setState(
                        () => _store.updateBoard(board.id, catId: cat.id),
                      ),
                      child: Container(
                        width: 62,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: board.catId == cat.id
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CatFace(spec: cat, width: 44),
                            Text(
                              cat.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _SheetLabel('고양이 자리'),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in const {
                    CatPose.peekTop: '위에 걸터앉기',
                    CatPose.peekBottom: '오른쪽 아래',
                    CatPose.peekLeft: '왼쪽 아래',
                    CatPose.trio: '세 마리',
                    CatPose.watermark: '옅게 깔기',
                    CatPose.none: '없음',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: board.pose == entry.key,
                      onSelected: (_) => setState(
                        () => _store.updateBoard(board.id, pose: entry.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
