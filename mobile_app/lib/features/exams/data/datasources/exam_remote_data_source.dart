import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/exam_template.dart';
import '../models/exam_template_model.dart';

abstract class ExamRemoteDataSource {
  Future<List<ExamTemplateModel>> getCompanyExams(String companyId);
  Stream<List<ExamTemplateModel>> listenCompanyExams(String companyId);
  Future<ExamTemplateModel> getExamById(String examId);
  Future<String> createExam(ExamTemplateModel exam);
  Future<void> updateExam(ExamTemplateModel exam);
  Future<void> deleteExam(String examId);

  Future<AssignExamResult> assignExam({
    required String examId,
    required String applicationId,
    required String candidateId,
    String? jobId,
    int? durationMinutes,
    int? deadlineDays,
  });

  Future<List<ExamAttemptModel>> getCandidateAttempts(String candidateId);
  Stream<List<ExamAttemptModel>> listenCandidateAttempts(String candidateId);

  Future<String> quickGenerateExamForRole({
    required String companyId,
    required String roleTitle,
  });
}

class ExamRemoteDataSourceImpl implements ExamRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ExamRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference get _examsRef => _firestore.collection('exams');
  CollectionReference get _attemptsRef => _firestore.collection('examAttempts');

  @override
  Future<List<ExamTemplateModel>> getCompanyExams(String companyId) async {
    final snap = await _examsRef
        .where('companyId', isEqualTo: companyId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return snap.docs.map((doc) => ExamTemplateModel.fromFirestore(doc)).toList();
  }

  @override
  Stream<List<ExamTemplateModel>> listenCompanyExams(String companyId) {
    return _examsRef
        .where('companyId', isEqualTo: companyId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ExamTemplateModel.fromFirestore(doc)).toList());
  }

  @override
  Future<ExamTemplateModel> getExamById(String examId) async {
    final doc = await _examsRef.doc(examId).get();
    if (!doc.exists) {
      throw Exception('Exam template not found.');
    }
    return ExamTemplateModel.fromFirestore(doc);
  }

  @override
  Future<String> createExam(ExamTemplateModel exam) async {
    final docRef = await _examsRef.add(exam.toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateExam(ExamTemplateModel exam) async {
    await _examsRef.doc(exam.id).update(exam.toFirestore());
  }

  @override
  Future<void> deleteExam(String examId) async {
    // Soft delete / archive
    await _examsRef.doc(examId).update({
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<AssignExamResult> assignExam({
    required String examId,
    required String applicationId,
    required String candidateId,
    String? jobId,
    int? durationMinutes,
    int? deadlineDays,
  }) async {
    try {
      final callable = _functions.httpsCallable('assignExamToApplication');
      final payload = <String, dynamic>{
        'examId': examId,
        'applicationId': applicationId,
        'candidateId': candidateId,
      };
      if (jobId != null) payload['jobId'] = jobId;
      if (durationMinutes != null) payload['durationMinutes'] = durationMinutes;
      if (deadlineDays != null) payload['deadlineDays'] = deadlineDays;

      final result = await callable.call<Map<String, dynamic>>(payload);

      final attemptId = result.data['attemptId'] as String?;
      final token = result.data['token'] as String?;
      final duration = (result.data['durationMinutes'] as num?)?.toInt() ?? durationMinutes ?? 45;
      final expiresAtStr = result.data['expiresAt'] as String?;
      DateTime? expiresAt;
      if (expiresAtStr != null) {
        expiresAt = DateTime.tryParse(expiresAtStr);
      }

      if (attemptId != null && token != null) {
        return AssignExamResult(
          attemptId: attemptId,
          token: token,
          durationMinutes: duration,
          expiresAt: expiresAt,
        );
      }
    } catch (_) {
      // Fall back to direct Firestore assignment to ensure 100% availability
    }

    // Direct Firestore Assignment Fallback
    final examDoc = await _examsRef.doc(examId).get();
    final examData = examDoc.data() as Map<String, dynamic>? ?? {};
    final duration = durationMinutes ?? (examData['durationMinutes'] as num?)?.toInt() ?? 45;
    final days = deadlineDays ?? 7;
    final expiresAt = DateTime.now().add(Duration(days: days));

    // Generate cryptographically secure 32-character access token
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 32; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    final token = buffer.toString();

    final appDoc = await _firestore.collection('applications').doc(applicationId).get();
    final appData = appDoc.data() ?? {};

    final attemptRef = _attemptsRef.doc();
    final batch = _firestore.batch();

    batch.set(attemptRef, {
      'id': attemptRef.id,
      'examId': examId,
      'examTitle': examData['title'] ?? 'Assessment',
      'companyId': examData['companyId'] ?? appData['companyId'],
      'candidateId': candidateId,
      'candidateName': appData['candidateName'] ?? 'Candidate',
      'candidateEmail': appData['candidateEmail'] ?? '',
      'jobId': jobId ?? appData['jobId'] ?? '',
      'jobTitle': appData['jobTitle'] ?? '',
      'applicationId': applicationId,
      'token': token,
      'status': 'INVITED',
      'durationMinutes': duration,
      'passingPercentage': examData['passingPercentage'] ?? 70,
      'totalQuestions': examData['totalQuestions'] ?? 0,
      'totalPoints': examData['totalPoints'] ?? 0,
      'score': 0,
      'passed': false,
      'invitationSentAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_firestore.collection('applications').doc(applicationId), {
      'status': 'EXAM_ASSIGNED',
      'examAttemptId': attemptRef.id,
      'examToken': token,
      'examTitle': examData['title'] ?? 'Assessment',
      'examDurationMinutes': duration,
      'examExpiresAt': Timestamp.fromDate(expiresAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send in-app notification to candidate
    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'userId': candidateId,
      'title': 'Assessment Assigned!',
      'body': 'You have been invited to take "${examData['title'] ?? 'Assessment'}". Exam Key: $token ($duration mins).',
      'type': 'EXAM_ASSIGNED',
      'data': {
        'attemptId': attemptRef.id,
        'token': token,
        'examId': examId,
        'applicationId': applicationId,
        'durationMinutes': duration,
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return AssignExamResult(
      attemptId: attemptRef.id,
      token: token,
      durationMinutes: duration,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<List<ExamAttemptModel>> getCandidateAttempts(String candidateId) async {
    final snap = await _attemptsRef
        .where('candidateId', isEqualTo: candidateId)
        .limit(100)
        .get();

    final list = snap.docs.map((doc) => ExamAttemptModel.fromFirestore(doc)).toList();
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  @override
  Stream<List<ExamAttemptModel>> listenCandidateAttempts(String candidateId) {
    return _attemptsRef
        .where('candidateId', isEqualTo: candidateId)
        .limit(100)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) => ExamAttemptModel.fromFirestore(doc)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  @override
  Future<String> quickGenerateExamForRole({
    required String companyId,
    required String roleTitle,
  }) async {
    final normalized = roleTitle.toLowerCase();
    final List<Map<String, dynamic>> questionDefs;

    if (normalized.contains('flutter') || normalized.contains('dart') || normalized.contains('mobile')) {
      questionDefs = [
        {
          'title': 'Difference between StatelessWidget and StatefulWidget',
          'description': 'Which statement best describes the difference between a StatelessWidget and a StatefulWidget in Flutter?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'EASY',
          'points': 10,
          'options': [
            {'id': 'opt_1', 'text': 'StatefulWidget maintains mutable state that can trigger rebuilds via setState, while StatelessWidget is immutable.'},
            {'id': 'opt_2', 'text': 'StatelessWidget has a State object, while StatefulWidget only has a build method.'},
            {'id': 'opt_3', 'text': 'StatefulWidget cannot be rebuilt once rendered.'},
            {'id': 'opt_4', 'text': 'StatelessWidget is only used for canvas painting and animations.'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Triggering UI Rebuilds in Flutter',
          'description': 'Which method should be called to notify the Flutter framework that the internal state of a State object has changed?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'EASY',
          'points': 10,
          'options': [
            {'id': 'opt_1', 'text': 'setState()'},
            {'id': 'opt_2', 'text': 'updateState()'},
            {'id': 'opt_3', 'text': 'rebuild()'},
            {'id': 'opt_4', 'text': 'notifyListeners()'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Flutter Trees Architecture',
          'description': 'How does Flutter manage rendering under the hood across its three core trees?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'Widgets serve as lightweight configuration, Elements manage lifecycle, and RenderObjects handle layout and painting.'},
            {'id': 'opt_2', 'text': 'Widgets are directly converted into native Android and iOS Views.'},
            {'id': 'opt_3', 'text': 'Elements handle painting directly without any RenderObjects.'},
            {'id': 'opt_4', 'text': 'RenderObjects are re-instantiated on every frame regardless of state changes.'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Future vs Stream in Dart',
          'description': 'What is the primary difference between a Future and a Stream in Dart asynchronous programming?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'A Future provides a single async result or error, whereas a Stream provides a sequence of async events over time.'},
            {'id': 'opt_2', 'text': 'A Future can emit multiple values while a Stream only emits one.'},
            {'id': 'opt_3', 'text': 'Streams are strictly synchronous and run on a separate isolate by default.'},
            {'id': 'opt_4', 'text': 'Futures cannot be awaited using the await keyword.'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Purpose of Keys in Flutter',
          'description': 'Why are Keys used when manipulating collections of stateful widgets in Flutter?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'Keys preserve the state of widgets when they are moved or reordered in the widget tree.'},
            {'id': 'opt_2', 'text': 'Keys encrypt HTTP requests sent by the widget.'},
            {'id': 'opt_3', 'text': 'Keys are required for all stateless widgets to render.'},
            {'id': 'opt_4', 'text': 'Keys define primary keys for SQLite database queries.'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Flutter Architecture & Data Layer',
          'description': 'In Clean Architecture with Flutter, which layer is responsible for fetching raw data from remote APIs and local databases?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'HARD',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'Data Layer (DataSources and Repositories)'},
            {'id': 'opt_2', 'text': 'Presentation Layer (Widgets and Screens)'},
            {'id': 'opt_3', 'text': 'Domain Layer (Use Cases and Entities)'},
            {'id': 'opt_4', 'text': 'Asset Bundle Layer'},
          ],
          'correctAnswers': ['opt_1'],
        },
      ];
    } else if (normalized.contains('react') || normalized.contains('frontend') || normalized.contains('web')) {
      questionDefs = [
        {
          'title': 'React useEffect Hook Lifecycle',
          'description': 'When does the cleanup function returned by a useEffect hook execute?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'Before the component unmounts and before re-running the effect on subsequent renders.'},
            {'id': 'opt_2', 'text': 'Only once when the browser tab is closed.'},
            {'id': 'opt_3', 'text': 'Immediately before the component renders for the first time.'},
            {'id': 'opt_4', 'text': 'Only when an unhandled error is thrown inside render.'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Virtual DOM and Reconciliation',
          'description': 'What is the main benefit of the Virtual DOM in React?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'EASY',
          'points': 10,
          'options': [
            {'id': 'opt_1', 'text': 'It minimizes expensive real DOM manipulations by computing diffs in memory.'},
            {'id': 'opt_2', 'text': 'It completely replaces the need for CSS in modern web browsers.'},
            {'id': 'opt_3', 'text': 'It guarantees 120 FPS animations without JavaScript execution.'},
            {'id': 'opt_4', 'text': 'It connects directly to the backend database.'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'React State Immutability',
          'description': 'Why is mutating state directly considered an anti-pattern in React?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'React relies on object reference equality to detect changes and trigger UI re-renders.'},
            {'id': 'opt_2', 'text': 'JavaScript prevents all property assignments on objects in strict mode.'},
            {'id': 'opt_3', 'text': 'Direct mutation crashes the browser memory immediately.'},
            {'id': 'opt_4', 'text': 'It causes automatic navigation to 404 pages.'},
          ],
          'correctAnswers': ['opt_1'],
        },
      ];
    } else {
      questionDefs = [
        {
          'title': 'REST API Idempotency',
          'description': 'Which of the following HTTP methods is defined as idempotent according to the HTTP specification?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'PUT (making identical requests produces the same end state as a single request)'},
            {'id': 'opt_2', 'text': 'POST (always creates a new resource on each execution)'},
            {'id': 'opt_3', 'text': 'PATCH (always non-idempotent by specification)'},
            {'id': 'opt_4', 'text': 'CONNECT'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Database Indexing Trade-offs',
          'description': 'What is the primary trade-off of adding indexes to database tables?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 15,
          'options': [
            {'id': 'opt_1', 'text': 'Faster query performance at the cost of slower write operations and additional disk storage.'},
            {'id': 'opt_2', 'text': 'Lower memory usage but completely disabled table joins.'},
            {'id': 'opt_3', 'text': 'Guaranteed prevention of SQL injection vulnerabilities.'},
            {'id': 'opt_4', 'text': 'Automatic conversion of SQL tables into NoSQL collections.'},
          ],
          'correctAnswers': ['opt_1'],
        },
        {
          'title': 'Git Merge vs Git Rebase',
          'description': 'What is the main difference between git merge and git rebase?',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'EASY',
          'points': 10,
          'options': [
            {'id': 'opt_1', 'text': 'Merge creates a new commit combining histories, while Rebase rewrites history by moving commits onto a new base commit.'},
            {'id': 'opt_2', 'text': 'Rebase deletes all branch commits permanently while merge preserves them.'},
            {'id': 'opt_3', 'text': 'Merge only works on remote repositories while rebase is local only.'},
            {'id': 'opt_4', 'text': 'There is no difference; they are exact aliases in Git.'},
          ],
          'correctAnswers': ['opt_1'],
        },
      ];
    }

    final batch = _firestore.batch();
    final questionIds = <String>[];
    int totalPoints = 0;

    for (final qDef in questionDefs) {
      final qRef = _firestore.collection('questions').doc();
      final points = (qDef['points'] as num).toInt();
      totalPoints += points;
      questionIds.add(qRef.id);

      final Map<String, dynamic> qData = Map<String, dynamic>.from(qDef);
      qData['companyId'] = companyId;
      qData['createdAt'] = FieldValue.serverTimestamp();
      qData['updatedAt'] = FieldValue.serverTimestamp();

      batch.set(qRef, qData);
    }

    final examRef = _examsRef.doc();
    final examTitle = '$roleTitle Assessment';
    batch.set(examRef, {
      'title': examTitle,
      'description': 'Comprehensive technical assessment evaluating key competencies, architecture, and problem solving for $roleTitle.',
      'companyId': companyId,
      'durationMinutes': 45,
      'passingPercentage': 70,
      'questionIds': questionIds,
      'bankIds': <String>[],
      'randomizeQuestions': true,
      'randomizeOptions': true,
      'proctoringEnabled': true,
      'totalQuestions': questionIds.length,
      'totalPoints': totalPoints,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return examRef.id;
  }
}
