import 'package:flutter/material.dart';

class ReceiptEditScreen extends StatefulWidget {
  final String store;
  final String amount;
  final String date;

  const ReceiptEditScreen({
    required this.store,
    required this.amount,
    required this.date,
    super.key,
  });

  @override
  State<ReceiptEditScreen> createState() => _ReceiptEditScreenState();
}

class _ReceiptEditScreenState extends State<ReceiptEditScreen> {
  late TextEditingController _storeController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _storeController = TextEditingController(text: widget.store);
    _amountController = TextEditingController(text: widget.amount);
    _dateController = TextEditingController(text: widget.date);
  }

  @override
  void dispose() {
    _storeController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('レシート確認'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveReceipt,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📸 抽出された情報',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _storeController,
                        decoration: InputDecoration(
                          labelText: '🏪 店舗名',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.store),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '店舗名を入力してください';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: '💴 金額',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: '円',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '金額を入力してください';
                          }
                          if (int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                            return '有効な金額を入力してください';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: '📅 日付',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          hintText: '例: 2024/01/15',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '日付を入力してください';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveReceipt,
                icon: Icon(Icons.save),
                label: Text('登録する'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
              SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.cancel),
                label: Text('キャンセル'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveReceipt() {
    if (_formKey.currentState!.validate()) {
      final store = _storeController.text.trim();
      final amount = _amountController.text.trim();
      final date = _dateController.text.trim();

      Navigator.pop(context, {
        'store': store,
        'amount': amount,
        'date': date,
      });
    }
  }
} 