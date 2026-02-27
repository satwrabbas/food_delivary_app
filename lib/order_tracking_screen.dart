// اسم الملف: lib/order_tracking_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    // هنا نستخدم stream للاستماع لأي تغيير في هذا الطلب لحظياً
    final orderStream = supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الطلب 📍'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('الطلب غير موجود!'));
          }

          // جلب بيانات الطلب من الـ Stream
          final orderData = snapshot.data!.first;
          final String currentStatus = orderData['status'] ?? 'pending';
          final double grandTotal = (orderData['grand_total'] as num).toDouble();

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                // كارت معلومات الطلب الأساسية
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          Text('رقم الطلب: ${orderId.substring(0, 8)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text('الإجمالي: $grandTotal ر.س',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Icon(Icons.receipt_long, size: 40, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text('حالة الطلب:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // رسم مسار التتبع (Timeline)
                Expanded(
                  child: _buildTrackingTimeline(currentStatus),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // دالة مساعدة لرسم خطوات التتبع بناءً على الحالة الحالية
  Widget _buildTrackingTimeline(String currentStatus) {
    int stepIndex = _getStatusIndex(currentStatus);

    return ListView(
      children:[
        _buildStep(
          title: 'في انتظار قبول المطعم',
          icon: Icons.access_time_filled,
          isActive: stepIndex >= 0,
          isLast: false,
        ),
        _buildStep(
          title: 'جاري تجهيز الطلب',
          icon: Icons.soup_kitchen,
          isActive: stepIndex >= 1,
          isLast: false,
        ),
        _buildStep(
          title: 'الطلب جاهز للاستلام من المندوب', // الخطوة الجديدة!
          icon: Icons.takeout_dining,
          isActive: stepIndex >= 2,
          isLast: false,
        ),
        _buildStep(
          title: 'في الطريق إليك',
          icon: Icons.delivery_dining,
          isActive: stepIndex >= 3,
          isLast: false,
        ),
        _buildStep(
          title: 'تم التوصيل بنجاح',
          icon: Icons.check_circle,
          isActive: stepIndex >= 4,
          isLast: true, // هذه هي الخطوة الأخيرة
        ),
        if (currentStatus == 'cancelled') ...[
          const SizedBox(height: 20),
          const Center(
            child: Text('❌ تم إلغاء الطلب', style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ]
      ],
    );
  }

  
 // 🟢 التعديل الأول: أضفنا الحالات الجديدة المطابقة تماماً لقاعدة بياناتك
  int _getStatusIndex(String status) {
    switch (status) {
      case 'pending': return 0;
      case 'cooking': return 1;             // تم التعديل من preparing إلى cooking
      case 'ready_for_pickup': return 2;    // حالة جديدة أضفناها لتطابق الصورة
      case 'on_way': return 3;              // تم التعديل من on_the_way إلى on_way
      case 'delivered': return 4;
      default: return -1; // في حالة cancelled أو قيمة فارغة
    }
  }


  // تصميم كل خطوة (Step) في المسار
  Widget _buildStep({required String title, required IconData icon, required bool isActive, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Column(
          children:[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            if (!isLast)
              Container(
                width: 3,
                height: 40,
                color: isActive ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 15),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}