import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ugk_exercise/platform/video_replay_service.dart';

void main() {
  test('decodePpmFrame parses binary P6 frames with comments', () {
    final header = ascii.encode('P6\n# comment\n2 1\n255\n');
    final bytes = Uint8List.fromList([...header, 1, 2, 3, 4, 5, 6]);

    final frame = decodePpmFrame(bytes);

    expect(frame.width, 2);
    expect(frame.height, 1);
    expect(frame.rgb, [1, 2, 3, 4, 5, 6]);
  });
}
