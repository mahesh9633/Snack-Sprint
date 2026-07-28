// ─── Single source of truth for reading stock/quantity from backend JSON ──
// Every screen (Home, Categories, Trending, Product Detail) MUST call these
// two functions instead of writing its own parsing logic. This guarantees
// that whatever the backend sends is interpreted identically everywhere —
// if the backend updates a quantity, every screen updates the same way,
// automatically, with no per-screen drift.

/// Resolves a PRODUCT-level quantity from raw backend JSON.
///
/// Checks the raw quantity fields FIRST — trying BOTH the correct spelling
/// and the backend's misspelled `pos_quentity` key, since different
/// endpoints send different spellings for the same value. If a real,
/// positive quantity is present, it always wins.
///
/// ── FIX: previously `stock_status` was checked BEFORE the raw quantity,
/// so a stale/out-of-sync `stock_status` ("out of stock" / "0") could
/// force a return of 0 even when the backend's actual `quantity` had
/// since been increased and was genuinely > 0. This caused cart items to
/// be incorrectly auto-removed on refresh even though real stock was
/// available. Now a positive parsed quantity is trusted first, and
/// `stock_status` / `subtract` are only used as fallbacks when the raw
/// quantity itself is missing, empty, or non-positive. ──
int resolveProductQuantity(Map<String, dynamic> j) {
  final stockStatus = j['stock_status']?.toString().toLowerCase() ?? '';
  final subtract    = j['subtract']?.toString() ?? '';
  final rawQtyStr   = j['pos_quentity']?.toString() ??
      j['pos_quantity']?.toString() ??
      j['quantity']?.toString() ?? '';

  final int? parsedQty = int.tryParse(rawQtyStr);

  // ✅ A real positive quantity always wins — never let a stale
  // stock_status override actual available stock.
  if (parsedQty != null && parsedQty > 0) {
    return parsedQty;
  }

  if (stockStatus.isNotEmpty &&
      (stockStatus == 'out of stock' ||
          stockStatus == '0' ||
          stockStatus == 'outofstock')) {
    return 0;
  } else if (stockStatus.isNotEmpty &&
      (stockStatus.contains('in stock') ||
          stockStatus == '1' ||
          stockStatus == '2')) {
    return 1;
  } else if (subtract == '0') {
    return 1;
  } else if (rawQtyStr.isEmpty || rawQtyStr == 'null') {
    return 1;
  } else {
    int qty = parsedQty ?? 1;
    if (qty == 0 && stockStatus.isEmpty && subtract.isEmpty) qty = 1;
    return qty;
  }
}

/// Resolves whether a product is a combo, from raw backend JSON.
bool resolveIsCombo(Map<String, dynamic> j) {
  return (j['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes';
}

/// Resolves a PIECE-level stock from a single piece's raw JSON map.
/// Checks ALL known spellings the backend uses for this field
/// (`pos_quantity`, the misspelled `pos_quentity`, and plain `quantity`),
/// so no screen silently reads 0 just because it only checked one spelling.
///
/// For combo products, if the piece itself reports 0 stock, we fall back to
/// the product-level quantity (combos are sold as a whole unit).
int resolvePieceStock(
    Map<String, dynamic> pieceJson, {
      required bool productIsCombo,
      required int productLevelQty,
    }) {
  final pieceRawStock = int.tryParse(
      (pieceJson['pos_quantity'] ??
          pieceJson['pos_quentity'] ??
          pieceJson['quantity'] ??
          '0')
          .toString()) ??
      0;
  return (productIsCombo && pieceRawStock == 0)
      ? productLevelQty
      : pieceRawStock;
}