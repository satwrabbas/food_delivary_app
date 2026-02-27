// اسم الملف: lib/checkout_dialog.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'constants.dart';

class CheckoutDialog extends StatefulWidget {
  final int cartLength;
  final double cartTotal;
  // 🟢 التعديل الأول: جعلنا الدالة ترجع Future<bool> لكي ينتظرها الديالوج ويعرف هل نجحت أم فشلت
  final Future<bool> Function(String address, double? lat, double? lng) onSubmit;

  const CheckoutDialog({
    super.key,
    required this.cartLength,
    required this.cartTotal,
    required this.onSubmit, // حذفنا isSendingOrder من هنا لأن الديالوج سيدير حالته بنفسه
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final TextEditingController addressController = TextEditingController();
  double? currentLat;
  double? currentLng;
  bool isGettingLocation = false;
  bool _isLoading = false; // 🟢 التعديل الثاني: حالة التحميل خاصة بالديالوج فقط

  Future<void> _determinePosition() async {
    setState(() => isGettingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تفعيل خدمة الموقع (GPS)')));
      setState(() => isGettingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض إذن الوصول للموقع')));
        setState(() => isGettingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من الإعدادات')));
      setState(() => isGettingLocation = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentLat = position.latitude;
        currentLng = position.longitude;
        isGettingLocation = false;
        addressController.text = "موقعي الحالي (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";
      });
    } catch (e) {
      setState(() => isGettingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأكيد الطلب 📝'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children:[
          Text('عدد الوجبات: ${widget.cartLength}'),
          Text(
            'الإجمالي شامل التوصيل: ${widget.cartTotal + Constants.deliveryFee} ر.س',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: addressController,
            decoration: InputDecoration(
              labelText: 'عنوان التوصيل',
              hintText: 'اكتب العنوان أو استخدم الزر 📍',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: isGettingLocation ? null : () async => await _determinePosition(),
                icon: isGettingLocation
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(currentLat != null ? Icons.my_location : Icons.location_searching, color: currentLat != null ? Colors.green : Colors.grey),
              ),
            ),
          ),
        ],
      ),
      actions:[
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          // 🟢 التعديل الثالث: تشغيل التحميل ومنع الضغط المتكرر
          onPressed: _isLoading
              ? null
              : () async {
                  if (addressController.text.isNotEmpty) {
                    setState(() => _isLoading = true); // أظهر التحميل الدائري

                    // ننتظر حتى ينتهي الإرسال
                    bool isSuccess = await widget.onSubmit(
                      addressController.text,
                      currentLat,
                      currentLng,
                    );

                    // إذا فشل الطلب ولم ينغلق الديالوج، نوقف أيقونة التحميل ليعاود المحاولة
                    if (!isSuccess && mounted) {
                      setState(() => _isLoading = false);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء كتابة العنوان')));
                  }
                },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('إرسال الطلب 🚀'),
        ),
      ],
    );
  }
}