import 'package:flutter/material.dart';
import '../config/app_color.dart';

class CategoryChip extends StatelessWidget {
  final String? icon;
  final String? imageUrl;
  final String         label;
  final bool           isSelected;
  final VoidCallback   onTap;

  const CategoryChip({
    super.key,
    this.icon,
    this.imageUrl,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  62,
              height: 62,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryOrange : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryOrange
                      : Colors.grey[300]!,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                      color: AppColors.primaryOrange
                          .withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
                    : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4)
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _inner(),
            ),

            const SizedBox(height: 6),

            SizedBox(
              width: 70,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryOrange
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inner() {
    if (icon != null && icon!.isNotEmpty) {
      return Center(child: Text(icon!, style: const TextStyle(fontSize: 28)));
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: 62, height: 62,
        errorBuilder:   (_, __, ___) => _fallback(),
        loadingBuilder: (_, child, prog) =>
        prog == null ? child : _spinner(),
      );
    }

    return _fallback();
  }

  Widget _fallback() => Container(
    color: Colors.grey[100],
    child: Center(
      child: Icon(Icons.category,
          color: isSelected ? Colors.white : Colors.grey[400],
          size: 26),
    ),
  );

  Widget _spinner() => Container(
    color: Colors.grey[100],
    child: const Center(
      child: SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.primaryOrange),
      ),
    ),
  );
}