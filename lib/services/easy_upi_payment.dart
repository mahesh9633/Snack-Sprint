// import 'package:easy_upi_payment/easy_upi_payment.dart';
//
// class UpiPaymentResult {
//   final bool success;
//   final String transactionId;
//   final String transactionRefId;
//   final String approvalRefNo;
//   final String responseCode;
//   final String amount;
//
//   const UpiPaymentResult({
//     required this.success,
//     required this.transactionId,
//     required this.transactionRefId,
//     required this.approvalRefNo,
//     required this.responseCode,
//     required this.amount,
//   });
// }
//
// class EasyUpiPaymentService {
//   static final EasyUpiPaymentService instance =
//   EasyUpiPaymentService._internal();
//
//   EasyUpiPaymentService._internal();
//
//   Future<UpiPaymentResult> makePayment({
//     required String payeeVpa,
//     required String payeeName,
//     required double amount,
//     required String transactionId,
//     required String transactionRefId,
//     String description = 'Order Payment',
//     String? payeeMerchantCode,
//   }) async {
//     final payment = EasyUpiPaymentModel(
//       payeeVpa: payeeVpa,
//       payeeName: payeeName,
//       amount: double.parse(amount.toStringAsFixed(2)),
//       description: description,
//       transactionId: transactionId,
//       transactionRefId: transactionRefId,
//       payeeMerchantCode: payeeMerchantCode,
//     );
//
//     final response =
//     await EasyUpiPaymentPlatform.instance.startPayment(payment);
//
//     if (response == null) {
//       return UpiPaymentResult(
//         success: false,
//         transactionId: transactionId,
//         transactionRefId: transactionRefId,
//         approvalRefNo: '',
//         responseCode: '',
//         amount: amount.toStringAsFixed(2),
//       );
//     }
//
//     final responseCode = response.responseCode ?? '';
//
//     return UpiPaymentResult(
//       success: responseCode == '00',
//       transactionId: response.transactionId ?? '',
//       transactionRefId: response.transactionRefId ?? transactionRefId,
//       approvalRefNo: response.approvalRefNo ?? '',
//       responseCode: responseCode,
//       amount: response.amount ?? amount.toStringAsFixed(2),
//     );
//   }
// }

import 'package:easy_upi_payment/easy_upi_payment.dart';

class UpiPaymentResult {
  final bool success;
  final String transactionId;
  final String transactionRefId;
  final String approvalRefNo;
  final String responseCode;
  final String amount;
  final String errorMessage;

  const UpiPaymentResult({
    required this.success,
    required this.transactionId,
    required this.transactionRefId,
    required this.approvalRefNo,
    required this.responseCode,
    required this.amount,
    this.errorMessage = '',
  });
}

class EasyUpiPaymentService {
  static final EasyUpiPaymentService instance =
  EasyUpiPaymentService._internal();
  EasyUpiPaymentService._internal();

  Future<UpiPaymentResult> makePayment({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    required String transactionId,
    required String transactionRefId,
    String description = 'Order Payment',
    String? payeeMerchantCode,
  }) async {
    final fixedAmount = double.parse(amount.toStringAsFixed(2));

    final payment = EasyUpiPaymentModel(
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      amount: fixedAmount,
      description: description,
      transactionId: transactionId,
      transactionRefId: transactionRefId,
      payeeMerchantCode: payeeMerchantCode,
    );

    try {
      final response =
      await EasyUpiPaymentPlatform.instance.startPayment(payment);

      if (response == null) {
        return UpiPaymentResult(
          success: false,
          transactionId: transactionId,
          transactionRefId: transactionRefId,
          approvalRefNo: '',
          responseCode: '',
          amount: fixedAmount.toStringAsFixed(2),
          errorMessage: 'No response from UPI app.',
        );
      }

      final responseCode = response.responseCode ?? '';

      return UpiPaymentResult(
        success: responseCode == '00',
        transactionId: (response.transactionId?.isNotEmpty ?? false)
            ? response.transactionId!
            : transactionId,
        transactionRefId: (response.transactionRefId?.isNotEmpty ?? false)
            ? response.transactionRefId!
            : transactionRefId,
        approvalRefNo: response.approvalRefNo ?? '',
        responseCode: responseCode,
        amount: response.amount ?? fixedAmount.toStringAsFixed(2),
      );
      // } on EasyUpiPaymentException catch (e) {
      //   // Thrown on cancel / no UPI app installed / explicit failure.
      //   // The plugin's exception carries a `.type` + `.details` — log it once
      //   // during testing (print(e.type)) so you can map real device responses
      //   // to a friendlier message if you want to branch on cancel vs failure.
      //   return UpiPaymentResult(
      //     success: false,
      //     transactionId: transactionId,
      //     transactionRefId: transactionRefId,
      //     approvalRefNo: '',
      //     responseCode: '',
      //     amount: fixedAmount.toStringAsFixed(2),
      //     errorMessage: e.toString(),
      //   );
      // } catch (e) {
      //   return UpiPaymentResult(
      //     success: false,
      //     transactionId: transactionId,
      //     transactionRefId: transactionRefId,
      //     approvalRefNo: '',
      //     responseCode: '',
      //     amount: fixedAmount.toStringAsFixed(2),
      //     errorMessage: e.toString(),
      //   );
      // }
    } on EasyUpiPaymentException catch (e) {
      // ignore: avoid_print
      print('UPI EXCEPTION >>> ${e.toString()}');
      return UpiPaymentResult(
        success: false,
        transactionId: transactionId,
        transactionRefId: transactionRefId,
        approvalRefNo: '',
        responseCode: '',
        amount: fixedAmount.toStringAsFixed(2),
        errorMessage: e.toString(),
      );
    } catch (e) {
      // ignore: avoid_print
      print('UPI GENERIC ERROR >>> ${e.toString()}');
      return UpiPaymentResult(
        success: false,
        transactionId: transactionId,
        transactionRefId: transactionRefId,
        approvalRefNo: '',
        responseCode: '',
        amount: fixedAmount.toStringAsFixed(2),
        errorMessage: e.toString(),
      );
    }
  }
}