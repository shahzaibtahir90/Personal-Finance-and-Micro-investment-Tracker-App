import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
export 'package:flutter/material.dart' show RouteObserver, PageRoute;
import 'profile.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Define theme colors for consistency
const _kPrimaryColor = Color(0xFF3B82F6);
const _kDarkBackground = Color(0xff111111);
const _kCardBackground = Color(0xff1e1e1e);
const _kAppBarColor = Color(0xff1a1a1a);

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with RouteAware {
  void _showEditExpenseDialog(Map<String, dynamic> expense) {
    final categoryController = TextEditingController(
      text: expense["category"] ?? "",
    );
    final amountController = TextEditingController(
      text: expense["amount"]?.toString() ?? "",
    );
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate =
        DateTime.tryParse(expense["date"] ?? "") ?? DateTime.now();

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
                "Edit Expense",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: categoryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration("Category"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: amountController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _buildInputDecoration("Amount (Rs.)"),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
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
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setStateSB(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kDarkBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: _kPrimaryColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                selectedDate.toString().split(' ')[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      final category = categoryController.text.trim();
                      final amount = double.parse(amountController.text);
                      try {
                        await SupabaseService.updateExpense(
                          expenseId: expense["id"] as int,
                          userId: _currentUserId,
                          category: category,
                          amount: amount,
                          date: selectedDate,
                        );
                        _showSnackBar('Expense updated!');
                        _fetchUserAndExpenses();
                      } catch (e) {
                        _showSnackBar(
                          'Failed to update: ${e.toString()}',
                          isError: true,
                        );
                      }
                    }
                  },
                  child: const Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteExpense(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _kCardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Expense',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete this expense?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await SupabaseService.deleteExpense(
                    expenseId: expense["id"] as int,
                    userId: _currentUserId,
                  );
                  _showSnackBar('Expense deleted!');
                  _fetchUserAndExpenses();
                } catch (e) {
                  _showSnackBar(
                    'Failed to delete: ${e.toString()}',
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

  List<Map<String, dynamic>> expenses = [];
  bool _isLoading = true;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _fetchUserAndExpenses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final ModalRoute? modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when coming back to this screen
    _fetchUserAndExpenses();
  }

  // ...existing code...

  Future<void> _fetchUserAndExpenses() async {
    setState(() => _isLoading = true);
    try {
      // Only fetch user profile if we don't already have the user ID
      if (_currentUserId.isEmpty) {
        final profile = await SupabaseService.fetchUserProfile();
        _currentUserId = profile['id'] ?? '';
      }
      if (_currentUserId.isNotEmpty) {
        final data = await SupabaseService.fetchExpenses(_currentUserId);
        setState(() {
          expenses = data;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading expenses: ${e.toString()}', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBackground,
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text('Expenses', style: TextStyle(fontSize: 25)),
        ),
        backgroundColor: _kAppBarColor,
        foregroundColor: Colors.white,
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
                    if (mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
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
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUserAndExpenses,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _kPrimaryColor),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return Card(
                    color: _kCardBackground,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.money_off,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        expense["category"] ?? "Expense",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        "Date: ${expense["date"]?.toString().split(' ')[0] ?? 'N/A'}",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Rs. ${expense["amount"]?.toStringAsFixed(2) ?? '0.00'}",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Edit',
                            onPressed: () => _showEditExpenseDialog(expense),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            tooltip: 'Delete',
                            onPressed: () => _confirmDeleteExpense(expense),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kPrimaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showAddExpenseDialog(),
      ),
    );
  }

  // Show dialog to add new expense
  void _showAddExpenseDialog() {
    if (_currentUserId.isEmpty) {
      _showSnackBar("Cannot add expense: User ID not found.", isError: true);
      return;
    }

    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();

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
                "Add Expense",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: categoryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration("Category"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: amountController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _buildInputDecoration("Amount (Rs.)"),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
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
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setStateSB(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kDarkBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: _kPrimaryColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                selectedDate.toString().split(' ')[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context);

                      final category = categoryController.text.trim();
                      final amount = double.parse(amountController.text);

                      try {
                        await SupabaseService.addExpense(
                          userId: _currentUserId,
                          category: category,
                          amount: amount,
                          date: selectedDate,
                        );
                        _showSnackBar('Expense added successfully!');
                        _fetchUserAndExpenses();
                      } catch (e) {
                        _showSnackBar(
                          'Failed to add expense: ${e.toString()}',
                          isError: true,
                        );
                      }
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
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
}
