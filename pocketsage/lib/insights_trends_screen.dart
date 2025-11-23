import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class InsightsTrendsScreen extends StatefulWidget {
  const InsightsTrendsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsTrendsScreen> createState() => _InsightsTrendsScreenState();
}

class _InsightsTrendsScreenState extends State<InsightsTrendsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _insightsData;
  bool _isLoading = true;
  String _selectedPeriod = 'monthly';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInsightsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInsightsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user ID from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'testuser123'; // Fallback to test user if no current user
      
      final testParams = {
        "user_id": userId,
        "period": _selectedPeriod
      };

      // Use the same endpoint as in the test file (but with Android emulator IP)
      final uri = Uri.parse('http://10.0.2.2:8080/budget_insights')
          .replace(queryParameters: testParams);

      print('Fetching insights from: $uri');
      print('Using test parameters: $testParams');

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _insightsData = data;
          _isLoading = false;
        });
        
        // Show success message if data is loaded successfully
        if (data['success'] == true) {
          _showSuccessSnackBar('Insights loaded successfully!');
        }
      } else {
        setState(() {
          _insightsData = null;
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load insights data: ${response.statusCode}');
        
        // Load sample data for testing if API fails
        _loadSampleData();
      }
    } catch (e) {
      print('Error fetching insights: $e');
      setState(() {
        _insightsData = null;
        _isLoading = false;
      });
      
      if (e.toString().contains('TimeoutException')) {
        _showErrorSnackBar('Request timed out. Please check your connection and try again.');
      } else {
        _showErrorSnackBar('Error loading insights: $e');
      }
      
      // Load sample data for testing if API fails
      _loadSampleData();
    }
  }

  void _loadSampleData() {
    // Get current user ID for sample data
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'testuser123';
    
    setState(() {
      _insightsData = {
        "success": true,
        "message": "Budget insights generated for ${_selectedPeriod} period",
        "period": _selectedPeriod,
        "user_id": userId,
        "summary": {
          "total_spending": 700.0,
          "receipt_count": 8,
          "message_expenses_count": 2,
          "avg_daily_spending": _selectedPeriod == 'weekly' ? 100.0 : 23.33,
          "max_daily_spending": 150.0,
          "period_days": _selectedPeriod == 'weekly' ? 7 : 30
        },
        "category_breakdown": {
          "food": {
            "total": 250.0,
            "count": 3,
            "average": 83.33,
            "percentage": 35.7
          },
          "transportation": {
            "total": 150.0,
            "count": 2,
            "average": 75.0,
            "percentage": 21.4
          },
          "entertainment": {
            "total": 100.0,
            "count": 1,
            "average": 100.0,
            "percentage": 14.3
          },
          "shopping": {
            "total": 200.0,
            "count": 2,
            "average": 100.0,
            "percentage": 28.6
          }
        },
        "message_expenses": {
          "dining": 300.0,
          "transport": 100.0
        },
        "daily_spending": {
          "2025-01-26": 50.0,
          "2025-01-25": 75.0,
          "2025-01-24": 100.0,
          "2025-01-23": 125.0,
          "2025-01-22": 150.0,
          "2025-01-21": 100.0,
          "2025-01-20": 100.0
        },
        "insights": {
          "top_spending_category": "food",
          "biggest_expense": "Food expenses totaled ₹250 across 3 receipts, averaging ₹83.33 per transaction",
          "savings_opportunities": [
            "Consider meal planning to reduce food expenses",
            "Look for grocery store discounts and coupons",
            "Try cooking more meals at home instead of dining out"
          ],
          "spending_trends": "Your spending is well-distributed across multiple categories, with food being your highest expense at 35.7% of total spending",
          "budget_recommendations": [
            "Set a monthly food budget of ₹300 to control spending",
            "Track your dining expenses separately from grocery expenses",
            "Review your entertainment and shopping budgets"
          ],
          "alert_level": "medium",
          "next_month_prediction": "Based on current spending patterns, expect to spend around ₹700 next month across all categories"
        },
        "date_range": {
          "start_date": _selectedPeriod == 'weekly' ? "2025-01-20" : "2024-12-28",
          "end_date": "2025-01-27"
        }
      };
      _isLoading = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _fetchInsightsData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Insights & Trends',
          style: TextStyle(
            color: Color(0xFF2D223A),
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF826695)),
                 bottom: PreferredSize(
           preferredSize: const Size.fromHeight(120),
           child: Column(
             children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 child: Row(
                   children: [
                     Expanded(
                       child: _buildPeriodSelector(),
                     ),
                     const SizedBox(width: 16),
                     IconButton(
                       onPressed: _fetchInsightsData,
                       icon: const Icon(Icons.refresh_rounded, color: Color(0xFF826695)),
                       tooltip: 'Refresh',
                     ),
                   ],
                 ),
               ),
               Container(
                 color: Colors.white,
                 child: TabBar(
                   controller: _tabController,
                   labelColor: const Color(0xFF826695),
                   unselectedLabelColor: const Color(0xFF826695),
                   indicatorColor: const Color(0xFF826695),
                   indicatorWeight: 3,
                   tabs: const [
                     Tab(text: 'Overview'),
                     Tab(text: 'Spending'),
                     Tab(text: 'Recommendations'),
                   ],
                 ),
               ),
             ],
           ),
         ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF826695)),
                  const SizedBox(height: 16),
                  Text(
                    'Analyzing your spending data...',
                    style: const TextStyle(
                      color: Color(0xFF826695),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a few moments',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _insightsData == null
              ? _buildErrorState()
              : _buildInsightsContent(),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEAF6)),
      ),
      child: Row(
        children: [
          _buildPeriodButton('weekly', 'Week'),
          _buildPeriodButton('monthly', 'Month'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onPeriodChanged(period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF826695) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF826695),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load insights',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchInsightsData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF826695),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildSpendingTab(),
        _buildRecommendationsTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final summary = _insightsData?['summary'] ?? {};
    final insights = _insightsData?['insights'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(summary),
          const SizedBox(height: 24),
          _buildInsightsSection(insights),
          const SizedBox(height: 24),
          _buildAlertCard(insights),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D223A),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Spending',
                '₹${summary['total_spending']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.account_balance_wallet_rounded,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Receipts',
                '${summary['receipt_count'] ?? 0}',
                Icons.receipt_rounded,
                const Color(0xFF2196F3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Avg Daily',
                '₹${summary['avg_daily_spending']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.trending_up_rounded,
                const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Max Daily',
                '₹${summary['max_daily_spending']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.show_chart_rounded,
                const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(Map<String, dynamic> insights) {
    final topCategory = insights['top_spending_category'] ?? 'N/A';
    final biggestExpense = insights['biggest_expense'] ?? 'N/A';
    final spendingTrends = insights['spending_trends'] ?? 'N/A';
    
    // Handle special cases for top category
    String getDisplayCategory(String category) {
      if (category.toLowerCase() == 'unknown' || category.toLowerCase() == 'no_spending') {
        return 'No spending data';
      }
      if (category.toLowerCase() == 'miscellaneous') {
        return 'Miscellaneous';
      }
      return category[0].toUpperCase() + category.substring(1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Insights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D223A),
          ),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          'Top Spending Category',
          getDisplayCategory(topCategory),
          Icons.category_rounded,
          const Color(0xFF9C27B0),
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          'Biggest Expense',
          biggestExpense,
          Icons.payments_rounded,
          const Color(0xFFF44336),
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          'Spending Trend',
          spendingTrends,
          Icons.trending_up_rounded,
          const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEAF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF826695),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D223A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> insights) {
    final alertLevel = insights['alert_level'] ?? 'medium';
    final topCategory = insights['top_spending_category'] ?? '';
    Color alertColor;
    String alertMessage;
    
    switch (alertLevel.toLowerCase()) {
      case 'high':
        alertColor = const Color(0xFFF44336);
        alertMessage = 'High spending alert! Consider reviewing your budget and reducing expenses.';
        break;
      case 'medium':
        alertColor = const Color(0xFFFF9800);
        alertMessage = 'Moderate spending level. Keep an eye on your expenses and stay within budget.';
        break;
      case 'low':
        alertColor = const Color(0xFF4CAF50);
        alertMessage = 'Good spending control! Keep up the good work.';
        break;
      default:
        alertColor = const Color(0xFF4CAF50);
        alertMessage = 'Good spending control! Keep up the good work.';
    }
    
    // Add specific message for no spending data
    if (topCategory.toLowerCase() == 'no_spending' || topCategory.toLowerCase() == 'unknown') {
      alertColor = const Color(0xFF607D8B);
      alertMessage = 'No spending data available. Start tracking your expenses to get insights.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: alertColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alertMessage,
              style: TextStyle(
                color: alertColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTab() {
    final categoryBreakdown = _insightsData?['category_breakdown'] ?? {};
    final messageExpenses = _insightsData?['message_expenses'] ?? {};
    final dailySpending = _insightsData?['daily_spending'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySpendingChart(categoryBreakdown),
          const SizedBox(height: 24),
          _buildMessageExpensesChart(messageExpenses),
          const SizedBox(height: 24),
          _buildDailySpendingChart(dailySpending),
        ],
      ),
    );
  }

  Widget _buildCategorySpendingChart(Map<String, dynamic> categoryBreakdown) {
    if (categoryBreakdown.isEmpty) {
      return _buildEmptyState('No spending data available');
    }

    final categories = categoryBreakdown.keys.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending by Category',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D223A),
          ),
        ),
        const SizedBox(height: 16),
                 ...categories.map((category) {
           final data = categoryBreakdown[category] as Map<String, dynamic>;
           final total = (data['total'] ?? 0.0).toDouble();
           final percentage = (data['percentage'] ?? 0.0).toDouble();
           
           return _buildCategoryBar(category, total, percentage);
         }).toList(),
      ],
    );
  }

  Widget _buildCategoryBar(String category, double total, double percentage) {
    // Get category color based on category name
    Color getCategoryColor(String cat) {
      switch (cat.toLowerCase()) {
        case 'food':
        case 'dining':
        case 'groceries':
          return const Color(0xFF4CAF50);
        case 'transportation':
        case 'transport':
        case 'travel':
          return const Color(0xFF2196F3);
        case 'entertainment':
        case 'leisure':
          return const Color(0xFF9C27B0);
        case 'shopping':
        case 'retail':
          return const Color(0xFFFF9800);
        case 'healthcare':
        case 'medical':
          return const Color(0xFFF44336);
        case 'utilities':
        case 'bills':
          return const Color(0xFF607D8B);
        case 'housing':
        case 'rent':
          return const Color(0xFF795548);
        case 'miscellaneous':
        case 'other':
          return const Color(0xFF9E9E9E);
        default:
          return const Color(0xFF826695);
      }
    }

    final categoryColor = getCategoryColor(category);
    final displayName = category == 'miscellaneous' ? 'Miscellaneous' : 
                       category == 'unknown' ? 'Miscellaneous' :
                       category[0].toUpperCase() + category.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D223A),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF826695),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEAF6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percentage / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageExpensesChart(Map<String, dynamic> messageExpenses) {
    if (messageExpenses.isEmpty) {
      return _buildEmptyState('No message expenses available');
    }

    final totalMessageExpenses = messageExpenses.values
        .map((value) => (value ?? 0.0).toDouble())
        .reduce((a, b) => a + b);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message Expenses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D223A),
          ),
        ),
        const SizedBox(height: 16),
        ...messageExpenses.entries.map((entry) {
          final category = entry.key;
          final amount = (entry.value ?? 0.0).toDouble();
          final percentage = totalMessageExpenses > 0 ? (amount / totalMessageExpenses * 100) : 0.0;
          
          return _buildCategoryBar(category, amount, percentage);
        }).toList(),
      ],
    );
  }

  Widget _buildDailySpendingChart(Map<String, dynamic> dailySpending) {
    if (dailySpending.isEmpty) {
      return _buildEmptyState('No daily spending data available');
    }

    final sortedDays = dailySpending.keys.toList()..sort();
    final maxSpending = dailySpending.values
        .map((value) => (value ?? 0.0).toDouble())
        .reduce((a, b) => a > b ? a : b);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Spending Trend',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D223A),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDEAF6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                         children: sortedDays.map((day) {
               final spending = (dailySpending[day] ?? 0.0).toDouble();
               final height = maxSpending > 0 ? (spending / maxSpending) : 0.0;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '₹${spending.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF826695),
                    ),
                  ),
                  const SizedBox(height: 4),
                                     Container(
                     width: 20,
                     height: (120 * height).toDouble(),
                     decoration: BoxDecoration(
                       color: const Color(0xFF826695),
                       borderRadius: BorderRadius.circular(4),
                     ),
                   ),
                  const SizedBox(height: 4),
                  Text(
                    day.split('-').last,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF826695),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsTab() {
    final insights = _insightsData?['insights'] ?? {};
    final savingsOpportunities = insights['savings_opportunities'] ?? [];
    final budgetRecommendations = insights['budget_recommendations'] ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecommendationsSection(
            'Savings Opportunities',
            savingsOpportunities,
            Icons.savings_rounded,
            const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 24),
          _buildRecommendationsSection(
            'Budget Recommendations',
            budgetRecommendations,
            Icons.account_balance_wallet_rounded,
            const Color(0xFF2196F3),
          ),
          const SizedBox(height: 24),
          _buildPredictionCard(insights),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(
    String title,
    List<dynamic> recommendations,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recommendations.isEmpty)
          _buildEmptyState('No recommendations available')
        else
          ...recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final recommendation = entry.value;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendation.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D223A),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> insights) {
    final prediction = insights['next_month_prediction'] ?? 'Unable to predict';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF826695).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF826695).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                color: Color(0xFF826695),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Next Month Prediction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF826695),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prediction,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2D223A),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 