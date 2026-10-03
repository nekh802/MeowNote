import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/widgets/cat_face.dart';
import 'package:meow_note/widgets/original_artwork.dart';

void main() {
  test('CatSpec.spaceCats 는 오려 둔 우주 고양이 열여덟 마리와 정확히 같다', () {
    final ids = CatSpec.spaceCats.map((c) => c.id).toSet();
    expect(ids, OriginalArtwork.spaceCats);
    expect(ids, hasLength(18));
    // 원래 고양이(모찌 등)는 하나도 섞이지 않는다.
    expect(ids.contains('mochi'), isFalse);
  });
}
