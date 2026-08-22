import 'auth_service.dart';
import 'form_service.dart' show PagedResult;

/// Item user pada daftar admin
class AdminUserItem {
  final int id;
  final String fullname;
  final String? username;
  final String email;
  final String role;
  final bool isActive;
  final int formCount;
  final int responseCount;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  const AdminUserItem({
    required this.id,
    required this.fullname,
    required this.email,
    this.role = 'USER',
    this.username,
    this.isActive = true,
    this.formCount = 0,
    this.responseCount = 0,
    this.createdAt,
    this.deletedAt,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) => AdminUserItem(
        id: json['id'] as int,
        fullname: json['fullname'] as String? ?? '',
        username: json['username'] as String?,
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'USER',
        isActive: json['isActive'] as bool? ?? true,
        formCount: json['formCount'] as int? ?? 0,
        responseCount: json['responseCount'] as int? ?? 0,
        createdAt: _date(json['createdAt']),
        deletedAt: _date(json['deletedAt']),
      );
}

/// Detail lengkap satu user untuk admin
class AdminUserDetail {
  final int id;
  final String fullname;
  final String? username;
  final String email;
  final String? role;
  final String? profileImage;
  final String? birthdate;
  final bool isActive;
  final int formCount;
  final int responseCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const AdminUserDetail({
    required this.id,
    required this.fullname,
    required this.email,
    this.username,
    this.role,
    this.profileImage,
    this.birthdate,
    this.isActive = true,
    this.formCount = 0,
    this.responseCount = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) =>
      AdminUserDetail(
        id: json['id'] as int,
        fullname: json['fullname'] as String? ?? '',
        username: json['username'] as String?,
        email: json['email'] as String? ?? '',
        role: json['role'] as String?,
        profileImage: json['profileImage'] as String?,
        birthdate: json['birthdate'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        formCount: json['formCount'] as int? ?? 0,
        responseCount: json['responseCount'] as int? ?? 0,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        deletedAt: _date(json['deletedAt']),
      );
}

/// Item form pada daftar admin
class AdminFormItem {
  final int id;
  final String title;
  final String? description;
  final String formLink;
  final String status;
  final String ownerName;
  final String ownerEmail;
  final int responseCount;
  final DateTime? takenDownAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const AdminFormItem({
    required this.id,
    required this.title,
    required this.formLink,
    this.status = 'unknown',
    this.description,
    this.ownerName = '',
    this.ownerEmail = '',
    this.responseCount = 0,
    this.takenDownAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory AdminFormItem.fromJson(Map<String, dynamic> json) => AdminFormItem(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        formLink: json['formLink'] as String? ?? '',
        status: json['status'] as String? ?? 'unknown',
        ownerName: json['ownerName'] as String? ?? '',
        ownerEmail: json['ownerEmail'] as String? ?? '',
        responseCount: json['responseCount'] as int? ?? 0,
        takenDownAt: _date(json['takenDownAt']),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        deletedAt: _date(json['deletedAt']),
      );
}

/// Detail lengkap satu form untuk admin
class AdminFormDetail {
  final int id;
  final String title;
  final String? description;
  final String? bannerImage;
  final String formLink;
  final String status;
  final AdminFormOwner owner;
  final int responseCount;
  final DateTime? takenDownAt;
  final Map<String, dynamic>? settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const AdminFormDetail({
    required this.id,
    required this.title,
    required this.formLink,
    required this.owner,
    this.status = 'unknown',
    this.description,
    this.bannerImage,
    this.responseCount = 0,
    this.takenDownAt,
    this.settings,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory AdminFormDetail.fromJson(Map<String, dynamic> json) =>
      AdminFormDetail(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        bannerImage: json['bannerImage'] as String?,
        formLink: json['formLink'] as String? ?? '',
        status: json['status'] as String? ?? 'unknown',
        owner: AdminFormOwner.fromJson(
            json['owner'] as Map<String, dynamic>? ?? {}),
        responseCount: json['responseCount'] as int? ?? 0,
        takenDownAt: _date(json['takenDownAt']),
        settings: json['settings'] as Map<String, dynamic>?,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        deletedAt: _date(json['deletedAt']),
      );
}

class AdminFormOwner {
  final int? id;
  final String? fullname;
  final String? email;

  const AdminFormOwner({this.id, this.fullname, this.email});

  factory AdminFormOwner.fromJson(Map<String, dynamic> json) =>
      AdminFormOwner(
        id: json['id'] as int?,
        fullname: json['fullname'] as String?,
        email: json['email'] as String?,
      );
}

/// Item feedback pada daftar admin
class AdminFeedbackItem {
  final int id;
  final int formId;
  final String formTitle;
  final String formLink;
  final int userId;
  final String userName;
  final String userEmail;
  final String reason;
  final String? description;
  final DateTime createdAt;

  const AdminFeedbackItem({
    required this.id,
    required this.formId,
    required this.formTitle,
    required this.formLink,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.reason,
    required this.createdAt,
    this.description,
  });

  factory AdminFeedbackItem.fromJson(Map<String, dynamic> json) =>
      AdminFeedbackItem(
        id: json['id'] as int,
        formId: json['formId'] as int,
        formTitle: json['formTitle'] as String? ?? '',
        formLink: json['formLink'] as String? ?? '',
        userId: json['userId'] as int,
        userName: json['userName'] as String? ?? '',
        userEmail: json['userEmail'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        description: json['description'] as String?,
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );
}

DateTime? _date(Object? value) {
  final s = value as String?;
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

/// Akses endpoint khusus admin (/api/admin/*)
class AdminService {
  static PagedResult<T> _paged<T>(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      PagedResult(
        items: [
          for (final r in map['items'] as List<dynamic>? ?? [])
            fromJson(r as Map<String, dynamic>),
        ],
        total: map['total'] as int? ?? 0,
      );

  /// GET /admin/users
  static Future<PagedResult<AdminUserItem>> getUsers({
    int? page,
    int? pageSize,
    String? search,
  }) async {
    final params = <String>[
      if (page != null && pageSize != null) ...['page=$page', 'pageSize=$pageSize'],
      if (search != null && search.trim().isNotEmpty)
        'search=${Uri.encodeQueryComponent(search.trim())}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final json = await AuthService.get('/admin/users$query');
    return _paged(json['data'] as Map<String, dynamic>, AdminUserItem.fromJson);
  }

  /// GET /admin/users/{id}
  static Future<AdminUserDetail> getUserDetail(int id) async {
    final json = await AuthService.get('/admin/users/$id');
    return AdminUserDetail.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// PUT /admin/users/{id}/ban
  static Future<void> banUser(int id) =>
      AuthService.put('/admin/users/$id/ban', {});

  /// PUT /admin/users/{id}/activate
  static Future<void> activateUser(int id) =>
      AuthService.put('/admin/users/$id/activate', {});

  /// DELETE /admin/users/{id}
  static Future<void> deleteUser(int id) =>
      AuthService.delete('/admin/users/$id');

  /// GET /admin/forms
  static Future<PagedResult<AdminFormItem>> getForms({
    int? page,
    int? pageSize,
    String? search,
    String? status,
  }) async {
    final params = <String>[
      if (page != null && pageSize != null) ...['page=$page', 'pageSize=$pageSize'],
      if (search != null && search.trim().isNotEmpty)
        'search=${Uri.encodeQueryComponent(search.trim())}',
      if (status != null && status.isNotEmpty && status != 'all')
        'status=$status',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final json = await AuthService.get('/admin/forms$query');
    return _paged(json['data'] as Map<String, dynamic>, AdminFormItem.fromJson);
  }

  /// GET /admin/forms/{id}
  static Future<AdminFormDetail> getFormDetail(int id) async {
    final json = await AuthService.get('/admin/forms/$id');
    return AdminFormDetail.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// POST /admin/forms/{id}/takedown
  static Future<void> takedownForm(int id) =>
      AuthService.post('/admin/forms/$id/takedown', {});

  /// POST /admin/forms/{id}/restore
  static Future<void> restoreForm(int id) =>
      AuthService.post('/admin/forms/$id/restore', {});

  /// DELETE /admin/forms/{id}
  static Future<void> deleteForm(int id) =>
      AuthService.delete('/admin/forms/$id');

  /// GET /admin/feedback
  static Future<PagedResult<AdminFeedbackItem>> getFeedbacks({
    int? page,
    int? pageSize,
  }) async {
    final params = <String>[
      if (page != null && pageSize != null) ...['page=$page', 'pageSize=$pageSize'],
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final json = await AuthService.get('/admin/feedback$query');
    return _paged(
        json['data'] as Map<String, dynamic>, AdminFeedbackItem.fromJson);
  }

  /// DELETE /admin/feedback/{id}
  static Future<void> dismissFeedback(int id) =>
      AuthService.delete('/admin/feedback/$id');

  /// POST /admin/feedback/{id}/takedown — takedown form pelapor
  static Future<void> feedbackTakedown(int id) =>
      AuthService.post('/admin/feedback/$id/takedown', {});

  /// POST /admin/feedback/{id}/restore — restore form pelapor
  static Future<void> feedbackRestore(int id) =>
      AuthService.post('/admin/feedback/$id/restore', {});
}
