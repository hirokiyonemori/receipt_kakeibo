import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'database_helper.dart';
import 'history_screen.dart';
import 'package:permission_handler/permission_handler.dart';

String extractAmount(String text) {
  final yenPattern = RegExp(r'(¥|￥)?\s?(\d{1,3}(,\d{3})+|\d+)(円)?');
  final match = yenPattern.firstMatch(text);
  return match?.group(0) ?? '未検出';
}

String extractDate(String text) {
  final datePattern = RegExp(r'\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}');
  final match = datePattern.firstMatch(text);
  return match?.group(0) ?? '未検出';
}

String extractStoreName(String text) {
  // 簡易版：1行目 or 最上部に出てくる大きな文字を仮の店名とする
  final lines = text.split('\n');
  for (String line in lines) {
    if (line.length > 4 && !line.contains(RegExp(r'\d'))) {
      return line.trim();
    }
  }
  return '未検出';
}

Future<void> requestPermissions() async {
  await Permission.camera.request();
  await Permission.photos.request();
}

void main() {
  runApp(MaterialApp(
    home: OCRScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class OCRScreen extends StatefulWidget {
  @override
  _OCRScreenState createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  String extractedText = '';
  String extractedAmount = '';
  String extractedDate = '';
  String extractedStoreName = '';
  File? _image;
  final dbHelper = DatabaseHelper();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Future<bool> _ensurePermission(
    Permission permission,
    String deniedMessage,
  ) async {
    final status = await permission.status;
    if (status.isGranted) {
      return true;
    }

    final result = await permission.request();
    if (result.isGranted) {
      return true;
    }

    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }

    if (mounted) {
      _showSnackBar(deniedMessage);
    }
    return false;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> _pickImage() async {
    if (!await _ensurePermission(Permission.camera, 'カメラ権限が必要です')) {
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        _showSnackBar('画像が選択されませんでした');
        return;
      }

      await _handleImage(image);
    } catch (e) {
      _showSnackBar('カメラ起動に失敗しました: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (!await _ensurePermission(Permission.photos, 'フォトライブラリ権限が必要です')) {
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        _showSnackBar('画像が選択されませんでした');
        return;
      }

      await _handleImage(image);
    } catch (e) {
      _showSnackBar('画像の取得に失敗しました: $e');
    }
  }

  Future<void> _handleImage(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      final String rawText = recognizedText.text;

      if (!mounted) return;
      setState(() {
        _image = File(image.path);
        extractedText = rawText;

        // 抽出したテキストから情報を取り出す
        _dateController.text = extractDate(extractedText);
        _storeController.text = extractStoreName(extractedText);
        _amountController.text = extractAmount(extractedText);
      });
    } catch (e) {
      _showSnackBar('文字認識に失敗しました: $e');
    } finally {
      await textRecognizer.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('レシート読み取りOCR')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.camera_alt),
                  label: Text('カメラで撮影'),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: Icon(Icons.photo_library),
                  label: Text('ギャラリーから選択'),
                ),
              ],
            ),
            SizedBox(height: 16),
            _image != null ? Image.file(_image!, height: 200) : Container(),
            SizedBox(height: 16),
            if (extractedText.isNotEmpty) ...[
              TextField(
                controller: _dateController,
                decoration: InputDecoration(labelText: '日付'),
              ),
              TextField(
                controller: _storeController,
                decoration: InputDecoration(labelText: '店舗名'),
              ),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(labelText: '金額'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_amountController.text.isNotEmpty && _dateController.text.isNotEmpty) {
                    await dbHelper.insert({
                      'date': _dateController.text,
                      'store': _storeController.text,
                      'amount': _amountController.text,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('保存しました！')),
                    );
                  }
                },
                child: Text('登録'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistoryScreen()),
                  );
                },
                child: Text('履歴を見る'),
              ),
              SizedBox(height: 16),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Text(extractedText),
              ),
            )
          ],
        ),
      ),
    );
  }
}
