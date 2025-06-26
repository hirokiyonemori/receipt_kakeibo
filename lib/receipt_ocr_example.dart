import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper_enhanced.dart';
import 'receipt_list_screen.dart';
import 'receipt_list_page.dart';
import 'receipt_edit_screen.dart';

class ReceiptOCRPage extends StatefulWidget {
  @override
  _ReceiptOCRPageState createState() => _ReceiptOCRPageState();
}

class _ReceiptOCRPageState extends State<ReceiptOCRPage> {
  File? _image;
  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.photos.request();
  }

  // カメラテスト用の簡単なメソッド
  Future<void> _testCameraOnly() async {
    try {
      print('🔍 カメラテスト開始');
      
      // 権限チェック
      final cameraStatus = await Permission.camera.status;
      print('📱 カメラ権限状態: $cameraStatus');
      
      if (cameraStatus.isDenied) {
        final result = await Permission.camera.request();
        print('📱 カメラ権限結果: $result');
        
        if (result.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('カメラ権限が必要です')),
          );
          return;
        }
      }
      
      print('🔍 ImagePicker起動');
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 70,
      );
      
      if (pickedFile == null) {
        print('❌ 画像が選択されませんでした');
        return;
      }
      
      print('✅ 画像選択完了: ${pickedFile.path}');
      
      setState(() {
        _image = File(pickedFile.path);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('カメラテスト成功！'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e, stackTrace) {
      print('❌ カメラテストエラー: $e');
      print('📱 スタックトレース: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('カメラエラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getImageAndRecognizeText() async {
    try {
      print('🔍 カメラ起動開始');
      
      // 権限チェック
      print('🔍 カメラ権限チェック');
      final cameraStatus = await Permission.camera.status;
      print('📱 カメラ権限状態: $cameraStatus');
      
      if (cameraStatus.isDenied) {
        print('🔍 カメラ権限を要求');
        final result = await Permission.camera.request();
        print('📱 カメラ権限結果: $result');
        
        if (result.isDenied) {
          print('❌ カメラ権限が拒否されました');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('カメラ権限が必要です')),
          );
          return;
        }
      }
      
      print('🔍 ImagePicker起動');
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        print('❌ 画像が選択されませんでした');
        return;
      }
      
      print('✅ 画像選択完了: ${pickedFile.path}');
      print('📱 ファイルサイズ: ${await File(pickedFile.path).length()} bytes');

      setState(() {
        _image = File(pickedFile.path);
      });
      print('✅ 画像表示設定完了');

      print('🔍 OCR処理開始');
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      print('✅ InputImage作成完了');
      
      final textRecognizer = TextRecognizer();
      print('✅ TextRecognizer作成完了');
      
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      print('✅ OCR処理完了');

      String text = recognizedText.text;
      print('✅ OCR完了: ${text.length}文字抽出');
      print('📝 抽出テキスト: $text');
      
      // Extract information using enhanced patterns
      final extractedStore = _extractStore(text);
      final extractedDate = _extractDate(text);
      final extractedAmount = _extractAmount(text);
      print('✅ 情報抽出完了: 店舗=$extractedStore, 日付=$extractedDate, 金額=$extractedAmount');

      textRecognizer.close();
      print('✅ TextRecognizerクローズ完了');

      print('🔍 編集画面へ遷移');
      // Navigate to edit screen with extracted data
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptEditScreen(
            store: extractedStore ?? '',
            amount: extractedAmount ?? '',
            date: extractedDate ?? '',
          ),
        ),
      );

      // Handle the result from edit screen
      if (result != null) {
        print('🔍 データ保存開始');
        try {
          await DatabaseHelper().insertReceipt(
            result['store'],
            result['date'],
            result['amount'],
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('登録しました！'),
              backgroundColor: Colors.green,
            ),
          );

          // Clear the image after successful save
          setState(() {
            _image = null;
          });
          print('✅ 保存完了');
        } catch (e) {
          print('❌ 保存エラー: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('❌ 編集画面でキャンセルされました');
      }
    } catch (e, stackTrace) {
      print('❌ 予期しないエラー: $e');
      print('📱 スタックトレース: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      print('🔍 ギャラリー起動開始');
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        print('❌ 画像が選択されませんでした');
        return;
      }
      print('✅ 画像選択完了: ${pickedFile.path}');

      setState(() {
        _image = File(pickedFile.path);
      });
      print('✅ 画像表示設定完了');

      print('🔍 OCR処理開始');
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      String text = recognizedText.text;
      print('✅ OCR完了: ${text.length}文字抽出');
      
      // Extract information
      final extractedStore = _extractStore(text);
      final extractedDate = _extractDate(text);
      final extractedAmount = _extractAmount(text);
      print('✅ 情報抽出完了: 店舗=$extractedStore, 日付=$extractedDate, 金額=$extractedAmount');

      textRecognizer.close();

      print('🔍 編集画面へ遷移');
      // Navigate to edit screen with extracted data
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptEditScreen(
            store: extractedStore ?? '',
            amount: extractedAmount ?? '',
            date: extractedDate ?? '',
          ),
        ),
      );

      // Handle the result from edit screen
      if (result != null) {
        print('🔍 データ保存開始');
        try {
          await DatabaseHelper().insertReceipt(
            result['store'],
            result['date'],
            result['amount'],
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('登録しました！'),
              backgroundColor: Colors.green,
            ),
          );

          // Clear the image after successful save
          setState(() {
            _image = null;
          });
          print('✅ 保存完了');
        } catch (e) {
          print('❌ 保存エラー: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('❌ 編集画面でキャンセルされました');
      }
    } catch (e) {
      print('❌ 予期しないエラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _extractStore(String text) {
    // Enhanced store name extraction
    final lines = text.split('\n');
    for (String line in lines) {
      // Look for lines that are likely store names (no numbers, reasonable length)
      if (line.length > 3 && line.length < 50 && 
          !line.contains(RegExp(r'\d')) && 
          !line.contains('¥') && 
          !line.contains('￥')) {
        return line.trim();
      }
    }
    return lines.isNotEmpty ? lines.first.trim() : null;
  }

  String? _extractDate(String text) {
    // Enhanced date extraction for Japanese receipts
    final patterns = [
      RegExp(r'\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}'), // 2024/01/15 or 2024年1月15日
      RegExp(r'\d{1,2}[-/.月]\d{1,2}'), // 1/15 or 1月15日
      RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'), // 2024-01-15
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  String? _extractAmount(String text) {
    // Enhanced amount extraction for Japanese receipts
    final patterns = [
      RegExp(r'(¥|￥)?\s?(\d{1,3}(,\d{3})+|\d+)(円)?'), // ¥1,000 or 1000円
      RegExp(r'合計\s*[:：]\s*(¥|￥)?\s?(\d{1,3}(,\d{3})+|\d+)(円)?'), // 合計: ¥1,000
      RegExp(r'税込\s*[:：]\s*(¥|￥)?\s?(\d{1,3}(,\d{3})+|\d+)(円)?'), // 税込: ¥1,000
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  // より安全なカメラ実装
  Future<void> _safeCameraCapture() async {
    try {
      print('🔍 安全なカメラ起動開始');
      
      // 1. 権限チェック
      print('🔍 権限チェック開始');
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      
      print('📱 カメラ権限: $cameraStatus');
      print('📱 写真権限: $photosStatus');
      
      // 2. 権限要求
      if (cameraStatus.isDenied) {
        print('🔍 カメラ権限を要求');
        final cameraResult = await Permission.camera.request();
        print('📱 カメラ権限結果: $cameraResult');
        
        if (cameraResult.isDenied || cameraResult.isPermanentlyDenied) {
          print('❌ カメラ権限が拒否されました');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('カメラ権限が必要です。設定で権限を許可してください。'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      if (photosStatus.isDenied) {
        print('🔍 写真権限を要求');
        final photosResult = await Permission.photos.request();
        print('📱 写真権限結果: $photosResult');
      }
      
      // 3. ImagePicker設定
      print('🔍 ImagePicker設定');
      final ImagePicker picker = ImagePicker();
      
      // 4. カメラ起動
      print('🔍 カメラ起動');
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (pickedFile == null) {
        print('❌ 画像が選択されませんでした');
        return;
      }
      
      print('✅ 画像選択完了: ${pickedFile.path}');
      
      // 5. ファイル存在確認
      final file = File(pickedFile.path);
      if (!await file.exists()) {
        print('❌ ファイルが存在しません: ${pickedFile.path}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像ファイルが見つかりません')),
        );
        return;
      }
      
      final fileSize = await file.length();
      print('📱 ファイルサイズ: $fileSize bytes');
      
      if (fileSize == 0) {
        print('❌ ファイルサイズが0です');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像ファイルが空です')),
        );
        return;
      }
      
      // 6. UI更新
      setState(() {
        _image = file;
      });
      
      print('✅ 画像表示完了');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('カメラ撮影成功！'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e, stackTrace) {
      print('❌ カメラエラー: $e');
      print('📱 スタックトレース: $stackTrace');
      
      String errorMessage = 'カメラエラーが発生しました';
      if (e.toString().contains('permission')) {
        errorMessage = 'カメラ権限が不足しています';
      } else if (e.toString().contains('camera')) {
        errorMessage = 'カメラが使用できません';
      } else if (e.toString().contains('file')) {
        errorMessage = 'ファイルアクセスエラー';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('レシートOCR'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReceiptListPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Image capture buttons
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _getImageAndRecognizeText,
                  icon: Icon(Icons.camera_alt),
                  label: Text('カメラ'),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: Icon(Icons.photo_library),
                  label: Text('ギャラリー'),
                ),
              ],
            ),
            SizedBox(height: 12),
            // カメラテストボタン
            ElevatedButton.icon(
              onPressed: _testCameraOnly,
              icon: Icon(Icons.camera),
              label: Text('カメラテスト'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            // 安全なカメラボタン
            ElevatedButton.icon(
              onPressed: _safeCameraCapture,
              icon: Icon(Icons.camera_alt),
              label: Text('安全カメラ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            
            SizedBox(height: 16),
            
            // Display captured image
            if (_image != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '📸 撮影された画像',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 16),
                      Image.file(_image!, height: 200),
                      SizedBox(height: 16),
                      Text(
                        '画像を処理中...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            SizedBox(height: 20),
            
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 使用方法',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('1. カメラで撮影またはギャラリーから選択'),
                    Text('2. OCRでテキストを自動抽出'),
                    Text('3. 確認画面で情報を編集'),
                    Text('4. 登録ボタンで保存'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 