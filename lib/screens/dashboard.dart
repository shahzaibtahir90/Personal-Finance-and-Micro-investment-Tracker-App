import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for input formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/transaction.dart';
import 'profile.dart';

// Define theme colors for consistency
const _kPrimaryColor = Color(0xFF3B82F6); // BlueAccent
const _kDarkBackground = Color(0xff111111);
const _kCardBackground = Color(0xff1e1e1e);
const _kAppBarColor = Color(0xff1a1a1a);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Helper for popup menu items
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

  // Handle logout action
  void _handleLogout() async {
    try {
      await SupabaseService.signOut();
      _showSnackBar('Logged out successfully!');
    } catch (e) {
      _showSnackBar('Logout failed: $e', isError: true);
    }
  }

  // State variables for profile data
  String _userRole = 'Loading...';
  String _userName = 'User';
  String _currentUserId = ''; // Stores the user ID for fetching transactions
  bool _isLoading = true;
  late ScrollController _scrollController;
  bool _showAppBar = true;
  // bool _showFAB = true; // FAB removed

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _fetchUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    bool shouldShowAppBar = _scrollController.offset < 100;
    if (shouldShowAppBar != _showAppBar) {
      setState(() => _showAppBar = shouldShowAppBar);
    }
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.fetchUserProfile();
      setState(() {
        _userRole = profile['role'] ?? 'User';
        _userName = profile['name'] ?? 'User';
        _currentUserId = profile['id'] ?? '';
      });
    } catch (e) {
      _showSnackBar('Error loading profile: ${e.toString()}', isError: true);
      setState(() {
        _userRole = 'Error';
        _userName = 'User';
      });
    } finally {
      setState(() => _isLoading = false);
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

  void _showAddTransactionDialog(BuildContext context, String type) {
    if (_currentUserId.isEmpty) {
      _showSnackBar(
        "Cannot add transaction: User ID not found.",
        isError: true,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String currentIconName = (type == 'Income') ? 'payments' : 'shopping_bag';
    final Map<String, IconData> availableIcons = {
      'payments': Icons.payments,
      'work': Icons.work,
      'shopping_bag': Icons.shopping_bag,
      'fastfood': Icons.fastfood,
      'local_gas_station': Icons.local_gas_station,
      'attach_money': Icons.attach_money,
    };
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              backgroundColor: _kCardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Add $type',
                style: const TextStyle(color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          'Title / Description',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: amountController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Amount (Rs.)'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null ||
                              double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Please enter a valid positive amount.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Icon Selector
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kDarkBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Icon:',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: availableIcons.entries.map((entry) {
                                final isSelected = entry.key == currentIconName;
                                return GestureDetector(
                                  onTap: () {
                                    setStateSB(() {
                                      currentIconName = entry.key;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _kPrimaryColor
                                          : _kCardBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      entry.value,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (type == 'Income')
                        ? Colors.green
                        : Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(
                        context,
                      ).pop(); // Close the dialog immediately
                      final title = titleController.text.trim();
                      final amount = double.parse(amountController.text);
                      try {
                        await SupabaseService.addTransaction(
                          userId: _currentUserId,
                          title: title,
                          amount: amount,
                          type: type,
                          iconName: currentIconName,
                        );
                        // If adding an expense, also add to expenses table
                        if (type == 'Expense') {
                          await SupabaseService.addExpense(
                            userId: _currentUserId,
                            category: title,
                            amount: amount,
                            date: DateTime.now(),
                          );
                        }
                        _showSnackBar(
                          '$type added successfully!',
                          isError: false,
                        );
                      } catch (e) {
                        _showSnackBar(
                          'Failed to add $type: ${e.toString()}',
                          isError: true,
                        );
                      }
                    }
                  },
                  child: Text('Save $type'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddInvestmentDialog() {
    if (_currentUserId.isEmpty) {
      _showSnackBar("Cannot add investment: User ID not found.", isError: true);
      return;
    }

    final formKey = GlobalKey<FormState>();
    final investmentTypeController = TextEditingController();
    final amountController = TextEditingController();
    final rateController = TextEditingController();
    final periodController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _kCardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Investment',
            style: TextStyle(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: investmentTypeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Investment Type'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter investment type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: amountController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Amount (Rs.)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null ||
                          double.tryParse(value) == null ||
                          double.parse(value) <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: rateController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Rate (%)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null ||
                          double.tryParse(value) == null ||
                          double.parse(value) < 0) {
                        return 'Please enter a valid rate';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: periodController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Period'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter investment period';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop();

                  final investmentType = investmentTypeController.text.trim();
                  final amount = double.parse(amountController.text);
                  final rate = double.parse(rateController.text);
                  final period = periodController.text.trim();
                  final profit = (amount * rate) / 100;

                  try {
                    await SupabaseService.addInvestment(
                      userId: _currentUserId,
                      investmentType: investmentType,
                      amount: amount,
                      rate: rate,
                      period: period,
                      profit: profit,
                    );
                    _showSnackBar(
                      'Investment added successfully!',
                      isError: false,
                    );
                  } catch (e) {
                    _showSnackBar(
                      'Failed to add investment: \\${e.toString()}',
                      isError: true,
                    );
                  }
                }
              },
              child: const Text('Save Investment'),
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

  // --- WIDGET BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: _showAppBar ? Offset.zero : const Offset(0, -1),
          child: AppBar(
            title: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $_userName!', // Use fetched username
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Text(
                  //   _userRole,
                  //   style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  // ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: _kCardBackground,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case "logout":
                      _handleLogout();
                      break;
                    case "profile":
                    case "settings":
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
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
        ),
      ),

      // ---------------- BODY ----------------
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _kPrimaryColor),
            )
          : RefreshIndicator(
              color: _kPrimaryColor,
              onRefresh: () async {
                await _fetchUserData();
                setState(() {});
              },
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // Dynamic Summary Card based on Role
                        _userRole == 'Consultant'
                            ? _consultantSummaryCard()
                            : _userSummaryCard(),

                        const SizedBox(height: 25),

                        const SizedBox(height: 25),

                        // Quick Actions (Hide for Consultants)
                        if (_userRole != 'Consultant') ...[
                          _quickActionsRow(),
                          const SizedBox(height: 25),
                        ],
                      ],
                    ),
                  ),
                  // Recent Transactions (Hide for Consultants)
                  if (_userRole != 'Consultant')
                    Expanded(child: _recentTransactions()),
                ],
              ),
            ),
    );
  }

  // Helper Widgets -----------------------------------------------------------------

  Widget _userSummaryCard() {
    // Compute totals from the user's transactions stream. Defaults to zero
    // when there are no transactions (e.g., newly signed-up user).
    return StreamBuilder<List<Transaction>>(
      stream: _currentUserId.isNotEmpty
          ? SupabaseService.streamTransactions(_currentUserId)
          : const Stream<List<Transaction>>.empty(),
      builder: (context, snapshot) {
        double totalIncome = 0.0;
        double totalExpenses = 0.0;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          for (var tx in snapshot.data!) {
            if (tx.type == 'Income') {
              totalIncome += tx.amount;
            } else if (tx.type == 'Expense') {
              totalExpenses += tx.amount;
            }
          }
        }

        final currentBalance = totalIncome - totalExpenses;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kPrimaryColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: _kPrimaryColor.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Current Balance",
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                "Rs. ${currentBalance.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryStat(
                    "Total Income",
                    totalIncome,
                    Colors.greenAccent,
                    Icons.arrow_downward,
                  ),
                  _summaryStat(
                    "Total Expenses",
                    totalExpenses,
                    Colors.redAccent,
                    Icons.arrow_upward,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _consultantSummaryCard() {
    // This is the aggregated client overview for a Consultant
    int totalClients = 45; // Placeholder
    int activeClients = 32; // Placeholder

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Client Portfolio Overview",
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryStat(
                    "Total Clients",
                    totalClients.toString(),
                    Colors.purpleAccent,
                    Icons.people,
                  ),
                  _summaryStat(
                    "Active Clients",
                    activeClients.toString(),
                    Colors.cyanAccent,
                    Icons.verified,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _clientInvitationsSection(),
      ],
    );
  }

  Widget _clientInvitationsSection() {
    // Only show if we have an email (part of profile)
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: const Text(
          "No user email found",
          style: TextStyle(color: Colors.redAccent),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Stream.fromFuture(
        SupabaseService.fetchIncomingInvitations(user.email!),
      ),
      builder: (context, snapshot) {
        // Show loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            ),
          );
        }

        // Show error state
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Error Loading Invitations",
                  style: TextStyle(fontSize: 18, color: Colors.redAccent),
                ),
                const SizedBox(height: 10),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final invites = snapshot.data ?? [];

        // Always show section for debugging
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: invites.isEmpty
                  ? Colors.grey.withOpacity(0.3)
                  : Colors.orangeAccent.withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Client Invitations",
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  Text(
                    "${invites.length}",
                    style: TextStyle(
                      fontSize: 16,
                      color: invites.isEmpty
                          ? Colors.grey
                          : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (invites.isEmpty)
                Text(
                  "No pending invitations (Email: ${user.email})",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                )
              else
                ...invites.map((invite) {
                  return Card(
                    color: Colors.grey.shade900,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orangeAccent,
                        child: Icon(Icons.person_add, color: Colors.white),
                      ),
                      title: Text(
                        invite['name'] ?? 'Unknown Client',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "Sent: ${invite['created_at']?.split('T')[0] ?? 'N/A'}",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await SupabaseService.approveInvitation(
                              invitationId: invite['id'].toString(),
                              acceptorUserId: _currentUserId,
                              acceptorEmail: user.email!,
                            );
                            _showSnackBar(
                              'Invitation Accepted!',
                              isError: false,
                            );
                            setState(() {}); // Refresh UI
                          } catch (e) {
                            _showSnackBar(
                              'Error: ${e.toString()}',
                              isError: true,
                            );
                          }
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryStat(String title, dynamic value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value is double
              ? 'Rs. ${value.toStringAsFixed(2)}'
              : value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _quickActionsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: [
          _quickAction(
            Icons.arrow_downward,
            "Add Income",
            Colors.green,
            () => _showAddTransactionDialog(context, 'Income'),
          ),
          const SizedBox(width: 15),
          _quickAction(
            Icons.arrow_upward,
            "Add Expense",
            Colors.red,
            () => _showAddTransactionDialog(context, 'Expense'),
          ),
          const SizedBox(width: 15),
          _quickAction(
            Icons.trending_up,
            "Add Investment",
            Colors.purple,
            () => _showAddInvestmentDialog(),
          ),
        ],
      ),
    );
  }

  // Updated _quickAction to accept an onTap function
  Widget _quickAction(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentTransactions() {
    if (_currentUserId.isEmpty) {
      // Show loading indicator until the user profile/ID is fetched
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: CircularProgressIndicator(color: _kPrimaryColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Transactions",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: SupabaseService.streamTransactions(_currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: CircularProgressIndicator(color: _kPrimaryColor),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading data: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No recent transactions found. Add one now!',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  );
                }

                final transactions = snapshot.data!;
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return GestureDetector(
                      onTap: () => _showEditTransactionDialog(context, tx),
                      onLongPress: () => _confirmDeleteTransaction(tx),
                      child: _transactionTile(tx),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget for individual transaction row
  Widget _transactionTile(Transaction tx) {
    final isIncome = tx.type == "Income";
    final color = isIncome ? Colors.greenAccent : Colors.redAccent;
    final symbol = isIncome ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        tileColor: Colors.transparent,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(tx.icon, color: color),
        ),
        title: Text(
          tx.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(tx.type, style: TextStyle(color: Colors.grey.shade500)),
        trailing: Text(
          "$symbol Rs. ${tx.amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showEditTransactionDialog(BuildContext context, Transaction tx) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: tx.title);
    final amountController = TextEditingController(text: tx.amount.toString());
    String currentIconName = tx.iconName ?? 'shopping_bag';
    String currentType = tx.type;

    final Map<String, IconData> availableIcons = {
      'payments': Icons.payments,
      'work': Icons.work,
      'shopping_bag': Icons.shopping_bag,
      'fastfood': Icons.fastfood,
      'local_gas_station': Icons.local_gas_station,
      'attach_money': Icons.attach_money,
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              backgroundColor: _kCardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Transaction',
                style: TextStyle(color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          'Title / Description',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: amountController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Amount (Rs.)'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null ||
                              double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Please enter a valid positive amount.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Icon Selector
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kDarkBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Icon:',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: availableIcons.entries.map((entry) {
                                final isSelected = entry.key == currentIconName;
                                return GestureDetector(
                                  onTap: () {
                                    setStateSB(() {
                                      currentIconName = entry.key;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _kPrimaryColor
                                          : _kCardBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      entry.value,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Type Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Income'),
                            selected: currentType == 'Income',
                            onSelected: (selected) {
                              setStateSB(() {
                                currentType = 'Income';
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('Expense'),
                            selected: currentType == 'Expense',
                            onSelected: (selected) {
                              setStateSB(() {
                                currentType = 'Expense';
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop();
                      final title = titleController.text.trim();
                      final amount = double.parse(amountController.text);
                      try {
                        await SupabaseService.updateTransaction(
                          transactionId: tx.id,
                          userId: tx.userId,
                          title: title,
                          amount: amount,
                          type: currentType,
                          iconName: currentIconName,
                        );
                        _showSnackBar('Transaction updated!', isError: false);
                      } catch (e) {
                        _showSnackBar(
                          'Failed to update: \\${e.toString()}',
                          isError: true,
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTransaction(Transaction tx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _kCardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Transaction',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete this transaction?',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await SupabaseService.deleteTransaction(
                    transactionId: tx.id,
                    userId: tx.userId,
                  );
                  _showSnackBar('Transaction deleted!', isError: false);
                } catch (e) {
                  _showSnackBar(
                    'Failed to delete: \\${e.toString()}',
                    isError: true,
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
