import 'dart:typed_data';
import '../entities/company_profile.dart';

abstract class CompanyRepository {
  Future<CompanyProfile> getCompanyProfile(String companyId);
  Stream<CompanyProfile> listenCompanyProfile(String companyId);
  Future<void> updateCompanyProfile(CompanyProfile profile);
  Future<String> uploadCompanyLogo(String companyId, Uint8List fileBytes, String fileName);
}
