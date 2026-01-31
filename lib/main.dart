import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// اسم صندوق البيانات
const String kInvoicesBox = 'invoices_box';

void main() async {
  // تهيئة Hive (قاعدة البيانات) قبل تشغيل التطبيق
  await Hive.initFlutter();
  await Hive.openBox(kInvoicesBox);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام إدارة الحلويات',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF673AB7),
          secondary: const Color(0xFFFFC107),
        ),
        fontFamily: 'Cairo',
      ),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const InvoiceScreen(),
    );
  }
}

// --- MODELS ---

class TrayType {
  final String id;
  final String name;
  final double defaultWeight;

  TrayType({required this.id, required this.name, required this.defaultWeight});
  
  // تحويل لـ JSON للحفظ
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'defaultWeight': defaultWeight};
  factory TrayType.fromJson(Map<String, dynamic> json) => 
      TrayType(id: json['id'], name: json['name'], defaultWeight: json['defaultWeight']);
}

class SweetType {
  final String id;
  final String name;
  final double price;

  SweetType({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory SweetType.fromJson(Map<String, dynamic> json) => 
      SweetType(id: json['id'], name: json['name'], price: json['price']);
}

class InvoiceItem {
  final String id;
  final SweetType sweet;
  final TrayType? tray;
  final double grossWeight;
  final double trayWeightUsed;
  final bool isReturn;

  InvoiceItem({
    required this.id,
    required this.sweet,
    this.tray,
    required this.grossWeight,
    required this.trayWeightUsed,
    required this.isReturn,
  });

  double get netWeight => grossWeight - trayWeightUsed;
  double get totalPrice {
    double value = netWeight * sweet.price;
    return isReturn ? -value : value;
  }

  // تحويل البيانات لـ Map لحفظها في Hive
  Map<String, dynamic> toJson() => {
    'id': id,
    'sweet': sweet.toJson(),
    'tray': tray?.toJson(),
    'grossWeight': grossWeight,
    'trayWeightUsed': trayWeightUsed,
    'isReturn': isReturn,
  };

  factory InvoiceItem.fromJson(Map<dynamic, dynamic> json) => InvoiceItem(
    id: json['id'],
    sweet: SweetType.fromJson(Map<String, dynamic>.from(json['sweet'])),
    tray: json['tray'] != null ? TrayType.fromJson(Map<String, dynamic>.from(json['tray'])) : null,
    grossWeight: json['grossWeight'],
    trayWeightUsed: json['trayWeightUsed'],
    isReturn: json['isReturn'],
  );
}

// --- SCREEN ---

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final Box _box = Hive.box(kInvoicesBox); // الوصول لقاعدة البيانات
  
  final List<TrayType> trays = [
    TrayType(id: '1', name: 'صاج مستطيل كبير', defaultWeight: 1.500),
    TrayType(id: '2', name: 'صاج مدور وسط', defaultWeight: 1.200),
    TrayType(id: '3', name: 'طبق فويل صغير', defaultWeight: 0.050),
    TrayType(id: '4', name: 'بدون صاج', defaultWeight: 0.0),
  ];

  final List<SweetType> sweets = [
    SweetType(id: '1', name: 'كنافة بالقشطة', price: 120),
    SweetType(id: '2', name: 'بسبوسة سادة', price: 80),
    SweetType(id: '3', name: 'بقلاوة مكسرات', price: 250),
    SweetType(id: '4', name: 'أصابع زينب', price: 60),
  ];

  List<InvoiceItem> currentItems = [];
  bool isReturnMode = false;
  SweetType? selectedSweet;
  TrayType? selectedTray;
  
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _trayWeightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData(); // استرجاع البيانات المحفوظة عند فتح التطبيق
  }

  // تحميل البيانات من Hive
  void _loadData() {
    List<dynamic>? savedList = _box.get('current_invoice');
    if (savedList != null) {
      setState(() {
        currentItems = savedList.map((e) => InvoiceItem.fromJson(e)).toList();
      });
    }
  }

  // حفظ البيانات
  void _saveData() {
    List<Map<String, dynamic>> jsonList = currentItems.map((e) => e.toJson()).toList();
    _box.put('current_invoice', jsonList);
  }

  @override
  void dispose() {
    _grossWeightController.dispose();
    _trayWeightController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (selectedSweet == null || _grossWeightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الصنف وإدخال الوزن')));
      return;
    }

    double gross = double.tryParse(_grossWeightController.text) ?? 0;
    double trayW = double.tryParse(_trayWeightController.text) ?? 0;

    if (gross <= trayW) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ: الوزن القائم أقل من وزن الصاج!')));
      return;
    }

    setState(() {
      currentItems.add(InvoiceItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sweet: selectedSweet!,
        tray: selectedTray,
        grossWeight: gross,
        trayWeightUsed: trayW,
        isReturn: isReturnMode,
      ));
      _saveData(); // حفظ تلقائي
      _grossWeightController.clear();
    });
  }

  void _deleteItem(String id) {
    setState(() {
      currentItems.removeWhere((element) => element.id == id);
      _saveData(); // حفظ التعديل
    });
  }

  // دالة تصدير الإكسل
  Future<void> _exportExcel() async {
    if (currentItems.isEmpty) return;

    var excel = Excel.createExcel();
    Sheet sheet = excel['الفاتورة'];
    
    // إضافة العناوين
    sheet.appendRow([
      TextCellValue('م'), 
      TextCellValue('الصنف'), 
      TextCellValue('النوع'), 
      TextCellValue('قائم'), 
      TextCellValue('فارغ'), 
      TextCellValue('صافي'), 
      TextCellValue('السعر'), 
      TextCellValue('الإجمالي')
    ]);

    // إضافة البيانات
    int index = 1;
    for (var item in currentItems) {
      sheet.appendRow([
        IntCellValue(index),
        TextCellValue(item.sweet.name),
        TextCellValue(item.isReturn ? 'مرتجع' : 'بيع'),
        DoubleCellValue(item.grossWeight),
        DoubleCellValue(item.trayWeightUsed),
        DoubleCellValue(item.netWeight),
        DoubleCellValue(item.sweet.price),
        DoubleCellValue(item.totalPrice),
      ]);
      index++;
    }

    // إضافة المجموع النهائي
    sheet.appendRow([
      TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue('المجموع الكلي:'),
      DoubleCellValue(_grandTotal)
    ]);

    // حفظ الملف والمشاركة
    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      // مشاركة الملف
      await Share.shareXFiles([XFile(path)], text: 'فاتورة حلويات');
    }
  }

  double get _grandTotal => currentItems.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    final currencyFormat = intl.NumberFormat.currency(symbol: 'ج.م', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموازين'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever), 
            onPressed: () {
              // زر مسح الفاتورة بالكامل
              setState(() {
                currentItems.clear();
                _saveData();
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildInputSection(theme),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: currentItems.length,
              itemBuilder: (context, index) {
                final item = currentItems[currentItems.length - 1 - index];
                return _buildListItem(item, theme, currencyFormat);
              },
            ),
          ),
          _buildFooter(theme, currencyFormat),
        ],
      ),
    );
  }

  Widget _buildInputSection(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('بيع'), icon: Icon(Icons.outbox)),
                      ButtonSegment(value: true, label: Text('مرتجع'), icon: Icon(Icons.move_to_inbox)),
                    ],
                    selected: {isReturnMode},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() => isReturnMode = newSelection.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return isReturnMode ? Colors.red.shade100 : Colors.green.shade100;
                        }
                        return null;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<SweetType>(
                    decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                    value: selectedSweet,
                    items: sweets.map((s) => DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (val) => setState(() => selectedSweet = val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<TrayType>(
                    decoration: const InputDecoration(labelText: 'الصاج', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                    value: selectedTray,
                    items: trays.map((t) => DropdownMenuItem(value: t, child: Text(t.name, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedTray = val;
                        if (val != null) _trayWeightController.text = val.defaultWeight.toString();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _trayWeightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الفارغ', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _grossWeightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'القائم', border: OutlineInputBorder(), filled: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReturnMode ? Colors.red : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: Text(isReturnMode ? 'تسجيل مرتجع' : 'إضافة', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(InvoiceItem item, ThemeData theme, intl.NumberFormat format) {
    return Dismissible(
      key: Key(item.id),
      background: Container(color: Colors.red, alignment: Alignment.centerLeft, child: const Padding(padding: EdgeInsets.only(left: 20), child: Icon(Icons.delete, color: Colors.white))),
      onDismissed: (_) => _deleteItem(item.id),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isReturn ? Colors.red.shade100 : Colors.green.shade100,
          child: Icon(item.isReturn ? Icons.reply : Icons.check, size: 20, color: item.isReturn ? Colors.red : Colors.green),
        ),
        title: Text(item.sweet.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${item.grossWeight} - ${item.trayWeightUsed} = ${item.netWeight.toStringAsFixed(3)} كجم'),
        trailing: Text(
          format.format(item.totalPrice.abs()),
          style: TextStyle(fontWeight: FontWeight.bold, color: item.isReturn ? Colors.red : theme.colorScheme.primary, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, intl.NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(format.format(_grandTotal), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _exportExcel, // ربط الزر بدالة التصدير
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              icon: const Icon(Icons.table_view),
              label: const Text('تصدير Excel ومشاركة', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

