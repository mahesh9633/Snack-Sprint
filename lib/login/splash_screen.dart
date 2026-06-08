import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/login/login_screen.dart';
import 'package:mtl_groceriesapp/screens/location_gateway.dart';
import '../services/session_manager.dart';
import '../services/api_server.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _animController.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      _checkLoginAndNavigate();
    });
  }

  Future<void> _checkLoginAndNavigate() async {
    if (!mounted) return;

    final isLoggedIn = await SessionManager.isLoggedIn();
    final token      = await SessionManager.getToken();
    final telephone  = await SessionManager.getTelephone();
    final customerId = await SessionManager.getCustomerId();

    if (!mounted) return;

    if (isLoggedIn && token != null && token.isNotEmpty) {
      final isValid = await ApiService.validateToken(
        token: token,
        customerId: customerId ?? '',
      );

      if (!mounted) return;

      if (!isValid) {
        await SessionManager.clearSession();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LocationGateway(
            telephone:     telephone ?? '',
            customerId:    customerId ?? '',
            authToken:     token,
            isNewCustomer: false,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFBA5523),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DiagonalPatternPainter(),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 220),
              painter: _StoreIllustrationPainter(),
            ),
          ),

          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: -50,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/dbm_logo.jpg',
                      width: 200,
                      height: 160,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Durga Bhavani',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 1.5,
                          color: const Color(0xFFF5A800),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'WHOLESALE MART',
                          style: TextStyle(
                            color: Color(0xFFF5A800),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 1.5,
                          color: const Color(0xFFF5A800),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TagBadge(icon: Icons.eco_outlined, label: 'Fresh'),
                        const SizedBox(width: 6),
                        const Text(
                          '•',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TagBadge(icon: Icons.bolt_outlined, label: 'Fast'),
                        const SizedBox(width: 6),
                        const Text(
                          '•',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TagBadge(
                            icon: Icons.local_offer_outlined,
                            label: 'Best Price'),
                      ],
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white.withOpacity(0.75),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                  children: const [
                    TextSpan(text: 'Powered by '),
                    TextSpan(
                      text: 'MY TEKNOLAND',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small icon + text badge ──
class _TagBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TagBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diagonal stripe painter ──
class _DiagonalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 14.0;
    final total = size.width + size.height;
    var d = -size.height;
    while (d < size.width) {
      canvas.drawLine(Offset(d, 0), Offset(d + total, total), paint);
      d += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Bottom store shelf illustration ──
class _StoreIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    // Ground wave
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.55);
    wavePath.quadraticBezierTo(
      size.width * 0.25, size.height * 0.42,
      size.width * 0.5,  size.height * 0.52,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.75, size.height * 0.62,
      size.width,        size.height * 0.50,
    );
    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();
    canvas.drawPath(wavePath, paint);

    // Left shelf unit
    _drawShelf(canvas, paint, size, 0.04, 0.30, 0.28);

    // Right shelf unit
    _drawShelf(canvas, paint, size, 0.72, 0.30, 0.28);
  }

  void _drawShelf(Canvas canvas, Paint paint, Size size,
      double xRatio, double yRatio, double widthRatio) {
    final x = size.width * xRatio;
    final y = size.height * yRatio;
    final w = size.width * widthRatio;
    final shelfH = size.height * 0.06;
    final gap = size.height * 0.10;

    // 3 shelf planks
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y + i * gap, w, shelfH),
          const Radius.circular(3),
        ),
        paint,
      );
      // Small boxes on each shelf
      final boxPaint = Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..style = PaintingStyle.fill;
      for (int j = 0; j < 4; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x + 4 + j * (w / 4.2),
              y + i * gap - shelfH * 1.2,
              w / 5,
              shelfH * 1.2,
            ),
            const Radius.circular(2),
          ),
          boxPaint,
        );
      }
    }

    // Vertical support
    canvas.drawRect(
      Rect.fromLTWH(x, y, 4, gap * 2 + shelfH),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + w - 4, y, 4, gap * 2 + shelfH),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}