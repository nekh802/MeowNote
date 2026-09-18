import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:url_launcher/url_launcher.dart';

import '../data/app_update.dart';
import '../data/memo_store.dart';
import '../data/share_text.dart';
import '../data/when.dart';
import '../data/widget_feed.dart';
import '../models/memo.dart';
import '../theme/palette.dart';
import '../widgets/cat_face.dart';
import '../widgets/original_artwork.dart';

/// 앱스토어에서 이 앱을 찾을 이름표. 기기에 적어 둔 메모가 이 이름에
/// 매여 있어 이름을 바꾼 뒤에도 그대로 두었다.
const appBundleId = 'com.mallang.mallangMemo';

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

/// 커서를 넣을 줄과, 그 줄 글자 중 몇 번째 앞에 세울지.
typedef _Caret = ({String entryId, int offset});

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _store = MemoStore.instance;

  /// 방금 추가한 줄. 생기자마자 커서가 들어가도록 한 번만 쓰인다.
  _Caret? _focus;
  String? _selectedBoardId;

  /// 홈 화면 위젯은 타자 한 글자마다가 아니라 잠깐 쉴 때 한 번 갱신한다.
  Timer? _widgetTimer;

  /// 지금 사라지는 중인 카드. 지우는 동안만 값이 들어 있다.
  String? _vanishingBoardId;
  static const _vanishDuration = Duration(milliseconds: 240);

  /// 왼쪽이 목록, 오른쪽이 펼친 메모. 켤 때는 메모부터 보이고, 화면을
  /// 오른쪽으로 쓸면 목록이 따라 나온다.
  late final PageController _pages = PageController(initialPage: memoPage);

  static const libraryPage = 0;
  static const memoPage = 1;

  @override
  void initState() {
    super.initState();
    // 어느 메모를 펼쳐 둘지 처음부터 정해 둔다. 이걸 비워 두면 목록의
    // 첫 장을 따라가느라, 붙박거나 차례를 바꿀 때마다 보던 메모가
    // 슬그머니 바뀐다.
    _selectedBoardId = _store.boards.firstOrNull?.id;
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_scheduleWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetFeed.publish(_store);
      _offerStoreUpdate();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _widgetTimer?.cancel();
    _store.removeListener(_scheduleWidget);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleWidget() {
    _widgetTimer?.cancel();
    _widgetTimer = Timer(
      const Duration(seconds: 1),
      () => WidgetFeed.publish(_store),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 물러날 때 적어 둔 것을 확실히 파일에 내려놓는다.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      unawaited(_store.flush().then((_) => WidgetFeed.publish(_store)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final bg = BackgroundTheme.byKey(_store.backgroundKey);
        final boards = _store.boards;
        final selected =
            boards.where((b) => b.id == _selectedBoardId).firstOrNull ??
            boards.firstOrNull;
        return Scaffold(
          body: AnimatedContainer(
            constraints: const BoxConstraints.expand(),
            duration: const Duration(milliseconds: 320),
            decoration: BoxDecoration(gradient: bg.gradient),
            child: SafeArea(
              child: PageView(
                controller: _pages,
                // 페이지를 넘길 때 자판이 따라오면 다음 장을 덮는다.
                onPageChanged: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                children: [
                  _LibraryPage(
                    bg: bg,
                    pinned: _store.pinnedBoards,
                    loose: _store.looseBoards,
                    selectedId: selected?.id,
                    onPick: _pickBoard,
                    onPin: (b) {
                      HapticFeedback.lightImpact();
                      setState(() => _store.togglePin(b.id));
                    },
                    onPickBackground: _openBackgroundSheet,
                    onExport: _exportAllBoards,
                    onSort: _openMoreSheet,
                    onAddBoard: _addBoard,
                    matches: _matches,
                    sort: _store.sort,
                  ),
                  if (selected == null)
                    const SizedBox()
                  else
                    _Vanishing(
                      gone: _vanishingBoardId == selected.id,
                      duration: _vanishDuration,
                      child: _MemoPage(
                        bg: bg,
                        board: selected,
                        entries: _store.entriesOf(selected.id),
                        focus: _focus,
                        onBack: _openLibrary,
                        onAdd: () => _addEntry(selected),
                        onEnter: _splitEntry,
                        onExport: () => _exportBoard(selected),
                        onDelete: () => _deleteBoard(selected),
                        onOpenSettings: () => _openBoardSheet(selected),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 새 메모 한 장. 색과 고양이는 돌아가며 골라 카드마다 다른 얼굴이
  /// 되게 한다. 놓자마자 그 메모를 펼친다.
  void _addBoard() {
    final n = _store.boards.length;
    final board = _store.addBoard(
      colorKey: CardPalette.all[n % CardPalette.all.length].key,
      catId: CatSpec.all[n % CatSpec.all.length].id,
    );
    _pickBoard(board);
  }

  /// 검색칸에 적은 말이 이 카드와 맞는지. 제목과 한 줄 설명뿐 아니라
  /// 적어 둔 글까지 뒤진다.
  bool _matches(Board board, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (board.title.toLowerCase().contains(q)) return true;
    if (board.subtitle.toLowerCase().contains(q)) return true;
    return _store
        .entriesOf(board.id)
        .any((e) => e.text.toLowerCase().contains(q));
  }

  /// 목록에서 한 장을 고르면 곧바로 그 메모로 넘어간다.
  void _pickBoard(Board board) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedBoardId = board.id;
      _focus = null;
    });
    _slideTo(memoPage);
  }

  void _openLibrary() {
    FocusManager.instance.primaryFocus?.unfocus();
    _slideTo(libraryPage);
  }

  void _slideTo(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  void _addEntry(Board board) {
    final entry = _store.addEntry(board.id);
    setState(() => _focus = (entryId: entry.id, offset: 0));
  }

  /// 엔터와 붙여넣기 — 누른 줄 아래에 줄을 놓고 커서를 마지막으로 옮긴다.
  /// [rest] 는 커서 뒤에 있던 글이 줄마다 나뉜 것이고, [caret] 은 마지막
  /// 줄에서 커서가 설 자리다. 글자 사이에서 누른 엔터면 옮겨 간 문장 맨
  /// 앞(0)이다.
  void _splitEntry(Entry at, List<String> rest, int caret) {
    final made = _store.insertEntriesAfter(at.id, rest);
    setState(() => _focus = (entryId: made.last.id, offset: caret));
  }

  /// 카드 한 장을 글로 옮겨 공유 시트에 넘긴다.
  Future<void> _exportBoard(Board board) async {
    try {
      await shareBoard(board, _store.entriesOf(board.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('내보내기에 실패했어요: $e')));
    }
  }

  /// 앱스토어에 더 새로운 판이 있으면 켤 때 한 번 알린다.
  ///
  /// 같은 판을 두고 켤 때마다 묻지 않도록, 한 번 알린 판은 적어 둔다.
  /// 인터넷이 없거나 아직 스토어에 없는 앱이면 아무 일도 일어나지 않는다.
  Future<void> _offerStoreUpdate() async {
    final release = await AppUpdate.lookUp(appBundleId);
    if (release == null || !mounted) return;
    if (!isNewerVersion(release.version, MemoStore.appVersion)) return;
    if (_store.toldStoreVersion == release.version) return;
    _store.markStoreVersionTold(release.version);

    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('새 버전이 나왔어요', style: _round(19, const Color(0xFF6B4F52))),
        content: const Text('앱스토어에서 말랑 고양이 메모를 최신으로 올려 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('앱스토어 열기'),
          ),
        ],
      ),
    );
    if (go ?? false) {
      await launchUrl(release.page, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMoreSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => _Sheet(
          title: '더보기',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetLabel('정렬하기'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    BoardSort.edited: '편집일',
                    BoardSort.created: '생성일',
                    BoardSort.name: '가나다·ABC',
                  }.entries)
                    _PickBox(
                      label: entry.value,
                      selected: _store.sort == entry.key,
                      onTap: () => setSheet(() => _store.setSort(entry.key)),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              const _SheetLabel('정리하기'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('메모 지우기'),
                subtitle: const Text('여러 장을 골라 한 번에'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openDeleteSheet();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 펼쳐 둔 메모 한 장을 지운다.
  ///
  /// 묻지 않고 바로 지우되, 카드가 작아지며 사라지는 동안 눈이 따라갈
  /// 틈을 준다. 지운 흔적만 남기므로 바로 되돌릴 수도 있다.
  Future<void> _deleteBoard(Board board) async {
    setState(() => _vanishingBoardId = board.id);
    await Future<void>.delayed(_vanishDuration);
    if (!mounted) return;
    setState(() {
      _vanishingBoardId = null;
      _store.deleteBoards([board.id]);
      _selectedBoardId = _store.boards.firstOrNull?.id;
    });
    _openLibrary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("'${board.title}' 을(를) 지웠어요"),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () => setState(() {
            _store.restoreBoards([board.id]);
            _selectedBoardId = board.id;
          }),
        ),
      ),
    );
  }

  /// 가진 메모를 모두 글 한 덩이로 옮겨 공유 창에 넘긴다.
  ///
  /// 애플이 다른 앱에서 메모 앱에 글을 써 넣는 길을 열어 두지 않아,
  /// 받는 곳으로 '메모'를 고르는 마지막 한 걸음은 사람이 한다.
  Future<void> _exportAllBoards() async {
    try {
      await shareAllBoards(_store.boards, _store.entriesOf);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('보내지 못했어요: $e')));
    }
  }

  /// 여러 장을 골라 한 번에 지운다.
  Future<void> _openDeleteSheet() async {
    final picked = <String>{};
    final gone = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) => SingleChildScrollView(
          child: _Sheet(
            title: '메모 지우기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetLabel('지울 메모를 고르세요'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final board in _store.boards)
                      _PickBox(
                        label: board.title,
                        selected: picked.contains(board.id),
                        onTap: () => setSheet(() {
                          if (!picked.remove(board.id)) picked.add(board.id);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: picked.isEmpty
                          ? null
                          : Theme.of(context).colorScheme.error,
                    ),
                    onPressed: picked.isEmpty
                        ? null
                        : () => Navigator.of(sheet).pop(picked.length),
                    child: Text(
                      picked.isEmpty ? '지우기' : '${picked.length}장 지우기',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (gone == null || !mounted) return;
    setState(() {
      _store.deleteBoards(picked);
      // 펼쳐 둔 메모가 사라졌으면 남은 것 가운데 첫 장을 편다.
      if (_store.boards.every((b) => b.id != _selectedBoardId)) {
        _selectedBoardId = _store.boards.firstOrNull?.id;
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('메모 $gone장을 지웠어요')));
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
      // 창이 길어져도 아이폰 위쪽 카메라 자리는 비워 둔다.
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BoardSettingsSheet(board: board),
    );
  }
}

// ------------------------------------------------------------------ 페이지

/// 왼쪽 장 — 제목과 메모 고르는 ∨ 박스.
class _LibraryPage extends StatefulWidget {
  const _LibraryPage({
    required this.bg,
    required this.pinned,
    required this.loose,
    required this.selectedId,
    required this.onPick,
    required this.onPin,
    required this.onPickBackground,
    required this.onExport,
    required this.onSort,
    required this.onAddBoard,
    required this.matches,
    required this.sort,
  });

  final BackgroundTheme bg;
  final List<Board> pinned;
  final List<Board> loose;
  final String? selectedId;
  final void Function(Board) onPick;
  final void Function(Board) onPin;
  final VoidCallback onPickBackground;
  final VoidCallback onExport;
  final VoidCallback onSort;
  final VoidCallback onAddBoard;

  /// 검색칸에 적은 말이 이 카드와 맞는지. 적어 둔 글까지 봐야 해서
  /// 저장소를 아는 바깥에서 받는다.
  final bool Function(Board, String) matches;

  /// 어떤 차례로 늘어놓는지. 때로 줄 세울 때만 '오늘·어제' 묶음을 짓는다.
  final BoardSort sort;

  @override
  State<_LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<_LibraryPage>
    with AutomaticKeepAliveClientMixin {
  // 메모를 펼치면 목록 장은 화면 밖으로 나간다. 그대로 두면 PageView 가
  // 이 장을 버려 검색어와 ∨ 박스 상태가 함께 사라진다.
  @override
  bool get wantKeepAlive => true;

  /// 이름표와 그 아래 설 카드들. 붙박은 것이 늘 앞이고, 때로 줄 세울
  /// 때는 '오늘·어제·이전 7일·이전 30일'로 묶는다.
  List<(String, List<Board>)> _sections(List<Board> pinned, List<Board> loose) {
    final out = <(String, List<Board>)>[];
    if (pinned.isNotEmpty) out.add(('고정된 메모', pinned));
    if (loose.isEmpty) return out;
    if (widget.sort == BoardSort.name) {
      out.add((pinned.isEmpty ? '모든 메모' : '모든 메모', loose));
      return out;
    }
    final byWhen = <String, List<Board>>{};
    for (final b in loose) {
      final at = widget.sort == BoardSort.created ? b.createdAt : b.updatedAt;
      byWhen.putIfAbsent(whenGroup(at), () => []).add(b);
    }
    // 카드는 이미 줄 세워 들어오므로 묶음도 그 차례 그대로 나온다.
    out.addAll(byWhen.entries.map((e) => (e.key, e.value)));
    return out;
  }

  /// ∨ 박스는 펼친 채로 연다. 이 장에 달리 할 일이 없어서 접어 두면
  /// 빈 화면만 남는다.
  bool _open = true;

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bg = widget.bg;
    final wide = MediaQuery.of(context).size.width >= 1080;
    final pad = wide ? 40.0 : 20.0;
    final all = [...widget.pinned, ...widget.loose];
    final picked = all.where((b) => b.id == widget.selectedId).firstOrNull;
    final q = _search.text;
    final pinned = widget.pinned.where((b) => widget.matches(b, q)).toList();
    final loose = widget.loose.where((b) => widget.matches(b, q)).toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  bg: bg,
                  showNotes: wide,
                  onPickBackground: widget.onPickBackground,
                  onExport: widget.onExport,
                  onSort: widget.onSort,
                ),
                const SizedBox(height: 4),
                _PickerBox(
                  bg: bg,
                  board: picked,
                  open: _open,
                  onTap: () => setState(() => _open = !_open),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _open
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, group) in _sections(
                          pinned,
                          loose,
                        ).indexed) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _GroupLabel(
                            group.$1,
                            bg: bg,
                            // 붙박는 법은 맨 위 묶음 곁에 한 번만 귀띔한다.
                            hint: i == 0 ? '메모를 길게 누르면 고정할 수 있어요' : null,
                          ),
                          _BoardChips(
                            boards: group.$2,
                            selectedId: widget.selectedId,
                            onPick: widget.onPick,
                            onPin: widget.onPin,
                            // 새 메모 단추는 맨 윗줄 남는 자리에 끼운다.
                            onAdd: i == 0 ? widget.onAddBoard : null,
                          ),
                        ],
                        if (pinned.isEmpty && loose.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              '찾는 메모가 없어요',
                              style: TextStyle(
                                fontSize: 13,
                                color: bg.onBackgroundMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 22),
                _Footer(bg: bg, showNotes: wide),
              ],
            ),
          ),
        ),
        // 검색칸은 목록과 함께 흘러가지 않고 화면 아래에 붙어 있는다.
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, 10),
          child: _SearchBox(
            bg: bg,
            controller: _search,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

/// 목록 맨 아래 검색칸. 제목·한 줄 설명·적어 둔 글을 모두 뒤진다.
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.bg,
    required this.controller,
    required this.onChanged,
  });

  final BackgroundTheme bg;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = bg.onBackground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg.isDark
            ? Colors.white.withValues(alpha: .10)
            : Colors.white.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .8)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 19,
            color: ink.withValues(alpha: .5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('memo-search'),
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 15, color: ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                hintText: '메모 찾기',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: ink.withValues(alpha: .4),
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: ink.withValues(alpha: .5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 지금 펼쳐 둔 메모를 보여 주는 ∨ 박스.
class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.bg,
    required this.board,
    required this.open,
    required this.onTap,
  });

  final BackgroundTheme bg;
  final Board? board;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = board == null ? null : CardPalette.byKey(board!.colorKey);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        decoration: BoxDecoration(
          color: bg.isDark
              ? Colors.white.withValues(alpha: .10)
              : Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // 앱 이름을 여기에 못 박는다. 어느 메모를 펼쳐 두었는지는
                // 아래 블록의 체크 표시가 알려 준다.
                '말랑 고양이 메모',
                style: _round(19, p?.ink ?? bg.onBackground),
              ),
            ),
            AnimatedRotation(
              turns: open ? .5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: bg.onBackground.withValues(alpha: .6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지워지는 카드가 작아지며 사라지는 동안만 쓰이는 껍데기.
class _Vanishing extends StatelessWidget {
  const _Vanishing({
    required this.gone,
    required this.duration,
    required this.child,
  });

  final bool gone;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: gone ? .88 : 1,
    duration: duration,
    curve: Curves.easeInCubic,
    child: AnimatedOpacity(
      opacity: gone ? 0 : 1,
      duration: duration,
      child: child,
    ),
  );
}

/// 목록 위에 붙는 작은 이름표.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {required this.bg, this.hint});

  final String text;
  final BackgroundTheme bg;

  /// 곁들일 귀띔. 물음표를 누르면 뜬다.
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Row(
      children: [
        Text(text, style: TextStyle(fontSize: 12, color: bg.onBackgroundMuted)),
        if (hint != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: hint!,
            // 손가락으로 쓰는 화면에서는 눌러야 뜬다.
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 4),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: bg.onBackgroundMuted,
            ),
          ),
        ],
      ],
    ),
  );
}

/// 작은 블록 한 장의 셈.
const _chipPadH = 16.0;
const _chipPadV = 10.0;
const _chipEdge = 1.5;

/// 블록 모서리. 높이의 절반에 가까우면 알약처럼 보인다 — 컨셉아트의
/// 블록은 그보다 각이 살아 있는 둥근 네모다.
const _chipRadius = 10.0;

/// 블록 테두리. 카드 색을 따라가지 않고 어느 블록이나 같은 옅은 잿빛이다.
const _chipEdgeColor = Color(0xFFE0D5CD);
const _chipGap = 8.0;

/// 메모를 고르는 작은 블록들. 꾸욱 누르면 맨 위에 붙박는다.
///
/// [onAdd] 를 주면 새 메모 [+] 블록을 맨 앞에 세운다.
class _BoardChips extends StatelessWidget {
  const _BoardChips({
    required this.boards,
    required this.selectedId,
    required this.onPick,
    required this.onPin,
    this.onAdd,
  });

  final List<Board> boards;
  final String? selectedId;
  final void Function(Board) onPick;
  final void Function(Board) onPin;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _chipGap,
      runSpacing: _chipGap,
      children: [
        // 새 메모는 언제나 맨 앞이다. 차례를 바꾸거나 붙박아 두어도
        // 찾는 자리가 달라지지 않는다.
        if (onAdd != null) _AddBoardChip(onTap: onAdd!),
        for (final board in boards)
          _BoardChip(
            board: board,
            selected: board.id == selectedId,
            onTap: () => onPick(board),
            onLongPress: () => onPin(board),
          ),
      ],
    );
  }
}

/// 메모 한 장을 가리키는 블록.
class _BoardChip extends StatelessWidget {
  const _BoardChip({
    required this.board,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Board board;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = CardPalette.byKey(board.colorKey);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _chipPadH,
          vertical: _chipPadV,
        ),
        decoration: BoxDecoration(
          // 고른 것은 그 메모의 카드 바탕색, 나머지는 반투명한 흰색이라
          // 뒤 배경이 은은하게 비친다. 글자색은 어느 쪽이든 그 메모의
          // 카드 글자색이다.
          color: selected ? p.bg : Colors.white.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(_chipRadius),
          border: Border.all(
            color: selected ? p.bg : _chipEdgeColor,
            width: _chipEdge,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 16, color: p.ink),
              const SizedBox(width: 5),
            ],
            if (board.isPinned) ...[
              Icon(Icons.push_pin, size: 12, color: p.ink),
              const SizedBox(width: 5),
            ],
            Text(board.title, style: _round(14, p.ink)),
          ],
        ),
      ),
    );
  }
}

/// 새 메모를 놓는 [+] 블록.
class _AddBoardChip extends StatelessWidget {
  const _AddBoardChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final edge = _pickedEdge(context);
    return Tooltip(
      message: '새 메모',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _chipPadH,
            vertical: _chipPadV,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(_chipRadius),
            // 메모가 아니라 단추라는 것이 보이도록 이것만 색 테두리를 둔다.
            border: Border.all(
              color: edge.withValues(alpha: .45),
              width: _chipEdge,
            ),
          ),
          child: SizedBox(
            width: 20,
            child: Icon(Icons.add_rounded, size: 20, color: edge),
          ),
        ),
      ),
    );
  }
}

/// 오른쪽 장 — 펼친 메모 한 장만.
class _MemoPage extends StatelessWidget {
  const _MemoPage({
    required this.bg,
    required this.board,
    required this.entries,
    required this.focus,
    required this.onBack,
    required this.onAdd,
    required this.onEnter,
    required this.onExport,
    required this.onDelete,
    required this.onOpenSettings,
  });

  final BackgroundTheme bg;
  final Board board;
  final List<Entry> entries;
  final _Caret? focus;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final void Function(Entry, List<String>, int) onEnter;
  final VoidCallback onExport;

  /// 이 메모를 통째로 지운다.
  final VoidCallback onDelete;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1080;
    final pad = wide ? 40.0 : 20.0;
    // 위로 튀어나온 고양이 자리와 아래 여백.
    const top = 26.0, bottom = 36.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 밀어서 가는 길은 눈에 띄지 않는다. 눌러서도 갈 수 있게 둔다.
        Padding(
          padding: EdgeInsets.fromLTRB(pad - 12, 4, pad, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              tooltip: '목록',
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              color: bg.onBackground.withValues(alpha: .75),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
              child: ConstrainedBox(
                // 카드는 제 높이만큼만 자란다. 남는 자리는 카드를 늘리지
                // 않고 가운데로 옮겨 채운다 — 줄을 지우면 카드도 그만큼
                // 짧아져야 하기 때문이다.
                constraints: BoxConstraints(
                  minHeight: (c.maxHeight - top - bottom).clamp(0.0, 4000.0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BoardCard(
                      key: ValueKey(board.id),
                      board: board,
                      entries: entries,
                      focus: focus,
                      onAdd: onAdd,
                      onEnter: onEnter,
                      onExport: onExport,
                      onDelete: onDelete,
                      onOpenSettings: onOpenSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
    required this.onSort,
  });

  final BackgroundTheme bg;
  final bool showNotes;
  final VoidCallback onPickBackground;
  final VoidCallback onExport;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showNotes) ...[
            Positioned(
              left: 4,
              top: 2,
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
              top: 0,
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
                  tooltip: '전체 내보내기',
                  bg: bg,
                  onTap: onExport,
                ),
                const SizedBox(width: 6),
                _TopAction(
                  icon: Icons.more_horiz_rounded,
                  tooltip: '더보기',
                  bg: bg,
                  onTap: onSort,
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
        // 줄 사이를 오갈 때 이 단추에 초점이 걸리지 않게 한다.
        canRequestFocus: false,
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
    super.key,
    required this.board,
    required this.entries,
    required this.focus,
    required this.onAdd,
    required this.onEnter,
    required this.onExport,
    required this.onDelete,
    required this.onOpenSettings,
  });

  final Board board;
  final List<Entry> entries;
  final _Caret? focus;
  final VoidCallback onAdd;
  final void Function(Entry, List<String>, int) onEnter;
  final VoidCallback onExport;

  /// 이 메모를 통째로 지운다.
  final VoidCallback onDelete;
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
    // 고양이가 앉은 구석에는 발자국을 찍지 않는다. 겹쳐 그리면 발바닥이
    // 고양이 몸에 찍힌 것처럼 보인다.
    final showPaw =
        board.pose != CatPose.peekLeft &&
        board.pose != CatPose.peekBottom &&
        board.pose != CatPose.trio;
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
                            // 카드 글씨를 가리지 않게 절반만 비친다. 별이는
                            // 원본부터 수채로 옅게 그린 아이라 더 깎으면
                            // 아예 보이지 않는다.
                            opacity: cat.id == 'byeol' ? 1 : .5,
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
                            // Spacer 를 쓰면 남는 자리를 제목과 절반씩
                            // 나눠 가져 제목이 먼저 줄바꿈된다. 제목 묶음에
                            // 먼저 자리를 주고 남는 만큼만 벌린다.
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  // 제목은 카드마다 같은 크기로 둔다. 길면
                                  // 줄여 쓰지 않고 줄을 바꿔 끝까지 보여 준다.
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: _InlineText(
                                          value: board.title,
                                          style: _round(24, p.ink),
                                          maxLines: 2,
                                          onChanged: (v) => MemoStore.instance
                                              .updateBoard(board.id, title: v),
                                        ),
                                      ),
                                      if (badge.icon != null) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          badge.icon,
                                          size: 17,
                                          color: badge.color,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                AnimatedOpacity(
                                  opacity: _hover || touch ? 1 : 0,
                                  duration: const Duration(milliseconds: 140),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _CardAction(
                                        icon: Icons.ios_share,
                                        tooltip: '이 카드 내보내기',
                                        ink: p.ink,
                                        onTap: widget.onExport,
                                      ),
                                      const SizedBox(width: 2),
                                      _CardAction(
                                        icon: Icons.more_horiz_rounded,
                                        tooltip: '카드 꾸미기',
                                        ink: p.ink,
                                        onTap: widget.onOpenSettings,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (board.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            // 한 줄 설명은 제목과 같은 서체로 둔다.
                            _InlineText(
                              value: board.subtitle,
                              style: _round(16, p.ink.withValues(alpha: .78)),
                              maxLines: 2,
                              onChanged: (v) => MemoStore.instance.updateBoard(
                                board.id,
                                subtitle: v,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          // 이 카드를 처음 편 날. 지워도 되는 장식이 아니라
                          // 카드가 늘 지니고 있는 값이다.
                          Text(
                            '${ymd(board.createdAt)} 시작',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: p.ink.withValues(alpha: .45),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < widget.entries.length; i++)
                            _EntryRow(
                              key: ValueKey(widget.entries[i].id),
                              entry: widget.entries[i],
                              board: board,
                              palette: p,
                              autofocus:
                                  widget.entries[i].id == widget.focus?.entryId,
                              caret: widget.focus?.offset ?? 0,
                              onEnter: (rest, caret) => widget.onEnter(
                                widget.entries[i],
                                rest,
                                caret,
                              ),
                            ),
                          // 컨셉아트처럼 빈 줄도 괘선으로 남겨 둔다. 여기엔
                          // 줄 앞 표시를 찍지 않는다 — 아직 만든 줄이 아니라
                          // 카드를 채우는 장식이다.
                          for (var i = widget.entries.length; i < minRules; i++)
                            _EmptyRule(palette: p, onTap: widget.onAdd),
                        ],
                      ),
                    ),

                    // 발자국 — + 버튼 반대편 구석
                    if (showPaw)
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

                    // 이 메모 지우기
                    Positioned(
                      left: catOnRight ? 16 : null,
                      right: catOnRight ? null : 16,
                      bottom: 14,
                      child: _TrashButton(palette: p, onTap: widget.onDelete),
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

/// 눌러서 그 자리에서 고치는 글.
///
/// 제목과 한 줄 설명은 카드에서 가장 자주 손보는 곳이라, 꾸미기 창을
/// 열지 않고 바로 고칠 수 있어야 한다. 꾸미기 창의 입력란도 그대로
/// 두어, 어느 쪽으로 고치든 같은 값을 본다.
class _InlineText extends StatefulWidget {
  const _InlineText({
    required this.value,
    required this.style,
    required this.maxLines,
    required this.onChanged,
  });

  final String value;
  final TextStyle style;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && mounted) setState(() => _editing = false);
    });
  }

  @override
  void didUpdateWidget(_InlineText old) {
    super.didUpdateWidget(old);
    // 꾸미기 창에서 고친 값이 들어오면 따라 간다. 고치는 중에는 손대지
    // 않는다 — 커서가 튀고 한글 조합이 끊긴다.
    if (!_editing && widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onTap: () {
          setState(() => _editing = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focus.requestFocus();
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Text(
          widget.value,
          maxLines: widget.maxLines,
          style: widget.style,
        ),
      );
    }
    return TextField(
      controller: _c,
      focusNode: _focus,
      style: widget.style,
      maxLines: widget.maxLines,
      minLines: 1,
      cursorColor: widget.style.color,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
      onTapOutside: (_) => _focus.unfocus(),
      onSubmitted: (_) => _focus.unfocus(),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// 카드 제목 줄 오른쪽에 서는 작은 단추.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      // 줄 사이를 오갈 때 이 단추에 초점이 걸리지 않게 한다.
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: ink.withValues(alpha: .45)),
      ),
    ),
  );
}

/// 카드 오른쪽 위 모서리에 걸터앉는 고양이 자리. 제목 줄이 그 밑으로
/// 들어가지 않도록 카드 본문에서도 같은 값을 본다.
const _peekTopCat = (width: 116.0, right: 12.0);

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

/// 이 메모를 통째로 지우는 단추. 줄은 엔터로 늘리고 빈 괘선을 눌러 쓴다.
class _TrashButton extends StatelessWidget {
  const _TrashButton({required this.palette, required this.onTap});

  final CardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '이 메모 지우기',
      child: InkWell(
        onTap: onTap,
        // 줄 사이를 오갈 때 이 단추에 초점이 걸리지 않게 한다.
        canRequestFocus: false,
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
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 글줄 한 칸의 셈.
///
/// 칸(TextField)과 빈 괘선이 똑같은 높이여야 한다. 조금이라도 어긋나면
/// 엔터로 줄이 늘고 줄 때마다 카드 높이가 미세하게 출렁이고, 카드에
/// 매달린 고양이까지 따라 흔들린다. 그래서 글줄 높이를 글꼴 속사정에
/// 맡기지 않고 여기서 못 박는다.
const _rowText = 17.0;
const _rowLine = 22.0;
const _rowPad = 8.0;
const _rowRule = 1.6;
const _rowHeight = _rowLine + _rowPad * 2;

/// 괘선까지 더한 한 칸의 실제 높이.
///
/// Container 는 테두리 두께만큼 제 몸을 더 키운다. 글을 적는 칸은 그래서
/// _rowHeight + _rowRule 이 되는데, 장식용 빈 괘선을 _rowHeight 로 두면
/// 엔터로 줄이 하나 생길 때마다 카드가 그 차이만큼 들썩였다.
const _ruleHeight = _rowHeight + _rowRule;

/// 줄 앞 표시가 서는 자리.
///
/// 글을 따라 위아래로 흔들리지 않도록 높이를 한 줄로 못 박고 그 가운데에
/// 세운다. 글줄의 한가운데와 눈높이가 맞는다.
class _MarkSlot extends StatelessWidget {
  const _MarkSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _rowHeight,
    child: Center(widthFactor: 1, child: child),
  );
}

/// 줄 앞에 놓이는 작은 하트. 두 번째 장의 하트 줄 카드에 쓴다.
class _HeartBullet extends StatelessWidget {
  const _HeartBullet({required this.palette});

  final CardPalette palette;

  @override
  Widget build(BuildContext context) => _MarkSlot(
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Icon(Icons.favorite, size: 15, color: palette.tint),
    ),
  );
}

/// 아직 아무것도 없는 자리에 놓이는 괘선.
class _EmptyRule extends StatelessWidget {
  const _EmptyRule({required this.palette, required this.onTap});

  final CardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 카드에 + 단추가 없으므로, 빈 괘선을 누르는 것이 줄을 더하는 길이다.
    // 눈으로 보이지 않아도 손끝과 보이스오버가 찾을 수 있어야 한다.
    return Semantics(
      label: '줄 추가',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _ruleHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: palette.line, width: _rowRule),
            ),
          ),
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
    required this.caret,
    required this.onEnter,
  });

  final Entry entry;
  final Board board;
  final CardPalette palette;
  final bool autofocus;

  /// [autofocus] 로 커서를 받을 때 글자 몇 번째 앞에 세울지.
  final int caret;

  /// 엔터를 누르거나 여러 줄을 붙여넣은 순간. 커서 앞 글은 이 칸에 남고,
  /// 뒤의 글이 줄마다 넘어간다. 두 번째 값은 넘어간 마지막 줄에서 커서가
  /// 있던 자리다.
  final void Function(List<String> rest, int caret) onEnter;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

/// 글 안의 주소. 뒤에 붙은 문장부호까지 주소로 삼지 않도록 나중에 깎는다.
final _urlPattern = RegExp(r'(https?://|www\.)[^\s]+', caseSensitive: false);

class _EntryRowState extends State<_EntryRow> {
  /// 빈 칸에서 지우기를 누른 걸 알아채려고 앞에 세워 두는 보이지 않는 글자.
  /// 칸이 정말 비어 있으면 지우기를 눌러도 아무 일이 일어나지 않아
  /// 윗 줄로 갈 때를 알 수 없다.
  static const _mark = '\u200b';

  late final TextEditingController _c = TextEditingController(
    text: _mark + widget.entry.text,
  );
  final _focus = FocusNode();

  /// 직전에 본 칸의 내용. 한글을 조합하다 값이 잠깐 비는 것과, 정말로
  /// 빈 줄에서 지우기를 누른 것을 가른다. late 초기화로 미루면 처음 읽는
  /// 때가 이미 칸이 빈 뒤라 둘을 가르지 못한다 — initState 에서 채운다.
  late String _prev;

  bool _hover = false;
  bool _movingCaret = false;

  /// 주소가 눌리게 그려 둔 줄을 눌러 다시 쓰기로 돌아가는 중. 이때는 칸을
  /// 새로 세우므로 autofocus 가 먹는다. 칸이 빠져 있는 동안에는 초점을
  /// 달라고 해도 받아 줄 상대가 없다.
  bool _wantEdit = false;

  @override
  void initState() {
    super.initState();
    _prev = _c.text;
    _c.addListener(_keepCaretAfterMark);
    _focus.addListener(_onFocusChanged);
    if (widget.autofocus) {
      // 초점을 받을 때 커서 자리가 비어 있으면 글 끝에 선다. 미리 세워
      // 두어야 글자 사이에서 엔터를 눌러 넘어온 문장 맨 앞에 선다.
      final at = widget.caret.clamp(0, widget.entry.text.length);
      _c.selection = TextSelection.collapsed(offset: _mark.length + at);
      _grabFocusSoon();
    }
  }

  @override
  void didUpdateWidget(_EntryRow old) {
    super.didUpdateWidget(old);
    if (!old.autofocus && widget.autofocus) _grabFocusSoon();
  }

  /// 방금 생긴 줄로 커서를 옮긴다.
  ///
  /// TextField 의 autofocus 는 그 자리에 이미 초점을 쥔 칸이 있으면 조용히
  /// 넘어간다. 엔터로 줄을 만들 때는 바로 윗 줄이 초점을 쥐고 있으므로,
  /// 칸이 자리를 잡은 다음 초점을 직접 가져와야 커서가 실제로 내려온다.
  void _grabFocusSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _text => _c.text.replaceAll(_mark, '');

  void _save(String text) =>
      MemoStore.instance.setEntryText(widget.entry.id, text);

  void _put(String text) {
    _c.value = TextEditingValue(
      text: _mark + text,
      selection: TextSelection.collapsed(offset: _mark.length + text.length),
    );
    _prev = _c.text;
  }

  /// 커서가 보이지 않는 표식 앞에 서지 못하게 막는다.
  ///
  /// 거기서 글을 쓰면 새 글자가 표식보다 앞에 붙는다. 그걸 되돌리려고
  /// 칸 값을 다시 쓰는 순간 한글 조합이 끊겨, 글자가 사라지거나 윗 줄로
  /// 딸려 올라갔다. 아예 커서를 표식 뒤로만 세워 두면 되돌릴 일이 없다.
  void _keepCaretAfterMark() {
    if (_movingCaret) return;
    final v = _c.value;
    if (!v.text.startsWith(_mark) || v.composing.isValid) return;
    final s = v.selection;
    if (!s.isValid || !s.isCollapsed || s.baseOffset != 0) return;
    _movingCaret = true;
    _c.selection = const TextSelection.collapsed(offset: _mark.length);
    _movingCaret = false;
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) {
      _wantEdit = false;
      // 붙여넣기처럼 표식째 갈아치운 뒤에는 커서가 떠난 김에 되살린다.
      if (_c.text.isNotEmpty && !_c.text.startsWith(_mark)) _put(_c.text);
    }
    if (mounted) setState(() {});
  }

  void _onChanged(String v) {
    final composing = _c.value.composing.isValid;

    if (v.isEmpty) {
      // 보이지 않는 표식까지 지워졌다 = 빈 줄에서 지우기를 눌렀다.
      // 조합 중에 값이 잠깐 비는 일이 있어 직전 내용도 함께 본다.
      if (_prev == _mark && !composing) {
        _prev = '';
        // 지우기 전에 초점을 옮겨야 이미 사라진 칸에서 초점을 찾지 않는다.
        FocusScope.of(context).previousFocus();
        MemoStore.instance.deleteEntry(widget.entry.id);
        return;
      }
      _prev = v;
      _save('');
      setState(() {});
      return;
    }
    _prev = v;

    final text = v.replaceAll(_mark, '');
    if (text.contains('\n')) {
      // 칸 안에서 줄을 바꾸는 대신 줄마다 제 칸을 준다. 긴 글을 붙여넣어도
      // 한 줄에 뭉치지 않는다.
      final parts = text.split('\n');
      final head = parts.first;
      // 커서가 마지막 줄 안 어디에 있었는지. 끝에서 누른 엔터나 붙여넣기는
      // 그 줄 끝, 글자 사이에서 누른 엔터는 옮겨 가는 문장 맨 앞이다.
      final sel = _c.value.selection;
      final before = sel.isValid
          ? v.substring(0, sel.baseOffset).replaceAll(_mark, '').length
          : text.length;
      final caret = (before - (text.lastIndexOf('\n') + 1)).clamp(
        0,
        parts.last.length,
      );
      _put(head);
      _save(head);
      widget.onEnter(parts.skip(1).toList(), caret);
      return;
    }
    // 표식이 사라졌으면 되살린다. 조합 중에는 손대지 않는다 — 값을
    // 되돌리는 순간 조합이 끊긴다.
    if (!v.startsWith(_mark) && !composing) _put(text);
    _save(text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isCheck = widget.board.kind == BoardKind.checklist;
    final done = widget.entry.checked;
    final style = TextStyle(
      fontSize: _rowText,
      height: _rowLine / _rowText,
      color: done ? p.ink.withValues(alpha: .45) : p.ink,
      decoration: done ? TextDecoration.lineThrough : null,
      decorationColor: p.ink.withValues(alpha: .45),
    );
    final text = _text;
    // 쓰는 중에는 글자 그대로 두고, 손을 뗀 뒤에만 주소를 눌리게 한다.
    // 칸 위에 겹쳐 그리면 커서와 글자가 어긋난다.
    final showLinks =
        !_wantEdit && !_focus.hasFocus && _urlPattern.hasMatch(text);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        // 글이 길어지면 줄을 바꿔 칸이 같이 자란다.
        constraints: const BoxConstraints(minHeight: _rowHeight),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: p.line, width: _rowRule),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCheck) ...[
              _MarkSlot(
                child: _CheckBox(
                  checked: done,
                  palette: p,
                  onTap: () => MemoStore.instance.toggleEntry(widget.entry.id),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (widget.board.kind == BoardKind.hearts) _HeartBullet(palette: p),
            Expanded(
              child: Stack(
                children: [
                  if (showLinks)
                    _LinkedText(
                      text: text,
                      style: style,
                      linkColor: p.tint,
                      onTapText: () {
                        setState(() => _wantEdit = true);
                        _grabFocusSoon();
                      },
                    )
                  else
                    TextField(
                      controller: _c,
                      focusNode: _focus,
                      autofocus: widget.autofocus || _wantEdit,
                      onChanged: _onChanged,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      cursorColor: p.ink,
                      style: style,
                      // 줄 높이가 글꼴 속사정을 타지 않도록 못 박는다.
                      strutStyle: const StrutStyle(
                        fontSize: _rowText,
                        height: _rowLine / _rowText,
                        forceStrutHeight: true,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: _rowPad),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: InkWell(
                onTap: () => MemoStore.instance.deleteEntry(widget.entry.id),
                // 줄 사이를 오갈 때 이 단추에 걸리지 않게 한다.
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(9),
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

/// 적어 둔 글을 그대로 보여 주되 주소만 눌리게 한다.
///
/// 칸(TextField)과 같은 자리·같은 서체로 그려야 커서가 들어올 때 글자가
/// 움직이지 않는다. 주소가 아닌 자리를 누르면 다시 쓰던 칸으로 돌아간다.
class _LinkedText extends StatefulWidget {
  const _LinkedText({
    required this.text,
    required this.style,
    required this.linkColor,
    required this.onTapText,
  });

  final String text;
  final TextStyle style;
  final Color linkColor;
  final VoidCallback onTapText;

  @override
  State<_LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<_LinkedText> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _clear() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주소를 열지 못했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _urlPattern.allMatches(widget.text)) {
      if (m.start > at) {
        spans.add(TextSpan(text: widget.text.substring(at, m.start)));
      }
      final whole = m.group(0)!;
      // 문장 끝의 마침표나 괄호는 주소가 아니다.
      final url = whole.replaceFirst(RegExp(r'[.,!?;:)\]}>"\u2019]+$'), '');
      final tap = TapGestureRecognizer()..onTap = () => _open(url);
      _taps.add(tap);
      spans.add(
        TextSpan(
          text: url,
          recognizer: tap,
          style: widget.style.copyWith(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        ),
      );
      at = m.start + url.length;
    }
    if (at < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(at)));
    }

    return GestureDetector(
      onTap: widget.onTapText,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          // 칸의 contentPadding 과 같은 값 — 커서가 들어와도 글자가
          // 위아래로 움직이지 않는다.
          padding: const EdgeInsets.symmetric(vertical: _rowPad),
          child: Text.rich(
            TextSpan(style: widget.style, children: spans),
            strutStyle: const StrutStyle(
              fontSize: _rowText,
              height: _rowLine / _rowText,
              forceStrutHeight: true,
            ),
          ),
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
  const _Footer({required this.bg, required this.showNotes});

  final BackgroundTheme bg;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    // 좁은 화면에서는 귀퉁이 쪽지를 접으므로 꼬리말에 남는 것이 없다.
    if (!showNotes) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Transform.rotate(
            angle: -.03,
            alignment: Alignment.centerLeft,
            child: _CornerNote('오늘도\n말랑한 하루 ♡', bg: bg, align: TextAlign.left),
          ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        // Material 로 깔아야 안에 놓인 ListTile 이 제 바탕 위에 잉크를
        // 번지게 할 수 있다. 색칠한 상자로 감싸면 그 효과가 가려진다.
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: _round(19, const Color(0xFF6B4F52)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '닫기',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: const Color(0xFF6B4F52),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in const {
                    BoardKind.note: '메모',
                    BoardKind.checklist: '체크리스트',
                    BoardKind.hearts: '하트',
                  }.entries)
                    _PickBox(
                      label: kind.value,
                      selected: board.kind == kind.key,
                      onTap: () => setState(
                        () => _store.updateBoard(board.id, kind: kind.key),
                      ),
                    ),
                ],
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
                            // 고양이를 고를 때와 같은 테두리 색.
                            color: board.badgeKey == b.key
                                ? _pickedEdge(context)
                                : Colors.black.withValues(alpha: .08),
                            width: board.badgeKey == b.key ? 2.2 : 1,
                          ),
                        ),
                        child: b.icon == null
                            // '없음' 은 그림 대신 빈 자리를 보여 준다.
                            ? SizedBox(
                                width: 19,
                                height: 19,
                                child: Icon(
                                  Icons.block,
                                  size: 15,
                                  color: Colors.black.withValues(alpha: .25),
                                ),
                              )
                            : Icon(b.icon, size: 19, color: b.color),
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
                    _CatPick(
                      label: cat.name,
                      // 세 마리를 고르면 한 마리 선택은 쉬어 간다.
                      selected:
                          board.pose != CatPose.trio && board.catId == cat.id,
                      onTap: () => setState(() {
                        _store.updateBoard(
                          board.id,
                          catId: cat.id,
                          pose: board.pose == CatPose.trio
                              ? CatPose.peekBottom
                              : null,
                        );
                      }),
                      child: CatFace(spec: cat, width: 44),
                    ),
                  // 세 마리는 그림 한 장이라 자리가 아니라 고양이로 고른다.
                  _CatPick(
                    label: '세 마리',
                    selected: board.pose == CatPose.trio,
                    onTap: () => setState(
                      () => _store.updateBoard(board.id, pose: CatPose.trio),
                    ),
                    child: const OriginalArtwork(art: 'trio', width: 56),
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

/// 고른 것을 감싸는 테두리 색. 고양이·배지·카드 종류가 같은 색을 쓴다.
Color _pickedEdge(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

/// 그림 하나와 이름으로 고르는 칸.
class _CatPick extends StatelessWidget {
  const _CatPick({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _pickedEdge(context) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 40, child: Center(child: child)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}

/// 글자 하나로 고르는 둥근 박스.
class _PickBox extends StatelessWidget {
  const _PickBox({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final edge = _pickedEdge(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? edge.withValues(alpha: .10) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? edge : Colors.black.withValues(alpha: .12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected ? edge : const Color(0xFF6B4F52),
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
