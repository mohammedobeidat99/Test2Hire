import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_user.dart';

class UserModel extends AppUser {
  const UserModel({
    required super.uid,
    required super.email,
    required super.role,
    required super.fullName,
    super.phoneNumber,
    super.photoUrl,
    required super.isEmailVerified,
    super.isProfileComplete = false,
    super.createdAt,
  });

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    bool isEmailVerified = false,
  }) {
    final data = snapshot.data() ?? {};
    final bool firestoreVerified = (data['isEmailVerified'] as bool? ?? false);
    return UserModel(
      uid: snapshot.id,
      email: data['email'] as String? ?? '',
      role: UserRoleExtension.fromString(data['role'] as String? ?? 'USER'),
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      photoUrl: data['photoUrl'] as String?,
      isEmailVerified: isEmailVerified || firestoreVerified,
      isProfileComplete: data['isProfileComplete'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromMap(
    Map<String, dynamic> data,
    String uid, {
    bool isEmailVerified = false,
  }) {
    final bool firestoreVerified = (data['isEmailVerified'] as bool? ?? false);
    return UserModel(
      uid: uid,
      email: data['email'] as String? ?? '',
      role: UserRoleExtension.fromString(data['role'] as String? ?? 'USER'),
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      photoUrl: data['photoUrl'] as String?,
      isEmailVerified: isEmailVerified || firestoreVerified,
      isProfileComplete: data['isProfileComplete'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role.toShortString(),
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'isProfileComplete': isProfileComplete,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    UserRole? role,
    String? fullName,
    String? phoneNumber,
    String? photoUrl,
    bool? isEmailVerified,
    bool? isProfileComplete,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
