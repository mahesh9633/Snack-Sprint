import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/products/product_detail_screen.dart';
import 'package:provider/provider.dart';

import '../model/cart_model.dart';
import '../model/product_model.dart';
import '../services/api_config_service.dart';

final String _kImgBase = ApiConfig.imageBase;

class ProductCard extends StatelessWidget {
  final Product product;
  final double  imageHeight;
  final double  cardRightMargin;
  final bool    compactCart;

  const ProductCard({
    super.key,
    required this.product,
    this.imageHeight     = 0,
    this.cardRightMargin = 0,
    this.compactCart     = false,
  });

  @override
  Widget build(BuildContext context) =>
      compactCart ? _buildCompact(context) : _buildFull(context);

  // ── Full card ──────────────────────────────────────────────────────────────
  Widget _buildFull(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
        margin: EdgeInsets.only(right: cardRightMargin),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: Colors.pink),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset:     const Offset(0, 2)),
          ],
        ),
        // KEY FIX: max fills the cell; Spacer pushes ADD to bottom
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [

            // // ── Image: height = 72% of actual card width ──────────────
            // LayoutBuilder(builder: (_, constraints) {
            // ── Image: height = 72% of actual card width ──────────────
            GestureDetector(
            onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product))),
      child: LayoutBuilder(builder: (_, constraints) {
              final imgH = imageHeight > 0
                  ? imageHeight
                  : constraints.maxWidth * 0.72;
              return Stack(children: [
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
                  child: SizedBox(
                    height: imgH,
                    width:  double.infinity,
                    child:  _safeImage(
                        image: product.image, imageUrl: product.imageUrl),
                  ),
                ),
                if (product.computedDiscount > 0)
                  Positioned(
                    top: 5, left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('↓${product.computedDiscount}%',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                // Out-of-stock overlay
                if (!product.isInStock)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10)),
                      child: Container(
                        color:     Colors.black.withOpacity(0.35),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Out of Stock',
                              style: TextStyle(
                                  color:      Colors.red,
                                  fontSize:   10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
            ),

            // ── Content (price / discount / name) ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Price row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF388E3C),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('₹${product.price.toInt()}',
                                  style: const TextStyle(
                                      color:      Colors.white,
                                      fontSize:   9,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (product.originalPrice > product.price) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                    '₹${product.originalPrice.toInt()}',
                                    style: TextStyle(
                                        fontSize:   9,
                                        color:      Colors.grey[500],
                                        decoration:
                                        TextDecoration.lineThrough),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (product.displayWeight.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(product.displayWeight,
                              style: TextStyle(
                                  fontSize: 8, color: Colors.grey[500]),
                              maxLines:  1,
                              overflow:  TextOverflow.ellipsis,
                              textAlign: TextAlign.right),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Discount % — only shown when available (no reserved SizedBox)
                  if (product.computedDiscount > 0) ...[
                    Text('${product.computedDiscount}% off',
                        style: const TextStyle(
                            fontSize:   9,
                            color:      Color(0xFF388E3C),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                  ],

                  // Product name — 2 lines max, ellipsis
                  Text(product.name,
                      style: const TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.w500,
                          color:      Colors.black87,
                          height:     1.35),
                      maxLines:  2,
                      overflow:  TextOverflow.ellipsis),
                ],
              ),
            ),

            // Spacer absorbs leftover space → ADD button always at bottom
            const Spacer(),

            // ── ADD button always at bottom ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
              child: _CartButton(
                  product: product,
                  isInStock: product.isInStock),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact card (overlay ADD button on image) ────────────────────────────
  Widget _buildCompact(BuildContext context) {
    return Consumer<CartModel>(
      builder: (context, cart, _) {
        final quantity = cart.getQuantity(product);
        return Container(
          margin: EdgeInsets.only(right: cardRightMargin),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset:     const Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product))),
        child: Stack(children: [
        ClipRRect(
        borderRadius: const BorderRadius.vertical(
        top: Radius.circular(10)),
                    child: SizedBox(
                      height: imageHeight > 0 ? imageHeight : 100,
                      width:  double.infinity,
                      child:  _safeImage(
                          image: product.image, imageUrl: product.imageUrl),
                    ),
                  ),
                  if (product.computedDiscount > 0)
                    Positioned(
                      top: 5, left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('↓${product.computedDiscount}%',
                            style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   7,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    bottom: 6, right: 6,
                    child: quantity == 0
                        ? _AddButton(onTap: () => cart.addItem(product))
                        : _StepperWidget(
                      quantity:    quantity,
                      onIncrement: () => cart.addItem(product),
                      onDecrement: () =>
                          cart.decrementQuantity(product.id),
                    ),
                  ),
                ]),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Price + weight
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF388E3C),
                                      borderRadius:
                                      BorderRadius.circular(4)),
                                  child: Text('₹${product.price.toInt()}',
                                      style: const TextStyle(
                                          color:      Colors.white,
                                          fontSize:   10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (product.originalPrice >
                                    product.price) ...[
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                        '₹${product.originalPrice.toInt()}',
                                        style: TextStyle(
                                            color:      Colors.grey[500],
                                            fontSize:   9,
                                            decoration:
                                            TextDecoration.lineThrough),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (product.displayWeight.isNotEmpty)
                            Flexible(
                              child: Text(product.displayWeight,
                                  style: TextStyle(
                                      fontSize: 8,
                                      color:    Colors.grey[500]),
                                  maxLines:  1,
                                  overflow:  TextOverflow.ellipsis,
                                  textAlign: TextAlign.right),
                            ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Discount %
                      if (product.computedDiscount > 0) ...[
                        Text('${product.computedDiscount}% off',
                            style: const TextStyle(
                                fontSize:   8,
                                color:      Color(0xFF388E3C),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                      ],

                      // Product name
                      Text(product.name,
                          maxLines:  2,
                          overflow:  TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize:   10,
                              fontWeight: FontWeight.w500,
                              color:      Colors.black87,
                              height:     1.3)),
                    ],
                  ),
                ),
              ],
            ),
        );
      }
    );
  }

  // ── Image helper ───────────────────────────────────────────────────────────
  Widget _safeImage({
    required String image,
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
  }) {
    bool isValid(String s) =>
        s.isNotEmpty &&
            s != 'no_image.png' &&
            !s.startsWith('catalog/s-') &&
            (s.startsWith('http') || s.startsWith('catalog/products/'));

    String url = '';
    if (isValid(imageUrl)) {
      url = imageUrl.startsWith('http') ? imageUrl : '$_kImgBase$imageUrl';
    } else if (isValid(image)) {
      url = image.startsWith('http') ? image : '$_kImgBase$image';
    }

    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (_, child, prog) =>
        prog == null ? child : Container(color: Colors.grey[100]),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    color: Colors.grey[100],
    child: const Center(
        child: Icon(Icons.image_not_supported,
            color: Colors.grey, size: 32)),
  );
}

// ── Full ADD / stepper (bottom of full card) ──────────────────────────────────
class _CartButton extends StatelessWidget {
  final Product product;
  final bool    isInStock;
  const _CartButton({required this.product, required this.isInStock});

  @override
  Widget build(BuildContext context) {
    if (!isInStock) {
      return Container(
        width:     double.infinity,
        height:    30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color:        Colors.grey[200],
            borderRadius: BorderRadius.circular(6)),
        child: const Text('Out of Stock',
            style: TextStyle(
                fontSize:   10,
                color:      Colors.red,
                fontWeight: FontWeight.bold)),
      );
    }

    return Consumer<CartModel>(
      builder: (_, cart, __) {
        final qty = cart.getQuantity(product);
        if (qty == 0) {
          return GestureDetector(
            onTap: () => cart.addItem(product),
            child: Container(
              width:     double.infinity,
              height:    30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFFF0080), width: 1.2),
              ),
              child: const Text('ADD',
                  style: TextStyle(
                      color:         Color(0xFFFF0080),
                      fontSize:      12,
                      fontWeight:    FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          );
        }
        return Container(
          height: 30,
          decoration: BoxDecoration(
              color:        const Color(0xFFFF0080),
              borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => cart.decrementQuantity(product.id),
                child: const SizedBox(
                    width: 32, height: 30,
                    child: Icon(Icons.remove, color: Colors.white, size: 15)),
              ),
              Text('$qty',
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   12,
                      fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => cart.addItem(product),
                child: const SizedBox(
                    width: 32, height: 30,
                    child: Icon(Icons.add, color: Colors.white, size: 15)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Small + button (overlay on compact card) ──────────────────────────────────
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  30,
        height: 30,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF0080), width: 1.5),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset:     const Offset(0, 1))
          ],
        ),
        child: const Icon(Icons.add, color: Color(0xFFB85C00), size: 18),
      ),
    );
  }
}

// ── Inline stepper (overlay on compact card) ──────────────────────────────────
class _StepperWidget extends StatelessWidget {
  final int          quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _StepperWidget({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color:        const Color(0xFFFF0080),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset:     const Offset(0, 1))
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onDecrement,
          child: Container(
              width: 28, height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 15)),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 22),
          alignment:   Alignment.center,
          child: Text('$quantity',
              style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   12,
                  fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: onIncrement,
          child: Container(
              width: 28, height: 30,
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 15)),
        ),
      ]),
    );
  }
}