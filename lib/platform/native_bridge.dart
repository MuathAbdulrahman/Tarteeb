import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../sms/sms_parser.dart';

enum PermState { granted, denied, permanentlyDenied, unavailable }

PermState _perm(Object? v) {
  switch (v) {
    case 'granted':
      return PermState.granted;
    case 'permanentlyDenied':
      return PermState.permanentlyDenied;
    case 'denied':
      return PermState.denied;
  }
  return PermState.unavailable;
}

class SmsPermissions {
  final PermState read;
  final PermState receive;
  const SmsPermissions(this.read, this.receive);
  bool get canRead => read == PermState.granted;
  bool get canReceive => receive == PermState.granted;
}

/// A queued incoming message with its queue id (acknowledged after saving).
class QueuedSms {
  final String id;
  final RawSms sms;
  QueuedSms(this.id, this.sms);
}

class InboxChunk {
  final int scanned;
  final List<RawSms> candidates;
  InboxChunk(this.scanned, this.candidates);
}

/// Reminder handed to the native alarm scheduler.
class ReminderSpec {
  final int id;
  final String title;
  final String body;

  /// 'once' (fires at [at]) or 'weekly' (fires at [minutes] on [weekdayMask] days).
  final String kind;
  final int at;
  final int minutes;
  final int weekdayMask;

  /// Weekly reminders do not fire before this time (e.g. habit already done today).
  final int skipUntil;

  const ReminderSpec({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    this.at = 0,
    this.minutes = 0,
    this.weekdayMask = 0,
    this.skipUntil = 0,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'kind': kind,
        'at': at,
        'minutes': minutes,
        'mask': weekdayMask,
        'skipUntil': skipUntil,
      };
}

/// Thin wrapper over the Kotlin side (MainActivity.kt). Every call degrades
/// gracefully when the platform side is missing (tests, non-Android).
class NativeBridge {
  static const _ch = MethodChannel('tarteeb/native');

  final _smsQueued = StreamController<void>.broadcast();
  Stream<void> get onSmsQueued => _smsQueued.stream;

  NativeBridge() {
    try {
      _ch.setMethodCallHandler((call) async {
        if (call.method == 'smsQueued') _smsQueued.add(null);
        return null;
      });
    } catch (_) {}
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  // ---- SMS ----
  Future<SmsPermissions> smsPermissions() async {
    final m = await _call<Map<Object?, Object?>>('smsPermissionStatus');
    if (m == null) return const SmsPermissions(PermState.unavailable, PermState.unavailable);
    return SmsPermissions(_perm(m['read']), _perm(m['receive']));
  }

  /// [which] contains 'read' and/or 'receive'.
  Future<SmsPermissions> requestSms(List<String> which) async {
    final m = await _call<Map<Object?, Object?>>('requestSmsPermissions', {'which': which});
    if (m == null) return const SmsPermissions(PermState.unavailable, PermState.unavailable);
    return SmsPermissions(_perm(m['read']), _perm(m['receive']));
  }

  /// Reads inbox messages between [fromMs] and [toMs] (exclusive). Only
  /// messages passing the native financial pre-filter are returned.
  Future<InboxChunk> queryInbox(int fromMs, int toMs) async {
    final m = await _call<Map<Object?, Object?>>('querySmsInbox', {'from': fromMs, 'to': toMs});
    if (m == null) return InboxChunk(0, const []);
    final items = (m['items'] as List<Object?>? ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map((e) => RawSms(
              sender: (e['sender'] as String?) ?? '',
              body: (e['body'] as String?) ?? '',
              receivedAt: (e['date'] as num?)?.toInt() ?? 0,
              sentAt: (e['dateSent'] as num?)?.toInt() ?? 0,
            ))
        .toList();
    return InboxChunk((m['scanned'] as num?)?.toInt() ?? 0, items);
  }

  Future<void> setSmsProcessingEnabled(bool enabled) async {
    await _call<void>('setSmsProcessingEnabled', {'enabled': enabled});
  }

  Future<List<QueuedSms>> peekSmsQueue() async {
    final list = await _call<List<Object?>>('peekSmsQueue');
    if (list == null) return const [];
    return list.whereType<Map<Object?, Object?>>().map((e) {
      return QueuedSms(
        (e['id'] as String?) ?? '',
        RawSms(
          sender: (e['sender'] as String?) ?? '',
          body: (e['body'] as String?) ?? '',
          receivedAt: (e['receivedAt'] as num?)?.toInt() ?? 0,
          sentAt: (e['sentAt'] as num?)?.toInt() ?? 0,
        ),
      );
    }).toList();
  }

  Future<void> ackSmsQueue(List<String> ids) async {
    if (ids.isEmpty) return;
    await _call<void>('ackSmsQueue', {'ids': ids});
  }

  Future<void> clearSmsQueue() async {
    await _call<void>('clearSmsQueue');
  }

  // ---- notifications & reminders ----
  Future<PermState> notificationPermission() async => _perm(await _call<String>('notificationPermission'));

  Future<PermState> requestNotificationPermission() async =>
      _perm(await _call<String>('requestNotificationPermission'));

  Future<bool> canScheduleExact() async => (await _call<bool>('canScheduleExact')) ?? false;

  Future<void> openExactAlarmSettings() async {
    await _call<void>('openExactAlarmSettings');
  }

  Future<void> openAppSettings() async {
    await _call<void>('openAppSettings');
  }

  /// Replaces all scheduled reminders with [specs].
  Future<void> syncReminders(List<ReminderSpec> specs) async {
    await _call<void>('syncReminders', {'items': specs.map((e) => e.toMap()).toList()});
  }

  Future<void> showTxnNotification(String title, String body) async {
    await _call<void>('showNotification', {'title': title, 'body': body, 'channel': 'transactions'});
  }

  // ---- files ----
  Future<bool> saveDocument(String fileName, String mime, Uint8List bytes) async =>
      (await _call<bool>('saveDocument', {'name': fileName, 'mime': mime, 'bytes': bytes})) ?? false;

  Future<Uint8List?> openDocument() async => _call<Uint8List>('openDocument');

  // ---- crypto (AES-256-GCM, PBKDF2-HMAC-SHA256) ----
  Future<Map<String, Object?>?> encrypt(Uint8List plain, String password) async {
    final m = await _call<Map<Object?, Object?>>('encrypt', {'data': plain, 'password': password});
    return m?.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Returns null when the password is wrong or data is corrupt.
  Future<Uint8List?> decrypt(Map<String, Object?> envelope, String password) async =>
      _call<Uint8List>('decrypt', {'envelope': envelope, 'password': password});
}
