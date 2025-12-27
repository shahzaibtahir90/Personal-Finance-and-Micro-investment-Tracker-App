import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transaction.dart';
import '../models/consultant.dart';
import '../models/investment.dart';
import '../models/consultation.dart';

final _supabase = Supabase.instance.client;

class SupabaseService {
  // Check if user and consultant are linked (approved)
  static Future<bool> isConsultantApproved({
    required String userId,
    required String consultantId,
  }) async {
    final result = await _supabase
        .from('user_consultants')
        .select('user_id')
        .eq('user_id', userId)
        .eq('consultant_id', consultantId)
        .maybeSingle();
    return result != null;
  }

  // Approve an invitation.
  // Flow: Consultant (inviter_id) invited a Client (email).
  // The Client is now accepting.
  static Future<void> approveInvitation({
    required String invitationId,
    required String acceptorUserId, // The ID of the user accepting
    required String acceptorEmail, // The email check
  }) async {
    // 1. Mark invitation as accepted
    final response = await _supabase
        .from('consultant_invitations')
        .update({'status': 'accepted'})
        .eq('id', invitationId)
        .eq('email', acceptorEmail)
        .select('inviter_id')
        .single();

    final inviterId = response['inviter_id']; // This is the Consultant

    if (inviterId == null) {
      throw Exception('Original invitation has no inviter ID.');
    }

    // 2. Link Client (acceptor) and Consultant (inviter)
    final existingLink = await _supabase
        .from('user_consultants')
        .select()
        .eq('user_id', acceptorUserId)
        .eq('consultant_id', inviterId)
        .maybeSingle();

    if (existingLink == null) {
      await _supabase.from('user_consultants').insert({
        'user_id': acceptorUserId,
        'consultant_id': inviterId,
      });
    }
  }

  // Fetch invitations sent TO this consultant's email
  static Future<List<Map<String, dynamic>>> fetchIncomingInvitations(
    String email,
  ) async {
    try {
      print('🔍 Fetching invitations for email: $email');

      final data = await _supabase
          .from('consultant_invitations')
          .select(
            'id, name, specialization, inviter_id, status, created_at, email',
          )
          .eq('email', email)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      print('📧 Query returned ${(data as List).length} invitations');
      print('📧 Data: $data');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ Error fetching invitations: $e');
      throw Exception('Failed to fetch incoming invitations: $e');
    }
  }

  // Call Edge Function to send consultant invitation email
  static Future<void> sendConsultantInviteEmail({
    required String to,
    required String name,
    required String inviter,
    required String inviteLink,
  }) async {
    final response = await _supabase.functions.invoke(
      'send_consultant_invite',
      body: {
        'to': to,
        'name': name,
        'inviter': inviter,
        'invite_link': inviteLink,
      },
    );
    if (response.status != 200) {
      throw Exception('Failed to send invitation email: \\${response.data}');
    }
  }

  static Future<void> updateExpense({
    required int expenseId,
    required String userId,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    if (amount <= 0) {
      throw Exception('Expense amount must be positive.');
    }
    try {
      await _supabase
          .from('expenses')
          .update({
            'category': category,
            'amount': amount,
            'date': date.toString().split(' ')[0],
          })
          .eq('id', expenseId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  static Future<void> deleteExpense({
    required int expenseId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('expenses')
          .delete()
          .eq('id', expenseId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  static Future<void> updateTransaction({
    required int transactionId,
    required String userId,
    required String title,
    required double amount,
    required String type,
    required String iconName,
  }) async {
    if (amount <= 0) {
      throw Exception('Transaction amount must be positive.');
    }
    if (type != 'Income' && type != 'Expense') {
      throw Exception('Transaction type must be Income or Expense.');
    }
    try {
      await _supabase
          .from('transactions')
          .update({
            'title': title,
            'amount': amount,
            'type': type,
            'icon_name': iconName,
          })
          .eq('id', transactionId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  static Future<void> deleteTransaction({
    required int transactionId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('transactions')
          .delete()
          .eq('id', transactionId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  //
  // Upload a file for chat and send as a message
  static Future<void> uploadChatFile({
    required String userId,
    required String consultantId,
    required String filePath,
    required String fileName,
  }) async {
    // Upload to Supabase Storage (bucket: 'chat_files')
    final storage = _supabase.storage.from('chat_files');
    final file = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.any,
      allowedExtensions: null,
    );
    if (file == null || file.files.isEmpty || file.files.first.bytes == null) {
      throw Exception('Failed to read file');
    }
    final fileBytes = file.files.first.bytes!;
    final uploadPath =
        '$userId/$consultantId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await storage.uploadBinary(uploadPath, fileBytes);
    final publicUrl = storage.getPublicUrl(uploadPath);
    // Send a chat message with the file URL, prefixed for UI detection
    await addConsultation(
      userId: userId,
      consultantId: consultantId,
      message: '[file]$publicUrl',
    );
  }

  // CHAT/CONSULTATION FUNCTIONS
  static Future<List<Consultation>> fetchConsultations({
    required String userId,
    required String consultantId,
  }) async {
    try {
      final data = await _supabase
          .from('consultations')
          .select('id, user_id, consultant_id, message, date, created_at')
          .or('user_id.eq.$userId,and.consultant_id.eq.$consultantId')
          .order('created_at', ascending: true);
      return data.map((map) => Consultation.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch consultations: $e');
    }
  }

  static Future<void> addConsultation({
    required String userId,
    required String consultantId,
    required String message,
  }) async {
    // Only allow chat if approved
    final approved = await isConsultantApproved(
      userId: userId,
      consultantId: consultantId,
    );
    if (!approved) {
      throw Exception(
        'You cannot chat until the consultant has approved your invitation.',
      );
    }
    try {
      await _supabase.from('consultations').insert({
        'user_id': userId,
        'consultant_id': consultantId,
        'message': message,
        'date': DateTime.now().toString().split(' ')[0],
      });
    } catch (e) {
      throw Exception('Failed to add consultation: $e');
    }
  }

  static Future<void> deleteInvestment({
    required int investmentId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('investments')
          .delete()
          .eq('id', investmentId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        throw Exception(
          'Unable to delete investment: row-level security prevents this operation. Ensure your RLS policies allow authenticated users to delete their own investments (user_id = auth.uid()).',
        );
      }
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete investment: $e');
    }
  }
  // ------------------------------------
  // AUTHENTICATION FUNCTIONS
  // ------------------------------------

  static Future<void> signUpUser({
    required String email,
    required String password,
    required bool isConsultant,
    required String name,
    String? specialization,
  }) async {
    try {
      // Include name and consultant flag in the user metadata so a DB-side
      // trigger (recommended) can create the profile row atomically when the
      // auth user is created. Avoid client-side inserts which will be blocked
      // by RLS when email confirmation is required.
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'is_consultant': isConsultant,
          'name': name,
          if (specialization != null) 'specialization': specialization,
        },
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Sign up failed; no user information returned.');
      }

      // If the sign-up returns an active session (email confirmation not
      // required, or auto-confirmed) then create the profile row client-side
      // now. If your project prefers server-side triggers, keep server
      // trigger instead and skip this step.
      final session = response.session;
      if (session != null) {
        await _ensureProfileForCurrentUser();
      }
    } on AuthException catch (e) {
      throw Exception('Authentication Error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Ensure the authenticated user has a profile row in either `users` or
  // `consultants`. This is safe to call after sign-in or when a session is
  // active. It will do nothing if the profile already exists.
  static Future<void> _ensureProfileForCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final userId = user.id;

    try {
      // Check users table first
      final existingUser = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existingUser != null) return; // profile exists

      // If not in users, check consultants
      final existingConsultant = await _supabase
          .from('consultants')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existingConsultant != null) return;

      // No profile found; attempt to create one using auth user metadata
      final meta = user.userMetadata ?? <String, dynamic>{};
      final name = (meta['name'] as String?) ?? user.email ?? '';
      final isConsultant =
          meta['is_consultant'] == true || meta['is_consultant'] == 'true';
      final specialization = meta['specialization'] as String?;

      if (isConsultant) {
        await _supabase.from('consultants').insert({
          'id': userId,
          'email': user.email,
          'name': name,
          'specialization': specialization ?? 'General',
        });
      } else {
        await _supabase.from('users').insert({
          'id': userId,
          'email': user.email,
          'name': name,
          'role': 'User',
        });
      }
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        throw Exception(
          'Unable to create profile automatically: row-level security prevents this operation. If you want automatic profile creation on signup, either allow inserts from the authenticated client for the users/consultants table, add a DB trigger that runs with elevated privileges, or create profiles server-side with the service_role key.',
        );
      }
      rethrow;
    }
  }

  static Future<void> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // If sign-in succeeded and a session exists, ensure the profile row
      // exists so subsequent inserts (expenses/transactions) won't fail.
      if (res.session != null) {
        await _ensureProfileForCurrentUser();
      }
    } on AuthException catch (e) {
      throw Exception('Login Error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred during login: $e');
    }
  }

  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final userId = user.id;

    final userData = await _supabase
        .from('users')
        .select('email, name, role')
        .eq('id', userId)
        .maybeSingle();

    if (userData != null) {
      return {
        'role': userData['role'] ?? 'User',
        'email': userData['email'],
        'name': userData['name'],
        'id': userId,
      };
    }

    final consultantData = await _supabase
        .from('consultants')
        .select('email, name, specialization')
        .eq('id', userId)
        .maybeSingle();

    if (consultantData != null) {
      return {
        'role': 'Consultant',
        'email': consultantData['email'],
        'name': consultantData['name'],
        'id': userId,
        'specialization': consultantData['specialization'],
      };
    }

    throw Exception('Profile not found for this user ID.');
  }

  // ------------------------------------
  // TRANSACTION FUNCTIONS
  // ------------------------------------

  static Future<void> addTransaction({
    required String userId,
    required String title,
    required double amount,
    required String type, // 'Income' or 'Expense'
    required String iconName,
  }) async {
    if (amount <= 0) {
      throw Exception('Transaction amount must be positive.');
    }
    try {
      await _supabase.from('transactions').insert({
        'user_id': userId,
        'title': title,
        'amount': amount,
        'type': type,
        'icon_name': iconName,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        throw Exception(
          'Unable to add transaction: row-level security prevents this operation. Ensure your RLS policies allow authenticated users to insert their own transactions (user_id = auth.uid()).',
        );
      }
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  static Stream<List<Transaction>> streamTransactions(String userId) {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(10)
        .map((maps) {
          return maps.map((map) => Transaction.fromMap(map)).toList();
        });
  }

  // ------------------------------------
  // CONSULTANT FUNCTIONS
  // ------------------------------------

  static Future<List<Consultant>> fetchConsultants() async {
    // Deprecated for User view, but maybe useful for Admin?
    // Kept standard implementation but we will prefer Linked for users.
    try {
      final data = await _supabase
          .from('consultants')
          .select('id, email, name, specialization')
          .order('name');

      return data.map((map) => Consultant.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch consultants: $e');
    }
  }

  // Stream consultants linked to a specific user (Approved connections)
  static Stream<List<Consultant>> streamLinkedConsultants(String userId) {
    // We stream the junction table 'user_consultants'
    // and map it to a Future to fetch actual consultant details.
    // Note: Supabase Stream modifiers are limited.
    // We'll stream the junction table and for each emission, fetch the consultants.
    return _supabase
        .from('user_consultants')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((List<Map<String, dynamic>> junctionMaps) async {
          if (junctionMaps.isEmpty) return [];

          final consultantIds = junctionMaps
              .map((map) => map['consultant_id'] as String)
              .toList();

          if (consultantIds.isEmpty) return [];

          // Fetch details for these IDs
          final consultantsData = await _supabase
              .from('consultants')
              .select('id, email, name, specialization')
              .inFilter('id', consultantIds);

          return (consultantsData as List)
              .map((map) => Consultant.fromMap(map))
              .toList();
        });
  }

  // Stream clients linked to a specific consultant (for Consultant Dashboard)
  static Stream<List<Consultant>> streamLinkedClients(String consultantId) {
    // Queries 'user_consultants' where consultant_id matches
    // Fetches USER details from 'users' table
    return _supabase
        .from('user_consultants')
        .stream(primaryKey: ['id'])
        .eq('consultant_id', consultantId)
        .asyncMap((List<Map<String, dynamic>> junctionMaps) async {
          if (junctionMaps.isEmpty) return [];

          final clientIds = junctionMaps
              .map((map) => map['user_id'] as String)
              .toList();

          if (clientIds.isEmpty) return [];

          // Fetch details for these IDs from USERS table
          final clientsData = await _supabase
              .from('users')
              .select('id, email, name')
              .inFilter('id', clientIds);

          // Map Result to Consultant object (reusing model for simplicity in list view)
          // We mark specialization as 'Client' or null
          return (clientsData as List)
              .map(
                (map) => Consultant(
                  id: map['id'],
                  name: map['name'] ?? 'Unknown Client',
                  email: map['email'] ?? '',
                  specialization: 'Client', // Hardcode role for display
                ),
              )
              .toList();
        });
  }

  // Remove connection between user and consultant
  static Future<void> deleteConnection(
    String userId,
    String consultantId,
  ) async {
    // Deletes the row in junction table where BOTH match.
    // Note: This assumes unique constraints or we just delete all matches (should be 1).
    try {
      await _supabase.from('user_consultants').delete().match({
        'user_id': userId,
        'consultant_id': consultantId,
      });
    } catch (e) {
      throw Exception('Failed to remove connection: $e');
    }
  }

  // Invite a consultant by creating an invitation row. The client cannot
  // create an auth user or send an email on behalf of another user without
  // service_role credentials; here we record the invitation in a table
  // `consultant_invitations` with status 'pending'. The backend should
  // optionally trigger an email to the recipient using a secure service role.
  static Future<void> inviteConsultant({
    required String email,
    required String name,
    String? specialization,
  }) async {
    final inviter = _supabase.auth.currentUser;
    if (inviter == null) {
      throw Exception('Must be signed in to invite consultants.');
    }

    try {
      await _supabase.from('consultant_invitations').insert({
        'email': email,
        'name': name,
        'specialization': specialization ?? 'General',
        'inviter_id': inviter.id,
        'status': 'pending',
      });

      // NOTE: Email sending via Edge Function is disabled as it requires backend deployment.
      // The invitation is recorded in the database and will appear for the Consultant if they check their dashboard.
      /*
      final inviterProfile = await fetchUserProfile();
      final inviterName = inviterProfile['name'] ?? 'A user';
      // Generate invite link (replace with your actual registration/acceptance URL)
      final inviteLink = 'https://your-app.com/consultant-invite?email=$email';
      await sendConsultantInviteEmail(
        to: email,
        name: name,
        inviter: inviterName,
        inviteLink: inviteLink,
      );
      */
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        throw Exception(
          'Unable to create invitation: row-level security prevents this operation. Consider using a server-side endpoint with service_role key to create invitations and send emails.',
        );
      }
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create invitation: $e');
    }
  }

  // Fetch pending invitations created by the current user
  static Future<List<Map<String, dynamic>>> fetchPendingInvitations() async {
    final inviter = _supabase.auth.currentUser;
    if (inviter == null) return [];

    try {
      final data = await _supabase
          .from('consultant_invitations')
          .select('id, email, name, specialization, status, created_at')
          .eq('inviter_id', inviter.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to fetch pending invitations: $e');
    }
  }

  // ------------------------------------
  // INVESTMENT FUNCTIONS
  // ------------------------------------

  static Future<List<Investment>> fetchInvestments(String userId) async {
    try {
      final data = await _supabase
          .from('investments')
          .select(
            'id, user_id, investment_type, amount, rate, period, profit, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return data.map((map) => Investment.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch investments: $e');
    }
  }

  static Future<void> addInvestment({
    required String userId,
    required String investmentType,
    required double amount,
    required double rate,
    required String period,
    required double profit,
  }) async {
    if (amount <= 0) {
      throw Exception('Investment amount must be positive.');
    }
    if (rate < 0) {
      throw Exception('Rate cannot be negative.');
    }

    try {
      await _supabase.from('investments').insert({
        'user_id': userId,
        'investment_type': investmentType,
        'amount': amount,
        'rate': rate,
        'period': period,
        'profit': profit,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        throw Exception(
          'Unable to add investment: row-level security prevents this operation. Ensure your RLS policies allow authenticated users to insert their own investments (user_id = auth.uid()).',
        );
      }
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to add investment: $e');
    }
  }

  // ------------------------------------
  // EXPENSE FUNCTIONS
  // ------------------------------------

  static Future<void> addExpense({
    required String userId,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    if (amount <= 0) {
      throw Exception('Expense amount must be positive.');
    }

    try {
      await _supabase.from('expenses').insert({
        'user_id': userId,
        'category': category,
        'amount': amount,
        'date': date.toString().split(' ')[0], // Format: YYYY-MM-DD
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        throw Exception(
          'Unable to add expense: row-level security prevents this operation. Ensure your RLS policies allow authenticated users to insert their own expenses (user_id = auth.uid()).',
        );
      }
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchExpenses(String userId) async {
    try {
      final data = await _supabase
          .from('expenses')
          .select('id, category, amount, date, created_at')
          .eq('user_id', userId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to fetch expenses: $e');
    }
  }

  // ------------------------------------
  // UPDATE PROFILE FUNCTIONS
  // ------------------------------------

  static Future<void> updateUserProfile({
    String? name,
    String? email,
    String? password,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }

    try {
      // Update auth user email if provided
      if (email != null && email.isNotEmpty) {
        await _supabase.auth.updateUser(UserAttributes(email: email));
      }

      // Update auth user password if provided
      if (password != null && password.isNotEmpty) {
        await _supabase.auth.updateUser(UserAttributes(password: password));
      }

      // Update user profile in database
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) {
        updates['name'] = name;
      }
      if (email != null && email.isNotEmpty) {
        updates['email'] = email;
      }

      if (updates.isNotEmpty) {
        // Try updating users table
        try {
          await _supabase.from('users').update(updates).eq('id', user.id);
        } catch (e) {
          // If not in users table, try consultants table
          await _supabase.from('consultants').update(updates).eq('id', user.id);
        }
      }
    } on AuthException catch (e) {
      throw Exception('Authentication Error: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Database Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
