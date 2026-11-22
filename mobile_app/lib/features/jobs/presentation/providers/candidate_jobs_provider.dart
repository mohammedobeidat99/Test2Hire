import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_posting.dart';
import '../../domain/repositories/job_repository.dart';

enum JobSortOption {
  newest,
  salaryHighToLow,
  bestMatch,
}

extension JobSortOptionExtension on JobSortOption {
  String get displayName {
    switch (this) {
      case JobSortOption.newest:
        return 'Most Recent';
      case JobSortOption.salaryHighToLow:
        return 'Highest Salary';
      case JobSortOption.bestMatch:
        return 'Best Skill Match';
    }
  }

  String localizedName(bool isArabic) {
    if (!isArabic) return displayName;
    switch (this) {
      case JobSortOption.newest:
        return 'الأحدث نشراً';
      case JobSortOption.salaryHighToLow:
        return 'الأعلى راتباً';
      case JobSortOption.bestMatch:
        return 'أفضل مطابقة للمهارات';
    }
  }
}

class CandidateJobsProvider extends ChangeNotifier {
  final JobRepository _jobRepository;
  final FirebaseFirestore? _firestore;
  StreamSubscription<List<JobPosting>>? _jobsSubscription;

  List<JobPosting> _jobs = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filter & Sort state
  String _searchQuery = '';
  JobType? _selectedJobType;
  WorkplaceType? _selectedWorkplaceType;
  ExperienceLevel? _selectedExperienceLevel;
  String _selectedCategory = 'All';
  JobSortOption _sortOption = JobSortOption.newest;
  final Set<String> _selectedSkills = {};

  // Saved & Recently Viewed Jobs
  final Set<String> _savedJobIds = {};
  final List<String> _recentlyViewedJobIds = [];
  bool _userPrefsLoaded = false;

  CandidateJobsProvider({
    required JobRepository jobRepository,
    FirebaseFirestore? firestore,
  })  : _jobRepository = jobRepository,
        _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  List<JobPosting> get jobs => _jobs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  JobType? get selectedJobType => _selectedJobType;
  WorkplaceType? get selectedWorkplaceType => _selectedWorkplaceType;
  ExperienceLevel? get selectedExperienceLevel => _selectedExperienceLevel;
  String get selectedCategory => _selectedCategory;
  JobSortOption get sortOption => _sortOption;
  Set<String> get selectedSkills => _selectedSkills;
  Set<String> get savedJobIds => _savedJobIds;
  List<String> get recentlyViewedJobIds => _recentlyViewedJobIds;

  bool isJobSaved(String jobId) => _savedJobIds.contains(jobId);

  List<JobPosting> get savedJobs =>
      _jobs.where((j) => _savedJobIds.contains(j.id)).toList();

  List<JobPosting> get recentlyViewedJobs {
    final byId = {for (final j in _jobs) j.id: j};
    return _recentlyViewedJobIds
        .map((id) => byId[id])
        .whereType<JobPosting>()
        .toList();
  }

  List<JobPosting> recommendedJobs(List<String> candidateSkills) {
    final scores = computeSkillMatches(_jobs, candidateSkills);
    final copy = List<JobPosting>.from(_jobs);
    copy.sort((a, b) {
      final scoreB = scores[b.id] ?? 0;
      final scoreA = scores[a.id] ?? 0;
      return scoreB.compareTo(scoreA);
    });
    return copy;
  }

  List<JobPosting> getSortedAndFilteredJobs(List<String> candidateSkills) {
    var result = _jobs.where((job) {
      if (_selectedCategory != 'All') {
        final text =
            '${job.title} ${job.description} ${job.requiredSkills.join(" ")}'
                .toLowerCase();
        switch (_selectedCategory) {
          case 'Engineering':
            if (!text.contains('engineer') &&
                !text.contains('developer') &&
                !text.contains('flutter') &&
                !text.contains('react') &&
                !text.contains('backend') &&
                !text.contains('frontend')) {
              return false;
            }
            break;
          case 'Data & AI':
            if (!text.contains('data') &&
                !text.contains('ai') &&
                !text.contains('machine learning') &&
                !text.contains('python') &&
                !text.contains('analytics')) {
              return false;
            }
            break;
          case 'Cloud & DevOps':
            if (!text.contains('cloud') &&
                !text.contains('devops') &&
                !text.contains('aws') &&
                !text.contains('docker') &&
                !text.contains('kubernetes') &&
                !text.contains('security')) {
              return false;
            }
            break;
          case 'Product & Design':
            if (!text.contains('product') &&
                !text.contains('design') &&
                !text.contains('ux') &&
                !text.contains('ui')) {
              return false;
            }
            break;
        }
      }
      return true;
    }).toList();

    switch (_sortOption) {
      case JobSortOption.newest:
        result.sort((a, b) {
          final dA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dB.compareTo(dA);
        });
        break;
      case JobSortOption.salaryHighToLow:
        result.sort((a, b) {
          final sA = a.salaryRange?.max ?? a.salaryRange?.min ?? 0;
          final sB = b.salaryRange?.max ?? b.salaryRange?.min ?? 0;
          return sB.compareTo(sA);
        });
        break;
      case JobSortOption.bestMatch:
        final scores = computeSkillMatches(result, candidateSkills);
        result.sort((a, b) {
          final mA = scores[a.id] ?? 0;
          final mB = scores[b.id] ?? 0;
          return mB.compareTo(mA);
        });
        break;
    }

    return result;
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedJobType != null ||
      _selectedWorkplaceType != null ||
      _selectedExperienceLevel != null ||
      _selectedCategory != 'All' ||
      _selectedSkills.isNotEmpty;

  Future<void> loadCandidateJobPreferences(String userId) async {
    if (_userPrefsLoaded && userId.isEmpty) return;
    _userPrefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final localSaved = prefs.getStringList('saved_jobs_$userId') ?? [];
      final localRecent = prefs.getStringList('recent_jobs_$userId') ?? [];
      _savedJobIds.addAll(localSaved);
      for (final id in localRecent) {
        if (!_recentlyViewedJobIds.contains(id)) {
          _recentlyViewedJobIds.add(id);
        }
      }
      notifyListeners();
    } catch (_) {}

    if (userId.isEmpty) return;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final remoteSaved = (data['savedJobIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final remoteRecent = (data['recentlyViewedJobIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (remoteSaved.isNotEmpty) {
          _savedJobIds
            ..clear()
            ..addAll(remoteSaved);
        }
        if (remoteRecent.isNotEmpty) {
          _recentlyViewedJobIds
            ..clear()
            ..addAll(remoteRecent);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleSaveJob(String jobId, {String? userId}) async {
    if (_savedJobIds.contains(jobId)) {
      _savedJobIds.remove(jobId);
    } else {
      _savedJobIds.add(jobId);
    }
    notifyListeners();

    final uid = userId ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_jobs_$uid', _savedJobIds.toList());
    } catch (_) {}

    if (uid.isNotEmpty) {
      try {
        await _db.collection('users').doc(uid).set(
          {
            'savedJobIds': _savedJobIds.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  Future<void> recordJobViewed(String jobId, {String? userId}) async {
    _recentlyViewedJobIds.remove(jobId);
    _recentlyViewedJobIds.insert(0, jobId);
    if (_recentlyViewedJobIds.length > 15) {
      _recentlyViewedJobIds.removeLast();
    }
    notifyListeners();

    final uid = userId ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_jobs_$uid', _recentlyViewedJobIds);
    } catch (_) {}

    if (uid.isNotEmpty) {
      try {
        await _db.collection('users').doc(uid).set(
          {
            'recentlyViewedJobIds': _recentlyViewedJobIds,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  void listenJobs({bool force = false}) {
    if (!force && _jobsSubscription != null) return;
    _jobsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _jobsSubscription = _jobRepository
        .listenPublishedJobs(
      searchQuery: _searchQuery.trim().isNotEmpty ? _searchQuery : null,
      jobType: _selectedJobType,
      workplaceType: _selectedWorkplaceType,
      experienceLevel: _selectedExperienceLevel,
      skills: _selectedSkills.isNotEmpty ? _selectedSkills.toList() : null,
    )
        .listen((list) {
      _jobs = list;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> fetchJobs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _jobs = await _jobRepository.getPublishedJobs(
        searchQuery: _searchQuery.trim().isNotEmpty ? _searchQuery : null,
        jobType: _selectedJobType,
        workplaceType: _selectedWorkplaceType,
        experienceLevel: _selectedExperienceLevel,
        skills: _selectedSkills.isNotEmpty ? _selectedSkills.toList() : null,
      );
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _refreshJobs() {
    if (_jobsSubscription != null) {
      listenJobs(force: true);
    } else {
      fetchJobs();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _refreshJobs();
  }

  void setJobType(JobType? type) {
    _selectedJobType = type;
    _refreshJobs();
  }

  void setWorkplaceType(WorkplaceType? type) {
    _selectedWorkplaceType = type;
    _refreshJobs();
  }

  void setExperienceLevel(ExperienceLevel? level) {
    _selectedExperienceLevel = level;
    _refreshJobs();
  }

  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  void setSortOption(JobSortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    notifyListeners();
  }

  void toggleSkill(String skill) {
    if (_selectedSkills.contains(skill)) {
      _selectedSkills.remove(skill);
    } else {
      _selectedSkills.add(skill);
    }
    _refreshJobs();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedJobType = null;
    _selectedWorkplaceType = null;
    _selectedExperienceLevel = null;
    _selectedCategory = 'All';
    _selectedSkills.clear();
    _refreshJobs();
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    super.dispose();
  }

  Future<JobPosting?> getJobDetails(String jobId) async {
    try {
      return await _jobRepository.getJobById(jobId);
    } catch (e) {
      return null;
    }
  }

  /// Precomputes skill match scores for a batch of jobs in one pass.
  Map<String, int> computeSkillMatches(
    Iterable<JobPosting> jobList,
    List<String> candidateSkills,
  ) {
    final candidateSet =
        candidateSkills.map((s) => s.trim().toLowerCase()).toSet();
    return {
      for (final job in jobList)
        job.id: _calculateSkillMatchWithSet(job, candidateSet),
    };
  }

  /// Calculates candidate skill match score with a job posting
  int calculateSkillMatch(JobPosting job, List<String> candidateSkills) {
    if (job.requiredSkills.isEmpty) return 100;
    final candidateSet =
        candidateSkills.map((s) => s.trim().toLowerCase()).toSet();
    return _calculateSkillMatchWithSet(job, candidateSet);
  }

  int _calculateSkillMatchWithSet(JobPosting job, Set<String> candidateSet) {
    if (job.requiredSkills.isEmpty) return 100;
    final matchedCount = job.requiredSkills
        .where((s) => candidateSet.contains(s.trim().toLowerCase()))
        .length;
    return ((matchedCount / job.requiredSkills.length) * 100).round();
  }
}
