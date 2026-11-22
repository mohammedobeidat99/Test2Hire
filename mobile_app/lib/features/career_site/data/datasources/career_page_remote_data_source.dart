import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_app/features/career_site/domain/entities/company_career_page.dart';
import 'package:mobile_app/features/career_site/data/models/company_career_page_model.dart';
import 'package:mobile_app/features/jobs/data/models/job_posting_model.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';

abstract class CareerPageRemoteDataSource {
  Stream<CompanyCareerPage?> listenCompanyCareerPage(String companyId);
  Future<CompanyCareerPage?> getCompanyCareerPage(String companyId);
  Stream<List<JobPosting>> listenCompanyPublicJobs(String companyId);
  Future<List<JobPosting>> getCompanyPublicJobs(String companyId);
  Future<void> updateCompanyBranding({
    required String companyId,
    required CompanyBranding branding,
  });
}

class CareerPageRemoteDataSourceImpl implements CareerPageRemoteDataSource {
  final FirebaseFirestore _firestore;

  CareerPageRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String _extractLocation(dynamic rawLocation) {
    if (rawLocation is Map) {
      final map = Map<String, dynamic>.from(rawLocation);
      final city = (map['city'] ?? '').toString().trim();
      final country = (map['country'] ?? '').toString().trim();
      final combined = [city, country].where((s) => s.isNotEmpty).join(', ');
      if (combined.isNotEmpty) return combined;
    } else if (rawLocation is String && rawLocation.trim().isNotEmpty) {
      return rawLocation.trim();
    }
    return 'Remote / Global';
  }

  @override
  Stream<CompanyCareerPage?> listenCompanyCareerPage(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .asyncMap((snapshot) async {
      final jobsSnap = await _firestore
          .collection('jobs')
          .where('companyId', isEqualTo: companyId)
          .get();
      final openDocs = jobsSnap.docs.where((d) {
        final st = (d.data()['status'] ?? 'PUBLISHED').toString().toUpperCase();
        return st == 'PUBLISHED' || st == 'OPEN';
      }).toList();

      if (snapshot.exists && snapshot.data() != null) {
        return CompanyCareerPageModel.fromFirestore(snapshot, openDocs.length);
      }
      // Fallback: synthesize company profile from published jobs if company doc is absent
      if (openDocs.isNotEmpty) {
        final firstJob = openDocs.first.data();
        return CompanyCareerPage(
          companyId: companyId,
          companyName: (firstJob['companyName'] ?? 'Verified Company').toString(),
          logoUrl: firstJob['companyLogoUrl'] as String?,
          industry: (firstJob['category'] ?? 'Technology & Engineering').toString(),
          description:
              'Official recruitment profile and open career opportunities on Test2Hire.',
          location: _extractLocation(firstJob['location']),
          activeJobsCount: openDocs.length,
          isApproved: false,
        );
      }
      return null;
    });
  }

  @override
  Future<CompanyCareerPage?> getCompanyCareerPage(String companyId) async {
    final doc = await _firestore.collection('companies').doc(companyId).get();
    final jobsQuery = await _firestore
        .collection('jobs')
        .where('companyId', isEqualTo: companyId)
        .get();
    final openDocs = jobsQuery.docs.where((d) {
      final st = (d.data()['status'] ?? 'PUBLISHED').toString().toUpperCase();
      return st == 'PUBLISHED' || st == 'OPEN';
    }).toList();

    if (doc.exists && doc.data() != null) {
      return CompanyCareerPageModel.fromFirestore(doc, openDocs.length);
    }
    if (openDocs.isNotEmpty) {
      final firstJob = openDocs.first.data();
      return CompanyCareerPage(
        companyId: companyId,
        companyName: (firstJob['companyName'] ?? 'Verified Company').toString(),
        logoUrl: firstJob['companyLogoUrl'] as String?,
        industry: (firstJob['category'] ?? 'Technology & Engineering').toString(),
        description:
            'Official recruitment profile and open career opportunities on Test2Hire.',
        location: _extractLocation(firstJob['location']),
        activeJobsCount: openDocs.length,
        isApproved: false,
      );
    }
    return null;
  }

  @override
  Stream<List<JobPosting>> listenCompanyPublicJobs(String companyId) {
    return _firestore
        .collection('jobs')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
      final jobs = snapshot.docs
          .where((doc) {
            final st = (doc.data()['status'] ?? 'PUBLISHED').toString().toUpperCase();
            return st == 'PUBLISHED' || st == 'OPEN';
          })
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
  Future<List<JobPosting>> getCompanyPublicJobs(String companyId) async {
    final snapshot = await _firestore
        .collection('jobs')
        .where('companyId', isEqualTo: companyId)
        .get();

    final jobs = snapshot.docs
        .where((doc) {
          final st = (doc.data()['status'] ?? 'PUBLISHED').toString().toUpperCase();
          return st == 'PUBLISHED' || st == 'OPEN';
        })
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
  Future<void> updateCompanyBranding({
    required String companyId,
    required CompanyBranding branding,
  }) async {
    await _firestore.collection('companies').doc(companyId).update({
      'branding': branding.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
