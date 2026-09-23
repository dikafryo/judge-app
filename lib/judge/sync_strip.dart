import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design.dart';
import '../store/judge_session.dart';

/// 전송 상태 띠. 보낼 것도 없고 연결도 멀쩡하면 아무것도 그리지 않는다 —
/// 늘 떠 있는 "정상" 표시는 곧 아무도 읽지 않는 표시가 된다.
class SyncStrip extends ConsumerWidget {
  const SyncStrip({super.key, required this.session});

  final JudgeState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.isSettled) return const SizedBox.shrink();

    final pending = session.pendingCount;
    void retry() => unawaited(ref.read(judgeSessionProvider.notifier).syncNow());

    if (session.offline) {
      return StatusStrip(
        icon: Icons.cloud_off,
        foreground: AppColor.warn,
        background: AppColor.warnSoft,
        text: pending > 0
            ? '연결이 끊겼습니다. $pending건을 기기에 보관 중이며 연결되면 자동으로 보냅니다.'
            : '연결이 끊겼습니다. 채점은 그대로 하실 수 있습니다.',
        action: '다시 시도',
        onAction: retry,
      );
    }

    if (session.serverError) {
      return StatusStrip(
        icon: Icons.error_outline,
        foreground: AppColor.dangerInk,
        background: AppColor.dangerSoft,
        text: pending > 0
            ? '서버가 $pending건을 받지 못했습니다. 자동으로 다시 시도합니다.'
            : '서버와 연결이 고르지 않습니다. 자동으로 다시 시도합니다.',
        action: '다시 시도',
        onAction: retry,
      );
    }

    return StatusStrip(
      busy: true,
      icon: Icons.cloud_upload_outlined,
      foreground: AppColor.accent,
      background: AppColor.accentSoft,
      text: '$pending건 전송 중입니다.',
    );
  }
}
