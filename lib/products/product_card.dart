// import 'package:flutter/material.dart';
// import 'package:mtl_groceriesapp/products/product_detail_screen.dart';
// import 'package:provider/provider.dart';
//
// import '../model/cart_model.dart';
// import '../model/product_model.dart';
// import '../services/api_config_service.dart';
// import '../widgets/piece_selector_sheet.dart';
//
// final String _kImgBase = ApiConfig.imageBase;
//
// class ProductCard extends StatelessWidget {
//   final Product product;
//   final double  imageHeight;
//   final double  cardRightMargin;
//   final bool    compactCart;
//
//   const ProductCard({
//     super.key,
//     required this.product,
//     this.imageHeight     = 0,
//     this.cardRightMargin = 0,
//     this.compactCart     = false,
//   });
//
//   @override
//   Widget build(BuildContext context) =>
//       compactCart ? _buildCompact(context) : _buildFull(context);
//
//   // ── Full card ──────────────────────────────────────────────────────────────
//   Widget _buildFull(BuildContext context) {
//     return Container(
//       margin: EdgeInsets.only(right: cardRightMargin),
//       decoration: BoxDecoration(
//         color:        Colors.white,
//         borderRadius: BorderRadius.circular(10),
//         boxShadow: [
//           BoxShadow(
//               color:      Colors.black.withOpacity(0.05),
//               blurRadius: 4,
//               offset:     const Offset(0, 2)),
//         ],
//       ),
//       // KEY FIX: max fills the cell; Spacer pushes ADD to bottom
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.max,
//         children: [
//
//           // // ── Image: height = 72% of actual card width ──────────────
//           // LayoutBuilder(builder: (_, constraints) {
//           // ── Image: height = 72% of actual card width ──────────────
//           GestureDetector(
//             onTap: () => Navigator.push(context,
//                 MaterialPageRoute(
//                     builder: (_) => ProductDetailScreen(product: product))),
//             child: LayoutBuilder(builder: (_, constraints) {
//               final imgH = imageHeight > 0
//                   ? imageHeight
//                   : constraints.maxWidth * 0.72;
//               return Stack(children: [
//                 Container(
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey[300]!, width: 1),
//                     borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
//                   ),
//                   child: ClipRRect(
//                     borderRadius:
//                     const BorderRadius.vertical(top: Radius.circular(10)),
//                     child: SizedBox(
//                       height: imgH,
//                       width:  double.infinity,
//                       child:  _safeImage(
//                           image: product.image, imageUrl: product.imageUrl),
//                     ),
//                   ),
//                 ),
//                 if (product.computedDiscount > 0)
//                   Positioned(
//                     top: 5, left: 5,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 5, vertical: 2),
//                       decoration: BoxDecoration(
//                           color: const Color(0xFF1B5E20),
//                           borderRadius: BorderRadius.circular(4)),
//                       child: Text('↓${product.computedDiscount}%',
//                           style: const TextStyle(
//                               color:      Colors.white,
//                               fontSize:   8,
//                               fontWeight: FontWeight.bold)),
//                     ),
//                   ),
//                 // Out-of-stock overlay
//                 if (!product.isInStock)
//                   Positioned.fill(
//                     child: ClipRRect(
//                       borderRadius: const BorderRadius.vertical(
//                           top: Radius.circular(10)),
//                       child: Container(
//                         color:     Colors.black.withOpacity(0.35),
//                         alignment: Alignment.center,
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(6)),
//                           child: const Text('Out of Stock',
//                               style: TextStyle(
//                                   color:      Colors.red,
//                                   fontSize:   10,
//                                   fontWeight: FontWeight.bold)),
//                         ),
//                       ),
//                     ),
//                   ),
//               ]);
//             }),
//           ),
//
//           // ── Content (price / discount / name) ────────────────────
//           GestureDetector(
//             onTap: () {},
//             behavior: HitTestBehavior.opaque,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(7, 6, 7, 0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Price row
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Flexible(
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 5, vertical: 2),
//                               decoration: BoxDecoration(
//                                   color: const Color(0xFF388E3C),
//                                   borderRadius: BorderRadius.circular(4)),
//                               child: Text('₹${product.price.toInt()}',
//                                   style: const TextStyle(
//                                       color:      Colors.white,
//                                       fontSize:   9,
//                                       fontWeight: FontWeight.bold)),
//                             ),
//                             if (product.originalPrice > product.price && product.price > 0) ...[
//                               const SizedBox(width: 4),
//                               Flexible(
//                                 child: Text(
//                                     '₹${product.originalPrice.toInt()}',
//                                     style: TextStyle(
//                                         fontSize:   9,
//                                         color:      Colors.grey[500],
//                                         decoration:
//                                         TextDecoration.lineThrough),
//                                     overflow: TextOverflow.ellipsis,
//                                     maxLines: 1),
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                       if (product.displayWeight.isNotEmpty) ...[
//                         const SizedBox(width: 4),
//                         Flexible(
//                           child: Text(product.displayWeight,
//                               style: TextStyle(
//                                   fontSize: 8, color: Colors.grey[500]),
//                               maxLines:  1,
//                               overflow:  TextOverflow.ellipsis,
//                               textAlign: TextAlign.right),
//                         ),
//                       ],
//                     ],
//                   ),
//
//                   const SizedBox(height: 3),
//
//                   // Discount % — only shown when available (no reserved SizedBox)
//                   if (product.computedDiscount > 0) ...[
//                     Text('${product.computedDiscount}% off',
//                         style: const TextStyle(
//                             fontSize:   9,
//                             color:      Color(0xFF388E3C),
//                             fontWeight: FontWeight.w600)),
//                     const SizedBox(height: 3),
//                   ],
//
//                   // Product name — 2 lines max, ellipsis
//                   Text(product.name,
//                       style: const TextStyle(
//                           fontSize:   10,
//                           fontWeight: FontWeight.w500,
//                           color:      Colors.black87,
//                           height:     1.35),
//                       maxLines:  2,
//                       overflow:  TextOverflow.ellipsis),
//                 ],
//               ),
//             ),
//           ),
//
//           // Spacer absorbs leftover space → ADD button always at bottom
//           const Spacer(),
//
//           // ── ADD button always at bottom ────────────────────────────
//           Padding(
//             padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
//             child: _CartButton(
//                 product: product,
//                 isInStock: product.isInStock),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Compact card (overlay ADD button on image) ────────────────────────────
//   Widget _buildCompact(BuildContext context) {
//     return Consumer<CartModel>(
//         builder: (context, cart, _) {
//           final quantity = cart.getQuantity(product);
//           return Container(
//             margin: EdgeInsets.only(right: cardRightMargin),
//             decoration: BoxDecoration(
//               color:        Colors.white,
//               borderRadius: BorderRadius.circular(10),
//               border:       Border.all(color: Colors.grey[200]!),
//               boxShadow: [
//                 BoxShadow(
//                     color:      Colors.black.withOpacity(0.05),
//                     blurRadius: 4,
//                     offset:     const Offset(0, 2)),
//               ],
//             ),
//             child: Column(
//               mainAxisSize:       MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 GestureDetector(
//                   onTap: () => Navigator.push(context,
//                       MaterialPageRoute(
//                           builder: (_) => ProductDetailScreen(product: product))),
//                   child: Stack(children: [
//                     ClipRRect(
//                       borderRadius: const BorderRadius.vertical(
//                           top: Radius.circular(10)),
//                       child: SizedBox(
//                         height: imageHeight > 0 ? imageHeight : 100,
//                         width:  double.infinity,
//                         child:  _safeImage(
//                             image: product.image, imageUrl: product.imageUrl),
//                       ),
//                     ),
//                     if (product.computedDiscount > 0)
//                       Positioned(
//                         top: 5, left: 5,
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 4, vertical: 2),
//                           decoration: BoxDecoration(
//                               color: const Color(0xFF1B5E20),
//                               borderRadius: BorderRadius.circular(4)),
//                           child: Text('↓${product.computedDiscount}%',
//                               style: const TextStyle(
//                                   color:      Colors.white,
//                                   fontSize:   7,
//                                   fontWeight: FontWeight.bold)),
//                         ),
//                       ),
//                     Positioned(
//                       bottom: 6, right: 6,
//                       child: quantity == 0
//                           ? _AddButton(onTap: () => cart.addItem(product))
//                           : _StepperWidget(
//                         quantity:    quantity,
//                         onIncrement: () => cart.addItem(product),
//                         onDecrement: () =>
//                             cart.decrementQuantity(product.id),
//                       ),
//                     ),
//                   ]),
//                 ),
//
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // Price + weight
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Flexible(
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Container(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 5, vertical: 2),
//                                   decoration: BoxDecoration(
//                                       color: const Color(0xFF388E3C),
//                                       borderRadius:
//                                       BorderRadius.circular(4)),
//                                   child: Text('₹${product.price.toInt()}',
//                                       style: const TextStyle(
//                                           color:      Colors.white,
//                                           fontSize:   10,
//                                           fontWeight: FontWeight.bold)),
//                                 ),
//                                 if (product.originalPrice >
//                                     product.price) ...[
//                                   const SizedBox(width: 3),
//                                   Flexible(
//                                     child: Text(
//                                         '₹${product.originalPrice.toInt()}',
//                                         style: TextStyle(
//                                             color:      Colors.grey[500],
//                                             fontSize:   9,
//                                             decoration:
//                                             TextDecoration.lineThrough),
//                                         overflow: TextOverflow.ellipsis,
//                                         maxLines: 1),
//                                   ),
//                                 ],
//                               ],
//                             ),
//                           ),
//                           if (product.displayWeight.isNotEmpty)
//                             Flexible(
//                               child: Text(product.displayWeight,
//                                   style: TextStyle(
//                                       fontSize: 8,
//                                       color:    Colors.grey[500]),
//                                   maxLines:  1,
//                                   overflow:  TextOverflow.ellipsis,
//                                   textAlign: TextAlign.right),
//                             ),
//                         ],
//                       ),
//
//                       const SizedBox(height: 2),
//
//                       // Discount %
//                       if (product.computedDiscount > 0) ...[
//                         Text('${product.computedDiscount}% off',
//                             style: const TextStyle(
//                                 fontSize:   8,
//                                 color:      Color(0xFF388E3C),
//                                 fontWeight: FontWeight.w600)),
//                         const SizedBox(height: 2),
//                       ],
//
//                       // Product name
//                       Text(product.name,
//                           maxLines:  2,
//                           overflow:  TextOverflow.ellipsis,
//                           style: const TextStyle(
//                               fontSize:   10,
//                               fontWeight: FontWeight.w500,
//                               color:      Colors.black87,
//                               height:     1.3)),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }
//     );
//   }
//
//   // ── Image helper ───────────────────────────────────────────────────────────
//   Widget _safeImage({
//     required String image,
//     required String imageUrl,
//     BoxFit fit = BoxFit.cover,
//   }) {
//     bool isValid(String s) =>
//         s.isNotEmpty &&
//             s != 'no_image.png' &&
//             !s.startsWith('catalog/s-') &&
//             (s.startsWith('http') || s.startsWith('catalog/products/'));
//
//     String url = '';
//     if (isValid(imageUrl)) {
//       url = imageUrl.startsWith('http') ? imageUrl : '$_kImgBase$imageUrl';
//     } else if (isValid(image)) {
//       url = image.startsWith('http') ? image : '$_kImgBase$image';
//     }
//
//     if (url.isNotEmpty) {
//       return Image.network(
//         url,
//         fit: fit,
//         loadingBuilder: (_, child, prog) =>
//         prog == null ? child : Container(color: Colors.grey[100]),
//         errorBuilder: (_, __, ___) => _placeholder(),
//       );
//     }
//     return _placeholder();
//   }
//
//   Widget _placeholder() => Container(
//     color: Colors.grey[100],
//     child: const Center(
//         child: Icon(Icons.image_not_supported,
//             color: Colors.grey, size: 32)),
//   );
// }
//
// // ── Full ADD / stepper (bottom of full card) ──────────────────────────────────
// class _CartButton extends StatefulWidget {
//   final Product product;
//   final bool    isInStock;
//   const _CartButton({required this.product, required this.isInStock});
//
//   @override
//   State<_CartButton> createState() => _CartButtonState();
// }
//
// class _CartButtonState extends State<_CartButton> {
//   bool _editing = false;
//   late final TextEditingController _ctrl;
//   late final FocusNode _focus;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl  = TextEditingController();
//     _focus = FocusNode();
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     _focus.dispose();
//     super.dispose();
//   }
//
//   void _startEditing(int currentQty) {
//     _ctrl.text = '$currentQty';
//     _focus.requestFocus();
//     setState(() => _editing = true);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _ctrl.selection = TextSelection(
//         baseOffset:   0,
//         extentOffset: _ctrl.text.length,
//       );
//     });
//   }
//
//   void _commitEdit(CartModel cart) {
//     final val   = int.tryParse(_ctrl.text.trim()) ?? 0;
//     final stock = widget.product.quantity > 0
//         ? widget.product.quantity
//         : widget.product.posQuantity;
//     if (val <= 0) {
//       cart.removeItem(widget.product);
//     } else if (stock > 0 && val > stock) {
//       cart.setQuantity(widget.product, stock);
//       showDialog(
//         context: context,
//         barrierColor: Colors.black26,
//         builder: (_) => Center(
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 40),
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(Icons.info_outline, color: Color(0xFFFF0080), size: 36),
//                 const SizedBox(height: 12),
//                 Text(
//                   'Only $stock item${stock == 1 ? '' : 's'} available',
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
//                 ),
//                 const SizedBox(height: 16),
//                 GestureDetector(
//                   onTap: () => Navigator.pop(context),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
//                     decoration: BoxDecoration(color: const Color(0xFFFF0080), borderRadius: BorderRadius.circular(8)),
//                     child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     } else {
//       cart.setQuantity(widget.product, val);
//     }
//     setState(() => _editing = false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!widget.isInStock) {
//       return Container(
//         width:     double.infinity,
//         height:    30,
//         alignment: Alignment.center,
//         decoration: BoxDecoration(
//             color:        Colors.grey[200],
//             borderRadius: BorderRadius.circular(6)),
//         child: const Text('Out of Stock',
//             style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
//       );
//     }
//
//     // ── Has piece variants? Show "2 options" style label ──────────────
//     if (widget.product.pieces.isNotEmpty) {
//       return Consumer<CartModel>(
//         builder: (_, cart, __) {
//           int    totalQty = 0;
//           double totalAmt = 0;
//           for (final piece in widget.product.pieces) {
//             final pieceId = piece.cartId(widget.product.id);
//             final tmp = Product(
//               id:                 pieceId,
//               name:               '${widget.product.name} – ${piece.label}',
//               price:              piece.effectivePrice,
//               originalPrice:      piece.hasDiscount ? piece.price : piece.effectivePrice,
//               image:              widget.product.image,
//               imageUrl:           widget.product.imageUrl,
//               category:           widget.product.category,
//               weight:             piece.label,
//               sku:                widget.product.sku,
//               discountPercentage: piece.discountPct.toDouble(),
//               quantity:           widget.product.quantity,
//               posQuantity:        widget.product.posQuantity,
//             );
//             final q = cart.getQuantity(tmp);
//             totalQty += q;
//             totalAmt += q * piece.effectivePrice;
//           }
//           final hasItems  = totalQty > 0;
//           final borderClr = hasItems ? const Color(0xFF388E3C) : Colors.grey[300]!;
//           final textClr   = hasItems ? const Color(0xFF388E3C) : const Color(0xFFFF0080);
//           return GestureDetector(
//             onTap: () => handleAddToCart(context: context, product: widget.product, pieces: widget.product.pieces),
//             child: Container(
//               width:     double.infinity,
//               height:    36,
//               alignment: Alignment.center,
//               decoration: BoxDecoration(
//                 color:        Colors.white,
//                 borderRadius: BorderRadius.circular(6),
//                 border: Border.all(color: borderClr, width: 1.2),
//               ),
//               child: hasItems
//                   ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//                 Text('ADD (${widget.product.pieces.length} opp)',
//                     style: TextStyle(color: textClr, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
//                 Text('₹${totalAmt.toInt()}', style: TextStyle(color: textClr, fontSize: 9, fontWeight: FontWeight.w700)),
//               ])
//                   : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//                 Text('ADD', style: TextStyle(color: textClr, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
//                 Text(widget.product.pieces.length == 1 ? '1 option' : '${widget.product.pieces.length} options',
//                     textAlign: TextAlign.center, style: TextStyle(color: textClr, fontSize: 8)),
//               ]),
//             ),
//           );
//         },
//       );
//     }
//
//     return Consumer<CartModel>(
//       builder: (_, cart, __) {
//         final qty = cart.getQuantity(widget.product);
//         if (qty == 0) {
//           return GestureDetector(
//             onTap: () => cart.addItem(widget.product),
//             child: Container(
//               width:     double.infinity,
//               height:    36,
//               alignment: Alignment.center,
//               decoration: BoxDecoration(
//                 color:        Colors.white,
//                 borderRadius: BorderRadius.circular(6),
//                 border: Border.all(color: Colors.grey[300]!, width: 1.2),
//               ),
//               child: const Text('ADD',
//                   style: TextStyle(color: Color(0xFFFF0080), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
//             ),
//           );
//         }
//         final liveQty   = _editing ? (int.tryParse(_ctrl.text) ?? qty) : qty;
//         final liveTotal = (liveQty * widget.product.price).toInt();
//         return Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               height: 36,
//               decoration: BoxDecoration(color: const Color(0xFFFF0080), borderRadius: BorderRadius.circular(6)),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   GestureDetector(
//                     onTap: () => cart.decrementQuantity(widget.product.id),
//                     child: const SizedBox(width: 32, height: 36, child: Icon(Icons.remove, color: Colors.white, size: 15)),
//                   ),
//                   if (_editing)
//                     SizedBox(
//                       width: 42,
//                       child: TextField(
//                         controller:   _ctrl,
//                         focusNode:    _focus,
//                         keyboardType: TextInputType.number,
//                         textAlign:    TextAlign.center,
//                         style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
//                         decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
//                         onChanged:    (_) => setState(() {}),
//                         onSubmitted:  (_) => _commitEdit(cart),
//                         onTapOutside: (_) => _commitEdit(cart),
//                       ),
//                     )
//                   else
//                     GestureDetector(
//                       onTapDown: (_) => _startEditing(qty),
//                       child: Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
//                     ),
//                   GestureDetector(
//                     onTap: () {
//                       final stock = widget.product.quantity > 0 ? widget.product.quantity : widget.product.posQuantity;
//                       if (stock > 0 && qty >= stock) {
//                         showDialog(
//                           context: context,
//                           barrierColor: Colors.black26,
//                           builder: (_) => Center(
//                             child: Container(
//                               margin: const EdgeInsets.symmetric(horizontal: 40),
//                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//                               decoration: BoxDecoration(
//                                 color: Colors.white, borderRadius: BorderRadius.circular(16),
//                                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)],
//                               ),
//                               child: Column(mainAxisSize: MainAxisSize.min, children: [
//                                 const Icon(Icons.info_outline, color: Color(0xFFFF0080), size: 36),
//                                 const SizedBox(height: 12),
//                                 Text('Only $stock item${stock == 1 ? '' : 's'} available',
//                                     textAlign: TextAlign.center,
//                                     style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
//                                 const SizedBox(height: 16),
//                                 GestureDetector(
//                                   onTap: () => Navigator.pop(context),
//                                   child: Container(
//                                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
//                                     decoration: BoxDecoration(color: const Color(0xFFFF0080), borderRadius: BorderRadius.circular(8)),
//                                     child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
//                                   ),
//                                 ),
//                               ]),
//                             ),
//                           ),
//                         );
//                         return;
//                       }
//                       cart.addItem(widget.product);
//                     },
//                     child: const SizedBox(width: 32, height: 36, child: Icon(Icons.add, color: Colors.white, size: 15)),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
//
// // ── Small + button (overlay on compact card) ──────────────────────────────────
// class _AddButton extends StatelessWidget {
//   final VoidCallback onTap;
//   const _AddButton({required this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width:  30,
//         height: 30,
//         decoration: BoxDecoration(
//           color:        Colors.white,
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: const Color(0xFFFF0080), width: 1.5),
//           boxShadow: [
//             BoxShadow(
//                 color:      Colors.black.withOpacity(0.1),
//                 blurRadius: 4,
//                 offset:     const Offset(0, 1))
//           ],
//         ),
//         child: const Icon(Icons.add, color: Color(0xFFB85C00), size: 18),
//       ),
//     );
//   }
// }
//
// // ── Inline stepper (overlay on compact card) ──────────────────────────────────
// class _StepperWidget extends StatelessWidget {
//   final int          quantity;
//   final VoidCallback onIncrement;
//   final VoidCallback onDecrement;
//
//   const _StepperWidget({
//     required this.quantity,
//     required this.onIncrement,
//     required this.onDecrement,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 30,
//       decoration: BoxDecoration(
//         color:        const Color(0xFFFF0080),
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//               color:      Colors.black.withOpacity(0.15),
//               blurRadius: 4,
//               offset:     const Offset(0, 1))
//         ],
//       ),
//       child: Row(mainAxisSize: MainAxisSize.min, children: [
//         GestureDetector(
//           onTap: onDecrement,
//           child: Container(
//               width: 28, height: 30,
//               alignment: Alignment.center,
//               child: const Icon(Icons.remove, color: Colors.white, size: 15)),
//         ),
//         Container(
//           constraints: const BoxConstraints(minWidth: 22),
//           alignment:   Alignment.center,
//           child: Text('$quantity',
//               style: const TextStyle(
//                   color:      Colors.white,
//                   fontSize:   12,
//                   fontWeight: FontWeight.bold)),
//         ),
//         GestureDetector(
//           onTap: onIncrement,
//           child: Container(
//               width: 28, height: 30,
//               alignment: Alignment.center,
//               child: const Icon(Icons.add, color: Colors.white, size: 15)),
//         ),
//       ]),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/products/product_detail_screen.dart';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../model/favorites_model.dart';
import '../model/product_model.dart';
import '../services/api_config_service.dart';
import '../widgets/piece_selector_sheet.dart';

final String _kImgBase = ApiConfig.imageBase;

const Color _kGreen      = AppColors.freshGreen;
const Color _kLightGreen = AppColors.lightGreen;

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

  // ── Full card — Blinkit style ──────────────────────────────────────────────
  Widget _buildFull(BuildContext context) {
    return Consumer2<CartModel, FavoritesModel>(
      builder: (context, cart, favs, _) {
        final isFav = favs.isFavorite(product.id);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
          ),
          child: Container(
            margin: EdgeInsets.only(right: cardRightMargin),
            decoration: BoxDecoration(
              color:        AppColors.cardWhite,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset:     const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Image area ──────────────────────────────────────────
                LayoutBuilder(builder: (_, constraints) {
                  final imgH = imageHeight > 0
                      ? imageHeight
                      : constraints.maxWidth * 0.55;
                  return Stack(clipBehavior: Clip.none, children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: Container(
                        color: const Color(0xFFF8F8F8),
                        child: SizedBox(
                          height: imgH,
                          width:  double.infinity,
                          child:  _safeImage(image: product.image, imageUrl: product.imageUrl),
                        ),
                      ),
                    ),

                    // Out-of-stock overlay
                    if (!product.isInStock)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          child: Container(
                            color: Colors.white.withOpacity(0.72),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Text('Out of Stock',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),

                    // Heart button — top right
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: () {
                          favs.toggleFavorite(product);
                        },
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isFav ? Colors.red : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),

                    // Cart stepper — bottom right overlay
                    Positioned(
                      bottom: -6, right: 0,
                      child: GestureDetector(
                        onTap: () {}, // absorb tap so card nav doesn't fire
                        behavior: HitTestBehavior.opaque,
                        child: _OverlayCartButton(product: product, cart: cart),
                      ),
                    ),
                  ]);
                }),

                // ── Info below image ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Discount badge — yellow pill
                      if (product.computedDiscount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryYellow,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${product.computedDiscount}% OFF',
                            style: const TextStyle(
                              color:      AppColors.textDark,
                              fontSize:   10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),

                      const SizedBox(height: 2),

// Price row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${product.price % 1 == 0 ? product.price.toInt() : product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w900,
                              color:      AppColors.textDark,
                            ),
                          ),
                          if (product.originalPrice > product.price && product.price > 0) ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '₹${product.originalPrice.toInt()}',
                                style: const TextStyle(
                                  fontSize:        12,
                                  color:           AppColors.textGrey,
                                  decoration:      TextDecoration.lineThrough,
                                  decorationColor: AppColors.textGrey,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 1),

                      // Brand / category label (small muted text)
                      if (product.category.isNotEmpty && int.tryParse(product.category) == null)
                        Text(
                          product.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize:      9,
                            color:         Color(0xFF888888),
                            fontWeight:    FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 1),

// Product name
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.textDark,
                          height:     1.3,
                        ),
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      // Weight selector row (green text + chevron)
                      if (product.displayWeight.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.displayWeight,
                              style: const TextStyle(
                                fontSize:   12,
                                color:      _kGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // const SizedBox(width: 3),
                            // const Icon(Icons.keyboard_arrow_down,
                            //     color: _kGreen, size: 16),
                          ],
                        ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Compact card (unchanged logic, minor style refresh) ───────────────────
  Widget _buildCompact(BuildContext context) {
    return Consumer<CartModel>(
      builder: (context, cart, _) {
        final quantity = cart.getQuantity(product);
        return Container(
          margin: EdgeInsets.only(right: cardRightMargin),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8)),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      color: const Color(0xFFF8F8F8),
                      child: SizedBox(
                        height: imageHeight > 0 ? imageHeight : 100,
                        width:  double.infinity,
                        child:  _safeImage(image: product.image, imageUrl: product.imageUrl),
                      ),
                    ),
                  ),
                  if (product.computedDiscount > 0)
                    Positioned(
                      top: 5, left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow,
                          borderRadius: BorderRadius.circular(4)),
                        child: Text('${product.computedDiscount}% OFF',
                            style: const TextStyle(
                                color:      AppColors.textDark,
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
                      onDecrement: () => cart.decrementQuantity(product.id),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (product.displayWeight.isNotEmpty)
                      Text(product.displayWeight,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF777777),
                              fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(product.name,
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                            color:      Color(0xFF1C1C1C),
                            height:     1.3)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('₹${product.price.toInt()}',
                            style: const TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w800,
                                color:      Color(0xFF1C1C1C))),
                        if (product.originalPrice > product.price) ...[
                          const SizedBox(width: 4),
                          Text('₹${product.originalPrice.toInt()}',
                              style: const TextStyle(
                                  color:           Color(0xFF999999),
                                  fontSize:        10,
                                  decoration:      TextDecoration.lineThrough,
                                  decorationColor: Color(0xFF999999)),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        prog == null ? child : Container(color: const Color(0xFFF8F8F8)),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF8F8F8),
    child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.grey.shade300, size: 28)),
  );
}

// ── Overlay cart button (stepper on image, bottom-right) ─────────────────────
// Matches the screenshot: white square with green "+" when empty,
// green pill stepper with – qty + when in cart.
class _OverlayCartButton extends StatefulWidget {
  final Product   product;
  final CartModel cart;
  const _OverlayCartButton({required this.product, required this.cart});

  @override
  State<_OverlayCartButton> createState() => _OverlayCartButtonState();
}

class _OverlayCartButtonState extends State<_OverlayCartButton> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing(int currentQty) {
    _ctrl.text = '$currentQty';
    _focus.requestFocus();
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.selection = TextSelection(
          baseOffset: 0, extentOffset: _ctrl.text.length);
    });
  }

  void _commitEdit(CartModel cart) {
    final val   = int.tryParse(_ctrl.text.trim()) ?? 0;
    final stock = widget.product.quantity > 0
        ? widget.product.quantity
        : widget.product.posQuantity;
    if (val <= 0) {
      cart.removeItem(widget.product);
    } else if (stock > 0 && val > stock) {
      cart.setQuantity(widget.product, stock);
    } else {
      cart.setQuantity(widget.product, val);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Piece-variant products: show ADD sheet trigger
    if (widget.product.pieces.isNotEmpty) {
      return Consumer<CartModel>(
        builder: (_, cart, __) {
          final qty = cart.getPieceQuantity(widget.product.id);
          return GestureDetector(
            onTap: () => handleAddToCart(
                context: context,
                product: widget.product,
                pieces:  widget.product.pieces),
            child: qty > 0
                ? _greenStepper(
              qty: qty,
              onDecrement: () => cart.getPieceQuantity(widget.product.id) > 0
                  ? handleAddToCart(
                  context: context,
                  product: widget.product,
                  pieces:  widget.product.pieces)
                  : null,
              onIncrement: () => handleAddToCart(
                  context: context,
                  product: widget.product,
                  pieces:  widget.product.pieces),
            )
                : _addBox(),
          );
        },
      );
    }

    // Standard product
    return Consumer<CartModel>(
      builder: (_, cart, __) {
        final qty = cart.getQuantity(widget.product);
        if (qty == 0) {
          return GestureDetector(
            onTap: () {
              if (!widget.product.isInStock) return;
              cart.addItem(widget.product);
            },
            child: _addBox(),
          );
        }
        return _greenStepper(
          qty: qty,
          onDecrement: () => cart.decrementQuantity(widget.product.id),
          onIncrement: () {
            final stock = widget.product.quantity > 0
                ? widget.product.quantity
                : widget.product.posQuantity;
            if (stock > 0 && qty >= stock) return;
            cart.addItem(widget.product);
          },
          editing:     _editing,
          ctrl:        _ctrl,
          focus:       _focus,
          onTapQty:    () => _startEditing(qty),
          onSubmitQty: () => _commitEdit(cart),
        );
      },
    );
  }

  // White box with green + (empty state)
  Widget _addBox() => Container(
    width: 34, height: 30,
    decoration: BoxDecoration(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.addBtnGreen, width: 1.8),
      boxShadow: [
        BoxShadow(
          color:      Colors.black.withOpacity(0.10),
          blurRadius: 6,
          offset:     const Offset(0, 2),
        ),
      ],
    ),
    child: const Icon(Icons.add, color: AppColors.addBtnGreen, size: 18),
  );

  // Green pill stepper (in-cart state)
  Widget _greenStepper({
    required int qty,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    bool editing = false,
    TextEditingController? ctrl,
    FocusNode? focus,
    VoidCallback? onTapQty,
    VoidCallback? onSubmitQty,
  }) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color:        AppColors.addBtnGreen,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color:      AppColors.addBtnGreen.withOpacity(0.30),
            blurRadius: 8,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: const SizedBox(
              width: 34, height: 30,
              child: Icon(Icons.remove, color: AppColors.textLight, size: 16),
            ),
          ),
          if (editing && ctrl != null && focus != null)
            SizedBox(
              width: 34,
              child: TextField(
                controller:   ctrl,
                focusNode:    focus,
                keyboardType: TextInputType.number,
                textAlign:    TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                onChanged:    (_) => setState(() {}),
                onSubmitted:  (_) => onSubmitQty?.call(),
                onTapOutside: (_) => onSubmitQty?.call(),
              ),
            )
          else
            GestureDetector(
              onTapDown: (_) => onTapQty?.call(),
              child: Container(
                constraints: const BoxConstraints(minWidth: 28),
                alignment: Alignment.center,
                child: Text(
                  '$qty',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          GestureDetector(
            onTap: onIncrement,
            child: const SizedBox(
              width: 34, height: 30,
              child: Icon(Icons.add, color: AppColors.textLight, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small + button (compact card overlay) ────────────────────────────────────
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGreen, width: 1.5),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset:     const Offset(0, 1)),
          ],
        ),
        child: const Icon(Icons.add, color: _kGreen, size: 18),
      ),
    );
  }
}

// ── Inline stepper (compact card overlay) ────────────────────────────────────
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
      height: 32,
      decoration: BoxDecoration(
        color:        _kGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onDecrement,
          child: Container(
              width: 28, height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 14)),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 22),
          alignment:   Alignment.center,
          child: Text('$quantity',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: onIncrement,
          child: Container(
              width: 28, height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 14)),
        ),
      ]),
    );
  }
}