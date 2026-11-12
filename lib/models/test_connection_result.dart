/// API 连接测试结果（v2.2）
///
/// 由 [AIService.testConnection] 返回，用于设置页的「测试连接」功能。
class TestConnectionResult {
  /// 是否连接成功
  final bool success;

  /// 结果摘要，如「连接成功！API Key、模型、端点均可用」
  final String message;

  /// 请求耗时（毫秒）
  final int latencyMs;

  /// 服务端实际返回的模型名（成功时可能为空）
  final String? modelUsed;

  /// 模型回复内容预览（成功时）
  final String? replyPreview;

  /// 失败详情（失败时）
  final String? errorDetail;

  const TestConnectionResult({
    required this.success,
    required this.message,
    required this.latencyMs,
    this.modelUsed,
    this.replyPreview,
    this.errorDetail,
  });
}
