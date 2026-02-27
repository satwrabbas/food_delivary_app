// اسم الملف: lib/menu_item_card.dart

import 'package:flutter/material.dart';
import 'menu_item.dart'; // نحتاج استيراد المودل ليعرف شكل البيانات

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onAdd; // دالة يتم استدعاؤها عند الضغط على الزر

  const MenuItemCard({
    super.key, 
    required this.item, 
    required this.onAdd
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 3, // إضافة ظل خفيف لجمالية أكثر
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fastfood, color: Colors.orange, size: 30),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${item.price} ر.س',
            style: const TextStyle(
              color: Colors.green, 
              fontWeight: FontWeight.bold,
              fontSize: 14
            ),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.red, size: 32),
          onPressed: onAdd, // استدعاء الدالة الممررة
        ),
      ),
    );
  }
}