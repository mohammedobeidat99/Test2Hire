import 'dart:typed_data';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/company_profile.dart';
import '../../domain/repositories/company_repository.dart';
import '../datasources/company_remote_data_source.dart';
import '../models/company_profile_model.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  final CompanyRemoteDataSource _remoteDataSource;

  CompanyRepositoryImpl({CompanyRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? CompanyRemoteDataSourceImpl();

  @override
  Future<CompanyProfile> getCompanyProfile(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyProfile(companyId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<CompanyProfile> listenCompanyProfile(String companyId) {
    return _remoteDataSource.listenCompanyProfile(companyId);
  }

  @override
  Future<void> updateCompanyProfile(CompanyProfile profile) async {
    try {
      final model = CompanyProfileModel(
        id: profile.id,
        ownerUid: profile.ownerUid,
        name: profile.name,
        legalName: profile.legalName,
        industry: profile.industry,
        website: profile.website,
        logoUrl: profile.logoUrl,
        coverUrl: profile.coverUrl,
        description: profile.description,
        location: profile.location,
        contactEmail: profile.contactEmail,
        contactPhone: profile.contactPhone,
        teamSize: profile.teamSize,
        verificationStatus: profile.verificationStatus,
      );
      await _remoteDataSource.updateCompanyProfile(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> uploadCompanyLogo(String companyId, Uint8List fileBytes, String fileName) async {
    try {
      return await _remoteDataSource.uploadCompanyLogo(companyId, fileBytes, fileName);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
