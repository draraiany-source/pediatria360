/// Fonte unica de verdade para os caminhos do Firestore.
///
/// Nenhum repositorio escreve o nome de uma collection na mao.
class FirestorePaths {
  const FirestorePaths._();

  // Collections raiz
  static const String users = 'users';
  static const String children = 'children';
  static const String articles = 'articles';
  static const String courses = 'courses';
  static const String lessons = 'lessons';
  static const String products = 'products';
  static const String orders = 'orders';
  static const String coupons = 'coupons';
  static const String subscriptions = 'subscriptions';
  static const String appointments = 'appointments';
  static const String preVisitQuestionnaires = 'pre_visit_questionnaires';
  static const String prescriptions = 'prescriptions';
  static const String aiConversations = 'ai_conversations';
  static const String growthRecords = 'growth_records';
  static const String badges = 'badges';
  static const String challenges = 'challenges';
  static const String leaderboard = 'leaderboard';
  static const String notifications = 'notifications';
  static const String config = 'config';

  // Subcollections
  static const String messages = 'messages';
  static const String progress = 'progress';
  static const String vaccineDoses = 'vaccine_doses';

  static String userDoc(String uid) => '$users/$uid';
  static String userChildren(String uid) => '$users/$uid/$children';
  static String childDoc(String uid, String childId) =>
      '$users/$uid/$children/$childId';
  static String childGrowth(String uid, String childId) =>
      '$users/$uid/$children/$childId/$growthRecords';
  static String childVaccines(String uid, String childId) =>
      '$users/$uid/$children/$childId/$vaccineDoses';
  static String conversationMessages(String conversationId) =>
      '$aiConversations/$conversationId/$messages';
  static String courseLessons(String courseId) => '$courses/$courseId/$lessons';
  static String userProgress(String uid) => '$users/$uid/$progress';
  static String userNotifications(String uid) => '$users/$uid/$notifications';
}
