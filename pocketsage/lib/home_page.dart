import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'receipt_stats_screen.dart';
import 'insights_trends_screen.dart';
import 'notification_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  ChatMessage({required this.role, required this.content, required this.timestamp});
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  XFile? _capturedFile;
  String? _captureType; // 'photo' or 'video'

  List<String> _uploadSteps = [];
  bool _isUploading = false;
  int _currentIndex = 0; // For bottom navigation (0: Home, 1: Chatbot, 2: Wallets, 3: Inventory)
  final TextEditingController _chatController = TextEditingController();

  // Chatbot state
  List<ChatMessage> _chatMessages = [];
  String? _conversationId;
  bool _isChatLoading = false;
  String _selectedLanguage = 'en'; // Default language
  Map<String, String> _availableLanguages = {
    "en": "English",
    "hi": "Hindi",
    "ta": "Tamil",
    "te": "Telugu",
    "bn": "Bengali",
    "mr": "Marathi"
  };
  List<String> _followUpSuggestions = [
    'Show my spending trends',
    'Analyze receipts',
    'What did I spend most on last month?',
    'Show my top vendors',
    'Summarize my expenses',
  ];

  // EcoScore state
  Map<String, dynamic>? _ecoscoreData;
  bool _isEcoScoreLoading = false;

  // Tip of the Day state
  String? _tipOfTheDay;
  bool _isTipLoading = false;

  // Dashboard state
  Map<String, dynamic>? _dashboardData;
  bool _isDashboardLoading = false;

  // Bangalore Insight state
  String? _bangaloreInsight;
  bool _isBangaloreInsightLoading = false;

  String? _pendingPassEventName;
  String? _pendingPassBarcodeValue;
  String? _pendingPassType;

  Future<void> _pickCamera({required bool isVideo}) async {
    final picker = ImagePicker();
    XFile? file;
    if (isVideo) {
      file = await picker.pickVideo(source: ImageSource.camera);
    } else {
      file = await picker.pickImage(source: ImageSource.camera);
    }
    if (file != null) {
      setState(() {
        _capturedFile = file;
        _captureType = isVideo ? 'video' : 'photo';
      });
      _showPreview();
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'jpg', 'jpeg', 'png', 'mp4', 'mov', 'heic'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _capturedFile = XFile(result.files.single.path!);
        _captureType = 'file';
      });
      _showPreview();
    }
  }

  String _getThinkingText() {
    final thinkingTexts = {
      "en": "SageBot is thinking...",
      "hi": "SageBot सोच रहा है...",
      "ta": "SageBot சிந்திக்கிறது...",
      "te": "SageBot ఆలోచిస్తున్నది...",
      "bn": "SageBot ভাবছে...",
      "mr": "SageBot विचार करत आहे..."
    };
    return thinkingTexts[_selectedLanguage] ?? "SageBot is thinking...";
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D223A),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _availableLanguages.length,
                  itemBuilder: (context, index) {
                    final languageCode = _availableLanguages.keys.elementAt(index);
                    final languageName = _availableLanguages.values.elementAt(index);
                    final isSelected = languageCode == _selectedLanguage;
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF826695) : const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.language,
                          color: isSelected ? Colors.white : const Color(0xFF826695),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        languageName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF826695) : const Color(0xFF2D223A),
                        ),
                      ),
                      subtitle: Text(
                        languageCode.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF826695).withOpacity(0.6),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF826695))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedLanguage = languageCode;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendMessage() {
    final message = _chatController.text.trim();
    if (message.isNotEmpty) {
      // TODO: Implement chatbot functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent: $message'),
          backgroundColor: const Color(0xFF826695),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      _chatController.clear();
    }
  }

  Future<void> _triggerParseReceipts() async {
    final url = Uri.parse('http://10.0.2.2:8000/parse_receipts');
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parsing triggered: ${response.body}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trigger parsing: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> uploadReceiptToFastAPI(Function closeModal) async {
    if (_capturedFile == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not signed in!')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadSteps = ['Uploading file...'];
    });

    final uri = Uri.parse('http://10.0.2.2:8080/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = user.uid
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        _capturedFile!.path,
        contentType: _captureType == 'photo'
            ? MediaType('image', 'jpeg')
            : MediaType('application', 'octet-stream'),
      ));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _uploadSteps.add('Parsing receipt...');
      });

      await Future.delayed(const Duration(seconds: 1)); // Simulate step

      if (response.statusCode == 200) {
        setState(() {
          _uploadSteps.add('Success!');
          _isUploading = false;
        });
        closeModal(); // Close the modal immediately on success
        
        // Show success message as snack bar at the bottom with white background and primary color text
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Receipt uploaded and parsed successfully!',
                style: TextStyle(
                  color: Color(0xFF826695),
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.white,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        setState(() {
          _uploadSteps.add('Failed!');
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _uploadSteps.add('Error!');
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      'Confirm Upload',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D223A),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_capturedFile != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEDEAF6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, color: Color(0xFF826695), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _capturedFile!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF2D223A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 28),
                    if (_isUploading)
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF826695)),
                          ),
                          const SizedBox(height: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _uploadSteps.map((step) {
                              Color color;
                              IconData icon;
                              if (step == 'Success!') {
                                color = Colors.green;
                                icon = Icons.check_circle;
                              } else if (step == 'Failed!' || step == 'Error!') {
                                color = Colors.red;
                                icon = Icons.error;
                              } else {
                                color = const Color(0xFF826695);
                                icon = Icons.radio_button_checked;
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Icon(icon, color: color, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      step,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF826695),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            setModalState(() {
                              _isUploading = true;
                              _uploadSteps = ['Uploading file...'];
                            });
                            await uploadReceiptToFastAPI(() {
                              if (mounted) Navigator.pop(context);
                              setState(() {
                                _capturedFile = null;
                                _captureType = null;
                              });
                            });
                          },
                          child: const Text('Submit'),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _ScanOption(
                icon: Icons.camera_alt_rounded,
                label: 'Scan Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickCamera(isVideo: false);
                },
              ),
              const SizedBox(height: 16),
              _ScanOption(
                icon: Icons.videocam_rounded,
                label: 'Scan Video',
                onTap: () {
                  Navigator.pop(context);
                  _pickCamera(isVideo: true);
                },
              ),
              const SizedBox(height: 16),
              _ScanOption(
                icon: Icons.upload_file_rounded,
                label: 'Upload Receipt',
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchEcoScore();
    _fetchTipOfTheDay();
    _fetchDashboardData();
    _fetchBangaloreInsight();
    _showBangaloreInsightNotification();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _fetchEcoScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isEcoScoreLoading = true;
    });

    try {
      final uri = Uri.parse('http://10.0.2.2:8080/user-ecoscore');
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = user.uid;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _ecoscoreData = data;
          _isEcoScoreLoading = false;
        });
      } else {
        print('Failed to fetch EcoScore: ${response.statusCode}');
        setState(() {
          _isEcoScoreLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching EcoScore: $e');
      setState(() {
        _isEcoScoreLoading = false;
      });
    }
  }

  Future<void> _fetchTipOfTheDay() async {
    setState(() {
      _isTipLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uri = Uri.parse('http://10.0.2.2:8080/tip-of-the-day');
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = user.uid;
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tipOfTheDay = data['tipOfTheDay'] is String ? data['tipOfTheDay'] : (data['tipOfTheDay']?['tip'] ?? '');
          _isTipLoading = false;
        });
      } else {
        print('Failed to fetch tip: ${response.statusCode}');
        setState(() {
          _isTipLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching tip: $e');
      setState(() {
        _isTipLoading = false;
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isDashboardLoading = true;
    });
    try {
      final uri = Uri.parse('http://10.0.2.2:8080/generate_chart');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _dashboardData = data;
          _isDashboardLoading = false;
        });
      } else {
        setState(() {
          _isDashboardLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isDashboardLoading = false;
      });
    }
  }

  Future<void> _fetchBangaloreInsight() async {
    setState(() {
      _isBangaloreInsightLoading = true;
    });

    // Define categories and random category at the beginning
    final categories = ['all', 'tech', 'real_estate', 'startup', 'cost_of_living'];
    final randomCategory = categories[DateTime.now().millisecond % categories.length];

    try {
      // First try to get the last insight from storage
      final lastInsight = await NotificationService.getLastInsight();
      if (lastInsight != null) {
        setState(() {
          _bangaloreInsight = lastInsight;
          _isBangaloreInsightLoading = false;
        });
        return;
      }

      // If no stored insight, fetch a new one
      
      final uri = Uri.parse('http://10.0.2.2:8080/news/insight/bangalore?category=$randomCategory&num=5');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['insight'] != null) {
          setState(() {
            _bangaloreInsight = data['insight'] as String;
            _isBangaloreInsightLoading = false;
          });
        } else {
          setState(() {
            _bangaloreInsight = _getFallbackInsight(randomCategory);
            _isBangaloreInsightLoading = false;
          });
        }
      } else {
        setState(() {
          _bangaloreInsight = _getFallbackInsight(randomCategory);
          _isBangaloreInsightLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching Bangalore insight: $e');
      setState(() {
        _bangaloreInsight = _getFallbackInsight(randomCategory);
        _isBangaloreInsightLoading = false;
      });
    }
  }

  Future<void> _showBangaloreInsightNotification() async {
    try {
      // Add a small delay to ensure the app is fully loaded
      await Future.delayed(const Duration(seconds: 2));
      
      // Show the Bangalore insight notification
      await NotificationService.showBangaloreInsightNotification();
    } catch (e) {
      print('Error showing Bangalore insight notification: $e');
    }
  }

  String _getFallbackInsight(String category) {
    final fallbackInsights = {
      'all': [
        'Bangalore\'s tech sector shows strong growth with increasing startup funding',
        'Real estate prices in Bangalore continue to rise in prime locations',
        'Cost of living in Bangalore remains competitive for tech professionals',
        'Bangalore leads India\'s startup ecosystem with innovative ventures',
        'Transportation infrastructure improving with metro expansion'
      ],
      'tech': [
        'Bangalore tech companies report 15\% salary growth this year',
        'Startup funding in Bangalore reaches new quarterly records',
        'Tech talent demand remains high in Bangalore\'s IT sector',
        'Bangalore continues to attract global tech investments',
        'AI and ML startups flourishing in Bangalore\'s tech ecosystem'
      ],
      'real_estate': [
        'Bangalore real estate market shows 8\% annual appreciation',
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

  String _sanitizeChatResponse(String response) {
    // Remove markdown formatting
    String sanitized = response;
    
    // Remove markdown code blocks
    sanitized = sanitized.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    
    // Remove inline code
    sanitized = sanitized.replaceAll(RegExp(r'`[^`]*`'), '');
    
    // Remove markdown headers
    sanitized = sanitized.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    
    // Remove bold formatting
    sanitized = sanitized.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (match) {
      return match.group(1) ?? '';
    });
    sanitized = sanitized.replaceAllMapped(RegExp(r'__([^_]+)__'), (match) {
      return match.group(1) ?? '';
    });
    
    // Remove italic formatting
    sanitized = sanitized.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (match) {
      return match.group(1) ?? '';
    });
    sanitized = sanitized.replaceAllMapped(RegExp(r'_([^_]+)_'), (match) {
      return match.group(1) ?? '';
    });
    
    // Remove strikethrough
    sanitized = sanitized.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (match) {
      return match.group(1) ?? '';
    });
    
    // Remove bullet points and numbered lists
    sanitized = sanitized.replaceAll(RegExp(r'^[\s]*[-*+]\s+', multiLine: true), '');
    sanitized = sanitized.replaceAll(RegExp(r'^[\s]*\d+\.\s+', multiLine: true), '');
    
    // Remove blockquotes
    sanitized = sanitized.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
    
    // Remove horizontal rules
    sanitized = sanitized.replaceAll(RegExp(r'^[-*_]{3,}$', multiLine: true), '');
    
    // Remove links but keep text
    sanitized = sanitized.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) {
      return match.group(1) ?? '';
    });
    
    // Remove image markdown
    sanitized = sanitized.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), (match) {
      return match.group(1) ?? '';
    });
    
    // Clean up extra whitespace
    sanitized = sanitized
        .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n')
        .replaceAll(RegExp(r'^\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\s+$', multiLine: true), '')
        .trim();

    return sanitized;
  }

  Future<String?> _createWalletPass({
    required String eventName,
    required String barcodeValue,
    String classId = "shoppingListClass",
    String objectId = "shoppingListObject",
    String issuerName = "PocketSage",
  }) async {
    final uri = Uri.parse('http://10.0.2.2:8080/create_pass');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "event_name": eventName,
        "barcode_value": barcodeValue,
        "class_id": classId,
        "object_id": objectId,
        "issuer_name": issuerName,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final url = data['wallet_url'];
      if (url != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add to Google Wallet'),
            content: const Text('Tap below to add your pass.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
                child: const Text('Open Wallet Link'),
              ),
            ],
          ),
        );
        return url;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create wallet pass.')),
      );
    }
    return null;
  }

  Future<void> _storeWalletUrl({
    required String passId,
    required String eventName,
    required String walletUrl,
    required String barcodeValue,
    required String type,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('wallet_passes').doc(passId).set({
          'userId': user.uid,
          'passId': passId,
          'eventName': eventName,
          'walletUrl': walletUrl,
          'barcodeValue': barcodeValue,
          'type': type,
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        });
      }
    } catch (e) {
      print('Error storing wallet URL: $e');
    }
  }

  Future<void> _createShoppingListPass() async {
    try {
      // Call Gemini to generate a smart shopping list based on user's spending patterns
      final uri = Uri.parse('http://10.0.2.2:8080/generate-shopping-list');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": FirebaseAuth.instance.currentUser?.uid ?? "default_user",
        }),
      );
      
      String shoppingList;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        shoppingList = data['shopping_list'] ?? "Milk, Bread, Eggs, Bananas, Chicken, Rice, Vegetables";
      } else {
        // Fallback to default list if API fails
        shoppingList = "Milk, Bread, Eggs, Bananas, Chicken, Rice, Vegetables";
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final passId = "shoppingList_$timestamp";
      
      final walletUrl = await _createWalletPass(
        eventName: "Smart Shopping List",
        barcodeValue: shoppingList,
        classId: "shoppingListClass",
        objectId: passId,
      );
      
      // Store the wallet URL in Firestore
      if (walletUrl != null) {
        await _storeWalletUrl(
          passId: passId,
          eventName: "Smart Shopping List",
          walletUrl: walletUrl,
          barcodeValue: shoppingList,
          type: "shopping_list",
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create shopping list: $e')),
      );
    }
  }

  Future<void> _createRecipePass() async {
    try {
      // Generate a sample recipe pass
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final passId = "recipe_$timestamp";
      
      // Sample recipe ingredients
      final recipeIngredients = "Chicken, Rice, Onions, Garlic, Olive Oil, Salt, Pepper, Herbs";
      
      final walletUrl = await _createWalletPass(
        eventName: "Quick Recipe",
        barcodeValue: recipeIngredients,
        classId: "recipeClass",
        objectId: passId,
      );
      
      // Store the wallet URL in Firestore
      if (walletUrl != null) {
        await _storeWalletUrl(
          passId: passId,
          eventName: "Quick Recipe",
          walletUrl: walletUrl,
          barcodeValue: recipeIngredients,
          type: "recipe",
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create recipe pass: $e')),
      );
    }
  }

  void _checkForPassOpportunity(String assistantMessage) {
    // Simple keyword-based detection for demo: look for 'shopping list:' or 'recipe:'
    final shoppingListPattern = RegExp(r'shopping list:(.*)', caseSensitive: false);
    final recipePattern = RegExp(r'recipe:(.*)', caseSensitive: false);
    final shoppingListMatch = shoppingListPattern.firstMatch(assistantMessage);
    final recipeMatch = recipePattern.firstMatch(assistantMessage);
    if (shoppingListMatch != null) {
      setState(() {
        _pendingPassEventName = 'Shopping List';
        _pendingPassBarcodeValue = shoppingListMatch.group(1)?.trim() ?? '';
        _pendingPassType = 'shopping';
      });
    } else if (recipeMatch != null) {
      setState(() {
        _pendingPassEventName = 'Recipe';
        _pendingPassBarcodeValue = recipeMatch.group(1)?.trim() ?? '';
        _pendingPassType = 'recipe';
      });
    } else {
      setState(() {
        _pendingPassEventName = null;
        _pendingPassBarcodeValue = null;
        _pendingPassType = null;
      });
    }
  }

  // Export Reports functionality
  Future<void> _showExportOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Export Reports',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D223A),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.open_in_browser, color: Color(0xFF826695)),
                title: const Text('Open Financial Dashboard', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('View your reports online'),
                onTap: () {
                  Navigator.pop(context);
                  _openFinancialDashboard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Color(0xFF826695)),
                title: const Text('Download as PDF', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Save report to your device'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAsPDF();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFinancialDashboard() async {
    const url = 'https://studio--fiscalvista-landing.us-central1.hosted.app';
    try {
      final uri = Uri.parse(url);
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: Color(0xFF826695)),
                SizedBox(width: 20),
                Text('Opening dashboard...'),
              ],
            ),
          );
        },
      );
      
      // Try different launch modes
      bool launched = false;
      
      // First try external application
      if (await canLaunchUrl(uri)) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
        } catch (e) {
          print('External application launch failed: $e');
        }
      }
      
      // If external failed, try in-app browser
      if (!launched) {
        try {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
          launched = true;
        } catch (e) {
          print('In-app browser launch failed: $e');
        }
      }
      
      // If in-app failed, try platform default
      if (!launched) {
        try {
          await launchUrl(uri);
          launched = true;
        } catch (e) {
          print('Platform default launch failed: $e');
        }
      }
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (launched) {
        _showSuccessSnackBar('Financial dashboard opened successfully!');
      } else {
        // Show fallback dialog with URL
        _showUrlFallbackDialog(url);
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      print('URL launch error: $e');
      _showUrlFallbackDialog(url);
    }
  }

  void _showUrlFallbackDialog(String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Dashboard Access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unable to open the dashboard automatically.'),
              const SizedBox(height: 10),
              const Text('Dashboard URL:'),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  url,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await Clipboard.setData(ClipboardData(text: url));
                  _showSuccessSnackBar('Dashboard URL copied to clipboard!');
                } catch (e) {
                  _showErrorSnackBar('Failed to copy URL: $e');
                }
              },
              child: const Text('Copy URL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAsPDF() async {
    try {
      // Request storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          _showErrorSnackBar('Storage permission is required to download PDF');
          return;
        }
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: Color(0xFF826695)),
                SizedBox(width: 20),
                Text('Downloading PDF...'),
              ],
            ),
          );
        },
      );

      // Get the downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        Navigator.pop(context); // Close loading dialog
        _showErrorSnackBar('Could not access download directory');
        return;
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'PocketSage_Financial_Report_$timestamp.pdf';
      final filePath = '${downloadsDir.path}/$fileName';

      // Download the PDF from the URL
      const url = 'https://studio--fiscalvista-landing.us-central1.hosted.app';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Save the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        Navigator.pop(context); // Close loading dialog
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Download Complete'),
              content: Text('PDF saved as: $fileName'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        
        _showSuccessSnackBar('PDF downloaded successfully!');
      } else {
        Navigator.pop(context); // Close loading dialog
        _showErrorSnackBar('Failed to download PDF. Status: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('Error downloading PDF: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: const Color(0xFFF5F5F7),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('Menu', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF826695))),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFEDEAF6)),
            ListTile(
              leading: const Icon(Icons.show_chart, color: Color(0xFF826695)),
              title: const Text('Insights & Trends', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InsightsTrendsScreen(),
                  ),
                );
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              hoverColor: const Color(0xFFF0EDF8),
            ),

            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Color(0xFF826695)),
              title: const Text('Goals & Budgets', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
              onTap: () {},
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              hoverColor: const Color(0xFFF0EDF8),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF826695)),
              title: const Text('Receipts History', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReceiptStatsScreen(),
                  ),
                );
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              hoverColor: const Color(0xFFF0EDF8),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded, color: Color(0xFF826695)),
              title: const Text('Subscriptions', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
              onTap: () {},
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              hoverColor: const Color(0xFFF0EDF8),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_rounded, color: Color(0xFF826695)),
              title: const Text('Export Reports', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showExportOptions();
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              hoverColor: const Color(0xFFF0EDF8),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Color(0xFF826695)),
              title: const Text('Linked Services', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
              onTap: () {},
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              hoverColor: const Color(0xFFF0EDF8),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Color(0xFF826695)),
              title: const Text('Settings', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
              onTap: () {},
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              hoverColor: const Color(0xFFF0EDF8),
            ),
          ],
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(color: Color(0xFFEDEAF6), width: 1),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.menu_rounded, color: Color(0xFF826695), size: 28),
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Menu',
                ),
                // Title
                Expanded(
                  child: Center(
                    child: Text(
                      _getTitleForIndex(_currentIndex),
                      style: const TextStyle(
                        color: Color(0xFF826695),
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF826695), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.logout, color: Color(0xFF826695), size: 24),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  tooltip: 'Logout',
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF826695),
        elevation: 8,
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
                  child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home tab
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_rounded,
                        color: _currentIndex == 0 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.7),
                        size: 22,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Home',
                        style: TextStyle(
                          color: _currentIndex == 0 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: _currentIndex == 0 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Chatbot tab
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_rounded,
                        color: _currentIndex == 1 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.7),
                        size: 22,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Chat',
                        style: TextStyle(
                          color: _currentIndex == 1 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: _currentIndex == 1 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Spacer for FAB
            const SizedBox(width: 60),
            // Wallets tab
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 2;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: _currentIndex == 2 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.7),
                        size: 22,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Wallets',
                        style: TextStyle(
                          color: _currentIndex == 2 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: _currentIndex == 2 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Inventory tab
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 3;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        color: _currentIndex == 3 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.7),
                        size: 22,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Inventory',
                        style: TextStyle(
                          color: _currentIndex == 3 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: _currentIndex == 3 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GlassmorphicFAB(
        onPressed: _showScanOptions,
        child: const Icon(Icons.document_scanner_rounded, size: 32, color: Colors.white),
      ),
    );
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Chatbot';
      case 2:
        return 'Wallets';
      case 3:
        return 'Inventory';
      default:
        return 'Home';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildChatbotContent();
      case 2:
        return _buildWalletScreen();
      case 3:
        return InventoryScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHomeContent() {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'User';
    final userEmail = user?.email ?? '';
    final userPhotoURL = user?.photoURL;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Profile Picture
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF826695),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: userPhotoURL != null
                        ? Image.network(
                            userPhotoURL,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFF5F5F7),
                                child: const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Color(0xFF826695),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFFF5F5F7),
                            child: const Icon(
                              Icons.person,
                              size: 30,
                              color: Color(0xFF826695),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Welcome Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF826695).withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 24,
                          color: Color(0xFF826695),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your smart financial companion',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF826695).withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Spending Dashboard Section
          _buildSpendingDashboard(),
          const SizedBox(height: 24),
          // Tip of the Day Section
          _buildTipOfTheDayTile(),
          const SizedBox(height: 18),
          // Chatbot Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF826695).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SageBot',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF826695),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // TODO: Navigate to full chatbot screen
                        setState(() {
                          _currentIndex = 1; // Switch to chatbot tab
                        });
                      },
                      icon: const Icon(
                        Icons.expand_less,
                        color: Color(0xFF826695),
                        size: 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEDEAF6),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF826695),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.smart_toy_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'How can I help you today?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF2D223A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ask me about your expenses, receipts, or financial insights',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFF2D223A).withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFEDEAF6),
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _chatController,
                                      decoration: const InputDecoration(
                                        hintText: 'Type your question here...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF9E9E9E),
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2D223A),
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF826695),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: _sendMessage,
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    style: IconButton.styleFrom(
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sample suggestion chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChatbotSuggestionChip(
                            text: 'Show my spending trends',
                            onTap: () {
                              setState(() {
                                _currentIndex = 1; // Switch to chatbot tab
                              });
                              _sendChatMessage('Show my spending trends');
                            },
                          ),
                          _buildChatbotSuggestionChip(
                            text: 'Analyze receipts',
                            onTap: () {
                              setState(() {
                                _currentIndex = 1; // Switch to chatbot tab
                              });
                              _sendChatMessage('Analyze receipts');
                            },
                          ),
                          _buildChatbotSuggestionChip(
                            text: 'What did I spend most on?',
                            onTap: () {
                              setState(() {
                                _currentIndex = 1; // Switch to chatbot tab
                              });
                              _sendChatMessage('What did I spend most on last month?');
                            },
                          ),
                          _buildChatbotSuggestionChip(
                            text: 'Show my top vendors',
                            onTap: () {
                              setState(() {
                                _currentIndex = 1; // Switch to chatbot tab
                              });
                              _sendChatMessage('Show my top vendors');
                            },
                          ),
                          _buildChatbotSuggestionChip(
                            text: 'Summarize expenses',
                            onTap: () {
                              setState(() {
                                _currentIndex = 1; // Switch to chatbot tab
                              });
                              _sendChatMessage('Summarize my expenses');
                            },
                          ),
                          _buildChatbotSuggestionChip(
                            text: 'Budget insights',
                            onTap: () {
                              setState(() {
                                _currentIndex = 1; // Switch to chatbot tab
                              });
                              _sendChatMessage('Give me budget insights');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Email conversations tile
                      if (_chatMessages.isNotEmpty && _conversationId != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEDEAF6),
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: _sendChatbotEmail,
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF826695).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.email_rounded,
                                    color: Color(0xFF826695),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mail the conversations',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF2D223A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Send this conversation to your email',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFF2D223A).withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFF826695),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Shopping List Chip Section
          _buildShoppingListChip(),
          const SizedBox(height: 24),
          // EcoScore Tile Section
          _buildEcoScoreTile(),
          const SizedBox(height: 24),
          // Bangalore Insight Tile Section
          _buildBangaloreInsightTile(),
        ],
      ),
    );
  }

  Widget _buildSpendingDashboard() {
    final categoryMeta = {
      'groceries': {
        'label': 'Groceries',
        'icon': Icons.shopping_cart,
        'color': const Color(0xFF4CAF50),
      },
      'utilities': {
        'label': 'Utilities',
        'icon': Icons.electric_bolt,
        'color': const Color(0xFFFF9800),
      },
      'transportation': {
        'label': 'Transportation',
        'icon': Icons.directions_car,
        'color': const Color(0xFF2196F3),
      },
      'dining': {
        'label': 'Dining',
        'icon': Icons.restaurant,
        'color': const Color(0xFFE91E63),
      },
      'travel': {
        'label': 'Travel',
        'icon': Icons.flight,
        'color': const Color(0xFFE74C3C),
      },
      'reimbursement': {
        'label': 'Reimbursement',
        'icon': Icons.attach_money,
        'color': const Color(0xFF4A90E2),
      },
      'home': {
        'label': 'Home',
        'icon': Icons.home,
        'color': const Color(0xFF7ED321),
      },
    };

    if (_isDashboardLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF826695).withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEDEAF6),
            width: 1,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF826695)),
        ),
      );
    }

    final data = _dashboardData ?? {};
    final categories = data.keys.toList();
    final amounts = categories.map((cat) => (data[cat] is List && data[cat].length > 1) ? (data[cat][1] as num).toDouble() : 0.0).toList();
    final totalSpending = amounts.fold<double>(0, (sum, amt) => sum + amt);
    final maxSpending = amounts.isNotEmpty ? amounts.reduce((a, b) => a > b ? a : b) : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF826695).withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDEAF6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Spending Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D223A),
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 14,
                      color: Color(0xFF826695),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'vs last week',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF826695).withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Total Spending
          Row(
            children: [
              Text(
                '₹${totalSpending.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D223A),
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.trending_up,
                size: 20,
                color: Color(0xFFE74C3C),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Spending Categories
          ...categories.map((cat) {
            final meta = categoryMeta[cat] ?? {
              'label': cat[0].toUpperCase() + cat.substring(1),
              'icon': Icons.category,
              'color': const Color(0xFF826695),
            };
            final amount = (data[cat] is List && data[cat].length > 1) ? (data[cat][1] as num).toDouble() : 0.0;
            final progress = maxSpending > 0 ? amount / maxSpending : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  // Category Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (meta['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      meta['icon'] as IconData,
                      color: meta['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category Name
                  Expanded(
                    flex: 2,
                    child: Text(
                      meta['label'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D223A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Progress Bar
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: meta['color'] as Color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Amount
                  Flexible(
                    child: Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D223A).withOpacity(0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildShoppingListChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF826695).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF826695).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF826695).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shopping_cart,
              color: Color(0xFF826695),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Shopping List',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D223A),
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add to Google Wallet for easy access',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF2D223A).withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _createShoppingListPass,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF826695),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Create',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoScoreTile() {
    if (_isEcoScoreLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FCF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD4EDDA),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'EcoScore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D223A),
                ),
              ),
            ),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      );
    }

    // Extract EcoScore data
    int ecoScore = 0;
    String trendText = '';
    List<String> recommendations = [];
    
    if (_ecoscoreData != null && _ecoscoreData!['ecoScoreResult'] != null) {
      final ecoScoreResult = _ecoscoreData!['ecoScoreResult'];
      
      if (ecoScoreResult is Map<String, dynamic>) {
        ecoScore = ecoScoreResult['ecoScore'] ?? 0;
        
        // Calculate trend from monthly trends
        final monthlyTrends = ecoScoreResult['monthlyTrends'];
        if (monthlyTrends is Map<String, dynamic> && monthlyTrends.isNotEmpty) {
          final scores = monthlyTrends.values.toList();
          if (scores.length >= 2) {
            final currentScore = scores.last;
            final previousScore = scores[scores.length - 2];
            final difference = currentScore - previousScore;
            if (difference > 0) {
              trendText = '+${difference.toStringAsFixed(0)} from last month';
            } else if (difference < 0) {
              trendText = '${difference.toStringAsFixed(0)} from last month';
            } else {
              trendText = 'No change from last month';
            }
          }
        }
        
        // Get recommendations
        final recs = ecoScoreResult['recommendations'];
        if (recs is List) {
          recommendations = recs.cast<String>();
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4EDDA),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'EcoScore',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D223A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ecoScore.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4CAF50).withOpacity(0.8),
                    ),
                  ),
                  if (trendText.isNotEmpty)
                    Text(
                      trendText,
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF4CAF50).withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Your eco impact",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ecoScore / 100, // Dynamic progress based on actual score
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (recommendations.isNotEmpty)
            Text(
              recommendations.first, // Show first recommendation
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2D223A),
                fontWeight: FontWeight.w500,
              ),
            )
          else
            const Text(
              "Great job! You're making eco-conscious choices.",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF2D223A),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTipOfTheDayTile() {
    final Color yellowBg = const Color(0xFFFFFCF3); // Very subtle yellow
    final Color yellowAccent = const Color(0xFFFFE066); // Accent for icon
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: yellowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: yellowAccent.withOpacity(0.13), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF826695).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: yellowAccent.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF826695), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip of the Day',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF826695).withOpacity(0.95),
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 6),
                _isTipLoading
                    ? Row(
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF826695)),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Loading tip...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF826695),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : (_tipOfTheDay != null && _tipOfTheDay!.isNotEmpty)
                        ? Text(
                            _tipOfTheDay!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF2D223A),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : const Text(
                            'Stay tuned for your daily financial tip!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF826695),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBangaloreInsightTile() {
    final Color blueBg = const Color(0xFFF0F8FF); // Very light blue
    final Color blueAccent = const Color(0xFF4A90E2); // Blue accent
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: blueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blueAccent.withOpacity(0.13), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF826695).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: blueAccent.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.location_city_rounded, color: Color(0xFF826695), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Bangalore Insight',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D223A),
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Local',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _isBangaloreInsightLoading
                    ? Row(
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF826695)),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Loading insight...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF826695),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : (_bangaloreInsight != null && _bangaloreInsight!.isNotEmpty)
                        ? Text(
                            _bangaloreInsight!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF2D223A),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : const Text(
                            'Stay updated with Bangalore\'s latest financial trends!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF826695),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildChatbotSuggestionChip({
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF826695),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildChatbotContent() {
    final user = FirebaseAuth.instance.currentUser;
    final userPhotoURL = user?.photoURL;
    return Column(
      children: [
        // Language selector header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFEDEAF6), width: 1),
            ),
          ),
          child: Row(
            children: [
              const Text(
                'Chat Language:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D223A),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showLanguageSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF826695).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF826695).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language,
                        size: 16,
                        color: Color(0xFF826695),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _availableLanguages[_selectedLanguage] ?? 'English',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF826695),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Color(0xFF826695),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_selectedLanguage != 'en')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate,
                        size: 12,
                        color: Color(0xFF4CAF50),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Translated',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF5F5F7),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isUser = msg.role == 'user';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF826695),
                            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isUser ? const Color(0xFF826695) : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                                  bottomRight: Radius.circular(isUser ? 6 : 18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isUser
                                        ? const Color(0xFF826695).withOpacity(0.10)
                                        : const Color(0xFF826695).withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                msg.content,
                                style: TextStyle(
                                  color: isUser ? Colors.white : const Color(0xFF2D223A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (!isUser &&
                                index == _chatMessages.length - 1 &&
                                _pendingPassEventName != null &&
                                _pendingPassBarcodeValue != null &&
                                !_isChatLoading)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.account_balance_wallet_rounded),
                                  label: Text('Add ${_pendingPassEventName!} to Wallet'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF826695),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () {
                                    _createWalletPass(
                                      eventName: _pendingPassEventName!,
                                      barcodeValue: _pendingPassBarcodeValue!,
                                      classId: _pendingPassType == 'shopping' ? 'shoppingListClass' : 'recipeClass',
                                      objectId: _pendingPassType == 'shopping' ? 'shoppingListObject' : 'recipeObject',
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isUser)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: userPhotoURL != null
                              ? CircleAvatar(
                                  radius: 18,
                                  backgroundImage: NetworkImage(userPhotoURL),
                                  backgroundColor: const Color(0xFF826695),
                                )
                              : CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF826695),
                                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (_isChatLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF826695)),
                ),
                const SizedBox(width: 12),
                Text(
                  _getThinkingText(),
                  style: const TextStyle(color: Color(0xFF826695), fontWeight: FontWeight.w600)
                ),
              ],
            ),
          ),
        if (!_isChatLoading && _chatMessages.isNotEmpty && _chatMessages.last.role == 'assistant')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _followUpSuggestions.map((s) => _buildChatbotSuggestionChip(
                text: s,
                onTap: () => _handleSuggestionTap(s),
              )).toList(),
            ),
          ),
        // Email conversations button for full chatbot screen
        if (!_isChatLoading && _chatMessages.isNotEmpty && _conversationId != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.email_rounded),
              label: const Text('Mail Conversation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF826695),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _sendChatbotEmail,
            ),
          ),
        // Input box with floating effect
        Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      enabled: !_isChatLoading,
                      decoration: const InputDecoration(
                        hintText: 'Type your question...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF2D223A),
                      ),
                      onSubmitted: (_) => _handleSendMessage,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: _isChatLoading ? Colors.grey[300] : const Color(0xFF826695),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF826695).withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _isChatLoading ? null : _handleSendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendChatMessage(String message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not signed in!')),
      );
      return;
    }
    if (message.trim().isEmpty) return;
    setState(() {
      _chatMessages.add(ChatMessage(
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
      ));
      _isChatLoading = true;
    });
    _chatController.clear();
    try {
      final uri = Uri.parse('http://10.0.2.2:8080/chatbot');
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = user.uid
        ..fields['message'] = message
        ..fields['language'] = _selectedLanguage; // Add language parameter
      if (_conversationId != null) {
        request.fields['conversation_id'] = _conversationId!;
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        final rawResponse = data['response'] ?? 'No response';
        final sanitizedResponse = _sanitizeChatResponse(rawResponse);
        _checkForPassOpportunity(sanitizedResponse);
        
        // Update follow-up suggestions with translated chips
        if (data['follow_up_chips'] != null) {
          final chips = List<String>.from(data['follow_up_chips']);
          setState(() {
            _followUpSuggestions = chips;
          });
        }
        
        setState(() {
          _conversationId = data['conversation_id'] as String?;
          _chatMessages.add(ChatMessage(
            role: 'assistant',
            content: sanitizedResponse,
            timestamp: DateTime.now(),
          ));
          _isChatLoading = false;
        });
      } else {
        setState(() {
          _chatMessages.add(ChatMessage(
            role: 'assistant',
            content: 'Sorry, there was an error: ${response.statusCode}',
            timestamp: DateTime.now(),
          ));
          _isChatLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add(ChatMessage(
          role: 'assistant',
          content: 'Sorry, there was an error: $e',
          timestamp: DateTime.now(),
        ));
        _isChatLoading = false;
      });
    }
  }

  void _handleSendMessage() {
    final message = _chatController.text.trim();
    if (message.isNotEmpty && !_isChatLoading) {
      _sendChatMessage(message);
    }
  }

  void _handleSuggestionTap(String suggestion) {
    if (!_isChatLoading) {
      _sendChatMessage(suggestion);
    }
  }

  Future<void> _sendChatbotEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not signed in!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No conversation to send!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse('http://10.0.2.2:8080/chatbot/send-email');
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = user.uid
        ..fields['user_email'] = user.email ?? ''
        ..fields['user_name'] = user.displayName ?? 'User'
        ..fields['conversation_id'] = _conversationId!
        ..fields['include_summary'] = 'true';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email sent successfully to ${user.email}'),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send email: ${data['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildWalletScreen() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallet_passes')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading wallet passes',
              style: TextStyle(color: Color(0xFF826695)),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF826695)),
          );
        }

        final passes = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreatedAt = DateTime.tryParse(aData['createdAt'] ?? '') ?? DateTime.now();
            final bCreatedAt = DateTime.tryParse(bData['createdAt'] ?? '') ?? DateTime.now();
            return bCreatedAt.compareTo(aCreatedAt); // Descending order
          });

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    'My Wallet Passes',
                    style: TextStyle(
                      color: Color(0xFF2D223A),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Create Wallet Pass Button Section
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF826695),
                        Color(0xFF9B7BB8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF826695).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_card_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Create New Wallet Pass',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Generate shopping lists, recipes, and more',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _createShoppingListPass,
                              icon: const Icon(Icons.shopping_cart_rounded, size: 20),
                              label: const Text(
                                'Shopping List',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF826695),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _createRecipePass,
                              icon: const Icon(Icons.restaurant_rounded, size: 20),
                              label: const Text(
                                'Recipe',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Wallet Passes List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Text(
                        'Your Passes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D223A),
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF826695).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${passes.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF826695),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (passes.isEmpty) {
                        return Container(
                          margin: const EdgeInsets.only(top: 40),
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFEDEAF6),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 64,
                                color: const Color(0xFF826695).withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No wallet passes yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF826695).withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first pass using the buttons above',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF826695).withOpacity(0.5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final pass = passes[index].data() as Map<String, dynamic>;
                      final eventName = pass['eventName'] ?? 'Unknown';
                      final walletUrl = pass['walletUrl'] ?? '';
                      final type = pass['type'] ?? 'unknown';
                      final createdAt = DateTime.tryParse(pass['createdAt'] ?? '') ?? DateTime.now();
                      final isActive = pass['isActive'] ?? true;
                      final barcodeValue = pass['barcodeValue'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF826695).withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getWalletColor(type).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getWalletIcon(type),
                                  color: _getWalletColor(type),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                eventName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF2D223A),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created ${_formatDate(createdAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF826695).withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive 
                                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                                              : const Color(0xFF9E9E9E).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getWalletColor(type).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          type.replaceAll('_', ' ').toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: _getWalletColor(type),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF826695)),
                                    onPressed: () {
                                      // Copy barcode value to clipboard
                                      // You can implement clipboard functionality here
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Barcode value copied to clipboard'),
                                          backgroundColor: Color(0xFF826695),
                                        ),
                                      );
                                    },
                                    tooltip: 'Copy barcode value',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, color: Color(0xFF826695)),
                                    onPressed: () {
                                      if (walletUrl.isNotEmpty) {
                                        launchUrl(Uri.parse(walletUrl), mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    tooltip: 'Open in Google Wallet',
                                  ),
                                ],
                              ),
                            ),
                            if (barcodeValue.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Barcode Value:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF826695).withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      barcodeValue.length > 50 
                                          ? '${barcodeValue.substring(0, 50)}...' 
                                          : barcodeValue,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF2D223A),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    childCount: passes.isEmpty ? 1 : passes.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getWalletIcon(String type) {
    switch (type) {
      case 'shopping_list':
        return Icons.shopping_cart;
      case 'recipe':
        return Icons.restaurant;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Color _getWalletColor(String type) {
    switch (type) {
      case 'shopping_list':
        return const Color(0xFF4CAF50);
      case 'recipe':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF826695);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }



  Future<void> _processInventoryFromReceipts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? "testuser123";
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF826695)),
              SizedBox(width: 16),
              Text('Processing receipts for inventory...'),
            ],
          ),
        ),
      );
      
      // Call the add_inventories endpoint
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8080/add_inventories'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'user_id': userId,
          'process_all': 'true',
        },
      );
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully processed ${data['items_count'] ?? 0} items'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        // Switch to inventory tab to show the updated data
        setState(() {
          _currentIndex = 3; // Switch to inventory tab
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process inventory: ${res.statusCode}'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing inventory: $e'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }
}

class GlassmorphicFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  const GlassmorphicFAB({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF826695).withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF826695).withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ScanOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF826695), size: 28),
              const SizedBox(width: 18),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF2D223A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<dynamic> _inventory = [];
  List<dynamic> _recipes = [];
  List<dynamic> _expiringItems = [];
  bool _isLoading = true;
  bool _isRecipesLoading = true;
  bool _isExpiringLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _fetchRecipes();
    _fetchExpiringItems();
  }

  Future<void> _fetchInventory() async {
    setState(() { 
      _isLoading = true; 
      _errorMessage = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      // Use testuser123 for now to match the API data
      final userId = "testuser123";
      print("Fetching inventory for user: $userId");
      
      final url = 'http://10.0.2.2:8080/get_inventories?order=desc&user_id=$userId';
      print("Making API call to: $url");
      final res = await http.get(Uri.parse(url));
      print("Inventory API response status: ${res.statusCode}");
      print("Inventory API response body: ${res.body}");
      
      List<dynamic> inventoryList = [];
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data.containsKey('inventories')) {
          inventoryList = data['inventories'] as List;
        } else if (data is List) {
          inventoryList = data;
        }
        print("Parsed inventory items: ${inventoryList.length}");
      } else {
        print("Inventory API error: ${res.statusCode} - ${res.body}");
        _errorMessage = "Failed to load inventory: ${res.statusCode}";
      }
      
      setState(() {
        _inventory = inventoryList;
        _isLoading = false;
      });
    } catch (e) {
      print("Inventory fetch error: $e");
      setState(() { 
        _isLoading = false; 
        _errorMessage = "Error loading inventory: $e";
      });
    }
  }

  Future<void> _fetchRecipes() async {
    setState(() { 
      _isRecipesLoading = true; 
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = "testuser123";
      print("Fetching recipes for user: $userId");
      
      final res = await http.get(Uri.parse('http://10.0.2.2:8080/get_recipes?user_id=$userId'));
      print("Recipes API response status: ${res.statusCode}");
      print("Recipes API response body: ${res.body}");
      
      List<dynamic> recipesList = [];
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          recipesList = data;
        } else if (data is Map && data.containsKey('recipes')) {
          recipesList = data['recipes'] as List;
        }
        print("Parsed recipes: ${recipesList.length}");
      }
      
      setState(() {
        _recipes = recipesList;
        _isRecipesLoading = false;
      });
    } catch (e) {
      print("Recipes fetch error: $e");
      setState(() { 
        _isRecipesLoading = false; 
      });
    }
  }

  Future<void> _fetchExpiringItems() async {
    setState(() { 
      _isExpiringLoading = true; 
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = "testuser123";
      print("Fetching expiring items for user: $userId");
      
      final res = await http.get(Uri.parse('http://10.0.2.2:8080/retrieve_expirations?user_id=$userId'));
      print("Expiring items API response status: ${res.statusCode}");
      print("Expiring items API response body: ${res.body}");
      
      List<dynamic> expiringList = [];
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data.containsKey('expiring_items')) {
          expiringList = data['expiring_items'] as List;
        }
        print("Parsed expiring items: ${expiringList.length}");
      }
      
      setState(() {
        _expiringItems = expiringList;
        _isExpiringLoading = false;
      });
    } catch (e) {
      print("Expiring items fetch error: $e");
      setState(() { 
        _isExpiringLoading = false; 
      });
    }
  }

  Future<void> _processInventoryFromReceipts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? "testuser123";
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF826695)),
              SizedBox(width: 16),
              Text('Processing receipts for inventory...'),
            ],
          ),
        ),
      );
      
      // Call the add_inventories endpoint
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8080/add_inventories'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'user_id': userId,
          'process_all': 'true',
        },
      );
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully processed ${data['items_count'] ?? 0} items'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        // Refresh the inventory
        await _fetchInventory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process inventory: ${res.statusCode}'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing inventory: $e'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  void _showEnhancedFullList(String title, List<dynamic> items, Widget Function(dynamic) itemBuilder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D223A),
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF826695).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length} items',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF826695),
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: const Color(0xFF826695).withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items found',
                              style: TextStyle(
                                color: const Color(0xFF826695).withOpacity(0.7),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Items will appear here when available',
                              style: TextStyle(
                                color: const Color(0xFF826695).withOpacity(0.5),
                                fontSize: 14,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) => itemBuilder(items[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullList(String title, List<dynamic> items, Widget Function(dynamic) itemBuilder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF826695))),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) => itemBuilder(items[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FA), Color(0xFFF5F5F7)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF826695),
                  backgroundColor: Color(0xFFEDEAF6),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Loading your inventory...',
                style: TextStyle(
                  color: Color(0xFF826695),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Montserrat',
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This may take a few moments',
                style: TextStyle(
                  color: Color(0xFF826695),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error message if there's an error
    if (_errorMessage != null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FA), Color(0xFFF5F5F7)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    color: Color(0xFF2D223A),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFF826695),
                    fontSize: 14,
                    fontFamily: 'Roboto',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    _fetchInventory();
                    _fetchRecipes();
                    _fetchExpiringItems();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF826695),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F9FA), Color(0xFFF5F5F7)],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await _fetchInventory();
          await _fetchRecipes();
          await _fetchExpiringItems();
        },
        color: const Color(0xFF826695),
        backgroundColor: Colors.white,
        child: CustomScrollView(
          slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Inventory',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D223A),
                        fontFamily: 'Montserrat',
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your items, track expirations, and discover recipes',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF826695).withOpacity(0.8),
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Inventory Overview Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildOverviewCard(),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            
            // Inventory Items Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildEnhancedPreviewCard(
                  title: 'Inventory Items',
                  subtitle: '${_inventory.length} items in your pantry',
                  items: _inventory,
                  previewCount: 3,
                  itemBuilder: (item) => _buildEnhancedInventoryTile(item),
                  onExpand: () => _showEnhancedFullList('All Inventory Items', _inventory, (item) => _buildEnhancedInventoryTile(item)),
                  showProcessButton: true,
                  onProcess: _processInventoryFromReceipts,
                  icon: Icons.inventory_2_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF826695), Color(0xFF9B7BB8)],
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            
            // Expiring Soon Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildEnhancedPreviewCard(
                  title: 'Expiring Soon',
                  subtitle: '${_expiringItems.length} items need attention',
                  items: _expiringItems,
                  previewCount: 3,
                  itemBuilder: (item) => _isExpiringLoading
                      ? _buildLoadingTile()
                      : _buildEnhancedExpiringTile(item),
                  onExpand: () => _showEnhancedFullList('Expiring Soon', _expiringItems, (item) => _buildEnhancedExpiringTile(item)),
                  icon: Icons.warning_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            
            // Recipes Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildEnhancedPreviewCard(
                  title: 'Recipe Suggestions',
                  subtitle: '${_recipes.length} recipes based on your inventory',
                  items: _recipes,
                  previewCount: 3,
                  itemBuilder: (item) => _isRecipesLoading
                      ? _buildLoadingTile()
                      : _buildEnhancedRecipeTile(item),
                  onExpand: () => _showEnhancedFullList('Recipe Suggestions', _recipes, (item) => _buildEnhancedRecipeTile(item)),
                  icon: Icons.restaurant_menu_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final totalItems = _inventory.length;
    final expiringItems = _expiringItems.length;
    final recipeCount = _recipes.length;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF826695), Color(0xFF9B7BB8)],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Inventory Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.inventory_2_rounded,
                  label: 'Total Items',
                  value: totalItems.toString(),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.warning_rounded,
                  label: 'Expiring Soon',
                  value: expiringItems.toString(),
                  color: const Color(0xFFFFB74D),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Recipes',
                  value: recipeCount.toString(),
                  color: const Color(0xFF66BB6A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPreviewCard({
    required String title,
    required String subtitle,
    required List<dynamic> items,
    required int previewCount,
    required Widget Function(dynamic) itemBuilder,
    required VoidCallback onExpand,
    bool showProcessButton = false,
    VoidCallback? onProcess,
    required IconData icon,
    required LinearGradient gradient,
  }) {
    final previewItems = items.take(previewCount).toList();
    final showExpand = items.length > previewCount;
    
    return Container(
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
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
                if (showProcessButton && onProcess != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                      onPressed: onProcess,
                      tooltip: 'Process receipts for inventory',
                    ),
                  ),
                if (showExpand)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.expand_more, color: Colors.white),
                      onPressed: onExpand,
                      tooltip: 'Show all',
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (previewItems.isNotEmpty) ...[
                  ...previewItems.map(itemBuilder),
                  if (showExpand)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: TextButton(
                          onPressed: onExpand,
                          child: Text(
                            'View all ${items.length} items',
                            style: const TextStyle(
                              color: Color(0xFF826695),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ),
                    ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          size: 48,
                          color: const Color(0xFF826695).withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items yet',
                          style: TextStyle(
                            color: const Color(0xFF826695).withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your items will appear here',
                          style: TextStyle(
                            color: const Color(0xFF826695).withOpacity(0.5),
                            fontSize: 14,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF826695),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading...',
            style: TextStyle(
              color: const Color(0xFF826695).withOpacity(0.7),
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard({
    required String title,
    required List<dynamic> items,
    required int previewCount,
    required Color cardBg,
    required Widget Function(dynamic) itemBuilder,
    required VoidCallback onExpand,
    bool showProcessButton = false,
    VoidCallback? onProcess,
  }) {
    final previewItems = items.take(previewCount).toList();
    final showExpand = items.length > previewCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF826695).withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF826695))),
              const Spacer(),
              if (showProcessButton && onProcess != null)
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart, color: Color(0xFF826695)),
                  onPressed: onProcess,
                  tooltip: 'Process receipts for inventory',
                ),
              if (showExpand)
                IconButton(
                  icon: const Icon(Icons.expand_more, color: Color(0xFF826695)),
                  onPressed: onExpand,
                  tooltip: 'Show all',
                ),
            ],
          ),
          ...previewItems.map(itemBuilder),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No items', style: TextStyle(color: Color(0xFF826695))),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInventoryTile(dynamic item) {
    final itemName = item['item_name'] ?? 'Unknown Item';
    final count = item['count'] ?? 0;
    final expiryDate = item['expiryDate'] ?? '';
    final lastBought = item['last_bought_date'] ?? '';
    
    // Calculate days until expiry if expiry date exists
    int? daysUntilExpiry;
    if (expiryDate.isNotEmpty) {
      try {
        final expiry = DateTime.parse(expiryDate);
        final now = DateTime.now();
        daysUntilExpiry = expiry.difference(now).inDays;
      } catch (e) {
        print("Error parsing expiry date: $e");
      }
    }
    
    // Determine if item is expiring soon
    bool isExpiringSoon = daysUntilExpiry != null && daysUntilExpiry <= 7;
    bool isExpired = daysUntilExpiry != null && daysUntilExpiry < 0;
    
    Color statusColor;
    Color backgroundColor;
    IconData statusIcon;
    
    if (isExpired) {
      statusColor = const Color(0xFFD32F2F);
      backgroundColor = const Color(0xFFFFEBEE);
      statusIcon = Icons.error_rounded;
    } else if (isExpiringSoon) {
      statusColor = const Color(0xFFFF9800);
      backgroundColor = const Color(0xFFFFF3E0);
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = const Color(0xFF4CAF50);
      backgroundColor = const Color(0xFFE8F5E8);
      statusIcon = Icons.check_circle_rounded;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: statusColor,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Qty: $count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                      if (daysUntilExpiry != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isExpired ? 'EXPIRED' :
                            daysUntilExpiry <= 1 ? 'TODAY' :
                            daysUntilExpiry <= 3 ? 'SOON' :
                            '$daysUntilExpiry days',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (expiryDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: statusColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Expires: ${expiryDate}',
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTile(dynamic item, Color cardBg, {bool warning = false}) {
    final itemName = item['item_name'] ?? 'Unknown Item';
    final count = item['count'] ?? 0;
    final expiryDate = item['expiryDate'] ?? '';
    final lastBought = item['last_bought_date'] ?? '';
    
    // Calculate days until expiry if expiry date exists
    int? daysUntilExpiry;
    if (expiryDate.isNotEmpty) {
      try {
        final expiry = DateTime.parse(expiryDate);
        final now = DateTime.now();
        daysUntilExpiry = expiry.difference(now).inDays;
      } catch (e) {
        print("Error parsing expiry date: $e");
      }
    }
    
    // Determine if item is expiring soon
    bool isExpiringSoon = daysUntilExpiry != null && daysUntilExpiry <= 7;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpiringSoon ? const Color(0xFFFFF3E0) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isExpiringSoon ? Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded, 
                color: isExpiringSoon ? const Color(0xFFFF9800) : const Color(0xFF826695)
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isExpiringSoon ? const Color(0xFFFF9800) : const Color(0xFF2D223A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF826695).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Qty: $count',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF826695),
                  ),
                ),
              ),
            ],
          ),
          if (expiryDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: isExpiringSoon ? const Color(0xFFFF9800) : const Color(0xFF826695).withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Expires: ${expiryDate}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpiringSoon ? const Color(0xFFFF9800) : const Color(0xFF826695).withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (daysUntilExpiry != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isExpiringSoon ? const Color(0xFFFF9800).withOpacity(0.1) : const Color(0xFF826695).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      daysUntilExpiry <= 0 ? 'EXPIRED' :
                      daysUntilExpiry <= 1 ? 'TODAY' :
                      daysUntilExpiry <= 3 ? 'SOON' :
                      '$daysUntilExpiry days',
                      style: TextStyle(
                        fontSize: 10,
                        color: isExpiringSoon ? const Color(0xFFFF9800) : const Color(0xFF826695),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedExpiringTile(dynamic item) {
    final itemName = item['item_name'] ?? 'Unknown Item';
    final count = item['count'] ?? 0;
    final expiryDate = item['expiry_date'] ?? '';
    final daysUntilExpiry = item['days_until_expiry'] ?? 0;
    final urgency = item['urgency'] ?? 'low';
    final urgencyMessage = item['urgency_message'] ?? '';
    
    // Define colors based on urgency
    Color urgencyColor;
    Color backgroundColor;
    IconData urgencyIcon;
    
    switch (urgency) {
      case 'critical':
        urgencyColor = const Color(0xFFD32F2F);
        backgroundColor = const Color(0xFFFFEBEE);
        urgencyIcon = Icons.error_rounded;
        break;
      case 'high':
        urgencyColor = const Color(0xFFF57C00);
        backgroundColor = const Color(0xFFFFF3E0);
        urgencyIcon = Icons.warning_rounded;
        break;
      case 'medium':
        urgencyColor = const Color(0xFFFF9800);
        backgroundColor = const Color(0xFFFFF8E1);
        urgencyIcon = Icons.schedule_rounded;
        break;
      default:
        urgencyColor = const Color(0xFF4CAF50);
        backgroundColor = const Color(0xFFE8F5E8);
        urgencyIcon = Icons.check_circle_rounded;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgencyColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: urgencyColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                urgencyIcon,
                color: urgencyColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: urgencyColor,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: urgencyColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Qty: $count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: urgencyColor,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: urgencyColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          urgency == 'critical' ? 'URGENT' :
                          urgency == 'high' ? 'SOON' :
                          urgency == 'medium' ? 'WEEK' :
                          'OK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: urgencyColor,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: urgencyColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          urgencyMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: urgencyColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringTile(dynamic item, Color cardBg) {
    final itemName = item['item_name'] ?? 'Unknown Item';
    final count = item['count'] ?? 0;
    final expiryDate = item['expiry_date'] ?? '';
    final daysUntilExpiry = item['days_until_expiry'] ?? 0;
    final urgency = item['urgency'] ?? 'low';
    final urgencyMessage = item['urgency_message'] ?? '';
    
    // Define colors based on urgency
    Color urgencyColor;
    Color backgroundColor;
    switch (urgency) {
      case 'critical':
        urgencyColor = const Color(0xFFD32F2F);
        backgroundColor = const Color(0xFFFFEBEE);
        break;
      case 'high':
        urgencyColor = const Color(0xFFF57C00);
        backgroundColor = const Color(0xFFFFF3E0);
        break;
      case 'medium':
        urgencyColor = const Color(0xFFFF9800);
        backgroundColor = const Color(0xFFFFF8E1);
        break;
      default:
        urgencyColor = const Color(0xFF4CAF50);
        backgroundColor = const Color(0xFFE8F5E8);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgencyColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: urgencyColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: urgencyColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quantity: $count',
                      style: TextStyle(
                        fontSize: 13,
                        color: urgencyColor.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  urgency == 'critical' ? 'URGENT' :
                  urgency == 'high' ? 'SOON' :
                  urgency == 'medium' ? 'WEEK' :
                  'OK',
                  style: TextStyle(
                    fontSize: 11,
                    color: urgencyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: urgencyColor.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                urgencyMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: urgencyColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedRecipeTile(dynamic item) {
    final recipeName = item['recipe'] ?? item['name'] ?? '';
    final ingredients = (item['ingredients'] as List?)?.cast<String>() ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recipeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D223A),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ingredients.isNotEmpty) ...[
              Text(
                'Ingredients:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF826695).withOpacity(0.8),
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ingredients.map((ingredient) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
                  ),
                  child: Text(
                    ingredient,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeTile(dynamic item, Color cardBg) {
    final recipeName = item['recipe'] ?? item['name'] ?? '';
    final ingredients = (item['ingredients'] as List?)?.cast<String>() ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF826695).withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipeName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF826695),
            ),
          ),
          const SizedBox(height: 8),
          if (ingredients.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: ingredients.map((ingredient) => Chip(
                label: Text(
                  ingredient,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF826695)),
                ),
                backgroundColor: const Color(0xFFF5F5F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: const Color(0xFF826695).withOpacity(0.08)),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }
}

