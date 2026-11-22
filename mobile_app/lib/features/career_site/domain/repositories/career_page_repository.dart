import 'package:mobile_app/features/career_site/domain/entities/company_career_page.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';

abstract class CareerPageRepository {
  Stream<CompanyCareerPage?> listenCompanyCareerPage(String companyId);
  Future<CompanyCareerPage?> getCompanyCareerPage(String companyId);
  Stream<List<JobPosting>> listenCompanyPublicJobs(String companyId);
  Future<List<JobPosting>> getCompanyPublicJobs(String companyId);
  Future<void> updateCompanyBranding({
    required String companyId,
    required CompanyBranding branding,
  });
}
