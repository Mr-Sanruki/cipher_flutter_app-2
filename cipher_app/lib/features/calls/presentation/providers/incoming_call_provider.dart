import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/data/repositories/chat_repository.dart';

class IncomingCallState {
  final String? fromUserId;
  final String? callId;
  final String callType;
  const IncomingCallState({this.fromUserId, this.callId, this.callType = 'voice'});

  bool get hasCall => fromUserId != null && callId != null;
}

final incomingCallProvider = StateNotifierProvider<IncomingCallNotifier, IncomingCallState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return IncomingCallNotifier(repo);
});

class IncomingCallNotifier extends StateNotifier<IncomingCallState> {
  final ChatRepository _repo;
  IncomingCallNotifier(this._repo) : super(const IncomingCallState()) {
    _repo.incomingCalls().listen((m) {
      final from = m['fromUserId'];
      final call = m['callId'];
      final type = (m['callType'] ?? 'voice').toString();
      if (from == null || call == null) return;
      state = IncomingCallState(fromUserId: from, callId: call, callType: type);
    });
  }

  void clear() => state = const IncomingCallState();
}
