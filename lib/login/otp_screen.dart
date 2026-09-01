//
//
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../config/app_color.dart';
// import '../model/cart_model.dart';
// import '../model/favorites_model.dart';
// import '../screens/location_gateway.dart';
// import '../services/auth_service.dart';
// import '../services/session_manager.dart';
//
// enum OtpChannel { phone, email }
//
// class OtpScreen extends StatefulWidget {
//   /// The phone number (no +91 prefix) or email address the OTP was sent to.
//   final String identifier;
//   final OtpChannel channel;
//   final String otpRef;
//   final String? debugOtp;
//
//   const OtpScreen({
//     super.key,
//     required this.identifier,
//     required this.channel,
//     required this.otpRef,
//     this.debugOtp,
//   });
//
//   @override
//   State<OtpScreen> createState() => _OtpScreenState();
// }
//
// class _OtpScreenState extends State<OtpScreen> {
//   final List<TextEditingController> _controllers =
//   List.generate(6, (_) => TextEditingController());
//   final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
//
//   bool   _isVerifying  = false;
//   bool   _isResending  = false;
//   int    _resendTimer  = 120;
//   Timer? _timer;
//   String _errorMessage = '';
//   late String _currentOtpRef = widget.otpRef;
//
//   bool get _isPhone => widget.channel == OtpChannel.phone;
//
//   @override
//   void initState() {
//     super.initState();
//     _startResendTimer();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       FocusScope.of(context).requestFocus(_focusNodes[0]);
//     });
//     if (widget.debugOtp != null) {}
//   }
//
//   void _startResendTimer() {
//     _resendTimer = 30;
//     _timer?.cancel();
//     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (!mounted) return;
//       if (_resendTimer == 0) {
//         t.cancel();
//       } else {
//         setState(() => _resendTimer--);
//       }
//     });
//   }
//
//   String get _enteredOtp => _controllers.map((c) => c.text).join();
//
//   /// Calls verifyOtp or verifyMailOtp depending on the channel.
//   Future<VerifyResult> _callVerify() {
//     if (_isPhone) {
//       return AuthService.verifyOtp(
//         telephone: widget.identifier,
//         otp:       _enteredOtp,
//         otpRef:    _currentOtpRef,
//       );
//     } else {
//       return AuthService.verifyMailOtp(
//         email:  widget.identifier,
//         otp:    _enteredOtp,
//         otpRef: _currentOtpRef,
//       );
//     }
//   }
//
//   /// Calls sendOtp or sendMailOtp depending on the channel.
//   Future<OtpResult> _callResend() {
//     return _isPhone
//         ? AuthService.sendOtp(widget.identifier)
//         : AuthService.sendMailOtp(widget.identifier);
//   }
//
//   Future<void> _verifyOtp() async {
//     if (_enteredOtp.length < 6) {
//       setState(() => _errorMessage = _isPhone
//           ? 'Enter the 6-digit Code Was Sent To Your WhatsApp Mobile Number'
//           : 'Enter the 6-digit Code Sent To Your Email');
//       return;
//     }
//     if (_isVerifying) return;
//
//     setState(() {
//       _isVerifying  = true;
//       _errorMessage = '';
//     });
//
//     final result = await _callVerify();
//
//     if (!mounted) return;
//
//     if (result.success) {
//
//       // NOTE: for email logins, verify_mail_otp's response has no
//       // telephone field, so widget.identifier (the email) is passed here
//       // in its place. If LocationGateway/SessionManager genuinely need a
//       // real phone number downstream, have the PHP include the
//       // customer's telephone in the verify_mail_otp JSON response too.
//       await SessionManager.saveSession(
//         telephone:  widget.identifier,
//         customerId: result.customerId,
//         token:      result.token,
//       );
//       await SessionManager.printSession();
//
//       if (!mounted) return;
//
//       if (result.token != null) {
//         await AuthService.sendFcmToken(result.token!);
//       }
//
//       final favs = context.read<FavoritesModel>();
//       final cart = context.read<CartModel>();
//       await favs.loadForUser(result.customerId!);
//       await cart.loadForUser(result.customerId!);
//
//       if (!mounted) return;
//
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (_) => LocationGateway(
//             telephone:     widget.identifier,
//             isNewCustomer: false,
//             authToken:     result.token,
//             customerId:    result.customerId ?? '',
//           ),
//         ),
//             (route) => false,
//       );
//     } else {
//       setState(() {
//         _isVerifying  = false;
//         _errorMessage = result.message ?? 'Invalid OTP. Please try again.';
//       });
//       _clearOtp();
//     }
//   }
//
//   void _clearOtp() {
//     for (final c in _controllers) {
//       c.clear();
//     }
//     if (mounted) FocusScope.of(context).requestFocus(_focusNodes[0]);
//   }
//
//   Future<void> _resendOtp() async {
//     if (_resendTimer > 0 || _isResending) return;
//     setState(() => _isResending = true);
//
//     final result = await _callResend();
//
//     if (!mounted) return;
//     setState(() => _isResending = false);
//
//     if (result.success) {
//       _currentOtpRef = result.otpRef ?? _currentOtpRef;
//       if (result.otp != null) {}
//     }
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           result.success
//               ? 'OTP resent to ${_isPhone ? '+91 ' : ''}${widget.identifier}'
//               : result.message ?? 'Failed to resend OTP.',
//         ),
//         backgroundColor: result.success ? AppColors.accentDark : AppColors.error,
//         behavior:        SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//
//     _startResendTimer();
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
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               const SizedBox(height: 20),
//               Container(
//                 width:  80,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   color:        AppColors.primaryOrange,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [
//                     BoxShadow(
//                       color:      AppColors.primaryOrange.withOpacity(0.3),
//                       blurRadius: 20,
//                       offset:     const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Icon(
//                   _isPhone ? Icons.lock_open : Icons.mark_email_read_outlined,
//                   color: Colors.white,
//                   size: 40,
//                 ),
//               ),
//               const SizedBox(height: 28),
//
//               const Text(
//                 'OTP Verification',
//                 style: TextStyle(
//                   fontSize:   26,
//                   fontWeight: FontWeight.bold,
//                   color:      AppColors.primaryBlue,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 _isPhone
//                     ? 'Enter the OTP code sent via WhatsApp.'
//                     : 'Enter the OTP code sent to your email.',
//                 style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 _isPhone ? '+91 ${widget.identifier}' : widget.identifier,
//                 style: const TextStyle(
//                   fontSize:   16,
//                   fontWeight: FontWeight.bold,
//                   color:      AppColors.primaryBlue,
//                 ),
//               ),
//               const SizedBox(height: 36),
//
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: List.generate(6, _buildOtpBox),
//               ),
//               const SizedBox(height: 16),
//
//               if (_errorMessage.isNotEmpty)
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 16, vertical: 10),
//                   decoration: BoxDecoration(
//                     color:        AppColors.errorLight,
//                     borderRadius: BorderRadius.circular(10),
//                     border:       Border.all(
//                         color: AppColors.error.withOpacity(0.4)),
//                   ),
//                   child: Row(children: [
//                     const Icon(Icons.error_outline,
//                         color: AppColors.error, size: 18),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         _errorMessage,
//                         style: const TextStyle(
//                             color: AppColors.error, fontSize: 13),
//                       ),
//                     ),
//                   ]),
//                 ),
//
//               const SizedBox(height: 32),
//
//               SizedBox(
//                 width:  double.infinity,
//                 height: 45,
//                 child: ElevatedButton(
//                   onPressed: _isVerifying ? null : _verifyOtp,
//
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor:         AppColors.primaryOrange,
//                     disabledBackgroundColor: AppColors.primaryOrange.withOpacity(0.5),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(14)),
//                     elevation:   4,
//                     shadowColor: AppColors.primaryOrange.withOpacity(0.4),
//                   ),
//                   child: _isVerifying
//                       ? const SizedBox(
//                     width:  18,
//                     height: 18,
//                     child: CircularProgressIndicator(
//                         color: Colors.white, strokeWidth: 1.5),
//                   )
//                       : const Text(
//                     'Verify & Continue',
//                     style: TextStyle(
//                       color:      Colors.white,
//                       fontSize:   17,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 24),
//
//               Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//                 const Text(
//                   "Didn't receive OTP? ",
//                   style: TextStyle(
//                       color: AppColors.textGrey, fontSize: 14),
//                 ),
//                 GestureDetector(
//                   onTap: (_resendTimer == 0 && !_isResending)
//                       ? _resendOtp
//                       : null,
//                   child: _isResending
//                       ? const SizedBox(
//                     width:  16,
//                     height: 16,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color:       AppColors.primaryBlue,
//                     ),
//                   )
//                       : Text(
//                     _resendTimer > 0
//                         ? 'Resend in ${_resendTimer}s'
//                         : 'Resend OTP',
//                     style: TextStyle(
//                       color: _resendTimer > 0
//                           ? AppColors.textGrey
//                           : AppColors.primaryBlue,
//                       fontSize:   14,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ]),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildOtpBox(int index) {
//     return SizedBox(
//       width:  48,
//       height: 56,
//       child: KeyboardListener(
//         focusNode: FocusNode(),
//         onKeyEvent: (event) {
//           if (event is KeyDownEvent &&
//               event.logicalKey == LogicalKeyboardKey.backspace &&
//               _controllers[index].text.isEmpty &&
//               index > 0) {
//             _controllers[index - 1].clear();
//             FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
//           }
//         },
//         child: TextFormField(
//           controller:      _controllers[index],
//           focusNode:       _focusNodes[index],
//           keyboardType:    TextInputType.number,
//           onTap: () {
//             _controllers[index].selection = TextSelection(
//               baseOffset:   0,
//               extentOffset: _controllers[index].text.length,
//             );
//           },
//           textAlign:       TextAlign.center,
//           maxLength:       1,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           style: const TextStyle(
//             fontSize:   22,
//             fontWeight: FontWeight.bold,
//             color:      AppColors.textDark,
//           ),
//           decoration: InputDecoration(
//             counterText: '',
//             filled:      true,
//             fillColor:   AppColors.cardWhite,
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide:
//               const BorderSide(color: AppColors.border, width: 1.5),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide:
//               const BorderSide(color: AppColors.primaryBlue, width: 2),
//             ),
//           ),
//           onChanged: (value) {
//             setState(() => _errorMessage = '');
//             if (value.isNotEmpty) {
//               if (index < 5) {
//                 FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
//               }
//               if (_enteredOtp.length == 6) {
//                 Future.delayed(
//                     const Duration(milliseconds: 300), _verifyOtp);
//               }
//             } else {
//               _controllers[index].clear();
//               if (index > 0) {
//                 _controllers[index - 1].clear();
//                 FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
//               }
//             }
//           },
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     for (final c in _controllers) {
//       c.dispose();
//     }
//     for (final f in _focusNodes) {
//       f.dispose();
//     }
//     super.dispose();
//   }
// }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../model/favorites_model.dart';
import '../screens/location_gateway.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';

enum OtpChannel { phone, email }

class OtpScreen extends StatefulWidget {
  /// The phone number (no +91 prefix) or email address the OTP was sent to.
  final String identifier;
  final OtpChannel channel;
  final String otpRef;
  final String? debugOtp;

  /// Only used when channel == OtpChannel.email: the WhatsApp mobile number
  /// entered alongside the email on EmailLoginScreen. Required by the
  /// backend's send_mail_otp / verify_mail_otp now that both fields are
  /// mandatory.
  final String? emailTelephone;

  const OtpScreen({
    super.key,
    required this.identifier,
    required this.channel,
    required this.otpRef,
    this.debugOtp,
    this.emailTelephone,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool   _isVerifying  = false;
  bool   _isResending  = false;
  int    _resendTimer  = 120;
  Timer? _timer;
  String _errorMessage = '';
  late String _currentOtpRef = widget.otpRef;

  bool get _isPhone => widget.channel == OtpChannel.phone;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
    if (widget.debugOtp != null) {}
  }

  void _startResendTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendTimer == 0) {
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  /// Calls verifyOtp or verifyMailOtp depending on the channel.
  Future<VerifyResult> _callVerify() {
    if (_isPhone) {
      return AuthService.verifyOtp(
        telephone: widget.identifier,
        otp:       _enteredOtp,
        otpRef:    _currentOtpRef,
      );
    } else {
      return AuthService.verifyMailOtp(
        email:     widget.identifier,
        telephone: widget.emailTelephone ?? '',
        otp:       _enteredOtp,
        otpRef:    _currentOtpRef,
      );
    }
  }

  /// Calls sendOtp or sendMailOtp depending on the channel.
  Future<OtpResult> _callResend() {
    return _isPhone
        ? AuthService.sendOtp(widget.identifier)
        : AuthService.sendMailOtp(
      email:     widget.identifier,
      telephone: widget.emailTelephone ?? '',
    );
  }

  Future<void> _verifyOtp() async {
    if (_enteredOtp.length < 6) {
      setState(() => _errorMessage = _isPhone
          ? 'Enter the 6-digit Code Was Sent To Your WhatsApp Mobile Number'
          : 'Enter the 6-digit Code Sent To Your Email');
      return;
    }
    if (_isVerifying) return;

    setState(() {
      _isVerifying  = true;
      _errorMessage = '';
    });

    final result = await _callVerify();

    if (!mounted) return;

    if (result.success) {

      // Phone logins use widget.identifier as the telephone directly.
      // Email logins now collect a real WhatsApp number alongside the
      // email (widget.emailTelephone), so use that instead of the email
      // string for anything downstream that expects an actual phone number.
      final sessionTelephone =
      _isPhone ? widget.identifier : (widget.emailTelephone ?? '');

      await SessionManager.saveSession(
        telephone:  sessionTelephone,
        customerId: result.customerId,
        token:      result.token,
      );
      await SessionManager.printSession();

      if (!mounted) return;

      if (result.token != null) {
        await AuthService.sendFcmToken(result.token!);
      }

      final favs = context.read<FavoritesModel>();
      final cart = context.read<CartModel>();
      await favs.loadForUser(result.customerId!);
      await cart.loadForUser(result.customerId!);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LocationGateway(
            telephone:     sessionTelephone,
            isNewCustomer: false,
            authToken:     result.token,
            customerId:    result.customerId ?? '',
          ),
        ),
            (route) => false,
      );
    } else {
      setState(() {
        _isVerifying  = false;
        _errorMessage = result.message ?? 'Invalid OTP. Please try again.';
      });
      _clearOtp();
    }
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  Future<void> _resendOtp() async {
    if (_resendTimer > 0 || _isResending) return;
    setState(() => _isResending = true);

    final result = await _callResend();

    if (!mounted) return;
    setState(() => _isResending = false);

    if (result.success) {
      _currentOtpRef = result.otpRef ?? _currentOtpRef;
      if (result.otp != null) {}
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'OTP resent to ${_isPhone ? '+91 ' : ''}${widget.identifier}'
              : result.message ?? 'Failed to resend OTP.',
        ),
        backgroundColor: result.success ? AppColors.accentDark : AppColors.error,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );

    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width:  80,
                height: 80,
                decoration: BoxDecoration(
                  color:        AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.primaryOrange.withOpacity(0.3),
                      blurRadius: 20,
                      offset:     const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _isPhone ? Icons.lock_open : Icons.mark_email_read_outlined,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'OTP Verification',
                style: TextStyle(
                  fontSize:   26,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isPhone
                    ? 'Enter the OTP code sent via WhatsApp.'
                    : 'Enter the OTP code sent to your email.',
                style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
              ),
              const SizedBox(height: 4),
              Text(
                _isPhone ? '+91 ${widget.identifier}' : widget.identifier,
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 36),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, _buildOtpBox),
              ),
              const SizedBox(height: 16),

              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:        AppColors.errorLight,
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(
                        color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ]),
                ),

              const SizedBox(height: 32),

              SizedBox(
                width:  double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,

                  style: ElevatedButton.styleFrom(
                    backgroundColor:         AppColors.primaryOrange,
                    disabledBackgroundColor: AppColors.primaryOrange.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation:   4,
                    shadowColor: AppColors.primaryOrange.withOpacity(0.4),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                    width:  22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text(
                    'Verify & Continue',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text(
                  "Didn't receive OTP? ",
                  style: TextStyle(
                      color: AppColors.textGrey, fontSize: 14),
                ),
                GestureDetector(
                  onTap: (_resendTimer == 0 && !_isResending)
                      ? _resendOtp
                      : null,
                  child: _isResending
                      ? const SizedBox(
                    width:  16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:       AppColors.primaryBlue,
                    ),
                  )
                      : Text(
                    _resendTimer > 0
                        ? 'Resend in ${_resendTimer}s'
                        : 'Resend OTP',
                    style: TextStyle(
                      color: _resendTimer > 0
                          ? AppColors.textGrey
                          : AppColors.primaryBlue,
                      fontSize:   14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width:  48,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _controllers[index - 1].clear();
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
        },
        child: TextFormField(
          controller:      _controllers[index],
          focusNode:       _focusNodes[index],
          keyboardType:    TextInputType.number,
          onTap: () {
            _controllers[index].selection = TextSelection(
              baseOffset:   0,
              extentOffset: _controllers[index].text.length,
            );
          },
          textAlign:       TextAlign.center,
          maxLength:       1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize:   22,
            fontWeight: FontWeight.bold,
            color:      AppColors.textDark,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled:      true,
            fillColor:   AppColors.cardWhite,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppColors.primaryBlue, width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() => _errorMessage = '');
            if (value.isNotEmpty) {
              if (index < 5) {
                FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
              }
              if (_enteredOtp.length == 6) {
                Future.delayed(
                    const Duration(milliseconds: 300), _verifyOtp);
              }
            } else {
              _controllers[index].clear();
              if (index > 0) {
                _controllers[index - 1].clear();
                FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
              }
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}