import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../models/message_model.dart';
import '../models/channel_model.dart';
import '../models/group_model.dart';
import '../models/dm_model.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../auth/data/repositories/auth_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return ChatRepository(ref.watch(authRepositoryProvider), baseUrl: cfg.backendBaseUrl);
});

class ChatRepository {
  final AuthRepository _authRepo;
  final Dio _dio;
  final String _baseUrl;

  sio.Socket? _socket;
  String? _socketToken;
  Timer? _socketRetryTimer;
  final _incomingCallController = StreamController<Map<String, String>>.broadcast();
  final _callEventController = StreamController<Map<String, String>>.broadcast();
  final Map<String, StreamController<List<MessageModel>>> _messageControllers = {};
  final Map<String, List<MessageModel>> _messageCache = {};

  ChatRepository(this._authRepo, {required String baseUrl})
      : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ));

  Map<String, String> _headers() {
    final token = _authRepo.getSavedToken();
    if (token == null) throw Exception('UNAUTHORIZED');
    return {'Authorization': 'Bearer $token'};
  }

  void _disposeSocket() {
    try {
      _socket?.dispose();
    } catch (_) {
      try {
        _socket?.disconnect();
      } catch (_) {}
    }
    _socket = null;
    _socketToken = null;
  }

  void _ensureSocketConnected() {
    final token = _authRepo.getSavedToken();
    if (token == null) return;

    if (_socket != null) {
      if (_socketToken != token) {
        if (kDebugMode) debugPrint('[socket] token changed -> recreating socket');
        _disposeSocket();
      } else {
        if (!_socket!.connected) {
          if (kDebugMode) debugPrint('[socket] reconnecting existing socket');
          _socket!.connect();
        }
        return;
      }
    }

    final s = sio.io(
      _baseUrl,
      sio.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(20000)
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    s.on('connect', (_) {
      if (kDebugMode) debugPrint('[socket] connected id=${s.id}');
    });
    s.on('disconnect', (reason) {
      if (kDebugMode) debugPrint('[socket] disconnected reason=$reason');
    });
    s.on('connect_error', (e) {
      if (kDebugMode) debugPrint('[socket] connect_error $e');
    });

    s.on('chat:cleared', (payload) async {
      try {
        if (payload is! Map) return;
        final chatType = (payload['chatType'] ?? '').toString().trim();
        final chatId = (payload['chatId'] ?? '').toString().trim();
        if (chatType.isEmpty || chatId.isEmpty) return;

        final key = _key(chatType, chatId);
        final controller = _messageControllers[key];
        if (controller == null) return;
        _messageCache[key] = [];
        if (!controller.isClosed) controller.add([]);

        final refreshed = await listMessages(chatType: chatType, chatId: chatId);
        _messageCache[key] = refreshed;
        if (!controller.isClosed) controller.add(refreshed);
      } catch (_) {}
    });

    s.on('call:incoming', (payload) {
      try {
        if (payload is! Map) return;
        final fromUserId = (payload['fromUserId'] ?? '').toString().trim();
        final callId = (payload['callId'] ?? '').toString().trim();
        final callType = 'video';
        if (fromUserId.isEmpty || callId.isEmpty) return;
        if (kDebugMode) {
          debugPrint('[socket] call:incoming from=$fromUserId callId=$callId type=$callType');
        }
        _incomingCallController.add({'fromUserId': fromUserId, 'callId': callId, 'callType': callType});
      } catch (_) {}
    });

    s.on('call:accepted', (payload) {
      try {
        if (payload is! Map) return;
        final fromUserId = (payload['fromUserId'] ?? '').toString().trim();
        final callId = (payload['callId'] ?? '').toString().trim();
        final callType = 'video';
        if (fromUserId.isEmpty || callId.isEmpty) return;
        _callEventController.add({'event': 'accepted', 'fromUserId': fromUserId, 'callId': callId, 'callType': callType});
      } catch (_) {}
    });

    s.on('call:declined', (payload) {
      try {
        if (payload is! Map) return;
        final fromUserId = (payload['fromUserId'] ?? '').toString().trim();
        final callId = (payload['callId'] ?? '').toString().trim();
        final callType = 'video';
        if (fromUserId.isEmpty || callId.isEmpty) return;
        _callEventController.add({'event': 'declined', 'fromUserId': fromUserId, 'callId': callId, 'callType': callType});
      } catch (_) {}
    });

    s.connect();
    _socket = s;
    _socketToken = token;
  }

  void _emitWhenConnected(String event, Map<String, dynamic> data) {
    _ensureSocketConnected();
    final s = _socket;
    if (s == null) return;

    if (s.connected) {
      s.emit(event, data);
      return;
    }

    void onConnect(_) {
      try {
        s.emit(event, data);
      } catch (_) {}
      s.off('connect', onConnect);
    }

    s.on('connect', onConnect);
  }

  Stream<Map<String, String>> incomingCalls() {
    _socketRetryTimer ??= Timer.periodic(const Duration(seconds: 2), (t) {
      try {
        _ensureSocketConnected();
      } catch (_) {}
    });
    _ensureSocketConnected();
    return _incomingCallController.stream;
  }

  Stream<Map<String, String>> callEvents() {
    _ensureSocketConnected();
    return _callEventController.stream;
  }

  void sendCallInvite({required String toUserId, required String callId, String callType = 'video'}) {
    _emitWhenConnected('call:invite', {'toUserId': toUserId, 'callId': callId, 'callType': 'video'});
  }

  void sendCallAccept({required String toUserId, required String callId, String callType = 'video'}) {
    _emitWhenConnected('call:accept', {'toUserId': toUserId, 'callId': callId, 'callType': 'video'});
  }

  void sendCallDecline({required String toUserId, required String callId, String callType = 'video'}) {
    _emitWhenConnected('call:decline', {'toUserId': toUserId, 'callId': callId, 'callType': 'video'});
  }

  // ─── Channels ───────────────────────────────────────────────
  Future<ChannelModel> createChannel({
    required String workspaceId,
    required String name,
    String? description,
    bool isAnnouncement = false,
  }) async {
    try {
      final res = await _dio.post(
        '/chats/channels',
        data: {
          'workspaceId': workspaceId,
          'name': name,
          'description': description,
          'isAnnouncement': isAnnouncement,
        },
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['channel'] is Map) {
        return ChannelModel.fromJson(Map<String, dynamic>.from(data['channel']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<GroupModel> addMembersToGroup({
    required String groupId,
    required List<String> memberIds,
  }) async {
    try {
      final res = await _dio.post(
        '/chats/groups/$groupId/members',
        data: {'memberIds': memberIds},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['group'] is Map) {
        return GroupModel.fromJson(Map<String, dynamic>.from(data['group']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Stream<List<ChannelModel>> getChannels(String workspaceId, {Duration pollEvery = const Duration(seconds: 3)}) async* {
    while (true) {
      yield await listChannels(workspaceId);
      await Future<void>.delayed(pollEvery);
    }
  }

  Future<List<ChannelModel>> listChannels(String workspaceId) async {
    try {
      final res = await _dio.get(
        '/chats/channels',
        queryParameters: {'workspaceId': workspaceId},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      final items = (data is Map ? data['items'] : null);
      if (items is List) {
        return items
            .whereType<Map>()
            .map((m) => ChannelModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  // ─── Groups ──────────────────────────────────────────────────
  Future<GroupModel> createGroup({
    required String workspaceId,
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      final res = await _dio.post(
        '/chats/groups',
        data: {
          'workspaceId': workspaceId,
          'name': name,
          'memberIds': memberIds,
        },
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['group'] is Map) {
        return GroupModel.fromJson(Map<String, dynamic>.from(data['group']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Stream<List<GroupModel>> getGroups(String workspaceId, {Duration pollEvery = const Duration(seconds: 3)}) async* {
    while (true) {
      yield await listGroups(workspaceId);
      await Future<void>.delayed(pollEvery);
    }
  }

  Future<List<GroupModel>> listGroups(String workspaceId) async {
    try {
      final res = await _dio.get(
        '/chats/groups',
        queryParameters: {'workspaceId': workspaceId},
        options: Options(headers: _headers(), receiveTimeout: const Duration(seconds: 60)),
      );
      final data = res.data;
      final items = (data is Map ? data['items'] : null);
      if (items is List) {
        return items
            .whereType<Map>()
            .map((m) => GroupModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  // ─── DMs ─────────────────────────────────────────────────────
  Future<DmModel> getDmById({required String dmId}) async {
    try {
      final res = await _dio.get(
        '/chats/dm/$dmId',
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['dm'] is Map) {
        return DmModel.fromJson(Map<String, dynamic>.from(data['dm']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<DmModel> getOrCreateDm({
    required String workspaceId,
    required String otherUserId,
  }) async {
    try {
      final res = await _dio.post(
        '/chats/dms',
        data: {'workspaceId': workspaceId, 'otherUserId': otherUserId},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['dm'] is Map) {
        return DmModel.fromJson(Map<String, dynamic>.from(data['dm']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Stream<List<DmModel>> getDms(String workspaceId, {Duration pollEvery = const Duration(seconds: 3)}) async* {
    while (true) {
      yield await listDms(workspaceId);
      await Future<void>.delayed(pollEvery);
    }
  }

  Future<List<DmModel>> listDms(String workspaceId) async {
    try {
      final res = await _dio.get(
        '/chats/dms',
        queryParameters: {'workspaceId': workspaceId},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      final items = (data is Map ? data['items'] : null);
      if (items is List) {
        return items
            .whereType<Map>()
            .map((m) => DmModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  // ─── Messages ────────────────────────────────────────────────
  String _key(String chatType, String chatId) => '$chatType:$chatId';

  Stream<List<MessageModel>> getMessages({required String chatType, required String chatId}) {
    final key = _key(chatType, chatId);
    final existing = _messageControllers[key];
    if (existing != null) return existing.stream;

    final controller = StreamController<List<MessageModel>>.broadcast();
    _messageControllers[key] = controller;

    () async {
      final initial = await listMessages(chatType: chatType, chatId: chatId);
      _messageCache[key] = initial;
      if (!controller.isClosed) controller.add(initial);

      _ensureSocketConnected();
      _socket?.emit('chat:join', {'chatType': chatType, 'chatId': chatId});

      void onNew(dynamic payload) {
        try {
          if (payload is! Map) return;
          final m = MessageModel.fromJson(Map<String, dynamic>.from(payload));
          if (m.chatType != chatType || m.chatId != chatId) return;
          final cur = _messageCache[key] ?? [];
          if (cur.any((x) => x.id == m.id)) return;
          final next = [m, ...cur];
          _messageCache[key] = next;
          if (!controller.isClosed) controller.add(next);
        } catch (_) {}
      }

      _socket?.on('message:new', onNew);

      void onUpdate(dynamic payload) {
        try {
          if (payload is! Map) return;
          final m = MessageModel.fromJson(Map<String, dynamic>.from(payload));
          if (m.chatType != chatType || m.chatId != chatId) return;
          final cur = _messageCache[key] ?? [];
          final idx = cur.indexWhere((x) => x.id == m.id);
          if (idx < 0) return;
          final next = [...cur];
          next[idx] = m;
          _messageCache[key] = next;
          if (!controller.isClosed) controller.add(next);
        } catch (_) {}
      }

      _socket?.on('message:update', onUpdate);

      controller.onCancel = () {
        _socket?.emit('chat:leave', {'chatType': chatType, 'chatId': chatId});
        _socket?.off('message:new', onNew);
        _socket?.off('message:update', onUpdate);
        _messageControllers.remove(key);
        _messageCache.remove(key);
      };
    }();

    return controller.stream;
  }

  Future<List<MessageModel>> listMessages({required String chatType, required String chatId, int limit = 50}) async {
    try {
      final res = await _dio.get(
        '/chats/$chatType/$chatId/messages',
        queryParameters: {'limit': limit},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      final items = (data is Map ? data['items'] : null);
      if (items is List) {
        return items
            .whereType<Map>()
            .map((m) => MessageModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<MessageModel> sendMessage({
    required String chatType,
    required String chatId,
    required String senderName,
    String? senderAvatar,
    required String content,
    MessageType type = MessageType.text,
    String? fileUrl,
    String? fileName,
    String? fileSize,
  }) async {
    try {
      final res = await _dio.post(
        '/chats/$chatType/$chatId/messages',
        data: {
          'content': content,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
          'type': type.name,
          'fileUrl': fileUrl,
          'fileName': fileName,
          'fileSize': fileSize,
        },
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['message'] is Map) {
        return MessageModel.fromJson(Map<String, dynamic>.from(data['message']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<void> markDelivered({required String chatType, required String chatId, required List<String> messageIds}) async {
    if (messageIds.isEmpty) return;
    await _dio.post(
      '/chats/$chatType/$chatId/messages/delivered',
      data: {'messageIds': messageIds},
      options: Options(headers: _headers()),
    );
  }

  Future<void> markRead({required String chatType, required String chatId, required List<String> messageIds}) async {
    if (messageIds.isEmpty) return;
    await _dio.post(
      '/chats/$chatType/$chatId/messages/read',
      data: {'messageIds': messageIds},
      options: Options(headers: _headers()),
    );
  }

  Future<void> editMessage(String chatId, String messageId, String newContent) async {}

  Future<void> deleteMessage({required String chatType, required String chatId, required String messageId}) async {
    await _dio.delete(
      '/chats/$chatType/$chatId/messages/$messageId',
      options: Options(headers: _headers()),
    );
  }

  Future<void> clearChat({required String chatType, required String chatId}) async {
    await _dio.post(
      '/chats/$chatType/$chatId/clear',
      options: Options(headers: _headers()),
    );
  }

  Future<void> hideDm({required String dmId}) async {
    await _dio.post(
      '/chats/dm/$dmId/hide',
      options: Options(headers: _headers()),
    );
  }

  Future<MessageModel> toggleReaction({
    required String chatType,
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final res = await _dio.post(
        '/chats/$chatType/$chatId/messages/$messageId/reactions',
        data: {'emoji': emoji, 'action': 'toggle'},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['message'] is Map) {
        return MessageModel.fromJson(Map<String, dynamic>.from(data['message']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<MessageModel> forwardMessage({
    required String sourceChatType,
    required String sourceChatId,
    required String messageId,
    required String targetChatType,
    required String targetChatId,
    required String senderName,
    String? senderAvatar,
  }) async {
    try {
      final res = await _dio.post(
        '/chats/$sourceChatType/$sourceChatId/messages/$messageId/forward',
        data: {
          'targetChatType': targetChatType,
          'targetChatId': targetChatId,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
        },
        options: Options(headers: _headers()),
      );
      final data = res.data;
      if (data is Map && data['message'] is Map) {
        return MessageModel.fromJson(Map<String, dynamic>.from(data['message']));
      }
      throw Exception('Invalid response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<List<MessageModel>> searchMessages({
    required String chatType,
    required String chatId,
    required String query,
    int limit = 30,
  }) async {
    try {
      final res = await _dio.get(
        '/chats/$chatType/$chatId/messages/search',
        queryParameters: {'q': query, 'limit': limit},
        options: Options(headers: _headers()),
      );
      final data = res.data;
      final items = (data is Map ? data['items'] : null);
      if (items is List) {
        return items
            .whereType<Map>()
            .map((m) => MessageModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  // ─── Threads ─────────────────────────────────────────────────
  Stream<List<MessageModel>> getThreadMessages({
    required String chatType,
    required String chatId,
    required String messageId,
    Duration pollEvery = const Duration(seconds: 3),
  }) async* {
    while (true) {
      yield await listThreadMessages(chatType: chatType, chatId: chatId, messageId: messageId);
      await Future<void>.delayed(pollEvery);
    }
  }

  Future<List<MessageModel>> listThreadMessages({required String chatType, required String chatId, required String messageId}) async {
    try {
      final res = await _dio.get(
        '/chats/$chatType/$chatId/messages/$messageId/threads',
        options: Options(headers: _headers()),
      );
      final data = res.data;
      final items = (data is Map ? data['items'] : null);
      if (items is List) {
        return items
            .whereType<Map>()
            .map((m) => MessageModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      throw Exception(e.message ?? 'Network error');
    }
  }

  Future<void> sendThreadMessage({
    required String chatType,
    required String chatId,
    required String messageId,
    required MessageModel message,
  }) async {
    await _dio.post(
      '/chats/$chatType/$chatId/messages/$messageId/threads',
      data: {
        'content': message.content,
        'senderName': message.senderName,
        'senderAvatar': message.senderAvatar,
        'type': message.type.name,
      },
      options: Options(headers: _headers()),
    );
  }

  // ─── File Upload ─────────────────────────────────────────────
  Future<String> uploadFile(File file, String chatId) async {
    final fileName = file.path.split('/').last;
    final form = FormData.fromMap({
      'chatId': chatId,
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final res = await _dio.post(
      '/uploads/chat-file',
      data: form,
      options: Options(
        headers: {
          ..._headers(),
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
    final data = res.data;
    if (data is Map && data['url'] != null) return data['url'].toString();
    throw Exception('Invalid response');
  }

  Future<String> uploadImage(File image, String chatId) async {
    final fileName = image.path.split('/').last;
    final form = FormData.fromMap({
      'chatId': chatId,
      'file': await MultipartFile.fromFile(image.path, filename: fileName),
    });

    final res = await _dio.post(
      '/uploads/chat-image',
      data: form,
      options: Options(
        headers: {
          ..._headers(),
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
    final data = res.data;
    if (data is Map && data['url'] != null) return data['url'].toString();
    throw Exception('Invalid response');
  }
}
