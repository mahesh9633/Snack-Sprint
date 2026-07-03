class MostBoughtItem {
  final String productId;
  final int totalOrders;
  final int totalQuantity;

  MostBoughtItem({
    required this.productId,
    required this.totalOrders,
    required this.totalQuantity,
  });

  factory MostBoughtItem.fromJson(Map<String, dynamic> json) {
    return MostBoughtItem(
      productId: json['product_id'].toString(),
      totalOrders: int.tryParse(json['total_orders'].toString()) ?? 0,
      totalQuantity: int.tryParse(json['total_quantity'].toString()) ?? 0,
    );
  }
}