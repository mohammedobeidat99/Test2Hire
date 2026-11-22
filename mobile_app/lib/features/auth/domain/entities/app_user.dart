enum UserRole {
  user, // Candidate / Job Seeker
  company, // Company / Recruiter
  admin, // Administrator
}

extension UserRoleExtension on UserRole {
  String toShortString() {
    switch (this) {
      case UserRole.user:
        return 'USER';
      case UserRole.company:
        return 'COMPANY';
      case UserRole.admin:
        return 'ADMIN';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toUpperCase()) {
      case 'COMPANY':
        return UserRole.company;
      case 'ADMIN':
        return UserRole.admin;
      case 'USER':
      default:
        return UserRole.user;
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final String fullName;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isEmailVerified;
  final bool isProfileComplete;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.fullName,
    this.phoneNumber,
    this.photoUrl,
    required this.isEmailVerified,
    this.isProfileComplete = false,
    this.createdAt,
  });

  bool get isCandidate => role == UserRole.user;
  bool get isCompany => role == UserRole.company;
  bool get isAdmin => role == UserRole.admin;
}
