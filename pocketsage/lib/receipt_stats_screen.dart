import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class ReceiptStatsScreen extends StatefulWidget {
  const ReceiptStatsScreen({super.key});

  @override
  State<ReceiptStatsScreen> createState() => _ReceiptStatsScreenState();
}

class _ReceiptStatsScreenState extends State<ReceiptStatsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _statsData;
  Map<String, dynamic>? _receiptsData;
  bool _isLoading = true;
  bool _isReceiptsLoading = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _selectedCategory;
  String? _selectedFilter;
  int _currentPage = 0;
  bool _hasMoreReceipts = true;

  // Colors for different categories using theme colors
  final Map<String, Color> _categoryColors = {
    'groceries': const Color(0xFF4CAF50),
    'utilities': const Color(0xFFFF9800),
    'transportation': const Color(0xFF2196F3),
    'dining': const Color(0xFFE91E63),
    'travel': const Color(0xFFE74C3C),
    'reimbursement': const Color(0xFF4A90E2),
    'home': const Color(0xFF7ED321),
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchReceiptStats();
    _fetchReceipts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchReceiptStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'User not signed in';
        _isLoading = false;
      });
      return;
    }

    try {
      final uri = Uri.parse('http://10.0.2.2:8080/receipt_stats')
          .replace(queryParameters: {'user_id': user.uid});
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _statsData = data;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _error = 'Failed to load receipt statistics: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchReceipts({bool refresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user signed in');
      return;
    }

    print('Fetching receipts for user: ${user.uid}');
    print('Selected filter: $_selectedFilter');
    print('Current page: $_currentPage');

    setState(() {
      _isReceiptsLoading = true;
    });

    try {
      final params = {
        'user_id': user.uid,
        'limit': 20,
        'offset': refresh ? 0 : _currentPage * 20,
        'sort_by': 'timestamp',
        'sort_order': 'desc',
      };

      if (_selectedFilter != null) {
        params['category'] = _selectedFilter!;
      }

      final uri = Uri.parse('http://10.0.2.2:8080/list_receipts')
          .replace(queryParameters: params);
      
      print('API URL: $uri');
      
      final response = await http.get(uri);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Parsed data: $data');
        
        setState(() {
          if (refresh) {
            _receiptsData = data;
            _currentPage = 0;
          } else {
            // Append new receipts to existing list
            final existingReceipts = _receiptsData?['receipts'] ?? [];
            final newReceipts = data['receipts'] ?? [];
            _receiptsData = {
              ...data,
              'receipts': [...existingReceipts, ...newReceipts],
            };
            _currentPage++;
          }
          _hasMoreReceipts = data['pagination']?['has_more'] ?? false;
          _isReceiptsLoading = false;
        });
        
        print('Total receipts loaded: ${(_receiptsData?['receipts'] as List?)?.length ?? 0}');
      } else {
        print('Error response: ${response.body}');
        setState(() {
          _isReceiptsLoading = false;
        });
      }
    } catch (e) {
      print('Exception fetching receipts: $e');
      setState(() {
        _isReceiptsLoading = false;
      });
    }
  }

  Future<void> _testWithKnownUser() async {
    print('Testing with known user ID: testuser123');
    
    setState(() {
      _isReceiptsLoading = true;
    });

    try {
      final params = {
        'user_id': 'testuser123',
        'limit': 20,
        'offset': 0,
        'sort_by': 'timestamp',
        'sort_order': 'desc',
      };

      final uri = Uri.parse('http://10.0.2.2:8080/list_receipts')
          .replace(queryParameters: params);
      
      print('Test API URL: $uri');
      
      final response = await http.get(uri);
      print('Test Response status: ${response.statusCode}');
      print('Test Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Test Parsed data: $data');
        
        setState(() {
          _receiptsData = data;
          _currentPage = 0;
          _hasMoreReceipts = data['pagination']?['has_more'] ?? false;
          _isReceiptsLoading = false;
        });
        
        print('Test Total receipts loaded: ${(_receiptsData?['receipts'] as List?)?.length ?? 0}');
      } else {
        print('Test Error response: ${response.body}');
        setState(() {
          _isReceiptsLoading = false;
        });
      }
    } catch (e) {
      print('Test Exception fetching receipts: $e');
      setState(() {
        _isReceiptsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF826695), size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.refresh_rounded, color: Color(0xFF826695), size: 20),
                ),
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                    _selectedCategory = null;
                    _selectedFilter = null;
                    _currentPage = 0;
                  });
                  _fetchReceiptStats();
                  _fetchReceipts(refresh: true);
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Receipt Analytics',
                style: TextStyle(
                  color: Color(0xFF2D223A),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Montserrat',
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: _isLoading
                ? Container(
                    height: 400,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF826695),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading your receipt data...',
                            style: TextStyle(
                              color: Color(0xFF826695),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _error != null
                    ? _buildErrorWidget()
                    : _buildStatsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF826695).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: const Color(0xFF826695),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D223A),
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF826695).withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchReceiptStats,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF826695),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    if (_statsData == null) return const SizedBox.shrink();

    final totalReceipts = _statsData!['total_receipts'] ?? 0;
    final categoryBreakdown = _statsData!['category_breakdown'] ?? {};

    // Filter out categories with 0 receipts
    final nonZeroCategories = Map<String, int>.from(categoryBreakdown)
      ..removeWhere((key, value) => value == 0);

    if (nonZeroCategories.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          _buildHeaderSection(totalReceipts),
          const SizedBox(height: 24),
          
          // Chart Section
          _buildChartSection(nonZeroCategories),
          const SizedBox(height: 24),
          
          // Categories Section
          _buildCategoriesSection(nonZeroCategories),
          const SizedBox(height: 24),
          
          // Receipts List Section
          _buildReceiptsListSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF826695).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 50,
                color: const Color(0xFF826695),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Receipts Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D223A),
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start uploading receipts to see your spending analytics and insights',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF826695).withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Upload Receipts',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF826695),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(int totalReceipts) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF826695),
            Color(0xFF9B7BB8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF826695).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Receipts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalReceipts',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Analytics Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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

  Widget _buildChartSection(Map<String, int> categories) {
    final total = categories.values.fold<int>(0, (sum, count) => sum + count);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF826695).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFF826695),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Category Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D223A),
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF826695).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return GestureDetector(
                    onTapUp: (details) {
                      _handleChartTap(details, categories, total);
                    },
                    child: CustomPaint(
                      size: const Size(220, 220),
                      painter: PieChartPainter(
                        categories: categories,
                        total: total,
                        animation: _animation.value,
                        categoryColors: _categoryColors,
                        selectedCategory: _selectedCategory,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _categoryColors[_selectedCategory!]?.withOpacity(0.1) ?? const Color(0xFF826695).withOpacity(0.1),
                    _categoryColors[_selectedCategory!]?.withOpacity(0.05) ?? const Color(0xFF826695).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _categoryColors[_selectedCategory!]?.withOpacity(0.3) ?? const Color(0xFF826695).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _categoryColors[_selectedCategory!] ?? const Color(0xFF826695),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCategoryDisplayName(_selectedCategory!),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D223A),
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${categories[_selectedCategory!]} receipts',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF826695).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _categoryColors[_selectedCategory!] ?? const Color(0xFF826695),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${((categories[_selectedCategory!]! / total) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(Map<String, int> categories) {
    final total = categories.values.fold<int>(0, (sum, count) => sum + count);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF826695).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Color(0xFF826695),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Category Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D223A),
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...categories.entries.map((entry) {
            final category = entry.key;
            final count = entry.value;
            final percentage = total > 0 ? (count / total * 100) : 0.0;
            final color = _categoryColors[category] ?? const Color(0xFF826695);
            final isSelected = _selectedCategory == category;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = isSelected ? null : category;
                  _selectedFilter = isSelected ? null : category;
                });
                _fetchReceipts(refresh: true);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? color.withOpacity(0.1) 
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected 
                      ? Border.all(color: color, width: 2)
                      : Border.all(color: const Color(0xFFEDEAF6), width: 1),
                ),
                child: Row(
                  children: [
                    // Color indicator
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Category info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCategoryDisplayName(category),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : const Color(0xFF2D223A),
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count receipts',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF826695).withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Percentage badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? color : const Color(0xFF826695),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _handleChartTap(TapUpDetails details, Map<String, int> categories, int total) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    // Calculate the center and radius of the pie chart (220x220)
    final center = const Offset(110, 110); // Half of 220x220
    final radius = 88.0; // 80% of 110
    
    // Calculate distance from center
    final distance = (localPosition - center).distance;
    
    if (distance <= radius) {
      // Calculate angle from center
      final angle = math.atan2(localPosition.dy - center.dy, localPosition.dx - center.dx);
      // Convert to positive angle starting from top
      double normalizedAngle = (-angle + math.pi / 2) % (2 * math.pi);
      if (normalizedAngle < 0) normalizedAngle += 2 * math.pi;
      
      // Find which category this angle corresponds to
      double currentAngle = 0;
      for (final entry in categories.entries) {
        final category = entry.key;
        final count = entry.value;
        final sweepAngle = (count / total) * 2 * math.pi;
        
        if (normalizedAngle >= currentAngle && normalizedAngle <= currentAngle + sweepAngle) {
          setState(() {
            _selectedCategory = _selectedCategory == category ? null : category;
          });
          break;
        }
        currentAngle += sweepAngle;
      }
    }
  }

  Widget _buildReceiptsListSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF826695).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF826695),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Raw Receipts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D223A),
                  fontFamily: 'Montserrat',
                ),
              ),
              const Spacer(),
              if (_selectedFilter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _categoryColors[_selectedFilter!]?.withOpacity(0.1) ?? const Color(0xFF826695).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _categoryColors[_selectedFilter!] ?? const Color(0xFF826695),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _categoryColors[_selectedFilter!] ?? const Color(0xFF826695),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getCategoryDisplayName(_selectedFilter!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _categoryColors[_selectedFilter!] ?? const Color(0xFF826695),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_receiptsData == null || (_receiptsData!['receipts'] as List).isEmpty)
            _buildEmptyReceiptsState()
          else
            _buildReceiptsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyReceiptsState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: const Color(0xFF826695).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter != null 
                ? 'No receipts in ${_getCategoryDisplayName(_selectedFilter!)} category'
                : 'No receipts found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF826695).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Debug information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDF8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Debug Info:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF826695),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'User ID: ${FirebaseAuth.instance.currentUser?.uid ?? 'Not signed in'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF826695).withOpacity(0.8),
                  ),
                ),
                Text(
                  'Receipts Data: ${_receiptsData != null ? 'Loaded' : 'Not loaded'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF826695).withOpacity(0.8),
                  ),
                ),
                Text(
                  'Receipts Count: ${(_receiptsData?['receipts'] as List?)?.length ?? 0}',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF826695).withOpacity(0.8),
                  ),
                ),
                Text(
                  'Selected Filter: ${_selectedFilter ?? 'None'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF826695).withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Test with the known working user ID
                    _testWithKnownUser();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF826695),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Test with testuser123'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList() {
    final receipts = _receiptsData!['receipts'] as List;
    
    return Column(
      children: [
        ...receipts.map((receipt) => _buildReceiptCard(receipt)).toList(),
        if (_hasMoreReceipts) ...[
          const SizedBox(height: 16),
          Center(
            child: _isReceiptsLoading
                ? const CircularProgressIndicator(
                    color: Color(0xFF826695),
                    strokeWidth: 2,
                  )
                : ElevatedButton(
                    onPressed: () => _fetchReceipts(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF826695),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Load More'),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final receiptId = receipt['receipt_id'] ?? 'Unknown ID';
    final userId = receipt['user_id'] ?? 'Unknown User';
    final timestamp = receipt['timestamp'] ?? '';
    final mediaUrl = receipt['media_url'];
    final status = receipt['status'] ?? 'unknown';
    final fileName = receipt['file_name'] ?? 'Unknown File';
    final mediaType = receipt['media_type'] ?? 'Unknown Type';
    
    // Parse timestamp
    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(timestamp);
    } catch (e) {
      dateTime = null;
    }
    
    final formattedDate = dateTime != null 
        ? '${dateTime.day}/${dateTime.month}/${dateTime.year}'
        : 'Unknown Date';
    
    final formattedTime = dateTime != null 
        ? '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'
        : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDEAF6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with receipt ID and status
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF826695),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt ID: $receiptId',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D223A),
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    Text(
                      'User ID: $userId',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF826695).withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'parsed' 
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : const Color(0xFFFF9800).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: status == 'parsed' 
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // File information
          Row(
            children: [
              Icon(
                Icons.file_present_rounded,
                size: 16,
                color: const Color(0xFF826695).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'File: $fileName',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF826695).withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // Media type
          Row(
            children: [
              Icon(
                Icons.image_rounded,
                size: 16,
                color: const Color(0xFF826695).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'Type: $mediaType',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF826695).withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // Timestamp
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: const Color(0xFF826695).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                '$formattedDate $formattedTime',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF826695).withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          // Media URL (if available)
          if (mediaUrl != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF826695).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEDEAF6),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_rounded,
                            size: 32,
                            color: const Color(0xFF826695).withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF826695).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'groceries':
        return 'Groceries';
      case 'utilities':
        return 'Utilities';
      case 'transportation':
        return 'Transportation';
      case 'dining':
        return 'Dining';
      case 'travel':
        return 'Travel';
      case 'reimbursement':
        return 'Reimbursement';
      case 'home':
        return 'Home';
      default:
        return category[0].toUpperCase() + category.substring(1);
    }
  }
}

class PieChartPainter extends CustomPainter {
  final Map<String, int> categories;
  final int total;
  final double animation;
  final Map<String, Color> categoryColors;
  final String? selectedCategory;

  PieChartPainter({
    required this.categories,
    required this.total,
    required this.animation,
    required this.categoryColors,
    this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;
    
    double startAngle = -math.pi / 2; // Start from top
    
    for (final entry in categories.entries) {
      final category = entry.key;
      final count = entry.value;
      final sweepAngle = (count / total) * 2 * math.pi * animation;
      final color = categoryColors[category] ?? const Color(0xFF826695);
      final isSelected = selectedCategory == category;
      
      // Create paint with selection effect
      final paint = Paint()
        ..color = isSelected ? color.withOpacity(0.8) : color
        ..style = PaintingStyle.fill;
      
      // Draw the pie slice
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      // Add selection highlight (outer glow or border)
      if (isSelected) {
        final selectionPaint = Paint()
          ..color = const Color(0xFF826695)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          selectionPaint,
        );
      }
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 