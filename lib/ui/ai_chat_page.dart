import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../models/thinker_persona.dart';
import 'ai_chat_panel.dart';

/// 全屏卡片流对话页：先选好思维模型，再进入全屏追问。
class AiChatPage extends StatelessWidget {
  const AiChatPage({
    super.key,
    required this.persona,
    required this.contextLabel,
    required this.initialContext,
    this.captureId,
    this.session,
  });

  final ThinkerPersona persona;
  final String contextLabel;
  final String initialContext;
  final int? captureId;
  final ChatSession? session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(persona.name),
      ),
      body: AiChatPanel(
        persona: persona,
        contextLabel: contextLabel,
        initialContext: initialContext,
        captureId: captureId,
        session: session,
      ),
    );
  }
}
