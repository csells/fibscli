import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GammonMove.hash', () {
    final gm1 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 2, hops: [1]);
    final gm2 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 2, hops: [1]);
    expect(gm1.hashCode, gm2.hashCode);

    final gm3 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 3, hops: [1]);
    final gm4 = GammonMove(sign: -1, fromPipNo: 2, toPipNo: 2, hops: [0]);
    final gm5 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 2, hops: [0]);
    expect(gm1.hashCode == gm3.hashCode, false);
    expect(gm1.hashCode == gm4.hashCode, false);
    expect(gm1.hashCode == gm5.hashCode, false);
  });

  test('GammonMove.operator==', () {
    final gm1 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 2, hops: [1]);
    final gm2 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 2, hops: [1]);
    expect(gm1, gm2);

    final gm3 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 3, hops: [1]);
    final gm4 = GammonMove(sign: -1, fromPipNo: 2, toPipNo: 2, hops: [0]);
    final gm5 = GammonMove(sign: -1, fromPipNo: 1, toPipNo: 2, hops: [0]);
    final gm6 = GammonMove(sign: 1, fromPipNo: 1, toPipNo: 2, hops: [1]);
    expect(gm1 == gm3, false);
    expect(gm1 == gm4, false);
    expect(gm1 == gm5, false);
    expect(gm1 == gm6, false);
  });
}
