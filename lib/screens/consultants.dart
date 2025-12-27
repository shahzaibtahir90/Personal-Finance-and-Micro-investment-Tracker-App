import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/consultant.dart';
import 'chat_screen.dart';
import 'profile.dart';

// Define theme colors for consistency
const _kPrimaryColor = Color(0xFF3B82F6);
const _kDarkBackground = Color(0xff111111);
const _kCardBackground = Color(0xff1e1e1e);
const _kAppBarColor = Color(0xff1a1a1a);

class ConsultantsScreen extends StatefulWidget {
  const ConsultantsScreen({super.key});

  @override
  State<ConsultantsScreen> createState() => _ConsultantsScreenState();
}

class _ConsultantsScreenState extends State<ConsultantsScreen> {
  List<Map<String, dynamic>> _pendingInvitations = [];
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchInvitations(String role, String email) async {
    try {
      List<Map<String, dynamic>> invites;
      if (role == 'Consultant') {
        // Consultants see who THEY invited
        invites = await SupabaseService.fetchPendingInvitations();
      } else {
        // Users see who invited THEM
        invites = await SupabaseService.fetchIncomingInvitations(email);
      }
      if (mounted) {
        setState(() {
          _pendingInvitations = invites;
          _userEmail = email;
        });
      }
    } catch (e) {
      debugPrint('Error fetching invitations: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _kPrimaryColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBackground,
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text('Consultants', style: TextStyle(fontSize: 25)),
        ),
        actions: [
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: _kCardBackground,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case "profile":
                case "settings":
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  break;
                case "logout":
                  try {
                    await SupabaseService.signOut();
                    if (mounted) _showSnackBar('Logged out successfully!');
                  } catch (e) {
                    if (mounted) {
                      _showSnackBar('Logout failed: $e', isError: true);
                    }
                  }
                  break;
                default:
                  break;
              }
            },
            itemBuilder: (context) => [
              _buildPopupMenuItem(
                "profile",
                "Profile",
                Icons.person,
                Colors.white,
              ),
              _buildPopupMenuItem(
                "settings",
                "Settings",
                Icons.settings,
                Colors.white,
              ),
              _buildPopupMenuItem(
                "logout",
                "Logout",
                Icons.logout,
                Colors.redAccent,
              ),
            ],
          ),
        ],
        backgroundColor: _kAppBarColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: SupabaseService.fetchUserProfile(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _kPrimaryColor),
            );
          }
          if (userSnapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${userSnapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final userData = userSnapshot.data!;
          final userId = userData['id'];
          final role = userData['role'];
          final email = userData['email'] ?? '';
          final isConsultant = role == 'Consultant';

          // Initial fetch for invitations
          if (_userEmail != email) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchInvitations(role, email);
            });
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _fetchInvitations(role, email);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pendingInvitations.isNotEmpty) ...[
                      Text(
                        isConsultant ? 'My Sent Invitations' : 'New Requests',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._pendingInvitations.map((inv) {
                        return Card(
                          color: _kCardBackground,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: _kPrimaryColor,
                              child: Icon(
                                Icons.mail_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              inv['name'] ?? inv['email'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              inv['email'] ?? '',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            trailing: !isConsultant
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      try {
                                        await SupabaseService.approveInvitation(
                                          invitationId: inv['id'].toString(),
                                          acceptorUserId: userId,
                                          acceptorEmail: email,
                                        );
                                        _showSnackBar('Invitation accepted!');
                                        _fetchInvitations(role, email);
                                      } catch (e) {
                                        _showSnackBar(
                                          'Error: $e',
                                          isError: true,
                                        );
                                      }
                                    },
                                    child: const Text('Accept'),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (inv['status'] ?? 'pending')
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],

                    Text(
                      isConsultant ? 'My Clients' : 'My Consultants',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: StreamBuilder<List<Consultant>>(
                        stream: isConsultant
                            ? SupabaseService.streamLinkedClients(userId)
                            : SupabaseService.streamLinkedConsultants(userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: _kPrimaryColor,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            );
                          }

                          final list = snapshot.data ?? [];
                          if (list.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isConsultant
                                        ? 'No clients connected yet.'
                                        : 'No consultants connected.',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    isConsultant
                                        ? 'Invite a client to get started.'
                                        : 'A consultant must invite you to get started.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final person = list[index];
                              return Card(
                                color: _kCardBackground,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: _kPrimaryColor,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    person.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isConsultant)
                                        Text(
                                          person.specialization,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      Text(
                                        person.email,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.message,
                                          color: _kPrimaryColor,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                userId: isConsultant
                                                    ? person.id
                                                    : userId,
                                                consultantId: isConsultant
                                                    ? userId
                                                    : person.id,
                                                consultantName: person.name,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _handleDeleteConnection(
                                              context,
                                              isConsultant,
                                              userId,
                                              person,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FutureBuilder<Map<String, dynamic>>(
        future: SupabaseService.fetchUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!['role'] == 'Consultant') {
            return FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: () => _showAddClientDialog(),
              child: const Icon(Icons.person_add),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    String text,
    IconData icon,
    Color iconColor,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Future<void> _handleDeleteConnection(
    BuildContext context,
    bool isConsultant,
    String userId,
    Consultant person,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBackground,
        title: const Text(
          "Remove Connection?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to remove ${person.name}?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Remove",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final targetUserId = isConsultant ? person.id : userId;
        final targetConsultantId = isConsultant ? userId : person.id;
        await SupabaseService.deleteConnection(
          targetUserId,
          targetConsultantId,
        );
        _showSnackBar("Connection removed.");
      } catch (e) {
        _showSnackBar("Error: $e", isError: true);
      }
    }
  }

  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _kCardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Invite Client",
            style: TextStyle(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration("Client Name"),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration("Client Email"),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@')
                      ? 'Enter valid email'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  try {
                    await SupabaseService.inviteConsultant(
                      email: emailController.text.trim(),
                      name: nameController.text.trim(),
                    );
                    _showSnackBar('Invitation sent!');
                  } catch (e) {
                    _showSnackBar('Failed: $e', isError: true);
                  }
                }
              },
              child: const Text("Invite"),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade400),
      filled: true,
      fillColor: _kDarkBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kPrimaryColor, width: 2),
      ),
    );
  }
}
