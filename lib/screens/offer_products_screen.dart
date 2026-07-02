

import 'package:flutter/material.dart';
import '../products/product_card.dart';
import '../model/product_model.dart';
import '../widgets/floating_cart.dart';

class OfferProductsScreen extends StatelessWidget {
  final String offerName;
  final List<Product> products;
  final String token;
  final String customerId;

  const OfferProductsScreen({
    super.key,
    required this.offerName,
    required this.products,
    this.token = '',
    this.customerId = '',
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    const int cols = 2;
    const double spacing = 10;
    const double hPad = 12;
    final cardW = (screenW - (hPad * 2) - spacing) / cols;
    final imgH  = cardW * 0.80;
    final cardH = imgH + 113.0;
    final ratio = cardW / cardH;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          offerName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),

            gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: ratio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 10,
            ),

            itemCount: products.length,

            itemBuilder: (_, i) {
              return ProductCard(
                product: products[i],
                imageHeight: imgH,
              );
            },
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FloatingCartBar(
              token: token,
              customerId: customerId,
            ),
          ),
        ],
      ),
    );
  }
}