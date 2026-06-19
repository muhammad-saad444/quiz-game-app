import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name; // 👈 Added custom player name field
  int currentQuestion;
  int totalScore;
  // A Map of Maps to perfectly match your category-specific Firestore structure
  Map<String, dynamic> scoreHistory;
  DateTime? lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    required this.name, // 👈 Required field for initialization
    this.currentQuestion = 1,
    this.totalScore = 0,
    this.scoreHistory = const {},
    this.lastLogin,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      email: data['email'] ?? '',
      name: data['name'] ?? 'Explorer', // 👈 Extracts name safely from Firestore maps
      currentQuestion: (data['currentQuestion'] ?? 1).toInt(),
      totalScore: (data['totalScore'] ?? 0).toInt(),
      // Safely cast as a Map structure instead of a List
      scoreHistory: data['scoreHistory'] != null
          ? Map<String, dynamic>.from(data['scoreHistory'])
          : {},
      lastLogin: data['lastLogin'] != null
          ? (data['lastLogin'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name, // 👈 Serializes name back to Firebase database
      'currentQuestion': currentQuestion,
      'totalScore': totalScore,
      'scoreHistory': scoreHistory,
      'lastLogin': lastLogin ?? FieldValue.serverTimestamp(),
    };
  }
}