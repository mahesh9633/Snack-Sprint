import 'package:flutter/material.dart';
import '../products/product_card.dart';
import '../model/product_model.dart';

class OfferProductsScreen extends StatelessWidget {
  final String offerName;
  final List<Product> products;

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
          return ProductCard(product: products[i]);
        },
      ),
    );
  }
}