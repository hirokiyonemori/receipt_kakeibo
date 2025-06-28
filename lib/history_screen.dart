import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _expenses = [];
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _registrationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    if (Platform.isAndroid) {
      _loadBannerAd();
    }
    _loadRegistrationCount();
  }

  Future<void> _loadRegistrationCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('registration_count') ?? 0;
    setState(() {
      _registrationCount = count;
    });
  }

  void _loadBannerAd() {
    if (!Platform.isAndroid) return;
    
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-8148356110096114/3236336102', // 本番用ID
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  Future<void> _loadExpenses() async {
    final dbHelper = DatabaseHelper();
    final expenses = await dbHelper.queryAllRows();
    setState(() {
      _expenses = expenses.reversed.toList();
    });
  }

  Future<void> _deleteExpense(int id) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.delete(id);
    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('家計簿履歴'),
        actions: [
          // 登録カウントを表示
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '登録回数: $_registrationCount',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _expenses.isEmpty
                ? Center(child: Text('まだ登録されていません'))
                : ListView.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final item = _expenses[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text('💴 ${item['amount']}'),
                          subtitle: Text('📅 ${item['date']}　🏪 ${item['store']}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteExpense(item['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // バナー広告（Androidのみ）
          if (Platform.isAndroid && _isAdLoaded)
            Container(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _bannerAd?.dispose();
    }
    super.dispose();
  }
} 