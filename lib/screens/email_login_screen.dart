// import 'package:flutter/material.dart';
// import '../config/app_color.dart';
// import '../login/otp_screen.dart';
//
// import '../services/auth_service.dart';
//
// class EmailLoginScreen extends StatefulWidget {
//   const EmailLoginScreen({super.key});
//
//   @override
//   State<EmailLoginScreen> createState() => _EmailLoginScreenState();
// }
//
// class _EmailLoginScreenState extends State<EmailLoginScreen> {
//   final TextEditingController _emailController = TextEditingController();
//   bool _isSending = false;
//   String _errorMessage = '';
//
//   static final RegExp _emailRegex =
//   RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
//
//   bool get _isValidEmail => _emailRegex.hasMatch(_emailController.text.trim());
//
//   Future<void> _sendOtp() async {
//     final email = _emailController.text.trim();
//     if (!_emailRegex.hasMatch(email)) {
//       setState(() => _errorMessage = 'Enter a valid email address');
//       return;
//     }
//
//     setState(() {
//       _isSending    = true;
//       _errorMessage = '';
//     });
//
//     final result = await AuthService.sendMailOtp(email);
//
//     if (!mounted) return;
//     setState(() => _isSending = false);
//
//     if (result.success) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => OtpScreen(
//             identifier: email,
//             channel:    OtpChannel.email,
//             otpRef:     result.otpRef ?? '',
//             debugOtp:   result.otp,
//           ),
//         ),
//       );
//     } else {
//       setState(() {
//         _errorMessage = result.message ?? 'Failed to send OTP. Try again.';
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.scaffoldBg,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 20),
//
//               Container(
//                 width:  64,
//                 height: 64,
//                 decoration: BoxDecoration(
//                   color:        AppColors.primaryOrange.withOpacity(0.12),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: const Icon(Icons.mail_outline,
//                     color: AppColors.primaryOrange, size: 30),
//               ),
//               const SizedBox(height: 20),
//
//               const Text(
//                 'Login with email',
//                 style: TextStyle(
//                   fontSize:   24,
//                   fontWeight: FontWeight.bold,
//                   color:      AppColors.primaryBlue,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 "We'll send a one-time OTP to your email",
//                 style: TextStyle(fontSize: 15, color: AppColors.textGrey),
//               ),
//               const SizedBox(height: 36),
//
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(14),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.08),
//                       blurRadius: 10,
//                     ),
//                   ],
//                 ),
//                 child: TextField(
//                   controller: _emailController,
//                   keyboardType: TextInputType.emailAddress,
//                   autofillHints: const [AutofillHints.email],
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.textDark,
//                   ),
//                   onChanged: (_) => setState(() => _errorMessage = ''),
//                   onSubmitted: (_) {
//                     if (_isValidEmail && !_isSending) _sendOtp();
//                   },
//                   decoration: InputDecoration(
//                     hintText: 'Enter your email',
//                     hintStyle: TextStyle(
//                       color: Colors.grey[400],
//                       fontSize: 16,
//                       fontWeight: FontWeight.normal,
//                     ),
//                     prefixIcon: const Icon(Icons.alternate_email,
//                         color: Color(0xFF6B7280)),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(14),
//                       borderSide: BorderSide.none,
//                     ),
//                     filled: true,
//                     fillColor: Colors.white,
//                     contentPadding: const EdgeInsets.symmetric(
//                         vertical: 8, horizontal: 10),
//                   ),
//                 ),
//               ),
//
//               if (_errorMessage.isNotEmpty) ...[
//                 const SizedBox(height: 10),
//                 Row(children: [
//                   Icon(Icons.error_outline, color: Colors.red[400], size: 16),
//                   const SizedBox(width: 6),
//                   Expanded(
//                     child: Text(
//                       _errorMessage,
//                       style: const TextStyle(color: AppColors.error, fontSize: 13),
//                     ),
//                   ),
//                 ]),
//               ],
//
//               const SizedBox(height: 32),
//
//               SizedBox(
//                 width: double.infinity,
//                 height: 45,
//                 child: ElevatedButton(
//                   onPressed: (_isValidEmail && !_isSending) ? _sendOtp : null,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primaryOrange,
//                     disabledBackgroundColor:
//                     AppColors.primaryOrange.withOpacity(0.5),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(14)),
//                     elevation: 4,
//                     shadowColor: AppColors.primaryOrange.withOpacity(0.4),
//                   ),
//                   child: _isSending
//                       ? const SizedBox(
//                     width: 18,
//                     height: 18,
//                     child: CircularProgressIndicator(
//                         color: Colors.white, strokeWidth: 1.5),
//                   )
//                       : const Text(
//                     'Send OTP',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     super.dispose();
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_color.dart';
import '../login/otp_screen.dart';

import '../services/auth_service.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  bool _isSending = false;
  String _errorMessage = '';

  static final RegExp _emailRegex =
  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isValidEmail => _emailRegex.hasMatch(_emailController.text.trim());
  bool get _isValidTelephone =>
      _telephoneController.text.trim().length == 10;
  bool get _isFormValid => _isValidEmail && _isValidTelephone;

  Future<void> _sendOtp() async {
    final email     = _emailController.text.trim();
    final telephone = _telephoneController.text.trim();

    if (!_emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid email address');
      return;
    }
    if (telephone.length != 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isSending    = true;
      _errorMessage = '';
    });

    final result = await AuthService.sendMailOtp(
      email:     email,
      telephone: telephone,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            identifier:     email,
            channel:        OtpChannel.email,
            otpRef:         result.otpRef ?? '',
            debugOtp:       result.otp,
            emailTelephone: telephone,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Failed to send OTP. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Container(
                width:  64,
                height: 64,
                decoration: BoxDecoration(
                  color:        AppColors.primaryOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mail_outline,
                    color: AppColors.primaryOrange, size: 30),
              ),
              const SizedBox(height: 20),

              const Text(
                'Login with email',
                style: TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "We'll send a one-time OTP to your email",
                style: TextStyle(fontSize: 15, color: AppColors.textGrey),
              ),
              const SizedBox(height: 28),

              // ── Email field ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  onChanged: (_) => setState(() => _errorMessage = ''),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: const Icon(Icons.alternate_email,
                        color: AppColors.textGrey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 14),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── WhatsApp mobile number field ────────────────────────
              const Text(
                'WhatsApp mobile number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.textDark,
                  ),
                  onChanged: (_) => setState(() => _errorMessage = ''),
                  onSubmitted: (_) {
                    if (_isFormValid && !_isSending) _sendOtp();
                  },
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Mobile Number',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      child: const Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                    prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 14),
                  ),
                ),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ]),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isFormValid && !_isSending) ? _sendOtp : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    disabledBackgroundColor:
                    AppColors.primaryOrange.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: AppColors.primaryOrange.withOpacity(0.4),
                  ),
                  child: _isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    'Send OTP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }
}