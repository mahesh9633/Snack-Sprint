import 'package:flutter/material.dart';
import '../products/product_card.dart';
import '../model/product_model.dart';

class OfferProductsScreen extends StatelessWidget {
  final String offerName;
  final List products;

  const OfferProductsScreen({
    super.key,
    required this.offerName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(offerName),
        backgroundColor: const Color(0xFFE91E63),
      ),

      body: GridView.builder(
        padding: const EdgeInsets.all(12),

        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),

        itemCount: products.length,

        itemBuilder: (_, i) {

          final p = products[i];

          return ProductCard(
            product: Product(
              id: p.productId,
              name: p.name,
              price: p.retailPrice,
              originalPrice: p.wholesalePrice > 0
                  ? p.wholesalePrice
                  : p.retailPrice,
              image: p.image,
              imageUrl: p.imageUrl,
              category: p.category,
              weight: p.unit,
              sku: p.sku,
              discountPercentage: p.discountPercent,
              quantity: p.quantity,
            ),
          );
        },
      ),
    );
  }
}