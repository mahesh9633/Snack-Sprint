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
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),

            itemCount: products.length,

            itemBuilder: (_, i) {
              return ProductCard(product: products[i]);
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