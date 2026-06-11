import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/privacy_policy.dart';
import '../config/app_color.dart';

class TermsConditionsScreen extends StatelessWidget {
  final bool fromProfile;

  const TermsConditionsScreen({super.key, this.fromProfile = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Outlined "Terms & Conditions" title ──
                  Stack(
                    children: [
                      Text(
                        '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2
                            ..color = Colors.black,
                        ),
                      ),
                      const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ── Outlined "Smile Basket" ──
                  Stack(
                    children: [
                      Text(
                        '',
                        style: TextStyle(
                          fontSize: 14,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.5
                            ..color = Colors.black,
                        ),
                      ),
                      const Text(
                        'Smile Basket',
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ── Outlined "Last updated" ──
                  Stack(
                    children: [
                      Text(
                        '',
                        style: TextStyle(
                          fontSize: 12,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.5
                            ..color = Colors.black,
                        ),
                      ),
                      const Text(
                        'Last updated: April 10, 2026',
                        style: TextStyle(color: Colors.black, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Privacy Policy link card ───────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.privacy_tip_outlined,
                        color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Read our Privacy Policy to understand how we collect and use your data.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.black, height: 1.4),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.black, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle('1. Acceptance of Terms'),
            _bodyText(
              'By accessing or using the Smile Basket application at '
                  'https:dbmarts.com/termsandconditions, you agree to be bound by these Terms '
                  'and Conditions. If you do not agree, please immediately stop '
                  'using the Application.',
            ),

            _sectionTitle('2. About the Application'),
            _bodyText(
              'The Application is a platform through which Registered Users '
                  'can order groceries and have them delivered to a specified '
                  'location. Over time, the Application learns user grocery habits '
                  'and proposes weekly grocery baskets. All available programs may '
                  'change at any time at Smile Basket\'s discretion.',
            ),

            _sectionTitle('3. Eligibility & Use Conditions'),
            _bodyText('As a condition of use, you agree that:'),
            _bulletPoint('You are at least 16 years of age.'),
            _bulletPoint('You are capable of creating a binding legal obligation.'),
            _bulletPoint(
              'You are not barred from receiving products or services under '
                  'applicable law.',
            ),
            _bulletPoint(
              'You will not use crawlers, robots, data mining or extraction tools.',
            ),
            _bulletPoint(
              'All information you provide is accurate, true, current and complete.',
            ),
            _bulletPoint(
              'You will keep your account information updated at all times.',
            ),
            _bodyText(
              'If you are between 16 and 18 years old, your parent or guardian '
                  'may be liable for your activities on the Application.',
            ),
            _noteText(
              'This Application is intended for users aged 16 and above. '
                  'The target audience is set accordingly in our app store listing.',
            ),

            _sectionTitle('4. Your Account'),
            _subTitle('4.1 Registration'),
            _bodyText(
              'To use the Application, you must provide: (i) first name; '
                  '(ii) last name; (iii) mobile phone number (used for OTP login); '
                  '(iv) delivery location; (v) payment information (where applicable); '
                  'and (vi) an account password.',
            ),
            _subTitle('4.2 Account Responsibility'),
            _bodyText(
              'You may only hold one Account for personal use. You are solely '
                  'responsible for maintaining the security of your Account and all '
                  'activities that occur under it.',
            ),
            _subTitle('4.3 Account Termination'),
            _bodyText(
              'Your Account is non-transferable. Any violation of these Terms '
                  'may result in cancellation of your Account at Smile Basket '
                  'Mart\'s sole discretion. Upon termination, all pending '
                  'promotional vouchers and unredeemed values will be forfeited. '
                  'Your personal data will be deleted within 30 days of account '
                  'closure, except where retention is required by applicable law.',
            ),

            _sectionTitle('5. Payment Methods'),
            _bodyText(
              'Smile Basket currently supports the following payment methods:',
            ),
            _bulletPoint(
              'Cash on Delivery (COD) — Pay in cash when your order is delivered to your doorstep.',
            ),
            _bulletPoint(
              'UPI (Unified Payments Interface) — Pay via Google Pay, PhonePe, Paytm, or any UPI-enabled app using our UPI ID.',
            ),
            _bodyText(
              'For UPI payments, you must provide a valid UTR (Unique Transaction Reference) number and attach a screenshot of the completed payment as proof. Orders will be processed only after payment verification.',
            ),
            _bodyText(
              'Smile Basket reserves the right to cancel any order where payment proof is found to be invalid, fraudulent, or unverifiable. In such cases, you will be notified and a refund (if applicable) will be processed within 5–7 business days.',
            ),
            _noteText(
              'We do not store any UPI credentials or banking information on our servers. All payment transactions are the responsibility of the respective payment platforms.',
            ),

            _sectionTitle('6. Orders, Cancellations & Refunds'),
            _bodyText(
              'For order cancellations, please call us at the phone number on '
                  'the Contact page.',
            ),
            _bodyText(
              'All requests for refunds or returns must be initiated within '
                  '24 hours of receiving the items.',
            ),

            _sectionTitle('7. Prohibited Conduct'),
            _bodyText(
              'The following activities are strictly prohibited on the Application:',
            ),
            _bulletPoint(
              'Submitting content that violates applicable laws or intellectual property rights.',
            ),
            _bulletPoint('Uploading viruses, malware or other harmful code.'),
            _bulletPoint('Impersonating others or submitting false information.'),
            _bulletPoint('Attempting to access unauthorized data or accounts.'),
            _bulletPoint('Scanning or testing the Application\'s security.'),
            _bulletPoint('Reselling or repurposing access to the Application.'),
            _bulletPoint(
              'Acting illegally or against the reputation of Smile Basket.',
            ),

            _sectionTitle('8. Intellectual Property'),
            _bodyText(
              'The Application and all its content — including text, software, '
                  'photos, video, graphics, music and sound — are protected under '
                  'Indian copyright, trademark and intellectual property laws. '
                  'You may not modify, distribute, publish, transmit, display, '
                  'perform, sell, or exploit any content without express permission '
                  'from Smile Basket.',
            ),

            _sectionTitle('9. Disclaimer of Warranty'),
            _bodyText(
              'THE APPLICATION IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" '
                  'BASIS. Smile Basket MAKES NO WARRANTIES, EXPRESS OR '
                  'IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF '
                  'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR '
                  'NON-INFRINGEMENT. USE OF THE APPLICATION IS AT YOUR SOLE RISK.',
            ),

            _sectionTitle('10. Limitation of Liability'),
            _bodyText(
              'TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT '
                  'SHALL Smile Basket BE LIABLE FOR ANY INDIRECT, INCIDENTAL, '
                  'SPECIAL, CONSEQUENTIAL OR PUNITIVE DAMAGES ARISING OUT OF OR '
                  'RELATED TO YOUR USE OF THE APPLICATION.',
            ),
            _bodyText(
              'NOTHING IN THESE TERMS SHALL LIMIT OR EXCLUDE LIABILITY FOR '
                  'DEATH OR PERSONAL INJURY CAUSED BY NEGLIGENCE, FRAUD, OR ANY '
                  'OTHER LIABILITY THAT CANNOT BE EXCLUDED UNDER APPLICABLE LAW, '
                  'INCLUDING THE CONSUMER PROTECTION ACT 2019 AND THE DIGITAL '
                  'PERSONAL DATA PROTECTION ACT 2023.',
            ),
            _noteText(
              'Your statutory rights as a consumer under Indian law are not '
                  'affected by these Terms.',
            ),

            _sectionTitle('11. Indemnification'),
            _bodyText(
              'You agree to defend, indemnify and hold harmless Smile Basket '
                  'Mart, its subsidiaries, affiliates, directors, officers, '
                  'employees and agents from and against all claims, expenses and '
                  'attorneys\' fees arising from your use of the Application or '
                  'violation of these Terms.',
            ),

            _sectionTitle('12. Governing Law & Dispute Resolution'),
            _bodyText(
              'These Terms are governed by the laws of India. Any dispute '
                  'arising out of or in connection with these Terms shall first '
                  'be attempted to be resolved through good-faith negotiation. '
                  'If unresolved within 30 days, the dispute shall be referred '
                  'to arbitration under the Arbitration and Conciliation Act, '
                  '1996, with the seat of arbitration in Andhra Pradesh, India.',
            ),
            _bodyText(
              'Nothing in this clause shall prevent either party from seeking '
                  'urgent interim relief from a court of competent jurisdiction. '
                  'Consumer disputes may also be referred to the appropriate '
                  'Consumer Disputes Redressal Forum under the Consumer Protection '
                  'Act, 2019.',
            ),

            _sectionTitle('13. Changes to These Terms'),
            _bodyText(
              'We may update these Terms from time to time. We will notify '
                  'you of significant changes via the Application. Your continued '
                  'use of the Application after such changes constitutes acceptance '
                  'of the revised Terms.',
            ),

            _sectionTitle('14. Contact Information'),
            _bodyText('For any questions about these Terms, please contact:'),
            _contactCard(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.appBarText,
      ),
    ),
  );

  Widget _subTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.appBarText,
      ),
    ),
  );

  Widget _bodyText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: AppColors.appBarText,
      ),
    ),
  );

  Widget _noteText(String text) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.appBarText.withOpacity(0.2)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: AppColors.appBarText.withOpacity(0.75),
        fontStyle: FontStyle.italic,
      ),
    ),
  );

  Widget _bulletPoint(String text) => Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: CircleAvatar(
            radius: 3,
            backgroundColor: AppColors.appBarText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.appBarText,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _contactCard() => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.appBarText.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Smile Basket',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.appBarText,
          ),
        ),
        SizedBox(height: 8),
        _ContactRow(
          icon: Icons.location_on_outlined,
          text:
          'Address: 67/163,Near Market,Veerabhadra Swamy Temple,Rayachoti. AP - 516269 ',
        ),
        SizedBox(height: 6),
        _ContactRow(icon: Icons.phone_outlined, text: '+91 9701657580'),
        SizedBox(height: 6),
        _ContactRow(
          icon: Icons.language_outlined,
          text: 'http:dbmarts.com/termsandconditions',
        ),
        SizedBox(height: 6),
        _ContactRow(
          icon: Icons.email_outlined,
          text: 'support@myteknoland.com',
        ),
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.headerBanner),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.appBarText,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}