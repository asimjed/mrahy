import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors; 
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

List<Map<String, dynamic>> goatsList = [];

void main() => runApp(const FarmExpertApp());

class FarmExpertApp extends StatelessWidget {
  const FarmExpertApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(primaryColor: CupertinoColors.activeGreen),
      home: MainTabNavigation(),
    );
  }
}

class MainTabNavigation extends StatefulWidget {
  const MainTabNavigation({super.key});
  @override
  State<MainTabNavigation> createState() => _MainTabNavigationState();
}

class _MainTabNavigationState extends State<MainTabNavigation> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('my_farm_data_v2');
    if (savedData != null) {
      setState(() {
        Iterable decoded = json.decode(savedData);
        goatsList = List<Map<String, dynamic>>.from(decoded.map((item) => {
          ...item,
          'date': DateTime.parse(item['date'].toString()), 
        }));
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(goatsList.map((g) => {
      ...g,
      'date': (g['date'] as DateTime).toIso8601String(),
    }).toList());
    await prefs.setString('my_farm_data_v2', encodedData);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_pie_fill), label: 'الإحصائيات'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.add_circled_solid), label: 'إضافة'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.bandage_fill), label: 'المعيشة'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: 'السجل'),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0: return DashboardPage(onRefresh: () => setState(() {}));
          case 1: return AddGoatPage(onSave: () { setState(() {}); _saveData(); });
          case 2: return SpendingPage(onUpdate: () { setState(() {}); _saveData(); });
          case 3: return const InventoryPage();
          default: return const Center(child: Text("قيد التطوير"));
        }
      },
    );
  }
}

class DashboardPage extends StatelessWidget {
  final VoidCallback onRefresh;
  const DashboardPage({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    double totalCosts = 0;
    int kids = 0; 
    int adults = 0; 
    int sickCount = 0; 
    DateTime now = DateTime.now();

    for (var g in goatsList) {
      totalCosts += (g['purchasePrice'] as num).toDouble() + 
                    (g['foodCosts'] as num).toDouble() + 
                    (g['healthCosts'] as num).toDouble();
      
      DateTime dt = g['date'] as DateTime;
      int months = (now.year - dt.year) * 12 + (now.month - dt.month);
      
      if (months < 5) { kids++; } else { adults++; }
      if ((g['healthCosts'] as num) > 0) { sickCount++; }
    }

    double estimatedValue = (adults * 1300.0) + (kids * 600.0); 
    double profit = estimatedValue - totalCosts;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('إحصائيات المراح')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF81C784)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text("الربح التقديري الإجمالي", style: TextStyle(color: Colors.white70)),
                        Text("${profit.toStringAsFixed(0)} ر.س", 
                          style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStatCard("المواليد", "$kids", CupertinoColors.activeBlue),
                      _buildStatCard("البالغات", "$adults", CupertinoColors.activeGreen),
                      _buildStatCard("تحت العلاج", "$sickCount", CupertinoColors.systemRed),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMiniBox("إجمالي المصاريف", "${totalCosts.toStringAsFixed(0)} ر.س", CupertinoColors.label),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBox(String l, String v, Color c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(color: CupertinoColors.systemGrey)),
          Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }
}

class AddGoatPage extends StatefulWidget {
  final VoidCallback onSave;
  const AddGoatPage({super.key, required this.onSave});
  @override
  State<AddGoatPage> createState() => _AddGoatPageState();
}

class _AddGoatPageState extends State<AddGoatPage> {
  final TextEditingController _p = TextEditingController();
  final TextEditingController _i = TextEditingController();
  String _c = ""; bool _isBornInFarm = false; DateTime _d = DateTime.now();
  String? _imagePath;

  void _generateCode() => setState(() => _c = "${String.fromCharCode(Random().nextInt(26) + 65)}${Random().nextInt(900) + 100}");
  
  @override void initState() { super.initState(); _generateCode(); }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) { setState(() => _imagePath = image.path); }
  }

  void _showImageOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(child: const Text("الكاميرا"), onPressed: () { _pickImage(ImageSource.camera); Navigator.pop(context); }),
          CupertinoActionSheetAction(child: const Text("الاستوديو"), onPressed: () { _pickImage(ImageSource.gallery); Navigator.pop(context); }),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text("إلغاء"), onPressed: () => Navigator.pop(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("إضافة رأس جديد")),
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          GestureDetector(
            onTap: _showImageOptions,
            child: Container(
              height: 150,
              decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(15)),
              child: _imagePath == null 
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.camera, size: 40), Text("إضافة صورة")])
                : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(_imagePath!, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(CupertinoIcons.person))),
            ),
          ),
          const SizedBox(height: 20),
          CupertinoSegmentedControl<bool>(
            groupValue: _isBornInFarm,
            children: const {false: Text("مشتراه"), true: Text("مولودة بالمراح")},
            onValueChanged: (v) => setState(() => _isBornInFarm = v ?? false),
          ),
          const SizedBox(height: 15),
          Text("كود التتبع: $_c", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("تاريخ الميلاد / الشراء:"),
          SizedBox(height: 100, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, onDateTimeChanged: (dt) => _d = dt)),
          if (!_isBornInFarm) CupertinoTextField(controller: _p, placeholder: "سعر الشراء (ر.س)", keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          CupertinoTextField(controller: _i, placeholder: "ملاحظات إضافية", maxLines: 2),
          const SizedBox(height: 30),
          CupertinoButton.filled(child: const Text("حفظ البيانات"), onPressed: () {
            goatsList.add({
              'code': _c, 'date': _d, 'image': _imagePath,
              'purchasePrice': double.tryParse(_p.text) ?? 0.0, 
              'foodCosts': 0.0, 'healthCosts': 0.0, 'info': _i.text
            });
            // الخطوة 3 المصححة: تحديث البيانات والعودة للواجهة الرئيسية
            widget.onSave();
            _p.clear(); _i.clear(); _generateCode();
            setState(() => _imagePath = null);
          }),
        ]),
      ),
    );
  }
}

class SpendingPage extends StatefulWidget {
  final VoidCallback onUpdate;
  const SpendingPage({super.key, required this.onUpdate});
  @override
  State<SpendingPage> createState() => _SpendingPageState();
}

class _SpendingPageState extends State<SpendingPage> {
  int _type = 0; int _cat = 0; String? _selCode;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();

  void _save() {
    double p = double.tryParse(_amount.text) ?? 0.0;
    if (p <= 0 || goatsList.isEmpty) return;
    if (_type == 0) {
      DateTime now = DateTime.now();
      var filtered = goatsList.where((g) {
        int m = (now.year - (g['date'] as DateTime).year) * 12 + (now.month - (g['date'] as DateTime).month);
        return (_cat == 0) ? (m < 5) : (m >= 5);
      }).toList();
      if (filtered.isNotEmpty) {
        double perHead = p / filtered.length;
        for (var x in filtered) { x['foodCosts'] = (x['foodCosts'] as num).toDouble() + perHead; }
      }
    } else {
      if (_selCode != null) {
        var g = goatsList.firstWhere((e) => e['code'] == _selCode);
        g['healthCosts'] = (g['healthCosts'] as num).toDouble() + p;
        g['info'] = "${g['info']}\n[علاج]: ${_note.text}";
      }
    }
    widget.onUpdate(); _amount.clear(); _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("إضافة مصاريف وعلاجات")),
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          CupertinoSegmentedControl<int>(
            groupValue: _type,
            children: const {0: Text("علف / غداء"), 1: Text("أدوية / بيطري")},
            onValueChanged: (v) => setState(() => _type = v ?? 0),
          ),
          const SizedBox(height: 25),
          if (_type == 0) 
            CupertinoSegmentedControl<int>(
              groupValue: _cat,
              children: const {0: Text("مواليد (<5ش)"), 1: Text("كبار (>=5ش)")},
              onValueChanged: (v) => setState(() => _cat = v ?? 0),
            )
          else ...[
            const Text("اختر الحالة المرضية:"),
            SizedBox(height: 100, child: CupertinoPicker(
              itemExtent: 35,
              onSelectedItemChanged: (i) => _selCode = goatsList[i]['code'].toString(),
              children: goatsList.map((e) => Text("رأس كود: ${e['code']}")).toList(),
            )),
            CupertinoTextField(controller: _note, placeholder: "نوع المرض أو العلاج"),
          ],
          const SizedBox(height: 15),
          CupertinoTextField(controller: _amount, placeholder: "المبلغ بالريال", keyboardType: TextInputType.number),
          const SizedBox(height: 30),
          CupertinoButton.filled(onPressed: _save, child: const Text("تحديث السجلات")),
        ]),
      ),
    );
  }
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("سجل الحلال")),
      child: goatsList.isEmpty ? const Center(child: Text("لا يوجد بيانات مسجلة")) : ListView.builder(
        itemCount: goatsList.length,
        itemBuilder: (c, i) {
          final g = goatsList[i];
          double total = (g['purchasePrice'] as num).toDouble() + (g['foodCosts'] as num).toDouble() + (g['healthCosts'] as num).toDouble();
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(8)),
              child: g['image'] != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(g['image'], fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(CupertinoIcons.photo))) : const Icon(CupertinoIcons.photo)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("كود: ${g['code']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(g['info'] ?? "", style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey), maxLines: 1),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text("التكلفة", style: TextStyle(fontSize: 10)),
                Text("${total.toStringAsFixed(0)} ر.س", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ]),
            ]),
          );
        },
      ),
    );
  }
}