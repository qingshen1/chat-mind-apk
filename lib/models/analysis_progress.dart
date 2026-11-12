import 'analysis_result.dart';

/// 流式分析进度（v2.2.2）
///
/// 模型每返回一段增量内容就产出一帧，界面可据此实时显示分析进展，
/// 不用再等到整段 JSON 生成完毕才看到任何反馈。
class AnalysisProgress {
  /// 已累积的原始输出（模型返回的 JSON 文本片段）
  final String raw;

  /// 从已完成字段中提取的可展示预览
  final String preview;

  /// 已接收的字符数
  final int receivedChars;

  /// 首字延迟（毫秒），null 表示还没收到第一个字
  final int? firstTokenMs;

  /// 解析完成后的最终结果，只在流结束时非空
  final AnalysisResult? result;

  const AnalysisProgress({
    required this.raw,
    required this.preview,
    required this.receivedChars,
    this.firstTokenMs,
    this.result,
  });

  /// 是否已拿到最终结果
  bool get isDone => result != null;

  @override
  String toString() =>
      'AnalysisProgress(chars: $receivedChars, first: ${firstTokenMs}ms, done: $isDone)';
}

/// 服务商不支持流式输出（或返回体无法解析）时抛出。
///
/// 调用方可以捕获它并回退到一次性请求，保证功能可用。
class StreamUnsupportedException implements Exception {
  final String message;

  StreamUnsupportedException(this.message);

  @override
  String toString() => message;
}
