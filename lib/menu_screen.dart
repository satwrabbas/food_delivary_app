// اسم الملف: lib/menu_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:geolocator/geolocator.dart'; // لم نعد نحتاجه هنا!
import 'package:shared_preferences/shared_preferences.dart'; // استيراد SharedPreferences

import 'menu_item.dart';
import 'constants.dart';
import 'menu_item_card.dart';
import 'order_tracking_screen.dart';
import 'checkout_dialog.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final supabase = Supabase.instance.client;

  List<MenuItem> menuItems =[];
  List<MenuItem> cart =[];
  bool isLoading = true;
  bool isSendingOrder = false;

  // 🟢 1. متغير جديد لحفظ رقم الطلب النشط إن وُجد
  String? activeOrderId;

  @override
  void initState() {
    super.initState();
    fetchMenu();
    _checkActiveOrder(); // 🟢 2. فحص هل هناك طلب سابق عند فتح التطبيق
  }

  // 🟢 3. دالة جديدة تفحص الذاكرة المحلية وتتأكد من حالة الطلب في قاعدة البيانات
  Future<void> _checkActiveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrderId = prefs.getString('active_order_id');

    if (savedOrderId != null) {
      try {
        // نتأكد من قاعدة البيانات هل الطلب ما زال نشطاً؟
        final response = await supabase
            .from('orders')
            .select('status')
            .eq('id', savedOrderId)
            .maybeSingle();

        if (response != null) {
          final status = response['status'];
          // إذا لم يكن ملغياً أو تم توصيله، نظهره للمستخدم
          if (status != 'delivered' && status != 'cancelled') {
            setState(() {
              activeOrderId = savedOrderId;
            });
          } else {
            // إذا انتهى الطلب، نمسحه من ذاكرة الجوال
            await prefs.remove('active_order_id');
            setState(() {
              activeOrderId = null;
            });
          }
        }
      } catch (e) {
        debugPrint('Error checking order status: $e');
      }
    }
  }

  Future<void> fetchMenu() async {
    try {
      final response = await supabase
          .from('menu_items')
          .select('*')
          .eq('is_available', true);

      setState(() {
        menuItems = (response as List)
            .map((item) => MenuItem.fromMap(item))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching menu: $e');
      setState(() => isLoading = false);
    }
  }

  void addToCart(MenuItem item) {
    setState(() {
      cart.add(item);
    });
  }

  double get cartTotal =>
      cart.fold(0, (sum, item) => sum + item.price);

  Future<bool> submitOrder(String address, double? lat, double? lng) async {
    try {
      final double deliveryFee = Constants.deliveryFee;
      final double tax = 0.0;
      final double grandTotal = cartTotal + deliveryFee + tax;

      // 1. إدخال الطلب الأساسي
      final orderResponse = await supabase.from('orders').insert({
        'delivery_address': address,
        'items_total': cartTotal,
        'delivery_fee': deliveryFee,
        'tax_amount': tax,
        'grand_total': grandTotal,
        'status': 'pending',
        'lat': lat,
        'lng': lng,
      }).select().single();

      final String orderId = orderResponse['id'];

      // 2. حساب الكميات
      final Map<String, int> quantities = {};
      for (var item in cart) {
        quantities[item.id] = (quantities[item.id] ?? 0) + 1;
      }

      // تجميع كل الأصناف في قائمة واحدة (Bulk Insert)
      List<Map<String, dynamic>> itemsToInsert = quantities.entries.map((entry) {
        return {
          'order_id': orderId,
          'menu_item_id': entry.key,
          'quantity': entry.value,
          'unit_price': cart.firstWhere((e) => e.id == entry.key).price,
        };
      }).toList();

      // إرسالها دفعة واحدة في طلب واحد
      await supabase.from('order_items').insert(itemsToInsert);

      // 🟢 4. حفظ رقم الطلب في ذاكرة الجوال بعد نجاحه
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_order_id', orderId);

      setState(() {
        cart.clear();
        activeOrderId = orderId; // تحديث الواجهة لتظهر الشريط
      });

      if (mounted) {
        Navigator.pop(context); // إغلاق الديالوج

        // الانتقال لشاشة التتبع (وعند العودة نفحص حالة الطلب لتحديث الشريط)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OrderTrackingScreen(orderId: orderId)),
        ).then((_) {
          _checkActiveOrder();
        });
      }
      return true; // نجح الطلب

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الطلب: $e'), backgroundColor: Colors.red),
        );
      }
      return false; // فشل الطلب
    }
  }

  void showCheckout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CheckoutDialog(
          cartLength: cart.length,
          cartTotal: cartTotal,
          onSubmit: (address, lat, lng) async {
            return await submitOrder(address, lat, lng);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الطعام 🍔'), centerTitle: true),
      body: Column( // 🟢 5. استبدلنا ListView بـ Column لنضع الشريط فوق المنيو
        children:[
          // 🟢 6. شريط الطلب النشط (يظهر فقط إذا كان هناك طلب)
          if (activeOrderId != null)
            GestureDetector(
              onTap: () {
                // عند الضغط على الشريط، نذهب لشاشة التتبع
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          OrderTrackingScreen(orderId: activeOrderId!)),
                ).then((_) {
                  // عند العودة من شاشة التتبع، نفحص إذا كان الطلب قد انتهى لنخفي الشريط
                  _checkActiveOrder();
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const[
                    Row(
                      children:[
                        Icon(Icons.motorcycle, color: Colors.deepOrange),
                        SizedBox(width: 10),
                        Text(
                          'لديك طلب نشط الآن، تتبعه!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.deepOrange),
                  ],
                ),
              ),
            ),

          // باقي القائمة (Menu Items)
          Expanded( // ضروري لكي تأخذ القائمة المساحة المتبقية داخل الـ Column
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      return MenuItemCard(
                        item: menuItems[index],
                        onAdd: () => addToCart(menuItems[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: showCheckout,
              backgroundColor: Colors.red,
              label: Text(
                '${cart.length} وجبات | إتمام الطلب',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}