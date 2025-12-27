import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../models/investment.dart';
import 'profile.dart';

// Define theme colors for consistency
const _kPrimaryColor = Color(0xFF3B82F6);
const _kDarkBackground = Color(0xff111111);
const _kCardBackground = Color(0xff1e1e1e);
const _kAppBarColor = Color(0xff1a1a1a);

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Investment> investments = [];
  bool _isLoading = true;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserAndInvestments();
  }

  Future<void> _fetchUserAndInvestments() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.fetchUserProfile();
      _currentUserId = profile['id'] ?? '';
      if (_currentUserId.isNotEmpty) {
        final data = await SupabaseService.fetchInvestments(_currentUserId);
        setState(() {
          investments = data;
        });
      }
    } catch (e) {
      _showSnackBar(
        'Error loading investments: ${e.toString()}',
        isError: true,
      );
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

  void _showAddInvestmentDialog() {
    if (_currentUserId.isEmpty) {
      _showSnackBar("Cannot add investment: User ID not found.", isError: true);
      return;
    }

    final investmentTypeController = TextEditingController();
    final amountController = TextEditingController();
    final rateController = TextEditingController();
    final periodController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Add Investment",
          style: TextStyle(fontSize: 20, color: Colors.white),
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
                  decoration: _buildInputDecoration("Investment Type"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter investment type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: rateController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _buildInputDecoration("Rate of Return (%)"),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  validator: (value) {
                    if (value == null || double.tryParse(value) == null) {
                      return 'Please enter a valid rate';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: periodController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration("Time Period (months)"),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter period';
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

                final investmentType = investmentTypeController.text.trim();
                final amount = double.parse(amountController.text);
                final rate = double.parse(rateController.text);
                final period = periodController.text.trim();
                final profit = amount * (int.parse(period)) * rate / 100;

                try {
                  await SupabaseService.addInvestment(
                    userId: _currentUserId,
                    investmentType: investmentType,
                    amount: amount,
                    rate: rate,
                    period: period,
                    profit: profit,
                  );
                  _showSnackBar('Investment added successfully!');
                  _fetchUserAndInvestments();
                } catch (e) {
                  _showSnackBar(
                    'Failed to add investment: ${e.toString()}',
                    isError: true,
                  );
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBackground,
      appBar: AppBar(
        title: const Text(
          "Investments",
          style: TextStyle(fontSize: 25, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kPrimaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "My Investments", icon: Icon(Icons.trending_up)),
            Tab(text: "Calculator", icon: Icon(Icons.calculate)),
          ],
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _kPrimaryColor),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Investments Tab
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: investments.isEmpty
                      ? Center(
                          child: Text(
                            "No investments added yet.",
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        )
                      : ListView.builder(
                          itemCount: investments.length,
                          itemBuilder: (context, index) {
                            final inv = investments[index];
                            return Card(
                              color: _kCardBackground,
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 0,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.trending_up,
                                  color: Colors.greenAccent,
                                ),
                                title: Text(
                                  inv.investmentType,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Amount: Rs. ${inv.amount.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    Text(
                                      "Rate: ${inv.rate.toStringAsFixed(2)}% • Period: ${inv.period}",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Profit",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    Text(
                                      "Rs. ${inv.profit.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Delete Investment',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Delete Investment',
                                            ),
                                            content: const Text(
                                              'Are you sure you want to delete this investment?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await SupabaseService.deleteInvestment(
                                              investmentId: inv.id,
                                              userId: _currentUserId,
                                            );
                                            _showSnackBar(
                                              'Investment deleted successfully!',
                                              isError: false,
                                            );
                                            await _fetchUserAndInvestments();
                                          } catch (e) {
                                            _showSnackBar(
                                              'Failed to delete investment: \\${e.toString()}',
                                              isError: true,
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Calculator Tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CalculatorTab(),
                ),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showAddInvestmentDialog,
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
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

// Calculator Tab Widget
class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  final amountController = TextEditingController();
  final periodController = TextEditingController();
  final rateController = TextEditingController();

  double profit = 0.0;

  void calculate() {
    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
    final period = double.tryParse(periodController.text.trim()) ?? 0.0;
    final rate = double.tryParse(rateController.text.trim()) ?? 0.0;

    setState(() {
      profit = amount * period * rate / 100;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: amountController,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Investment Amount (Rs.)",
              labelStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: _kCardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kPrimaryColor, width: 2),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: periodController,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Time Period (months)",
              labelStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: _kCardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kPrimaryColor, width: 2),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: rateController,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Expected Rate (%)",
              labelStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: _kCardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kPrimaryColor, width: 2),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: calculate,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            child: const Text(
              "Calculate Profit",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kPrimaryColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  "Estimated Profit",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Text(
                  "Rs. ${profit.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    periodController.dispose();
    rateController.dispose();
    super.dispose();
  }
}
