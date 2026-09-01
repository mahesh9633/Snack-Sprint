// import 'package:flutter/material.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/services.dart';
// import 'package:mtl_groceriesapp/login/otp_screen.dart';
// import '../config/app_color.dart';
// import '../screens/privacy_policy.dart';
// import '../screens/terms_conditions.dart';
// import '../services/auth_service.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final TextEditingController _telephoneController = TextEditingController();
//   bool _isSending = false;
//   String _errorMessage = '';
//
//   bool get _isValidTelephone =>
//       _telephoneController.text.trim().length == 10;
//
//   Future<void> _sendOtp() async {
//     final telephone = _telephoneController.text.trim();
//     if (telephone.length != 10) {
//       setState(() => _errorMessage = 'Enter a valid 10-digit mobile number');
//       return;
//     }
//
//     setState(() {
//       _isSending    = true;
//       _errorMessage = '';
//     });
//
//     final result = await AuthService.sendOtp(telephone);
//
//     if (!mounted) return;
//     setState(() => _isSending = false);
//
//     if (result.success) {
//       TextInput.finishAutofillContext();
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => OtpScreen(
//             telephone: telephone,
//             otpRef:    result.otpRef ?? '',
//             debugOtp:  result.otp,
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
//   void _openTerms() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => const TermsConditionsScreen(fromProfile: false),
//       ),
//     );
//   }
//
//   void _openPrivacyPolicy() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => const PrivacyPolicyScreen(fromProfile: false),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.scaffoldBg,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 40),
//
//               Center(
//                 child: Image.asset(
//                   'assets/images/smile_logo.png',
//                   width: 280,
//                   height: 240,
//                   fit: BoxFit.contain,
//                 ),
//               ),
//
//               const SizedBox(height: 10),
//
//               const Text(
//                 'Welcome!',
//                 style: TextStyle(
//                   fontSize: 30,
//                   fontWeight: FontWeight.bold,
//                   color: AppColors.primaryBlue,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 'Enter your WhatsApp mobile number',
//                 style: TextStyle(fontSize: 15, color: AppColors.textGrey),
//               ),
//               const SizedBox(height: 36),
//
//               AutofillGroup(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(14),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.08),
//                         blurRadius: 10,
//                       ),
//                     ],
//                   ),
//                   child: TextField(
//                     controller: _telephoneController,
//                     keyboardType: TextInputType.phone,
//                     maxLength: 10,
//                     autofillHints: const [AutofillHints.telephoneNumberNational],
//                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       letterSpacing: 2,
//                       color: AppColors.textDark,
//                     ),
//                     onChanged: (value) {
//                       String digits = value.replaceAll(RegExp(r'\D'), '');
//
//                       final matches = RegExp(r'([6-9]\d{9})').allMatches(digits).toList();
//
//                       if (matches.isNotEmpty) {
//                         digits = matches.last.group(0)!;
//                       } else if (digits.length > 10) {
//                         digits = digits.substring(digits.length - 10);
//                       }
//
//                       if (digits != _telephoneController.text) {
//                         _telephoneController.value = TextEditingValue(
//                           text: digits,
//                           selection: TextSelection.collapsed(offset: digits.length),
//                         );
//                       }
//
//                       setState(() => _errorMessage = '');
//                     },
//                     onSubmitted: (_) {
//                       if (_isValidTelephone && !_isSending) _sendOtp();
//                     },
//                     decoration: InputDecoration(
//                       counterText: '',
//                       hintText: 'Mobile Number',
//                       hintStyle: TextStyle(
//                         color: Colors.grey[400],
//                         fontSize: 16,
//                         fontWeight: FontWeight.normal,
//                         letterSpacing: 0,
//                       ),
//                       prefixIcon: Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 14, vertical: 14),
//                         child: const Text(
//                           '+91',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             // color: AppColors.appBarText,
//                             color: Color(0xFF6B7280),
//                           ),
//                         ),
//                       ),
//                       prefixIconConstraints:
//                       const BoxConstraints(minWidth: 0, minHeight: 0),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(14),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.white,
//                       contentPadding: const EdgeInsets.symmetric(
//                           vertical: 18, horizontal: 16),
//                     ),
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
//                 height: 56,
//                 child: ElevatedButton(
//                   onPressed:
//                   (_isValidTelephone && !_isSending) ? _sendOtp : null,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primaryOrange,
//                     disabledBackgroundColor: AppColors.primaryOrange.withOpacity(0.5),
//
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(14)),
//                     elevation: 4,
//                     shadowColor: AppColors.primaryOrange.withOpacity(0.4),
//                   ),
//                   child: _isSending
//                       ? const SizedBox(
//                     width: 24,
//                     height: 24,
//                     child: CircularProgressIndicator(
//                         color: Colors.white, strokeWidth: 2.5),
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
//
//               const SizedBox(height: 32),
//
//               Center(
//                 child: RichText(
//                   textAlign: TextAlign.center,
//                   text: TextSpan(
//                     text: 'By continuing, you agree to our ',
//                     style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
//                     children: [
//                       TextSpan(
//                         text: 'Terms of Service',
//                         style: const TextStyle(
//                           color: AppColors.primaryBlue,
//                           fontWeight: FontWeight.w600,
//                           fontSize: 12,
//                           decoration: TextDecoration.underline,
//                         ),
//                         recognizer: TapGestureRecognizer()
//                           ..onTap = _openTerms,
//                       ),
//                       const TextSpan(
//                         text: ' & ',
//                         style: TextStyle(color: AppColors.textGrey, fontSize: 12),
//                       ),
//                       TextSpan(
//                         text: 'Privacy Policy',
//                         style: const TextStyle(
//                           color: AppColors.primaryBlue,
//                           fontWeight: FontWeight.w600,
//                           fontSize: 12,
//                           decoration: TextDecoration.underline,
//                         ),
//                         recognizer: TapGestureRecognizer()
//                           ..onTap = _openPrivacyPolicy,
//                       ),
//                     ],
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
//     _telephoneController.dispose();
//     super.dispose();
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:mtl_groceriesapp/login/otp_screen.dart';
import '../config/app_color.dart';
import '../screens/email_login_screen.dart';
import '../screens/privacy_policy.dart';
import '../screens/terms_conditions.dart';
import '../services/auth_service.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _telephoneController = TextEditingController();
  bool _isSending = false;
  String _errorMessage = '';

  bool get _isValidTelephone =>
      _telephoneController.text.trim().length == 10;

  Future<void> _sendOtp() async {
    final telephone = _telephoneController.text.trim();
    if (telephone.length != 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isSending    = true;
      _errorMessage = '';
    });

    final result = await AuthService.sendOtp(telephone);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.success) {
      TextInput.finishAutofillContext();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            identifier: telephone,
            channel:    OtpChannel.phone,
            otpRef:     result.otpRef ?? '',
            debugOtp:   result.otp,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Failed to send OTP. Try again.';
      });
    }
  }

  void _openEmailLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
    );
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsConditionsScreen(fromProfile: false),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(fromProfile: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              Center(
                child: Image.asset(
                  'assets/images/smile_logo.png',
                  width: 280,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your WhatsApp mobile number',
                style: TextStyle(fontSize: 15, color: AppColors.textGrey),
              ),
              const SizedBox(height: 30),

              AutofillGroup(
                child: Container(
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: AppColors.textDark,
                    ),
                    onChanged: (value) {
                      String digits = value.replaceAll(RegExp(r'\D'), '');

                      final matches = RegExp(r'([6-9]\d{9})').allMatches(digits).toList();

                      if (matches.isNotEmpty) {
                        digits = matches.last.group(0)!;
                      } else if (digits.length > 10) {
                        digits = digits.substring(digits.length - 10);
                      }

                      if (digits != _telephoneController.text) {
                        _telephoneController.value = TextEditingValue(
                          text: digits,
                          selection: TextSelection.collapsed(offset: digits.length),
                        );
                      }

                      setState(() => _errorMessage = '');
                    },
                    onSubmitted: (_) {
                      if (_isValidTelephone && !_isSending) _sendOtp();
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Mobile Number',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0,
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        child: const Text(
                          '+91',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            // color: AppColors.appBarText,
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
                          vertical: 9, horizontal: 10),
                    ),
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

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed:
                  (_isValidTelephone && !_isSending) ? _sendOtp : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    disabledBackgroundColor: AppColors.primaryOrange.withOpacity(0.5),

                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: AppColors.primaryOrange.withOpacity(0.4),
                  ),
                  child: _isSending
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 1.5),
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

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or',
                        style: TextStyle(color: Colors.black, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: OutlinedButton.icon(
                  onPressed: _openEmailLogin,
                  icon: const Icon(Icons.mail_outline,
                      size: 18, color: AppColors.primaryYellow),
                  label: const Text(
                    'Continue with email',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'By continuing, you agree to our ',
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _openTerms,
                      ),
                      const TextSpan(
                        text: ' & ',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _openPrivacyPolicy,
                      ),
                    ],
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
    _telephoneController.dispose();
    super.dispose();
  }
}