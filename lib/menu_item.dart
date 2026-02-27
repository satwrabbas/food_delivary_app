// اسم الملف: lib/menu_item.dart

class MenuItem {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
  });

  // هذه الدالة تحول البيانات القادمة من Supabase (JSON) إلى كلاس نستطيع استخدامه
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'].toString(), // تحويل الـ ID لنص لضمان عدم حدوث مشاكل
      name: map['name'] ?? 'بدون اسم',
      price: (map['price'] as num).toDouble(), // ضمان أن السعر رقم عشري
      isAvailable: map['is_available'] ?? false,
    );
  }
}