/// Academy content contract for the future core service
/// (courses, ebooks, lessons, enrolment).
///
/// The mock below returns a small fake catalog. The providers currently serve
/// their bundled static data; rebinding them to [AcademyRepository] is a
/// follow-up that touches one file per provider (the construction site).
/// Swapping the mock for the real HTTP binding later is one file:
/// this one.
abstract class AcademyRepository {
  Future<List<AcademyCourse>> courses();
  Future<List<AcademyEbook>> ebooks();
}

class AcademyCourse {
  final String id;
  final String title;
  const AcademyCourse({required this.id, required this.title});
}

class AcademyEbook {
  final String id;
  final String title;
  const AcademyEbook({required this.id, required this.title});
}

/// Fake catalog used until the core service ships.
class MockAcademyRepository implements AcademyRepository {
  @override
  Future<List<AcademyCourse>> courses() async => const [
    AcademyCourse(id: 'mock-1', title: 'Mock Course One'),
    AcademyCourse(id: 'mock-2', title: 'Mock Course Two'),
  ];

  @override
  Future<List<AcademyEbook>> ebooks() async => const [
    AcademyEbook(id: 'mock-e1', title: 'Mock Ebook One'),
  ];
}
