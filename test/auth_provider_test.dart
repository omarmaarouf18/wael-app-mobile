import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/providers/auth_provider.dart';

import 'fakes.dart';

AuthProvider providerWith(FakeAuthRepository repo, MemoryTokenStore store) {
  return AuthProvider(repository: repo, tokenStore: store);
}

void main() {
  test('login success stores session and authenticates', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(FakeAuthRepository(), store);
    final ok = await auth.login('u@e.com', 'password123');
    expect(ok, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(await store.readAccessToken(), 'access-1');
    expect(auth.currentUser.email, 'u@e.com');
  });

  test('wrong password sets error and stays logged out', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(
      FakeAuthRepository(mode: 'wrong-password'),
      store,
    );
    final ok = await auth.login('u@e.com', 'wrong');
    expect(ok, isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.errorMessage, isNotNull);
    expect(await store.readAccessToken(), isNull);
  });

  test('signup moves to verification with pending email', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(FakeAuthRepository(), store);
    final ok = await auth.signup(
      fullName: 'New User',
      phone: '+201000000001',
      email: 'new@e.com',
      password: 'password123',
    );
    expect(ok, isTrue);
    expect(auth.status, AuthStatus.needsVerification);
    expect(auth.pendingVerificationEmail, 'new@e.com');
  });

  test('logout clears tokens and session', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(FakeAuthRepository(), store);
    await auth.login('u@e.com', 'password123');
    expect(auth.isAuthenticated, isTrue);
    await auth.logout();
    expect(auth.isAuthenticated, isFalse);
    expect(await store.readAccessToken(), isNull);
  });

  test('tryRestore authenticates with a valid stored token', () async {
    final store = MemoryTokenStore();
    await store.writeTokens(access: 'access-1', refresh: 'refresh-1');
    final auth = providerWith(FakeAuthRepository(), store);
    await auth.tryRestore();
    expect(auth.isAuthenticated, isTrue);
  });

  test('error messages never show raw exception text', () async {
    final store = MemoryTokenStore();
    final auth = providerWith(
      FakeAuthRepository(mode: 'wrong-password'),
      store,
    );
    await auth.login('u@e.com', 'wrong');
    expect(auth.errorMessage, isNot(contains('Exception')));
    expect(auth.errorMessage, isNot(contains('SocketException')));
    expect(auth.errorMessage, isNot(contains('instance of')));
    expect(
      auth.errorMessage,
      'Invalid credentials. Please verify your details and try again.',
    );
  });
}
