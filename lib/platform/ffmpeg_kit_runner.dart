import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

Future<String?> runFfmpegKit(List<String> args) async {
  final session = await FFmpegKit.executeWithArguments(args);
  final returnCode = await session.getReturnCode();
  if (ReturnCode.isSuccess(returnCode)) {
    return null;
  }
  final output = await session.getOutput();
  final stack = await session.getFailStackTrace();
  return 'ffmpeg failed (${returnCode?.getValue()}): $output $stack';
}
