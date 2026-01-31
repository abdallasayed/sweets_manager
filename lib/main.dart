import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

void main() {
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
          seedColor: const Color(0xFF673AB7), // لون بنفسجي ملكي
          secondary: const Color(0xFFFFC107), // لون ذهبي للحلويات
        ),
        fontFamily: 'Cairo', // يفضل إضافة خط عربي لاحقاً
      ),
      // دعم اللغة العربية
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const InvoiceScreen(),
    );
  }
}

// --- MODELS (بيانات النظام) ---

// نوع الصاج
class TrayType {
  final String id;
  final String name;
  final double defaultWeight; // وزن الصاج فارغ بالكيلو

  TrayType({required this.id, required this.name, required this.defaultWeight});
}

// نوع الحلوى
class SweetType {
  final String id;
  final String name;
  final double price; // السعر للكيلو

  SweetType({required this.id, required this.name, required this.price});
}

// عنصر في الفاتورة
class InvoiceItem {
  final String id;
  final SweetType sweet;
  final TrayType? tray;
  final double grossWeight; // الوزن القائم
  final double trayWeightUsed; // وزن الصاج المستخدم فعلياً
  final bool isReturn; // هل هو مرتجع؟

  InvoiceItem({
    required this.id,
    required this.sweet,
    this.tray,
    required this.grossWeight,
    required this.trayWeightUsed,
    required this.isReturn,
  });

  // حساب الصافي
  double get netWeight => grossWeight - trayWeightUsed;
  
  // حساب السعر الإجمالي (سالب لو مرتجع)
  double get totalPrice {
    double value = netWeight * sweet.price;
    return isReturn ? -value : value;
  }
}

// --- SCREENS (الشاشات) ---

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // بيانات تجريبية (لاحقاً تأتي من قاعدة البيانات)
  final List<TrayType> trays = [
    TrayType(id: '1', name: 'صاج مستطيل كبير', defaultWeight: 1.500),
    TrayType(id: '2', name: 'صاج مدور وسط', defaultWeight: 1.200),
    TrayType(id: '3', name: 'طبق فويل صغير', defaultWeight: 0.050),
    TrayType(id: '4', name: 'بدون صاج (وزن صافي)', defaultWeight: 0.0),
  ];

  final List<SweetType> sweets = [
    SweetType(id: '1', name: 'كنافة بالقشطة', price: 120),
    SweetType(id: '2', name: 'بسبوسة سادة', price: 80),
    SweetType(id: '3', name: 'بقلاوة مكسرات', price: 250),
    SweetType(id: '4', name: 'أصابع زينب', price: 60),
  ];

  // حالة الإدخال الحالية
  List<InvoiceItem> currentItems = [];
  bool isReturnMode = false; // وضع المرتجعات
  SweetType? selectedSweet;
  TrayType? selectedTray;
  
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _trayWeightController = TextEditingController(); // لتعديل وزن الصاج

  @override
  void dispose() {
    _grossWeightController.dispose();
    _trayWeightController.dispose();
    super.dispose();
  }

  // دالة إضافة البند
  void _addItem() {
    if (selectedSweet == null || _grossWeightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الصنف وإدخال الوزن')),
      );
      return;
    }

    double gross = double.tryParse(_grossWeightController.text) ?? 0;
    double trayW = double.tryParse(_trayWeightController.text) ?? 0;

    if (gross <= trayW) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: الوزن القائم أقل من وزن الصاج!')),
      );
      return;
    }

    setState(() {
      currentItems.add(InvoiceItem(
        id: DateTime.now().toString(),
        sweet: selectedSweet!,
        tray: selectedTray,
        grossWeight: gross,
        trayWeightUsed: trayW,
        isReturn: isReturnMode,
      ));
      
      // تصفية الحقول بعد الإضافة
      _grossWeightController.clear();
      // لا نمسح نوع الصاج لتسهيل الإدخال المتكرر
    });
  }

  // دالة حساب إجمالي الفاتورة
  double get _grandTotal => currentItems.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموازين - منفذ 1'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)), // للإعدادات لاحقاً
        ],
      ),
      body: Column(
        children: [
          // 1. منطقة الإدخال (الوزن)
          _buildInputSection(theme),
          
          const Divider(height: 1),

          // 2. قائمة العناصر المضافة
          Expanded(
            child: ListView.builder(
              itemCount: currentItems.length,
              itemBuilder: (context, index) {
                final item = currentItems[currentItems.length - 1 - index]; // عرض الأحدث أولاً
                return _buildListItem(item, theme);
              },
            ),
          ),

          // 3. الفوتر (الإجمالي وتصدير)
          _buildFooter(theme),
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
            // زر التبديل بين بيع ومرتجع
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('بيع (خروج)'), icon: Icon(Icons.outbox)),
                      ButtonSegment(value: true, label: Text('مرتجع (دخول)'), icon: Icon(Icons.move_to_inbox)),
                    ],
                    selected: {isReturnMode},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        isReturnMode = newSelection.first;
                      });
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

            // اختيار الصنف والصاج
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<SweetType>(
                    decoration: const InputDecoration(labelText: 'اختر الصنف', border: OutlineInputBorder()),
                    value: selectedSweet,
                    items: sweets.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (val) => setState(() => selectedSweet = val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<TrayType>(
                    decoration: const InputDecoration(labelText: 'نوع الصاج', border: OutlineInputBorder()),
                    value: selectedTray,
                    items: trays.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedTray = val;
                        // تحديث حقل وزن الصاج تلقائياً عند الاختيار
                        if (val != null) {
                          _trayWeightController.text = val.defaultWeight.toString();
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // الأوزان
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _trayWeightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'وزن الفارغ (كجم)',
                      hintText: 'وزن الصاج',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.layers_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _grossWeightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الوزن القائم (كجم)',
                      hintText: 'من الميزان',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                      filled: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // زر الإضافة
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReturnMode ? Colors.red : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  isReturnMode ? 'تسجيل مرتجع' : 'إضافة للفاتورة',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(InvoiceItem item, ThemeData theme) {
    final currencyFormat = intl.NumberFormat.currency(symbol: 'ج.م', decimalDigits: 2);
    
    return Dismissible(
      key: Key(item.id),
      background: Container(color: Colors.red, alignment: Alignment.centerLeft, child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (direction) {
        setState(() {
          currentItems.removeWhere((element) => element.id == item.id);
        });
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isReturn ? Colors.red.shade100 : Colors.green.shade100,
          child: Icon(item.isReturn ? Icons.reply : Icons.check, color: item.isReturn ? Colors.red : Colors.green),
        ),
        title: Text(item.sweet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'قائم: ${item.grossWeight} - فارغ: ${item.trayWeightUsed} = صافي: ${item.netWeight.toStringAsFixed(3)} كجم',
          style: TextStyle(color: Colors.grey[700], fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(item.totalPrice.abs()),
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: item.isReturn ? Colors.red : theme.colorScheme.primary,
                fontSize: 16,
              ),
            ),
            if(item.isReturn) const Text('مرتجع', style: TextStyle(fontSize: 10, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final currencyFormat = intl.NumberFormat.currency(symbol: 'ج.م', decimalDigits: 2);
    
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
              const Text('إجمالي الفاتورة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                currencyFormat.format(_grandTotal),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // هنا نضع كود الحفظ وتصدير الإكسيل لاحقاً
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ محلي'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // كود المزامنة
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.table_view),
                  label: const Text('تصدير Excel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

