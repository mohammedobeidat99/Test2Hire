import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/company_career_page.dart';
import '../../domain/repositories/career_page_repository.dart';
import '../datasources/career_page_remote_data_source.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';

class CareerPageRepositoryImpl implements CareerPageRepository {
  final CareerPageRemoteDataSource _remoteDataSource;

  CareerPageRepositoryImpl({required CareerPageRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Stream<CompanyCareerPage?> listenCompanyCareerPage(String companyId) {
    return _remoteDataSource.listenCompanyCareerPage(companyId);
  }

  @override
  Future<CompanyCareerPage?> getCompanyCareerPage(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyCareerPage(companyId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to load company career page.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<JobPosting>> listenCompanyPublicJobs(String companyId) {
    return _remoteDataSource.listenCompanyPublicJobs(companyId);
  }

  @override
  Future<List<JobPosting>> getCompanyPublicJobs(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyPublicJobs(companyId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to load company jobs.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateCompanyBranding({
    required String companyId,
    required CompanyBranding branding,
  }) async {
    try {
      await _remoteDataSource.updateCompanyBranding(
        companyId: companyId,
        branding: branding,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to update company branding.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
