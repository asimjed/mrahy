import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors; 
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
    final String? savedData = prefs.getString('my_farm_data');
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
    await prefs.setString('my_farm_data', encodedData);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.graph_square_fill), label: 'الأرباح'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.add_circled_solid), label: 'إضافة'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag_fill), label: 'المعيشة'),
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
    DateTime now = DateTime.now();

    for (var g in goatsList) {
      totalCosts += (g['purchasePrice'] as num).toDouble() + 
                    (g['foodCosts'] as num).toDouble() + 
                    (g['healthCosts'] as num).toDouble();
      
      DateTime dt = g['date'] as DateTime;
      // حل مشكلة num to int عبر الحساب المباشر
      int months = (now.year - dt.year) * 12 + (now.month - dt.month);
      
      if (months < 5) { kids++; } else { adults++; }
    }

    double estimatedMarketValue = (adults * 1200.0) + (kids * 500.0); 
    double profitOrLoss = estimatedMarketValue - totalCosts;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('الأداء المالي')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: profitOrLoss >= 0 
                          ? [const Color(0xFF1B5E20), const Color(0xFF4CAF50)] 
                          : [const Color(0xFFB71C1C), const Color(0xFFEF5350)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profitOrLoss >= 0 ? "صافي الربح التقديري" : "إجمالي الخسارة الحالية", 
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 10),
                        Text("${profitOrLoss.toStringAsFixed(2)} ر.س", 
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildMiniBox("المصاريف", totalCosts.toStringAsFixed(0), CupertinoColors.systemRed),
                      _buildMiniBox("قيمة الحلال", estimatedMarketValue.toStringAsFixed(0), CupertinoColors.activeGreen),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBox(String l, String v, Color c) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(5), padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          Text(l, style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey)),
          Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
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
  int _type = 0; int _cat = 0; String? _sel;
  final TextEditingController _a = TextEditingController();
  final TextEditingController _n = TextEditingController();

  void _run() {
    double p = double.tryParse(_a.text) ?? 0.0;
    if (p <= 0 || goatsList.isEmpty) return;
    if (_type == 0) {
      DateTime now = DateTime.now();
      var t = goatsList.where((g) {
        DateTime d = g['date'] as DateTime;
        int m = (now.year - d.year) * 12 + (now.month - d.month);
        return (_cat == 0) ? (m < 5) : (m >= 5);
      }).toList();
      if (t.isNotEmpty) {
        double s = p / t.length;
        for (var x in t) { x['foodCosts'] = (x['foodCosts'] as num).toDouble() + s; }
      }
    } else {
      if (_sel != null) {
        var g = goatsList.firstWhere((e) => e['code'] == _sel);
        g['healthCosts'] = (g['healthCosts'] as num).toDouble() + p;
        g['info'] = "${g['info']}\nعلاج: ${_n.text}";
      }
    }
    widget.onUpdate(); _a.clear(); _n.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("المعيشة")),
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          CupertinoSegmentedControl<int>(
            groupValue: _type,
            children: const {0: Text("علف"), 1: Text("علاج")},
            onValueChanged: (v) => setState(() => _type = v ?? 0),
          ),
          const SizedBox(height: 20),
          if (_type == 0) 
            CupertinoSegmentedControl<int>(
              groupValue: _cat,
              children: const {0: Text("للمواليد"), 1: Text("للكبار")},
              onValueChanged: (v) => setState(() => _cat = v ?? 0),
            )
          else ...[
            if(goatsList.isNotEmpty)
            SizedBox(height: 100, child: CupertinoPicker(
              itemExtent: 35,
              onSelectedItemChanged: (i) => _sel = goatsList[i]['code'].toString(),
              children: goatsList.map((e) => Text(e['code'].toString())).toList(),
            )),
            CupertinoTextField(controller: _n, placeholder: "الملاحظات الطبية"),
          ],
          const SizedBox(height: 15),
          CupertinoTextField(controller: _a, placeholder: "المبلغ", keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          CupertinoButton.filled(onPressed: _run, child: const Text("حفظ")),
        ]),
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
  String _c = ""; bool _b = false; DateTime _d = DateTime.now();
  void _g() => setState(() => _c = "${String.fromCharCode(Random().nextInt(26) + 65)}${Random().nextInt(900) + 100}");
  @override void initState() { super.initState(); _g(); }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("إضافة")),
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          CupertinoSegmentedControl<bool>(
            groupValue: _b,
            children: const {false: Text("مشتراه"), true: Text("مولودة")},
            onValueChanged: (v) => setState(() => _b = v ?? false),
          ),
          const SizedBox(height: 15),
          Text("كود الرأس: $_c", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 100, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, onDateTimeChanged: (dt) => _d = dt)),
          if (!_b) CupertinoTextField(controller: _p, placeholder: "سعر الشراء", keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          CupertinoTextField(controller: _i, placeholder: "معلومات", maxLines: 2),
          const SizedBox(height: 20),
          CupertinoButton.filled(child: const Text("حفظ"), onPressed: () {
            goatsList.add({
              'code': _c, 
              'date': _d, 
              'purchasePrice': double.tryParse(_p.text) ?? 0.0, 
              'foodCosts': 0.0, 
              'healthCosts': 0.0, 
              'info': _i.text
            });
            widget.onSave(); _g(); _p.clear(); _i.clear();
          }),
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
      navigationBar: const CupertinoNavigationBar(middle: Text("السجل")),
      child: goatsList.isEmpty ? const Center(child: Text("السجل فارغ")) : ListView.builder(
        itemCount: goatsList.length,
        itemBuilder: (c, i) {
          final g = goatsList[i];
          double total = (g['purchasePrice'] as num).toDouble() + 
                         (g['foodCosts'] as num).toDouble() + 
                         (g['healthCosts'] as num).toDouble();
          return Container(
            margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("كود: ${g['code']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${total.toStringAsFixed(2)} ر.س", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ]),
          );
        },
      ),
    );
  }
}
