import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  int currentQuestion;
  int totalScore;
  List<int> scoreHistory;
  DateTime? lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    this.currentQuestion = 1,
    this.totalScore = 0,
    this.scoreHistory = const [],
    this.lastLogin,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      email: data['email'] ?? '',
      currentQuestion: data['currentQuestion'] ?? 1,
      totalScore: data['totalScore'] ?? 0,
      scoreHistory: List<int>.from(data['scoreHistory'] ?? []),
      lastLogin: data['lastLogin'] != null
          ? (data['lastLogin'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'currentQuestion': currentQuestion,
      'totalScore': totalScore,
      'scoreHistory': scoreHistory,
      'lastLogin': lastLogin ?? FieldValue.serverTimestamp(),
    };
  }
}