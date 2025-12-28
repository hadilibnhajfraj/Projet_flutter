class OrderModel {
  final String id;
  final DateTime date;
  final String customerName;
  final String customerEmail;
  final String customerAvatarUrl; // Optional
  final String paymentStatus;
  final String orderStatus;
  final String paymentMethod;
  final String paymentLast4;
   bool isSelected=false;

  OrderModel({
    required this.id,
    required this.date,
    required this.customerName,
    required this.customerEmail,
    required this.customerAvatarUrl,
    required this.paymentStatus,
    required this.orderStatus,
    required this.paymentMethod,
    required this.paymentLast4,
    required this.isSelected,
  });
}
