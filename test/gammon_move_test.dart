import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GammonMove.hash', () {
    final gm1 = GammonMove(fromPipNo: 1, toPipNo: 2);
    final gm2 = GammonMove(fromPipNo: 1, toPipNo: 2);
    expect(gm1.hashCode, gm2.hashCode);

    final gm3 = GammonMove(fromPipNo: 1, toPipNo: 3);
    final gm4 = GammonMove(fromPipNo: 2, toPipNo: 3);
    expect(gm1.hashCode == gm3.hashCode, false);
    expect(gm1.hashCode == gm4.hashCode, false);
  });

  test('GammonMove.operator==', () {
    final gm1 = GammonMove(fromPipNo: 1, toPipNo: 2);
    final gm2 = GammonMove(fromPipNo: 1, toPipNo: 2);
    expect(gm1, gm2);

    final gm3 = GammonMove(fromPipNo: 1, toPipNo: 3);
    final gm4 = GammonMove(fromPipNo: 2, toPipNo: 3);
    expect(gm1 == gm3, false);
    expect(gm1 == gm4, false);
  });
}
