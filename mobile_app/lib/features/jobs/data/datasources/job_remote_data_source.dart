import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/job_posting.dart';
import '../models/job_posting_model.dart';

abstract class JobRemoteDataSource {
  Future<List<JobPostingModel>> getPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  });

  Stream<List<JobPostingModel>> listenPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  });

  Future<List<JobPostingModel>> getCompanyJobs(String companyId, {JobStatus? status});

  Stream<List<JobPostingModel>> listenCompanyJobs(String companyId);

  Future<JobPostingModel> getJobById(String jobId);

  Future<String> createJob(JobPostingModel job);

  Future<void> updateJob(JobPostingModel job);

  Future<void> updateJobStatus(String jobId, JobStatus status);

  Future<void> deleteJob(String jobId);
}

class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  final FirebaseFirestore _firestore;

  JobRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _jobsRef =>
      _firestore.collection('jobs');

  @override
  Future<List<JobPostingModel>> getPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      final q = _jobsRef.where('status', whereIn: ['PUBLISHED', 'OPEN']).limit(150);
      snapshot = await q.get();
    } catch (_) {
      final q = _jobsRef.where('status', isEqualTo: 'PUBLISHED').limit(150);
      snapshot = await q.get();
    }

    var jobs = snapshot.docs
        .map((doc) => JobPostingModel.fromFirestore(doc))
        .toList();

    // Sort by createdAt descending
    jobs.sort((a, b) {
      final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    // In-memory filter for jobType
    if (jobType != null) {
      jobs = jobs.where((j) => j.jobType == jobType).toList();
    }

    // In-memory filter for workplaceType
    if (workplaceType != null) {
      jobs = jobs.where((j) => j.workplaceType == workplaceType).toList();
    }

    // In-memory filter for experienceLevel
    if (experienceLevel != null) {
      jobs = jobs.where((j) => j.experienceLevel == experienceLevel).toList();
    }

    // In-memory filter for keyword search (title, description, companyName)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final queryLower = searchQuery.trim().toLowerCase();
      jobs = jobs.where((j) {
        return j.title.toLowerCase().contains(queryLower) ||
            j.companyName.toLowerCase().contains(queryLower) ||
            j.description.toLowerCase().contains(queryLower);
      }).toList();
    }

    // In-memory filter for required skills
    if (skills != null && skills.isNotEmpty) {
      final filterSkillsLower = skills.map((s) => s.toLowerCase()).toSet();
      jobs = jobs.where((j) {
        final jobSkills = j.requiredSkills.map((s) => s.toLowerCase()).toSet();
        return filterSkillsLower.any((s) => jobSkills.contains(s));
      }).toList();
    }

    return jobs;
  }

  @override
  Stream<List<JobPostingModel>> listenPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) {
    return _jobsRef
        .where('status', whereIn: ['PUBLISHED', 'OPEN'])
        .limit(150)
        .snapshots()
        .map((snapshot) {
          var jobs = snapshot.docs
              .map((doc) => JobPostingModel.fromFirestore(doc))
              .toList();

          jobs.sort((a, b) {
            final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });

          if (jobType != null) {
            jobs = jobs.where((j) => j.jobType == jobType).toList();
          }
          if (workplaceType != null) {
            jobs = jobs.where((j) => j.workplaceType == workplaceType).toList();
          }
          if (experienceLevel != null) {
            jobs = jobs.where((j) => j.experienceLevel == experienceLevel).toList();
          }
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final queryLower = searchQuery.trim().toLowerCase();
            jobs = jobs.where((j) {
              return j.title.toLowerCase().contains(queryLower) ||
                  j.companyName.toLowerCase().contains(queryLower) ||
                  j.description.toLowerCase().contains(queryLower);
            }).toList();
          }
          if (skills != null && skills.isNotEmpty) {
            final filterSkillsLower = skills.map((s) => s.toLowerCase()).toSet();
            jobs = jobs.where((j) {
              final jobSkills = j.requiredSkills.map((s) => s.toLowerCase()).toSet();
              return filterSkillsLower.any((s) => jobSkills.contains(s));
            }).toList();
          }

          return jobs;
        });
  }

  @override
  Future<List<JobPostingModel>> getCompanyJobs(String companyId, {JobStatus? status}) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      var q = _jobsRef
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true);
      if (status != null) {
        q = q.where('status', isEqualTo: status.toShortString());
      }
      snapshot = await q.get();
    } catch (_) {
      var q = _jobsRef.where('companyId', isEqualTo: companyId);
      if (status != null) {
        q = q.where('status', isEqualTo: status.toShortString());
      }
      snapshot = await q.get();
    }

    var jobs = snapshot.docs
        .map((doc) => JobPostingModel.fromFirestore(doc))
        .toList();

    jobs.sort((a, b) {
      final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    return jobs;
  }

  @override
  Stream<List<JobPostingModel>> listenCompanyJobs(String companyId) {
    // Stream query with fallback safety; sorting in-memory guarantees order without composite index failures
    return _jobsRef
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobPostingModel.fromFirestore(doc))
              .toList();
          jobs.sort((a, b) {
            final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          return jobs;
        });
  }

  @override
  Future<JobPostingModel> getJobById(String jobId) async {
    final doc = await _jobsRef.doc(jobId).get();
    if (!doc.exists) {
      throw Exception('Job posting with ID $jobId does not exist.');
    }
    return JobPostingModel.fromFirestore(doc);
  }

  @override
  Future<String> createJob(JobPostingModel job) async {
    final docRef = await _jobsRef.add(job.toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateJob(JobPostingModel job) async {
    await _jobsRef.doc(job.id).update(job.toFirestore());
  }

  @override
  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    await _jobsRef.doc(jobId).update({
      'status': status.toShortString(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteJob(String jobId) async {
    await _jobsRef.doc(jobId).delete();
  }
}
