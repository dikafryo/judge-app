// 오프라인 대기열은 이 앱의 핵심이자, 잘못되면 심사위원이 넣은 점수가 사라지는 곳이다.
// 실기기 없이 검증할 수 있도록 서버를 가짜 클라이언트로 세우고 상태 기계를 확인한다.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:judge_app/core/api.dart';
import 'package:judge_app/store/judge_session.dart';
import 'package:judge_app/store/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'payload_test.dart' show sample;

/// 지금 어떻게 응답할지 테스트가 바꿔 끼우는 가짜 서버.
class FakeServer {
  int scoreCalls = 0;
  int signatureCalls = 0;
  bool offline = false;
  int? failWith;

  final List<Map<String, dynamic>> received = [];

  http.Client get client => MockClient((request) async {
        if (offline) throw const SocketException('오프라인');

        final path = request.url.path;

        if (path.endsWith('/judge/session')) {
          return _json({'token': 'test-token', 'judge': {'id': 7, 'name': '홍길동'}});
        }

        if (path.endsWith('/judge/me')) return _json(sample());

        if (path.contains('/scores')) {
          scoreCalls += 1;
          received.add(jsonDecode(request.body) as Map<String, dynamic>);

          if (failWith != null) return _json({'message': '거절'}, status: failWith!);

          return _json({'message': '저장되었습니다.', 'total': 80});
        }

        if (path.endsWith('/judge/signature')) {
          signatureCalls += 1;

          if (failWith != null) return _json({'message': '거절'}, status: failWith!);

          return _json({'message': '서명이 저장되었습니다.'});
        }

        return _json({'message': '알 수 없는 요청'}, status: 404);
      });

  static http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

Future<(JudgeSession, FakeServer, LocalStore)> signedIn() async {
  SharedPreferences.setMockInitialValues({});

  final server = FakeServer();
  final store = await LocalStore.open();
  final session = JudgeSession(Api(client: server.client), store);

  await session.signIn('483920');

  return (session, server, store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('입장하면 토큰과 payload 가 기기에 저장된다', () async {
    final (session, _, store) = await signedIn();

    expect(session.state.status, SessionStatus.ready);
    expect(store.token, 'test-token');
    expect(store.payload?.candidates.length, 2, reason: '연결이 끊겨도 이 캐시로 화면을 그린다');
  });

  test('연결이 없으면 점수는 로컬에 반영되고 대기열에 남는다', () async {
    final (session, server, store) = await signedIn();

    server.offline = true;
    await session.saveScores(102, {11: 20, 12: 20, 2: 40});

    expect(session.state.payload!.isComplete(102), isTrue, reason: '화면에는 바로 반영돼야 한다');
    expect(session.state.pendingCount, 1);
    expect(session.state.offline, isTrue);
    expect(store.queue.length, 1, reason: '앱을 껐다 켜도 남아 있어야 한다');
  });

  test('연결이 돌아오면 대기열이 자동으로 비워진다', () async {
    final (session, server, store) = await signedIn();

    server.offline = true;
    await session.saveScores(102, {11: 20, 12: 20, 2: 40});

    server.offline = false;
    await session.sync();

    expect(session.state.pendingCount, 0);
    expect(store.queue, isEmpty);
    expect(server.scoreCalls, 1);
  });

  test('오프라인에서 같은 대상을 여러 번 고쳐도 마지막 한 건만 전송된다', () async {
    final (session, server, store) = await signedIn();

    server.offline = true;
    await session.saveScores(102, {11: 10, 12: 10, 2: 10});
    await session.saveScores(102, {11: 20, 12: 20, 2: 20});
    await session.saveScores(102, {11: 30, 12: 30, 2: 30});

    expect(session.state.pendingCount, 1, reason: '전체 교체라 이전 것은 버려도 된다');

    server.offline = false;
    await session.flush();

    expect(server.scoreCalls, 1);
    expect(server.received.single['scores'], {'11': 30.0, '12': 30.0, '2': 30.0});
    expect(store.queue, isEmpty);
  });

  test('서버가 거절하면(422) 대기열에서 빼고 사유를 알린다', () async {
    final (session, server, _) = await signedIn();

    server.failWith = 422;
    await session.saveScores(102, {11: 999, 12: null, 2: null});

    expect(session.state.pendingCount, 0, reason: '다시 보내도 같은 결과다 — 무한 재시도 금지');
    expect(session.state.notice, '거절');
  });

  test('마감(423)이면 대기열을 비우고 화면을 잠근다', () async {
    final (session, server, _) = await signedIn();

    server.failWith = 423;
    await session.saveScores(102, {11: 10, 12: 10, 2: 10});

    expect(session.state.pendingCount, 0);
    expect(session.state.payload!.event.isOpen, isFalse);
  });

  test('토큰이 죽으면(401) 재입장을 안내하고 저장된 세션을 지운다', () async {
    final (session, server, store) = await signedIn();

    server.failWith = 401;
    await session.saveScores(102, {11: 10, 12: 10, 2: 10});

    expect(session.state.status, SessionStatus.signedOut);
    expect(session.state.notice, contains('만료'));
    expect(store.token, isNull);
  });

  test('보내지 못한 점수가 있으면 서버 상태를 새로 받지 않는다', () async {
    // 이걸 어기면 대기 중인 입력이 서버의 옛 값으로 덮여 사라진다.
    final (session, server, _) = await signedIn();

    server.offline = true;
    await session.saveScores(102, {11: 20, 12: 20, 2: 40});

    server.offline = false;
    server.failWith = 500;
    await session.sync();

    expect(session.state.pendingCount, 1, reason: '5xx 는 일시 장애라 남겨 둔다');
    expect(session.state.payload!.isComplete(102), isTrue, reason: '로컬 입력이 살아 있어야 한다');
  });

  test('서명도 같은 대기열을 탄다', () async {
    final (session, server, _) = await signedIn();

    server.offline = true;
    await session.saveSignature('data:image/png;base64,AAAA');

    expect(session.state.payload!.hasSignature, isTrue);
    expect(session.state.pendingCount, 1);

    server.offline = false;
    await session.flush();

    expect(server.signatureCalls, 1);
    expect(session.state.pendingCount, 0);
  });
}
