import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تأكد من وضع مفاتيحك الصحيحة هنا
  await Supabase.initialize(
    url: 'https://fxifvbeaovnellxxsydj.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4aWZ2YmVhb3ZuZWxseHhzeWRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0NTIyMTYsImV4cCI6MjA4NjAyODIxNn0.7QNTPeHcKqyHNWdaIsgylt41CJC-ExBPX3QgxXN1HLY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق المطعم',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> cart = []; // السلة
  bool isLoading = true;
  bool isSendingOrder = false; // لمنع الضغط المتكرر

  @override
  void initState() {
    super.initState();
    fetchMenu();
  }

  // جلب المنيو
  Future<void> fetchMenu() async {
    try {
      final response = await supabase.from('menu_items').select('*').eq('is_available', true);
      setState(() {
        menuItems = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // إضافة للسلة
  void addToCart(Map<String, dynamic> item) {
    setState(() {
      cart.add(item);
    });
  }

  // حساب المجموع
  double get cartTotal => cart.fold(0, (sum, item) => sum + (item['price'] as num).toDouble());

  // إرسال الطلب لقاعدة البيانات
  Future<void> submitOrder(String address) async {
    setState(() => isSendingOrder = true);

    try {
      final double deliveryFee = 10.0;
      final double tax = 0.0;
      final double grandTotal = cartTotal + deliveryFee + tax;

      // 1. إنشاء الطلب الرئيسي (Order)
      final orderResponse = await supabase.from('orders').insert({
        'delivery_address': address,
        'items_total': cartTotal,
        'delivery_fee': deliveryFee,
        'tax_amount': tax,
        'grand_total': grandTotal,
        'status': 'pending', // حالة الانتظار
        // 'user_id': ... (يمكنك إضافته لاحقاً عند عمل تسجيل دخول)
      }).select().single();

      final String orderId = orderResponse['id'];

      // 2. إضافة تفاصيل الوجبات (Order Items)
      // تجميع الأصناف المتشابهة وحساب الكميات
      final Map<String, int> quantities = {};
      for (var item in cart) {
        quantities[item['id']] = (quantities[item['id']] ?? 0) + 1;
      }

      // إدراج كل صنف في قاعدة البيانات
      for (var entry in quantities.entries) {
        final itemId = entry.key;
        final quantity = entry.value;
        final itemPrice = cart.firstWhere((e) => e['id'] == itemId)['price'];

        await supabase.from('order_items').insert({
          'order_id': orderId,
          'menu_item_id': itemId,
          'quantity': quantity,
          'unit_price': itemPrice,
        });
      }

      // 3. تنظيف السلة ونجاح العملية
      setState(() {
        cart.clear();
        isSendingOrder = false;
      });

      if (mounted) {
        Navigator.pop(context); // إغلاق النافذة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال طلبك بنجاح! رقم الطلب: ${orderId.substring(0, 5)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      setState(() => isSendingOrder = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الطلب: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // نافذة إدخال العنوان
  void showCheckoutDialog() {
    final TextEditingController addressController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الطلب 📝'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('عدد الوجبات: ${cart.length}'),
            Text('الإجمالي شامل التوصيل: ${cartTotal + 10} ر.س', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'عنوان التوصيل (الحي، الشارع)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (addressController.text.isNotEmpty) {
                submitOrder(addressController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: isSendingOrder 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text('إرسال الطلب 🚀'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الطعام 🍔'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100), // مسافة للزر العائم
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Container(
                      width: 60, height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.orange),
                    ),
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item['price']} ر.س'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                      onPressed: () => addToCart(item),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: cart.isNotEmpty
          ? SizedBox(
              width: double.infinity,
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: showCheckoutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                        child: Text('${cart.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const Text('إتمام الطلب', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${cartTotal + 10} ر.س', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}