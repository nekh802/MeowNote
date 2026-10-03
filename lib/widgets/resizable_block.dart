import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n.dart';

import '../models/attachment.dart';

/// 손잡이를 끌어 가로 크기를 바꾸는 블록. 사진과 동영상이 메모 안에서 쓴다.
///
/// 크기는 부모가 내어 준 너비에 대한 몫([fraction])이다. 끄는 동안에는 이
/// 위젯이 값을 쥐고 있다가, 손을 뗀 순간 [onResized] 로 한 번만 알린다 —
/// 끄는 내내 저장하면 한 번 늘리는 데 파일을 수십 번 쓴다.
class ResizableBlock extends StatefulWidget {
  const ResizableBlock({
    super.key,
    required this.fraction,
    required this.onResized,
    required this.builder,
    this.handleColor = const Color(0xCC000000),
  });

  final double fraction;
  final ValueChanged<double> onResized;

  /// 지금 너비와, 늘려 볼 수 있는 가장 큰 너비를 받아 내용을 그린다.
  final Widget Function(BuildContext context, double width, double maxWidth)
  builder;
  final Color handleColor;

  /// 손잡이가 차지하는 네모의 한 변. 손가락으로 잡을 만큼은 되어야 한다.
  static const handleSize = 34.0;

  @override
  State<ResizableBlock> createState() => _ResizableBlockState();
}

class _ResizableBlockState extends State<ResizableBlock> {
  /// 끄는 동안의 몫. 끄지 않을 때는 null 이라 저장된 값을 따른다.
  double? _live;

  void _start(DragStartDetails _) => setState(() => _live = widget.fraction);

  void _update(DragUpdateDetails d, double max) {
    setState(() {
      _live = ((_live ?? widget.fraction) + d.delta.dx / max).clamp(
        Attachment.minWidth,
        Attachment.maxWidth,
      );
    });
  }

  void _end(DragEndDetails _) {
    final done = _live;
    setState(() => _live = null);
    if (done != null) widget.onResized(done);
  }

  void _cancel() => setState(() => _live = null);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final max = c.maxWidth;
      final fraction = _live ?? widget.fraction;
      final width = (fraction * max).clamp(max * Attachment.minWidth, max);
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.builder(context, width, max),
              Positioned(
                right: 2,
                bottom: 2,
                child: RawGestureDetector(
                  gestures: {
                    _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(
                      _EagerPan.new,
                      (pan) {
                        pan.onStart = _start;
                        pan.onUpdate = (d) => _update(d, max);
                        pan.onEnd = _end;
                        pan.onCancel = _cancel;
                      },
                    ),
                  },
                  child: Semantics(
                    label: tr(
                      context,
                      '크기 조절',
                      en: 'Resize',
                      zh: '调整大小',
                      fr: 'Redimensionner',
                      ja: 'サイズ調整',
                    ),
                    child: Container(
                      key: const Key('resizeHandle'),
                      width: ResizableBlock.handleSize,
                      height: ResizableBlock.handleSize,
                      alignment: Alignment.center,
                      color: Colors.transparent,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.handleColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.south_east_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 손가락이 닿자마자 제스처를 가져가는 끌기.
///
/// 이 블록은 세로로 밀리는 글 안에 있다. 그냥 끌기를 쓰면 위아래로 조금만
/// 움직여도 글이 밀려 가 버려 손잡이가 말을 듣지 않는다. 손잡이 위에서는
/// 닿는 순간 이쪽이 이긴다.
class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
