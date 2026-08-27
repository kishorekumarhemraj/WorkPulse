import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/services/timesheet_grid_math.dart';

void main() {
  group('packIntoTwoColumns tests', () {
    test('empty list returns two empty columns', () {
      final packed = packIntoTwoColumns<String>([], (s) => 100.0);
      expect(packed.length, 2);
      expect(packed[0], isEmpty);
      expect(packed[1], isEmpty);
    });

    test('fills left first when heights are equal', () {
      final items = ['item1', 'item2', 'item3', 'item4'];
      final packed = packIntoTwoColumns<String>(items, (s) => 50.0);

      // Heights:
      // item1: L (h=[50, 0])
      // item2: R (h=[50, 50])
      // item3: L (h=[100, 50])
      // item4: R (h=[100, 100])
      expect(packed[0], ['item1', 'item3']);
      expect(packed[1], ['item2', 'item4']);
    });

    test('puts each section in the currently shorter column', () {
      final items = [
        {'id': 'tall', 'height': 300.0},
        {'id': 'short1', 'height': 50.0},
        {'id': 'short2', 'height': 60.0},
        {'id': 'short3', 'height': 70.0},
        {'id': 'short4', 'height': 80.0},
      ];

      final packed = packIntoTwoColumns<Map<String, dynamic>>(
        items,
        (s) => s['height'] as double,
      );

      // 'tall' (300) goes to L (h=[300, 0])
      // 'short1' (50) goes to R (h=[300, 50])
      // 'short2' (60) goes to R (h=[300, 110])
      // 'short3' (70) goes to R (h=[300, 180])
      // 'short4' (80) goes to R (h=[300, 260])
      expect(packed[0].map((m) => m['id']).toList(), ['tall']);
      expect(packed[1].map((m) => m['id']).toList(),
          ['short1', 'short2', 'short3', 'short4']);
    });
  });
}
