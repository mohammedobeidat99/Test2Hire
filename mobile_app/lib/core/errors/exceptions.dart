class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server exception occurred']);
  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Network exception occurred']);
  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Auth exception occurred']);
  @override
  String toString() => message;
}

class PermissionException implements Exception {
  final String message;
  const PermissionException([this.message = 'Permission exception occurred']);
  @override
  String toString() => message;
}
