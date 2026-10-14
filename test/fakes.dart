import 'dart:typed_data';

import 'package:tarteeb/platform/native_bridge.dart';
import 'package:tarteeb/sms/sms_parser.dart';

/// In-memory stand-in for the Kotlin side.
class FakeNativeBridge extends NativeBridge {
  SmsPermissions perms = const SmsPermissions(PermState.granted, PermState.granted);
  List<RawSms> inbox = [];
  final List<QueuedSms> queue = [];
  List<ReminderSpec> reminders = [];
  final List<String> notifications = [];
  bool processingEnabled = false;

  @override
  Future<SmsPermissions> smsPermissions() async => perms;

  @override
  Future<SmsPermissions> requestSms(List<String> which) async => perms;

  @override
  Future<InboxChunk> queryInbox(int fromMs, int toMs) async {
    final items = inbox.where((m) => m.receivedAt >= fromMs && m.receivedAt < toMs).toList();
    return InboxChunk(items.length, items.where((m) => looksFinancial(m.body)).toList());
  }

  @override
  Future<void> setSmsProcessingEnabled(bool enabled) async {
    processingEnabled = enabled;
  }

  @override
  Future<List<QueuedSms>> peekSmsQueue() async => List.of(queue);

  @override
  Future<void> ackSmsQueue(List<String> ids) async {
    queue.removeWhere((q) => ids.contains(q.id));
  }

  @override
  Future<void> clearSmsQueue() async {
    queue.clear();
  }

  @override
  Future<void> syncReminders(List<ReminderSpec> specs) async {
    reminders = specs;
  }

  @override
  Future<void> showTxnNotification(String title, String body) async {
    notifications.add(title);
  }

  @override
  Future<PermState> notificationPermission() async => PermState.granted;

  @override
  Future<bool> canScheduleExact() async => true;

  /// Reversible stand-in for encryption (tests only): XOR with the password.
  @override
  Future<Map<String, Object?>?> encrypt(Uint8List plain, String password) async {
    final k = password.codeUnits;
    return {
      'alg': 'test',
      'data': [for (var i = 0; i < plain.length; i++) plain[i] ^ k[i % k.length]],
      'check': password.length,
    };
  }

  @override
  Future<Uint8List?> decrypt(Map<String, Object?> envelope, String password) async {
    if (envelope['check'] != password.length) return null;
    final k = password.codeUnits;
    final data = (envelope['data'] as List).cast<int>();
    return Uint8List.fromList([for (var i = 0; i < data.length; i++) data[i] ^ k[i % k.length]]);
  }
}
