import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';

import 'academy_fakes.dart';

void main() {
  group('loading', () {
    test('starts idle and loads levels then every level', () async {
      final repo = fake();
      final p = AcademyCatalogProvider(repo);
      expect(p.status, LoadStatus.idle);

      await p.ensureLoaded();

      expect(p.status, LoadStatus.ready);
      expect(repo.levelsCalls, 1);
      expect(repo.subjectCalls.map((c) => c.$1).toSet(), {
        'bachelor-y1',
        'bachelor-y2',
        'vocational',
      });
      expect(p.subjectsOf('bachelor-y1'), hasLength(2));
      expect(p.subjectsOf('vocational'), isEmpty);
    });

    test('ensureLoaded does not refetch after success', () async {
      final repo = fake();
      final p = AcademyCatalogProvider(repo);
      await p.ensureLoaded();
      await p.ensureLoaded();
      expect(repo.levelsCalls, 1);
    });

    test('notifies loading then ready', () async {
      final p = AcademyCatalogProvider(fake());
      final seen = <LoadStatus>[];
      p.addListener(() => seen.add(p.status));
      await p.reload();
      expect(seen, [LoadStatus.loading, LoadStatus.ready]);
    });

    test('pages through a level larger than one page', () async {
      final repo = FakeAcademyRepository(
        levelList: [level('bachelor-y1', 'bachelor', 1)],
        subjectsByLevel: {
          'bachelor-y1': [
            for (var i = 0; i < 230; i++) subject('s$i', 'bachelor-y1'),
          ],
        },
      );
      final p = AcademyCatalogProvider(repo);
      await p.reload();
      expect(p.subjectsOf('bachelor-y1'), hasLength(230));
      expect(repo.subjectCalls.map((c) => c.$2), [1, 2, 3]);
      expect(repo.subjectCalls.every((c) => c.$3 == 100), isTrue);
    });

    test('an empty catalog is ready with nothing selected', () async {
      final p = AcademyCatalogProvider(FakeAcademyRepository(levelList: []));
      await p.reload();
      expect(p.status, LoadStatus.ready);
      expect(p.studyTypes, isEmpty);
      expect(p.selectedLevel, isNull);
      expect(p.visibleSubjects, isEmpty);
    });
  });

  group('errors and retry', () {
    test('a levels failure is an error, retry recovers', () async {
      final repo = fake()
        ..levelsError = ApiException(statusCode: 503, message: 'down');
      final p = AcademyCatalogProvider(repo);
      await p.reload();
      expect(p.status, LoadStatus.error);
      expect(p.hasError, isTrue);
      expect((p.error! as ApiException).statusCode, 503);

      repo.levelsError = null;
      await p.reload();
      expect(p.status, LoadStatus.ready);
      expect(p.error, isNull);
    });

    test('one failing level fails the whole load', () async {
      final repo = fake()
        ..subjectsError = ApiException(statusCode: 500, message: 'x');
      final p = AcademyCatalogProvider(repo);
      await p.reload();
      expect(p.status, LoadStatus.error);
      expect(p.subjectsOf('bachelor-y1'), isEmpty);
    });

    test('a second reload while loading is ignored', () async {
      final repo = fake();
      final p = AcademyCatalogProvider(repo);
      final first = p.reload();
      await p.reload();
      await first;
      expect(repo.levelsCalls, 1);
    });

    test('a failed reload keeps no half-loaded state in view', () async {
      final repo = fake();
      final p = AcademyCatalogProvider(repo);
      await p.reload();
      repo.subjectsError = ApiException(statusCode: 500, message: 'x');
      await p.reload();
      expect(p.status, LoadStatus.error);
      expect(p.hasError, isTrue);
    });
  });

  group('selection', () {
    test(
      'defaults to the first study type and its lowest-position level',
      () async {
        final p = AcademyCatalogProvider(fake());
        await p.reload();
        expect(p.selectedStudyTypeKey, 'bachelor');
        expect(p.levelsOfSelectedType.map((l) => l.key), [
          'bachelor-y1',
          'bachelor-y2',
        ]);
        expect(p.selectedLevelKey, 'bachelor-y1');
        expect(p.selectedLevel!.title.resolve(false), 'en-bachelor-y1');
      },
    );

    test('selecting a study type picks its first level', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      p.selectStudyType('vocational');
      expect(p.selectedStudyTypeKey, 'vocational');
      expect(p.selectedLevelKey, 'vocational');
    });

    test('unknown keys are ignored', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      p.selectStudyType('nope');
      p.selectLevel('nope');
      p.selectLevel('vocational'); // another study type's level
      expect(p.selectedStudyTypeKey, 'bachelor');
      expect(p.selectedLevelKey, 'bachelor-y1');
    });

    test('selection survives a reload', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      p.selectLevel('bachelor-y2');
      await p.reload();
      expect(p.selectedLevelKey, 'bachelor-y2');
    });

    test(
      'study types are derived from levels when the server sends none',
      () async {
        final repo = fake()..studyTypesInResponse = false;
        final p = AcademyCatalogProvider(repo);
        await p.reload();
        expect(p.studyTypes.map((t) => t.key), ['bachelor', 'vocational']);
        expect(p.selectedStudyTypeKey, 'bachelor');
      },
    );
  });

  group('subjects view', () {
    test('visibleSubjects follows the selected level', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      expect(p.visibleSubjects.map((s) => s.id), ['s1', 's2']);
      p.selectLevel('bachelor-y2');
      expect(p.visibleSubjects.map((s) => s.id), ['s3']);
    });

    test('search matches title or description in either language', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      p.setSearchQuery('civil');
      expect(p.visibleSubjects.map((s) => s.id), ['s1']);
      p.setSearchQuery('المدني');
      expect(p.visibleSubjects.map((s) => s.id), ['s1']);
      p.setSearchQuery('offences');
      expect(p.visibleSubjects.map((s) => s.id), ['s2']);
      p.setSearchQuery('  ');
      expect(p.visibleSubjects, hasLength(2));
      p.setSearchQuery('zzz');
      expect(p.visibleSubjects, isEmpty);
      p.clearSearch();
      expect(p.visibleSubjects, hasLength(2));
    });

    test(
      'ownedSubjects spans all levels and only reflects the server',
      () async {
        final p = AcademyCatalogProvider(fake());
        await p.reload();
        expect(p.ownedSubjects.map((s) => s.id), ['s3']);
      },
    );

    test('findSubject looks across levels', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      expect(p.findSubject('s3')!.levelKey, 'bachelor-y2');
      expect(p.findSubject('missing'), isNull);
    });
  });

  group('detail', () {
    test('loads once, caches, and refetches on force', () async {
      final repo = fake();
      final p = AcademyCatalogProvider(repo);
      expect(p.detailOf('s1').status, LoadStatus.idle);
      await p.loadDetail('s1');
      expect(p.detailOf('s1').status, LoadStatus.ready);
      expect(p.detailOf('s1').detail!.id, 's1');
      await p.loadDetail('s1');
      expect(repo.detailCalls, 1);
      await p.loadDetail('s1', force: true);
      expect(repo.detailCalls, 2);
    });

    test('a failure is recorded per subject and retry recovers', () async {
      final repo = fake()
        ..detailError = ApiException(statusCode: 404, message: 'nf');
      final p = AcademyCatalogProvider(repo);
      await p.loadDetail('s1');
      expect(p.detailOf('s1').status, LoadStatus.error);
      expect((p.detailOf('s1').error! as ApiException).statusCode, 404);
      expect(p.detailOf('s2').status, LoadStatus.idle);

      repo.detailError = null;
      await p.loadDetail('s1', force: true);
      expect(p.detailOf('s1').status, LoadStatus.ready);
    });
  });

  group('access request', () {
    FakeAcademyRepository repoWith({bool owned = false, bool pending = false}) {
      final repo = fake()
        ..detailJson['s1'] = detailBody(id: 's1', owned: owned);
      if (pending) repo.pendingIds.add('s1');
      return repo;
    }

    test('opening an unowned subject without a request creates one', () async {
      final repo = repoWith();
      final p = AcademyCatalogProvider(repo);

      await p.openSubject('s1');

      expect(repo.accessCalls, ['s1']);
      expect(p.accessOf('s1').status, AccessRequestStatus.sent);
      expect(p.accessOf('s1').supportUrl, 'https://wa.me/201000000000');
      // The detail was refreshed, so the server's pending state is what shows.
      expect(repo.detailCalls, 2);
      expect(p.detailOf('s1').detail!.hasPendingRequest, isTrue);
    });

    test('an owned subject creates no request', () async {
      final repo = repoWith(owned: true);
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      expect(repo.accessCalls, isEmpty);
      expect(p.accessOf('s1').status, AccessRequestStatus.idle);
    });

    test('a subject that is already pending creates no request', () async {
      final repo = repoWith(pending: true);
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      expect(repo.accessCalls, isEmpty);
      expect(p.detailOf('s1').detail!.hasPendingRequest, isTrue);
    });

    test('a detail that failed to load creates no request', () async {
      final repo = repoWith()
        ..detailError = ApiException(statusCode: 404, message: 'nf');
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      expect(repo.accessCalls, isEmpty);
      expect(p.detailOf('s1').status, LoadStatus.error);
    });

    test('the retry after a failed detail load sends the request', () async {
      final repo = repoWith()..detailError = const SocketException('down');
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      repo.detailError = null;
      await p.openSubject('s1', force: true);
      expect(repo.accessCalls, ['s1']);
    });

    test(
      're-opening a pending subject refetches it but does not re-send',
      () async {
        final repo = repoWith();
        final p = AcademyCatalogProvider(repo);
        await p.openSubject('s1');
        final calls = repo.detailCalls;
        await p.openSubject('s1');
        expect(repo.detailCalls, calls + 1);
        expect(repo.accessCalls, ['s1']);
      },
    );

    test('re-opening shows an accepted request as owned', () async {
      final repo = repoWith();
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      repo.detailJson['s1'] = detailBody(id: 's1', owned: true);
      await p.openSubject('s1');
      expect(p.detailOf('s1').detail!.owned, isTrue);
      expect(repo.accessCalls, ['s1']);
    });

    test('a rejected request is sent again on the next open', () async {
      final repo = repoWith();
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      repo.pendingIds.clear(); // the admin rejected it
      await p.openSubject('s1');
      expect(repo.accessCalls, ['s1', 's1']);
      expect(p.detailOf('s1').detail!.hasPendingRequest, isTrue);
    });

    test(
      'sending is visible, and a second call while sending is ignored',
      () async {
        final gate = Completer<void>();
        final repo = repoWith()..accessGate = gate.future;
        final p = AcademyCatalogProvider(repo);
        await p.loadDetail('s1');

        final first = p.requestAccess('s1');
        await Future<void>.delayed(Duration.zero);
        expect(p.accessOf('s1').status, AccessRequestStatus.sending);
        await p.requestAccess('s1');
        expect(repo.accessCalls, ['s1']);

        gate.complete();
        await first;
        expect(p.accessOf('s1').status, AccessRequestStatus.sent);
      },
    );

    for (final (name, error, retry) in [
      ('409', ApiException(statusCode: 409, message: 'conflict'), false),
      ('404', ApiException(statusCode: 404, message: 'nf'), false),
      ('429', ApiException(statusCode: 429, message: 'slow down'), true),
      ('503', ApiException(statusCode: 503, message: 'down'), true),
      ('network', const SocketException('down'), true),
    ]) {
      test(
        'a $name failure is kept, not retried by itself, and retry=$retry',
        () async {
          final repo = repoWith()..accessError = error;
          final p = AcademyCatalogProvider(repo);

          await p.openSubject('s1');

          final access = p.accessOf('s1');
          expect(access.status, AccessRequestStatus.failed);
          expect(access.error, same(error));
          expect(access.canRetry, retry);
          expect(repo.accessCalls, hasLength(1));
          expect(repo.detailCalls, 1, reason: 'no refresh after a failure');
          expect(p.detailOf('s1').detail!.hasPendingRequest, isFalse);
        },
      );
    }

    test('retry after a failure sends again and recovers', () async {
      final repo = repoWith()
        ..accessError = ApiException(statusCode: 429, message: 'slow');
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      repo.accessError = null;
      await p.requestAccess('s1');
      expect(p.accessOf('s1').status, AccessRequestStatus.sent);
      expect(p.detailOf('s1').detail!.hasPendingRequest, isTrue);
    });

    test(
      'a stale failure is cleared when the subject is opened again',
      () async {
        final repo = repoWith()
          ..accessError = ApiException(statusCode: 409, message: 'conflict');
        final p = AcademyCatalogProvider(repo);
        await p.openSubject('s1');
        repo.accessError = null;
        final seen = <AccessRequestStatus>[];
        p.addListener(() => seen.add(p.accessOf('s1').status));
        await p.openSubject('s1');
        expect(seen, isNot(contains(AccessRequestStatus.failed)));
        expect(p.accessOf('s1').status, AccessRequestStatus.sent);
      },
    );

    test('state is per subject', () async {
      final repo = repoWith()
        ..accessError = ApiException(statusCode: 409, message: 'conflict');
      final p = AcademyCatalogProvider(repo);
      await p.openSubject('s1');
      expect(p.accessOf('s2').status, AccessRequestStatus.idle);
    });

    test('reset drops the state, and a late answer is dropped', () async {
      final gate = Completer<void>();
      final repo = repoWith()..accessGate = gate.future;
      final p = AcademyCatalogProvider(repo);
      await p.loadDetail('s1');
      final sending = p.requestAccess('s1');
      await Future<void>.delayed(Duration.zero);

      p.reset();
      gate.complete();
      await sending;

      expect(p.accessOf('s1').status, AccessRequestStatus.idle);
      expect(p.isPristine, isTrue);
      expect(repo.detailCalls, 1, reason: 'no refresh after logout');
    });

    test(
      'the support link is not in the detail, so it is only a session fact',
      () async {
        final repo = repoWith(pending: true);
        final p = AcademyCatalogProvider(repo);
        await p.openSubject('s1');
        expect(p.detailOf('s1').detail!.hasPendingRequest, isTrue);
        expect(p.accessOf('s1').supportUrl, isNull);
      },
    );
  });

  group('access request messages', () {
    for (final isArabic in [false, true]) {
      String m(Object e) =>
          ErrorMessages.forAccessRequest(e, isArabic: isArabic);

      test('maps statuses to fixed messages (ar=$isArabic)', () {
        expect(
          m(ApiException(statusCode: 429, message: 'x')),
          ErrorMessages.tryAgainLater(isArabic),
        );
        expect(
          m(ApiException(statusCode: 404, message: 'x')),
          ErrorMessages.subjectNotFound(isArabic),
        );
        expect(
          m(ApiException(statusCode: 409, message: 'x')),
          ErrorMessages.accessRequestUnavailable(isArabic),
        );
        expect(
          m(ApiException(statusCode: 503, message: 'x')),
          ErrorMessages.serviceUnavailable(isArabic),
        );
        expect(
          m(ApiException(statusCode: 500, message: 'x')),
          ErrorMessages.requestFailed(isArabic),
        );
        expect(
          m(AcademyParseException('bad')),
          ErrorMessages.requestFailed(isArabic),
        );
        expect(
          m(const SocketException('down')),
          ErrorMessages.networkError(isArabic),
        );
      });

      test('never shows raw server or exception text (ar=$isArabic)', () {
        const raw = 'secret-internal-detail';
        for (final e in <Object>[
          ApiException(statusCode: 409, message: raw),
          ApiException(statusCode: 429, message: raw),
          ApiException(statusCode: 418, message: raw),
          AcademyParseException(raw),
          const SocketException(raw),
          StateError(raw),
        ]) {
          expect(m(e), isNot(contains(raw)));
        }
      });

      test(
        '429 says to try again later, 409 and 404 are distinct (ar=$isArabic)',
        () {
          expect(ErrorMessages.tryAgainLater(isArabic), isNotEmpty);
          final texts = {
            m(ApiException(statusCode: 429, message: '')),
            m(ApiException(statusCode: 409, message: '')),
            m(ApiException(statusCode: 404, message: '')),
          };
          expect(texts, hasLength(3));
        },
      );
    }
  });

  group('reset', () {
    test('drops catalog, selection, search and details', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      p.setSearchQuery('civil');
      await p.loadDetail('s1');
      expect(p.isPristine, isFalse);

      p.reset();

      expect(p.status, LoadStatus.idle);
      expect(p.isPristine, isTrue);
      expect(p.studyTypes, isEmpty);
      expect(p.selectedLevelKey, isNull);
      expect(p.searchQuery, '');
      expect(p.subjectsOf('bachelor-y1'), isEmpty);
      expect(p.ownedSubjects, isEmpty);
      expect(p.detailOf('s1').status, LoadStatus.idle);
    });

    test('notify: false does not notify listeners', () async {
      final p = AcademyCatalogProvider(fake());
      await p.reload();
      var notified = 0;
      p.addListener(() => notified++);
      p.reset(notify: false);
      expect(notified, 0);
    });

    test('a response that arrives after reset is dropped', () async {
      final p = AcademyCatalogProvider(fake());
      final loading = p.reload();
      p.reset();
      await loading;
      expect(p.status, LoadStatus.idle);
      expect(p.studyTypes, isEmpty);
    });
  });
}
