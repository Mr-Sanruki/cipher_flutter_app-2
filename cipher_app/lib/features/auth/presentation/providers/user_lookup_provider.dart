import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final userByIdProvider = FutureProvider.family.autoDispose<UserModel?, String>((ref, userId) async {
  final id = userId.trim();
  if (id.isEmpty) return null;

  final isObjectId = RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);
  if (!isObjectId) return null;

  final t = Timer(const Duration(seconds: 20), () {
    ref.invalidateSelf();
  });
  ref.onDispose(t.cancel);

  final items = await ref.watch(authRepositoryProvider).getUsersByIds([id]);
  if (items.isEmpty) return null;
  return items.first;
});
