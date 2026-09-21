import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../data/memo_store.dart';
import '../models/memo.dart';
import '../theme/palette.dart';
import 'home_screen.dart';

/// The supplied artwork is the actual surface, so its texture, lettering and
/// illustrations survive intact. Hit regions use the artwork's coordinates.
class ReferenceHome extends StatefulWidget {
  const ReferenceHome({super.key});

  @override
  State<ReferenceHome> createState() => _ReferenceHomeState();
}

class _ReferenceHomeState extends State<ReferenceHome>
    with WidgetsBindingObserver {
  final store = MemoStore.instance;
  int selected = 0;
  bool _editorOpen = false;
  static const cards = [
    Rect.fromLTWH(61, 162, 450, 370),
    Rect.fromLTWH(543, 162, 450, 370),
    Rect.fromLTWH(1025, 162, 450, 370),
    Rect.fromLTWH(61, 555, 450, 360),
    Rect.fromLTWH(543, 555, 450, 360),
    Rect.fromLTWH(1025, 555, 450, 360),
  ];

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
    if (state != AppLifecycleState.resumed) unawaited(store.flush());
  }

  void customize() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));

  Future<void> edit(Board board) async {
    if (_editorOpen) return;
    _editorOpen = true;
    final initialFocusId = store.entriesOf(board.id).isEmpty
        ? store.addEntry(board.id).id
        : null;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: ColoredBox(
              color: CardPalette.byKey(
                board.colorKey,
              ).bg.withValues(alpha: .68),
              child: _MemoEditor(board: board, initialFocusId: initialFocusId),
            ),
          ),
        ),
      );
    } finally {
      _editorOpen = false;
      await store.flush();
    }
  }

  Widget artwork() {
    final boards = store.boards;
    return SizedBox(
      width: 1536,
      height: 1024,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xffe9d9d3),
              child: Image.asset(
                'assets/malang_reference_rgb.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            left: 499,
            top: 25,
            width: 550,
            height: 115,
            child: Semantics(
              button: true,
              label: '말랑 고양이 메모, 꾸미기 및 백업',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: customize,
                onDoubleTap: customize,
              ),
            ),
          ),
          for (var i = 0; i < boards.length && i < cards.length; i++) ...[
            Positioned.fromRect(
              rect: cards[i],
              child: Semantics(
                button: true,
                label: '${boards[i].title} 작성',
                child: InkWell(
                  onTap: () => edit(boards[i]),
                  onLongPress: customize,
                  borderRadius: BorderRadius.circular(32),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (i != 1)
              Positioned(
                left: cards[i].left + 39,
                top: cards[i].top + (i < 3 ? 128 : 98),
                width: 372,
                height: i == 4 ? 136 : 150,
                child: IgnorePointer(
                  child: Text(
                    store.entriesOf(boards[i].id).map((e) => e.text).join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'GamjaFlower',
                      fontSize: 25,
                      height: 1.76,
                      color: Color(0xff765348),
                    ),
                  ),
                ),
              ),
            if (i == 1)
              for (var j = 0; j < 3; j++)
                if (j < store.entriesOf(boards[i].id).length)
                  Positioned(
                    left: 578,
                    top: 264 + j * 70,
                    width: 44,
                    height: 44,
                    child: _ArtCheckbox(
                      entry: store.entriesOf(boards[i].id)[j],
                    ),
                  ),
            if (i == 1)
              for (var j = 0; j < 3; j++)
                if (j >= store.entriesOf(boards[i].id).length ||
                    store.entriesOf(boards[i].id)[j].text !=
                        const ['책 읽기', '산책하기', '메모 정리'][j])
                  Positioned(
                    left: 630,
                    top: 269 + j * 70,
                    width: 315,
                    height: 39,
                    child: IgnorePointer(
                      child: Container(
                        color: const Color(0xffffe9cc),
                        child: Text(
                          j < store.entriesOf(boards[i].id).length
                              ? store.entriesOf(boards[i].id)[j].text
                              : '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'GamjaFlower',
                            fontSize: 28,
                            color: Color(0xff765348),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget crop(Rect rect) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: rect.width,
      height: rect.height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: 1536,
          maxHeight: 1024,
          child: Transform.translate(offset: -rect.topLeft, child: artwork()),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xffe9d9d3),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boards = store.boards;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 96,
                        child: crop(const Rect.fromLTWH(480, 16, 580, 132)),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < boards.length && i < 6; i++)
                            ChoiceChip(
                              label: Text(
                                boards[i].title,
                                style: const TextStyle(
                                  fontFamily: 'GamjaFlower',
                                ),
                              ),
                              selected: selected == i,
                              selectedColor: const Color(0xffffdce5),
                              onSelected: (_) => setState(() => selected = i),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      AspectRatio(
                        aspectRatio: 478 / (selected < 3 ? 425 : 374),
                        child: crop(
                          Rect.fromLTWH(
                            cards[selected].left - 14,
                            cards[selected].top - (selected < 3 ? 48 : 0),
                            478,
                            selected < 3 ? 425 : 374,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: customize,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text(
                          '꾸미기 · 백업',
                          style: TextStyle(fontFamily: 'GamjaFlower'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _ArtCheckbox extends StatelessWidget {
  const _ArtCheckbox({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) => Semantics(
    label: entry.text,
    checked: entry.checked,
    child: InkWell(
      onTap: () => MemoStore.instance.toggleEntry(entry.id),
      child: entry.checked
          ? const Icon(Icons.check_rounded, color: Color(0xff806052), size: 36)
          : const SizedBox.expand(),
    ),
  );
}

class _MemoEditor extends StatefulWidget {
  const _MemoEditor({required this.board, this.initialFocusId});
  final Board board;
  final String? initialFocusId;
  @override
  State<_MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends State<_MemoEditor> {
  final store = MemoStore.instance;
  final controllers = <String, TextEditingController>{};
  String? focusId;

  @override
  void initState() {
    super.initState();
    focusId = widget.initialFocusId;
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    MediaQuery.paddingOf(context).top -
                    80)
                .clamp(120.0, 420.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.board.title,
                    style: const TextStyle(
                      fontFamily: 'GamjaFlower',
                      fontSize: 26,
                      color: Color(0xff765348),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('완료'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in store.entriesOf(widget.board.id))
                    Row(
                      key: ValueKey(entry.id),
                      children: [
                        if (widget.board.kind == BoardKind.checklist)
                          Checkbox(
                            value: entry.checked,
                            onChanged: (_) => store.toggleEntry(entry.id),
                          ),
                        Expanded(
                          child: TextField(
                            controller: controllers.putIfAbsent(
                              entry.id,
                              () => TextEditingController(text: entry.text),
                            ),
                            autofocus: entry.id == focusId,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: '작은 생각을 적어두기',
                              border: UnderlineInputBorder(),
                            ),
                            onChanged: (text) =>
                                store.setEntryText(entry.id, text),
                          ),
                        ),
                        IconButton(
                          tooltip: '메모 삭제',
                          onPressed: () => store.deleteEntry(entry.id),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                focusId = store.addEntry(widget.board.id).id;
              }),
              icon: const Icon(Icons.add),
              label: const Text('줄 추가'),
            ),
          ],
        ),
      ),
    ),
  );
}
