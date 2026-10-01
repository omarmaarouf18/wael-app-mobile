import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
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
