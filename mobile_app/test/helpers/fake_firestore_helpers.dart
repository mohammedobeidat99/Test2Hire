// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight in-memory [DocumentSnapshot] fake for testing `*Model.fromFirestore`
/// serialization logic without initializing Firebase.
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;

  final Map<String, dynamic>? _data;

  @override
  final bool exists;

  FakeDocumentSnapshot(
    this.id,
    this._data, {
    bool? exists,
  }) : exists = exists ?? (_data != null);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic get(Object field) => _data?[field];

  @override
  dynamic operator [](Object field) => _data?[field];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
