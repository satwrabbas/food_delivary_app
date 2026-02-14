import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart'; // استيراد مكتبة الموقع

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Supabase
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
  List<Map<String, dynamic>> cart = [];
  bool isLoading = true;
  bool isSendingOrder = false;

  // متغيرات لحفظ الموقع
  double? currentLat;
  double? currentLng;
  bool isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    fetchMenu();
  }

  // جلب المنيو
  Future<void> fetchMenu() async {
    try {
      final response = await supabase
          .from('menu_items')
          .select('*')
          .eq('is_available', true);
      setState(() {
        menuItems = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching menu: $e');
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
  double get cartTotal =>
      cart.fold(0, (sum, item) => sum + (item['price'] as num).toDouble());

  // دالة تحديد الموقع
  Future<void> _determinePosition(
      TextEditingController addressController, Function setDialogState) async {
    
    // تحديث واجهة الدايالوج لإظهار التحميل
    setDialogState(() => isGettingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    // 1. التأكد من أن خدمة الموقع مفعلة
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء تفعيل خدمة الموقع (GPS)')));
      }
      setDialogState(() => isGettingLocation = false);
      return;
    }

    // 2. التحقق من الأذونات
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم رفض إذن الوصول للموقع')));
        }
        setDialogState(() => isGettingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من الإعدادات')));
      }
      setDialogState(() => isGettingLocation = false);
      return;
    }

    // 3. جلب الموقع الحالي
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      // تحديث المتغيرات العامة (خارج الدايالوج)
      setState(() {
        currentLat = position.latitude;
        currentLng = position.longitude;
      });
      
      // تحديث واجهة الدايالوج وإكمال النص
      setDialogState(() {
        isGettingLocation = false;
        addressController.text =
            "موقعي الحالي (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";
      });

    } catch (e) {
      debugPrint('Error getting location: $e');
      setDialogState(() => isGettingLocation = false);
    }
  }

  // إرسال الطلب لقاعدة البيانات
  Future<void> submitOrder(String address) async {
    setState(() => isSendingOrder = true);

    try {
      final double deliveryFee = 10.0;
      final double tax = 0.0;
      final double grandTotal = cartTotal + deliveryFee + tax;

      // استخدام الموقع الحالي إذا وجد، وإلا نستخدم قيم افتراضية (يمكنك جعلها null إذا كان العمود يقبل null)
      final double? finalLat = currentLat;
      final double? finalLng = currentLng;

      // 1. إنشاء الطلب الرئيسي (Order)
      final orderResponse = await supabase.from('orders').insert({
        'delivery_address': address,
        'items_total': cartTotal,
        'delivery_fee': deliveryFee,
        'tax_amount': tax,
        'grand_total': grandTotal,
        'status': 'pending',
        'lat': finalLat, // إحداثيات GPS
        'lng': finalLng, // إحداثيات GPS
      }).select().single();

      final String orderId = orderResponse['id'];

      // 2. إضافة تفاصيل الوجبات (Order Items)
      final Map<String, int> quantities = {};
      for (var item in cart) {
        quantities[item['id']] = (quantities[item['id']] ?? 0) + 1;
      }

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
        currentLat = null; // إعادة تعيين الموقع
        currentLng = null;
      });

      if (mounted) {
        Navigator.pop(context); // إغلاق النافذة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم إرسال طلبك بنجاح! رقم الطلب: ${orderId.substring(0, 5)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => isSendingOrder = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل الطلب: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // نافذة إدخال العنوان مع زر الموقع
  void showCheckoutDialog() {
    final TextEditingController addressController = TextEditingController();

    // إعادة تعيين الموقع عند فتح النافذة
    setState(() {
      currentLat = null;
      currentLng = null;
      isGettingLocation = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false, // منع الإغلاق بالضغط في الخارج
      builder: (context) {
        // نستخدم StatefulBuilder لتحديث حالة الأيقونة داخل الديالوج
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تأكيد الطلب 📝'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('عدد الوجبات: ${cart.length}'),
                  Text(
                    'الإجمالي شامل التوصيل: ${cartTotal + 10} ر.س',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'عنوان التوصيل',
                      hintText: 'اكتب العنوان أو استخدم الزر 📍',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: isGettingLocation
                            ? null
                            : () async {
                                await _determinePosition(
                                    addressController, setDialogState);
                              },
                        icon: isGettingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(
                                currentLat != null
                                    ? Icons.my_location
                                    : Icons.location_searching,
                                color: currentLat != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                      ),
                    ),
                  ),
                  if (currentLat != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        '✅ تم التقاط الإحداثيات بنجاح',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSendingOrder ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSendingOrder
                      ? null
                      : () {
                          if (addressController.text.isNotEmpty) {
                            submitOrder(addressController.text);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('الرجاء كتابة العنوان')));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: isSendingOrder
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('إرسال الطلب 🚀'),
                ),
              ],
            );
          },
        );
      },
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.orange),
                    ),
                    title: Text(item['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item['price']} ر.س'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => addToCart(item),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: showCheckoutDialog,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Row(
                children: [
                  Text('${cart.length} وجبات | ',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const Text('إتمام الطلب',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}