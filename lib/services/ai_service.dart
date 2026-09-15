import 'package:cloud_functions/cloud_functions.dart';

/// Transit AI's contract. Swappable by design: today [FirebaseAiService]
/// answers with a rule-based intent matcher over real Firestore data (see
/// the `assistantQuery` Cloud Function), so it can never fabricate a fare
/// or balance. A future version backed by a real LLM can implement this
/// same interface — the API key would live in the Cloud Function, never
/// in the app — without any UI changes.
abstract class AiService {
  /// Sends [message] to the assistant and returns its reply. Implementers
  /// must only speak from real application data and must never mutate
  /// money — the assistant explains and reads, it doesn't transact.
  Future<String> sendMessage(String message);
}

class FirebaseAiService implements AiService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  Future<String> sendMessage(String message) async {
    try {
      final callable = _functions.httpsCallable('assistantQuery');
      final res = await callable.call<Map<String, dynamic>>({
        'message': message,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      return data['reply'] as String? ??
          "Sorry, I couldn't work that out. Try rephrasing?";
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Transit AI is unavailable right now. Please try again.';
    } catch (_) {
      return 'Transit AI is unavailable right now. Please try again.';
    }
  }
}
