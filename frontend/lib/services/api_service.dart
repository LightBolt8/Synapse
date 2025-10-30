import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Deployed API URL or localhost for development
  // If testing on Android emulator, use: http://10.0.2.2:8080/api/v1
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
  static String? authToken;
  static String? authCookie; // for session-cookie based backends

  static Map<String, String> _buildHeaders({String? token, String? cookie}) {
    final String? effectiveToken = token ?? authToken;
    final String? effectiveCookie = cookie ?? authCookie;
    return {
      'Content-Type': 'application/json',
      if (effectiveToken != null && effectiveToken.isNotEmpty)
        'Authorization': 'Bearer $effectiveToken',
      if (effectiveCookie != null && effectiveCookie.isNotEmpty)
        'Cookie': effectiveCookie,
    };
  }
  


  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final dynamic tokenCandidate = data['token'] ?? data['access_token'] ?? data['auth_token'] ?? data['jwt'] ?? data['idToken'];
      if (tokenCandidate is String && tokenCandidate.isNotEmpty) {
        authToken = tokenCandidate;
      }
      // capture Set-Cookie for session-based auth
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        // Extract just the cookie name=value pairs (exclude attributes)
        // Handle potential multiple cookies concatenated by comma
        final List<String> rawParts = setCookie.split(',');
        final List<String> cookiePairs = <String>[];
        for (final part in rawParts) {
          final segments = part.split(';');
          if (segments.isNotEmpty) {
            final pair = segments.first.trim();
            if (pair.contains('=')) {
              cookiePairs.add(pair);
            }
          }
        }
        if (cookiePairs.isNotEmpty) {
          authCookie = cookiePairs.join('; ');
        }
      }
      return data;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  static Future<void> signOut({String? token}) async {
    final headers = _buildHeaders(token: token);
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signout'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Sign out failed: ${response.body}');
    }
  }
  static Future<Map<String, dynamic>> joinClass({
    required String classCode,
    String? email,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final uri = Uri.parse('$baseUrl/classes/join').replace(queryParameters: {
      if (email != null) 'email': email,
    });
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({ 'class_code': classCode }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Join class failed: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> searchClasses({
    String? name,
    String? teacher,
    int limit = 20,
    String? token,
  }) async {
    if (name == null && teacher == null) {
      throw Exception('Must provide at least one search parameter');
    }

    final headers = _buildHeaders(token: token);
    final uri = Uri.parse('$baseUrl/classes/search').replace(queryParameters: {
      if (name != null && name.isNotEmpty) 'name': name,
      if (teacher != null && teacher.isNotEmpty) 'teacher': teacher,
      'limit': '$limit',
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = data['classes'] ?? [];
      return items.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Search classes failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> createClass({
    required String name,
    String? email,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final uri = Uri.parse('$baseUrl/classes').replace(queryParameters: {
      if (email != null) 'email': email,
    });
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({ 'name': name }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Create class failed: ${response.body}');
    }
  }
  static Future<Map<String, dynamic>> signup(
      String email, 
      String password, 
      String fullName, 
      String university
    ) async {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'university': university,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Signup failed: ${response.body}');
      }
    }

  static Future<Map<String, dynamic>> getProfile({String? token, String? email}) async {
    final headers = _buildHeaders(token: token);
    final uri = Uri.parse('$baseUrl/users/me').replace(queryParameters: {
      if (email != null) 'email': email,
    });
    final response = await http.get(
      uri,
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Get profile failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getClassRoster({
    required String classId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final response = await http.get(
      Uri.parse('$baseUrl/classes/$classId/roster'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Get roster failed: ${response.body}');
    }
  }

  static Future<void> removeStudent({
    required String classId,
    required String studentId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final response = await http.delete(
      Uri.parse('$baseUrl/classes/$classId/roster/$studentId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Remove student failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getClassDetails({
    required String classId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);  // Use _buildHeaders to include stored token
    final response = await http.get(
      Uri.parse('$baseUrl/classes/$classId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Get class details failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> listAssignments({
    required String classId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final response = await http.get(
      Uri.parse('$baseUrl/classes/$classId/assignments'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('List assignments failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> createAssignment({
    required String classId,
    required String title,
    String? description,
    String? dueDate,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final body = jsonEncode({
      'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'due_date': dueDate,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/classes/$classId/assignments'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Create assignment failed: ${response.body}');
    }
  }

  static Future<void> deleteClass({
    required String classId,
    String? email,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final uri = Uri.parse('$baseUrl/classes/$classId').replace(queryParameters: {
      if (email != null && email.isNotEmpty) 'email': email,
    });
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Delete class failed: ${response.body}');
    }
  }

  static Future<void> updateProfile({
    required String role,
    required String university,
    required String state,
    String? token,
    String? email,
  }) async {
    final headers = _buildHeaders(token: token);
    final body = jsonEncode({
      'role': role,
      'university': university,
      'state': state,
    });
    final uri = Uri.parse('$baseUrl/users/me').replace(queryParameters: {
      if (email != null) 'email': email,
    });
    final response = await http.put(
      uri,
      headers: headers,
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Update profile failed: ${response.body}');
    }
  }
  static Future<Map<String, dynamic>> getUserClasses({String? token, String? email}) async {
      final headers = _buildHeaders(token: token);
      final uri = Uri.parse('$baseUrl/classes').replace(queryParameters: {
        if (email != null && email.isNotEmpty) 'email': email,
      });
      final response = await http.get(
        uri,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get classes: ${response.body}');
      }
    }

  static Future<Map<String, dynamic>> getClassGradesForStudent({
    required String classId,
    required String studentId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final response = await http.get(
      Uri.parse('$baseUrl/classes/$classId/grades/student/$studentId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Get student grades failed: ${response.body}');
    }
  }

  static Future<void> setStudentGrade({
    required String classId,
    required String assignmentId,
    required String studentId,
    required double grade,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final body = jsonEncode({
      'assignment_id': assignmentId,
      'grade': grade,
    });
    final uri = Uri.parse('$baseUrl/classes/$classId/grades/set')
        .replace(queryParameters: {'student_id': studentId});
    final response = await http.post(
      uri,
      headers: headers,
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Set grade failed: ${response.body}');
    }
  }

    static Future<Map<String, dynamic>> chatWithAI(
      String message, {
      String? conversationId,
      String? token,
      String? classContext,
    }) async {
      final headers = _buildHeaders(token: token);
      final body = {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (classContext != null) 'class_context': classContext,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/ai-study-buddy'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('AI chat failed: ${response.body}');
      }
    }
    
    // Posts APIs
    static Future<Map<String, dynamic>> createPost({
      required String classId,
      required String title,
      String? content,
      String? imageUrl,
      String postType = 'discussion',
      List<String>? tags,
      String? token,
    }) async {
      final headers = _buildHeaders(token: token);
      final Map<String, dynamic> body = {
        'title': title,
        'content': content ?? '',
        'post_type': postType,
        'tags': tags ?? <String>[],
        'files': [if (imageUrl != null && imageUrl.isNotEmpty) imageUrl],
      };
      final response = await http.post(
        Uri.parse('$baseUrl/classes/$classId/posts'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Create post failed: ${response.body}');
      }
    }

  // --- Notes APIs ---
  static Future<Map<String, dynamic>> analyzeNotes({
    required List<http.MultipartFile> files,
    String? title,
    String? classId,
    String? token,
  }) async {
    final uri = Uri.parse('${baseUrl}/notes/analyze');
    final request = http.MultipartRequest('POST', uri);
    // Use provided token or fall back to stored authToken
    final String? effectiveToken = token ?? authToken;
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $effectiveToken';
    }
    for (final f in files) {
      request.files.add(f);
    }
    if (title != null) request.fields['title'] = title;
    if (classId != null) request.fields['class_id'] = classId;
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Analyze notes failed: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> listClassNoteSummaries({
    required String classId,
    int limit = 50,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final uri = Uri.parse('$baseUrl/classes/$classId/note_summaries').replace(queryParameters: {
      'limit': '$limit',
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = data['summaries'] ?? [];
      return items.cast<Map<String, dynamic>>();
    } else {
      throw Exception('List note summaries failed: ${response.body}');
    }
  }

  // --- Notes CRUD APIs ---
  static Future<Map<String, dynamic>> createNote({
    required String title,
    required String content,
    String? classId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final body = jsonEncode({
      'title': title,
      'content': content,
      if (classId != null) 'class_id': classId,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/notes'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Create note failed: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> listNotes({
    String? classId,
    int limit = 50,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final uri = Uri.parse('$baseUrl/notes').replace(queryParameters: {
      if (classId != null) 'class_id': classId,
      'limit': '$limit',
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = data['notes'] ?? [];
      return items.cast<Map<String, dynamic>>();
    } else {
      throw Exception('List notes failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getNote({
    required String noteId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final response = await http.get(
      Uri.parse('$baseUrl/notes/$noteId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Get note failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> updateNote({
    required String noteId,
    String? title,
    String? content,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final body = jsonEncode({
      if (title != null) 'title': title,
      if (content != null) 'content': content,
    });
    final response = await http.put(
      Uri.parse('$baseUrl/notes/$noteId'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Update note failed: ${response.body}');
    }
  }

  static Future<void> deleteNote({
    required String noteId,
    String? token,
  }) async {
    final headers = _buildHeaders(token: token);
    final response = await http.delete(
      Uri.parse('$baseUrl/notes/$noteId'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Delete note failed: ${response.body}');
    }
  }

    static Future<Map<String, dynamic>> votePost({
      required String classId,
      required String postId,
      required int value, // -1, 0, or 1
      String? token,
    }) async {
      final headers = _buildHeaders(token: token);
      final response = await http.post(
        Uri.parse('$baseUrl/classes/$classId/posts/$postId/vote'),
        headers: headers,
        body: jsonEncode({'value': value}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Vote failed: ${response.body}');
      }
    }

    static Future<List<Map<String, dynamic>>> listComments({
      required String classId,
      required String postId,
      String? token,
    }) async {
      final headers = _buildHeaders(token: token);
      final response = await http.get(
        Uri.parse('$baseUrl/classes/$classId/posts/$postId/comments'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> items = data['comments'] ?? [];
        return items.cast<Map<String, dynamic>>();
      } else {
        throw Exception('List comments failed: ${response.body}');
      }
    }

    static Future<Map<String, dynamic>> addComment({
      required String classId,
      required String postId,
      required String content,
      String? token,
    }) async {
      final headers = _buildHeaders(token: token);
      final response = await http.post(
        Uri.parse('$baseUrl/classes/$classId/posts/$postId/comments'),
        headers: headers,
        body: jsonEncode({'content': content}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Add comment failed: ${response.body}');
      }
    }

}