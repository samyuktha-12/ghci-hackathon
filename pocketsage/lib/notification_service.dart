import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

// Global key for showing notifications
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class NotificationService {
  static const String _lastNotificationKey = 'last_bangalore_insight';
  static const String _lastNotificationDateKey = 'last_notification_date';

  static Future<void> initialize() async {
    print('Notification service initialized');
  }

  static Future<void> showBangaloreInsightNotification() async {
    try {
      // Check if we should show notification (once per day)
      if (!await _shouldShowNotification()) {
        return;
      }

      // Fetch Bangalore insight
      final insight = await _fetchBangaloreInsight();
      if (insight == null) {
        return;
      }

      // Save the insight and date
      await _saveLastNotification(insight);
      
      // Show a console message for debugging
      print('💡 Bangalore Financial Insight: $insight');
      
      // Show a visual notification using SnackBar
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.location_city_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4A90E2),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error showing Bangalore insight notification: $e');
    }
  }

  static Future<bool> _shouldShowNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_lastNotificationDateKey);
      
      if (lastDate == null) {
        return true; // First time, show notification
      }

      final lastNotificationDate = DateTime.parse(lastDate);
      final now = DateTime.now();
      
      // Check if it's a different day
      return lastNotificationDate.year != now.year ||
             lastNotificationDate.month != now.month ||
             lastNotificationDate.day != now.day;
    } catch (e) {
      print('Error checking notification timing: $e');
      return true; // Show notification on error
    }
  }

  static Future<String?> _fetchBangaloreInsight() async {
    try {
      // Try different categories for variety
      final categories = ['all', 'tech', 'real_estate', 'startup', 'cost_of_living'];
      final randomCategory = categories[DateTime.now().millisecond % categories.length];
      
      final uri = Uri.parse('http://10.0.2.2:8080/news/insight/bangalore?category=$randomCategory&num=5');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['insight'] != null) {
          return data['insight'] as String;
        }
      }
      
      // If API fails, return a fallback insight
      return _getFallbackInsight(randomCategory);
    } catch (e) {
      print('Error fetching Bangalore insight: $e');
      // Return fallback insight on error
      return _getFallbackInsight('all');
    }
  }

  static String _getFallbackInsight(String category) {
    final fallbackInsights = {
      'all': [
        'Bangalore\'s tech sector shows strong growth with increasing startup funding',
        'Real estate prices in Bangalore continue to rise in prime locations',
        'Cost of living in Bangalore remains competitive for tech professionals',
        'Bangalore leads India\'s startup ecosystem with innovative ventures',
        'Transportation infrastructure improving with metro expansion'
      ],
      'tech': [
        'Bangalore tech companies report 15% salary growth this year',
        'Startup funding in Bangalore reaches new quarterly records',
        'Tech talent demand remains high in Bangalore\'s IT sector',
        'Bangalore continues to attract global tech investments',
        'AI and ML startups flourishing in Bangalore\'s tech ecosystem'
      ],
      'real_estate': [
        'Bangalore real estate market shows 8% annual appreciation',
        'Rental yields in prime Bangalore areas remain attractive',
        'New residential projects focus on sustainable living',
        'Commercial real estate demand strong in tech corridors',
        'Bangalore property market stable despite global uncertainties'
      ],
      'startup': [
        'Bangalore startups raised over \$2B in funding this quarter',
        'Fintech startups leading Bangalore\'s startup ecosystem',
        'Bangalore ranks #1 in India for startup success rate',
        'Angel investors increasingly active in Bangalore market',
        'Bangalore startups creating 50,000+ new jobs annually'
      ],
      'cost_of_living': [
        'Bangalore offers best value for money among metro cities',
        'Food and transportation costs remain reasonable in Bangalore',
        'Bangalore\'s cost of living 30\% lower than Mumbai',
        'Quality of life improving with better infrastructure',
        'Bangalore provides excellent work-life balance for professionals'
      ]
    };
    
    final insights = fallbackInsights[category] ?? fallbackInsights['all']!;
    final randomIndex = DateTime.now().millisecond % insights.length;
    return insights[randomIndex];
  }

  static Future<void> _saveLastNotification(String insight) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastNotificationKey, insight);
      await prefs.setString(_lastNotificationDateKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving notification data: $e');
    }
  }

  static Future<String?> getLastInsight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastNotificationKey);
    } catch (e) {
      print('Error getting last insight: $e');
      return null;
    }
  }

  static Future<void> clearNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastNotificationKey);
      await prefs.remove(_lastNotificationDateKey);
    } catch (e) {
      print('Error clearing notification history: $e');
    }
  }
} 