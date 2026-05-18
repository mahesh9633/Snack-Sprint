import 'package:flutter/material.dart';
import '../model/product_model.dart';
import '../products/product_card.dart';
import '../services/session_manager.dart';
import '../widgets/floating_cart.dart';


class SeeAllScreen extends StatefulWidget {
  final String title;
  final List<Product> products;

  const SeeAllScreen({super.key, required this.title, required this.products});

  @override
  State<SeeAllScreen> createState() => _SeeAllScreenState();
}

class _SeeAllScreenState extends State<SeeAllScreen> {
  String _token = '';
  String _customerId = '';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final token = await SessionManager.getToken();
    if (mounted) setState(() => _token = token ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: Stack(
        children: [
          widget.products.isEmpty
              ? const Center(
            child: Text(
              'No products available',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          )
              : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.products.length,
            itemBuilder: (_, i) => ProductCard(product: widget.products[i]),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: FloatingCartBar(
              token: _token,
              customerId: _customerId,
              onGoToHome: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
        ],
      ),
    );
  }
}