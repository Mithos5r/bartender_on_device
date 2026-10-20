import 'package:flutter_test/flutter_test.dart';

import 'package:bartender_on_device/core/model/chat_message.dart';

void main() {
  test('ChatMessage roundtrips through JSON', () {
    final original = ChatMessage(
      role: MessageRole.user,
      text: 'Recomiéndame un cóctel',
      timestamp: DateTime.utc(2026, 7, 8, 12, 0, 0),
    );

    final json = chatMessagesToJson([original]);
    final restored = chatMessagesFromJson(json);

    expect(restored, hasLength(1));
    expect(restored.first.role, MessageRole.user);
    expect(restored.first.text, 'Recomiéndame un cóctel');
    expect(restored.first.timestamp, original.timestamp);
  });

  test('Empty JSON source returns empty list', () {
    expect(chatMessagesFromJson(''), isEmpty);
    expect(chatMessagesFromJson('null'), isEmpty);
    expect(chatMessagesFromJson('{}'), isEmpty);
  });
}
