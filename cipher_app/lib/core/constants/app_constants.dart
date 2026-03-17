class AppConstants {
  static const String appName = 'Cipher';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String grokApiKey = String.fromEnvironment('GROK_API_KEY', defaultValue: '');

  static String get effectiveGroqApiKey => groqApiKey.isNotEmpty ? groqApiKey : grokApiKey;
  static const String groqModel = 'llama3-8b-8192';
  static const String streamApiKey = 'z3qps2tk4aes'; // Replace with your key

  static const String backendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: 'https://cipher1-backend.onrender.com');

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String workspacesCollection = 'workspaces';
  static const String channelsCollection = 'channels';
  static const String dmsCollection = 'dms';
  static const String groupsCollection = 'groups';
  static const String messagesCollection = 'messages';
  static const String threadsCollection = 'threads';

  // Hive Boxes
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';

  // Storage Paths
  static const String profileImages = 'profile_images';
  static const String chatFiles = 'chat_files';
  static const String chatImages = 'chat_images';
}
