// M0 fix F-1 — delete-account orchestration. The live bug: the server cascade
// completed (revoking the session) while the function response was lost, so
// the client hung in "Deleting…" forever. These tests pin the new contract:
// time-boxed invoke, auth-revoked-probe treated as success, local sign-out.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/account_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeFunctions extends Fake implements FunctionsClient {
  _FakeFunctions(this.onInvoke);
  final Future<FunctionResponse> Function() onInvoke;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
  }) =>
      onInvoke();
}

class _FakeAuth extends Fake implements GoTrueClient {
  _FakeAuth({required this.session, required this.onGetUser});
  Session? session;
  final Future<UserResponse> Function() onGetUser;
  int signOutCalls = 0;
  SignOutScope? lastSignOutScope;
  bool throwOnSignOut = false;

  @override
  Session? get currentSession => session;

  @override
  Future<UserResponse> getUser([String? jwt]) => onGetUser();

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    signOutCalls++;
    lastSignOutScope = scope;
    if (throwOnSignOut) {
      throw AuthException('session already revoked', statusCode: '401');
    }
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient(this._functions, this._auth);
  final FunctionsClient _functions;
  final GoTrueClient _auth;

  @override
  FunctionsClient get functions => _functions;

  @override
  GoTrueClient get auth => _auth;
}

const _userJson = {
  'id': 'u1',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'aud': 'authenticated',
  'created_at': '2026-01-01T00:00:00Z',
};

Session _aliveSession() => Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: User.fromJson(_userJson)!,
    );

Future<UserResponse> _userStillExists() async =>
    UserResponse.fromJson(Map<String, dynamic>.from(_userJson));

Future<UserResponse> _userGone() async =>
    throw AuthException('user not found', statusCode: '401');

void main() {
  test('ok response → success and LOCAL sign-out', () async {
    final auth = _FakeAuth(session: _aliveSession(), onGetUser: _userStillExists);
    final svc = AccountService(_FakeClient(
      _FakeFunctions(() async => FunctionResponse(status: 200, data: {'ok': true})),
      auth,
    ));

    await svc.deleteAccount();

    expect(auth.signOutCalls, 1);
    expect(auth.lastSignOutScope, SignOutScope.local);
  });

  test('ok response but server session already revoked → still success', () async {
    final auth = _FakeAuth(session: _aliveSession(), onGetUser: _userGone)
      ..throwOnSignOut = true;
    final svc = AccountService(_FakeClient(
      _FakeFunctions(() async => FunctionResponse(status: 200, data: {'ok': true})),
      auth,
    ));

    await expectLater(svc.deleteAccount(), completes);
  });

  test('non-ok payload → throws, no sign-out', () async {
    final auth = _FakeAuth(session: _aliveSession(), onGetUser: _userStillExists);
    final svc = AccountService(_FakeClient(
      _FakeFunctions(() async => FunctionResponse(status: 200, data: {'ok': false})),
      auth,
    ));

    await expectLater(svc.deleteAccount(), throwsException);
    expect(auth.signOutCalls, 0);
  });

  test('hang + auth revoked = the live F-1 case → success within the budget', () {
    fakeAsync((async) {
      final auth = _FakeAuth(session: _aliveSession(), onGetUser: _userGone);
      final svc = AccountService(_FakeClient(
        // Response never arrives — exactly what the device audit observed.
        _FakeFunctions(() => Completer<FunctionResponse>().future),
        auth,
      ));

      var completed = false;
      Object? error;
      svc.deleteAccount().then<void>(
        (_) => completed = true,
        onError: (Object e) => error = e,
      );

      // Must resolve within the 15s M0 acceptance budget.
      async.elapse(const Duration(seconds: 15));
      expect(error, isNull);
      expect(completed, isTrue, reason: 'revoked credentials mean the account is gone');
      expect(auth.signOutCalls, 1);
      expect(auth.lastSignOutScope, SignOutScope.local);
    });
  });

  test('hang + auth still valid → surfaces the timeout (deletion really failed)', () {
    fakeAsync((async) {
      final auth = _FakeAuth(session: _aliveSession(), onGetUser: _userStillExists);
      final svc = AccountService(_FakeClient(
        _FakeFunctions(() => Completer<FunctionResponse>().future),
        auth,
      ));

      Object? error;
      svc.deleteAccount().catchError((Object e) {
        error = e;
      });

      async.elapse(const Duration(seconds: 15));
      expect(error, isA<TimeoutException>());
      expect(auth.signOutCalls, 0);
    });
  });

  test('FunctionException(401) + revoked auth → success', () async {
    final auth = _FakeAuth(session: _aliveSession(), onGetUser: _userGone);
    final svc = AccountService(_FakeClient(
      _FakeFunctions(() async => throw FunctionException(status: 401)),
      auth,
    ));

    await expectLater(svc.deleteAccount(), completes);
    expect(auth.signOutCalls, 1);
  });

  test('FunctionException(500) + auth still valid → rethrows', () async {
    final auth = _FakeAuth(session: _aliveSession(), onGetUser: _userStillExists);
    final svc = AccountService(_FakeClient(
      _FakeFunctions(() async => throw FunctionException(status: 500)),
      auth,
    ));

    await expectLater(svc.deleteAccount(), throwsA(isA<FunctionException>()));
    expect(auth.signOutCalls, 0);
  });

  test('local session already cleared during the call → treated as revoked', () async {
    final auth = _FakeAuth(session: null, onGetUser: _userStillExists);
    final svc = AccountService(_FakeClient(
      _FakeFunctions(() async => throw FunctionException(status: 401)),
      auth,
    ));

    await expectLater(svc.deleteAccount(), completes);
  });
}
