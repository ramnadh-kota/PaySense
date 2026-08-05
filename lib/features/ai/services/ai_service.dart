abstract class AiService {
  Future<String> ask({
    required String message,
    required String financialContext,
  });
}
