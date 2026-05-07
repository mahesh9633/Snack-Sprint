import 'package:flutter/material.dart';
import '../config/app_color.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final bool fromProfile;

  const PrivacyPolicyScreen({super.key, this.fromProfile = false});

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
          'Privacy Policy',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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
                  // ── Outlined "Privacy Policy" title ──
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
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ── Outlined "Durga Bhavani Mart" ──
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
                        'Durga Bhavani Mart',
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ── Outlined "Effective Date" ──
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
                        'Effective Date: April 10, 2026',
                        style: TextStyle(color: Colors.black, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── DPDP Act compliance banner ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.gavel_outlined, color: Colors.black, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This policy complies with India\'s Digital Personal Data '
                          'Protection (DPDP) Act 2023, IT Rules 2021, and the '
                          'Consumer Protection Act 2019.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Data summary card ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data We Collect at a Glance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dataRow(Icons.phone_outlined, 'Phone Number',
                      'Login & OTP identity verification', true),
                  _dataRow(Icons.email_outlined, 'Email Address',
                      'Order confirmations (optional)', false),
                  _dataRow(Icons.person_outline, 'Profile Photo',
                      'Delivery identity check (optional)', false),
                  _dataRow(Icons.my_location_outlined, 'Live Address',
                      'Real-time delivery navigation', true),
                  _dataRow(Icons.location_on_outlined, 'Saved Address',
                      'Quick re-order convenience (optional)', false),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle('1. Overview & Data Fiduciary'),
            _bodyText(
              'Durga Bhavani Mart ("we", "us", or "our"), operating at '
                  'http://dbmarts/privacy, is the Data Fiduciary under the '
                  'Digital Personal Data Protection (DPDP) Act, 2023. Our sole '
                  'purpose for collecting personal data is to identify the '
                  'customer and deliver grocery products accurately to their '
                  'location.',
            ),
            _noteText(
              'We do NOT sell, rent, or share your personal data with any '
                  'third party for marketing or advertising purposes.',
            ),

            _sectionTitle('2. Legal Basis for Processing (DPDP Act 2023)'),
            _bodyText(
              'We process your personal data on the following legal bases:',
            ),
            _bulletPoint(
              'Consent — you provide explicit consent when registering and '
                  'placing orders. You may withdraw consent at any time.',
            ),
            _bulletPoint(
              'Contract performance — processing is necessary to fulfil your '
                  'grocery delivery orders.',
            ),
            _bulletPoint(
              'Legitimate interest — fraud prevention and service security.',
            ),
            _bulletPoint(
              'Legal obligation — compliance with Indian law where applicable.',
            ),

            _sectionTitle('3. Personal Data We Collect'),

            _subTitle('3.1 Phone Number'),
            _bodyText(
              'Your mobile phone number is used as your primary login '
                  'credential. When you register or log in, we send a One-Time '
                  'Password (OTP) to your number via our OTP service provider '
                  '(Firebase Authentication by Google / MSG91). Your phone number '
                  'is shared with this provider solely for OTP delivery and is '
                  'governed by their respective privacy policies.',
            ),
            _bulletPoint('Login via OTP authentication.'),
            _bulletPoint('Linking your orders to your profile.'),
            _bulletPoint(
              'Delivery coordination — our delivery partner may call you '
                  'if needed.',
            ),
            _noteText(
              'We do not use your phone number for promotional SMS without '
                  'your explicit consent. OTP logs are retained for 24 hours only.',
            ),

            _subTitle('3.2 Email Address'),
            _bodyText(
              'Providing your email address is optional. If you choose to '
                  'save it, it is used solely for:',
            ),
            _bulletPoint('Order confirmation emails after each successful order.'),
            _bulletPoint(
              'Account recovery to help you regain access if you lose phone access.',
            ),
            _noteText(
              'Your email is never shared with third parties or used for '
                  'unsolicited marketing.',
            ),

            _subTitle('3.3 Profile Photo'),
            _bodyText(
              'You may optionally upload a profile photo. This photo is used '
                  'only to help our delivery partners visually confirm they are '
                  'handing the order to the right customer.',
            ),
            _noteText(
              'Profile photos are stored on servers located in India, '
                  'encrypted using AES-256, and are never made publicly visible '
                  'outside the delivery process.',
            ),

            _subTitle('3.4 Live Address (GPS Location)'),
            _bodyText(
              'When you place an order or at the time of delivery, we request '
                  'access to your device\'s GPS location. This Application uses '
                  'Google Maps SDK (provided by Google LLC) for navigation and '
                  'delivery routing. Your live location data is shared with '
                  'Google Maps SDK solely for this purpose and is governed by '
                  'Google\'s Privacy Policy (https://policies.google.com/privacy).',
            ),
            _bulletPoint(
              'Pinpoint your exact delivery location so our delivery partner '
                  'can reach you accurately.',
            ),
            _bulletPoint(
              'Calculate delivery route and estimated time for your order.',
            ),
            _bulletPoint('Confirm successful delivery at your location.'),
            _noteText(
              'We only access your live location when you actively place an '
                  'order or when a delivery is in progress. We do NOT track your '
                  'location in the background at any other time. GPS location is '
                  'retained only for the duration of the active delivery session '
                  'and is not stored after delivery is complete.',
            ),

            _subTitle('3.5 Saved Address'),
            _bodyText(
              'You may choose to save one or more delivery addresses to your '
                  'profile for convenience. You can delete saved addresses at any '
                  'time from your profile settings.',
            ),
            _noteText(
              'Saved addresses are stored on secure servers in India and are '
                  'deleted within 30 days of account closure.',
            ),

            _sectionTitle('4. Third-Party Services & SDKs'),
            _bodyText(
              'This Application uses the following third-party services that '
                  'may process your personal data:',
            ),
            _thirdPartyRow(
              'Google Maps SDK',
              'Location / navigation',
              'https://dbmarts.com/policies.google.com/privacy',
            ),
            _thirdPartyRow(
              'Firebase Authentication (Google)',
              'OTP login & identity',
              'https://firebase.google.com/support/privacy',
            ),
            _thirdPartyRow(
              'Google Play Services',
              'App distribution & updates',
              'https://policies.google.com/privacy',
            ),
            _bodyText(
              'Each of these providers is contractually bound to process your '
                  'data only as directed by us and in accordance with applicable '
                  'data protection law.',
            ),

            _sectionTitle('5. How We Use Your Data'),
            _bodyText(
              'All personal data collected is used strictly for our grocery '
                  'delivery service:',
            ),
            _bulletPoint('Verify your identity through OTP-based phone login.'),
            _bulletPoint(
              'Process and fulfil your grocery orders accurately and on time.',
            ),
            _bulletPoint('Identify the correct customer for each delivery.'),
            _bulletPoint(
              'Navigate to your delivery address using your live or saved address.',
            ),
            _bulletPoint(
              'Send order confirmations to your email address (if provided).',
            ),
            _bulletPoint(
              'Resolve delivery issues by contacting you via phone if needed.',
            ),

            _sectionTitle('6. Data Sharing'),
            _subTitle('6.1 Delivery Partners'),
            _bodyText(
              'Our delivery personnel are provided with your name, phone '
                  'number, and delivery address solely to complete your order '
                  'delivery. They are not permitted to use this information for '
                  'any other purpose.',
            ),
            _subTitle('6.2 Technology Service Providers'),
            _bodyText(
              'We use trusted third-party technology providers (listed in '
                  'Section 4) to operate our App. These providers are '
                  'contractually bound to keep your data confidential and may '
                  'not use it for their own purposes.',
            ),
            _subTitle('6.3 Legal Requirements'),
            _bodyText(
              'We may disclose your information if required to do so by law '
                  'or a valid order from a competent court or government authority '
                  'in India.',
            ),

            _sectionTitle('7. Data Retention'),
            _bodyText(
              'We retain your personal data only for as long as necessary '
                  'for the purposes described in this policy:',
            ),
            _retentionRow('OTP logs', '24 hours from generation'),
            _retentionRow('GPS / live location', 'Session only (deleted after delivery)'),
            _retentionRow('Order history', '2 years from order date'),
            _retentionRow('Email address', 'Until account deletion'),
            _retentionRow('Phone number', 'Until account deletion'),
            _retentionRow('Profile photo', 'Until deleted by user or account closure'),
            _retentionRow('Saved addresses', 'Until deleted by user or account closure'),
            _retentionRow('Account data', 'Deleted within 30 days of account closure'),
            _bodyText(
              'Data may be retained longer where required by Indian law '
                  '(e.g. tax records under GST Act).',
            ),

            _sectionTitle('8. Data Storage & Security'),
            _bodyText(
              'Your information is stored on secure servers located in India '
                  'and protected by:',
            ),
            _bulletPoint(
              'Encrypted data transmission (HTTPS/TLS for all App communications).',
            ),
            _bulletPoint('AES-256 encryption for data stored at rest.'),
            _bulletPoint(
              'Secure server storage with access controls limited to '
                  'authorised personnel only.',
            ),
            _bulletPoint(
              'OTP-based authentication to prevent unauthorised account access.',
            ),
            _bulletPoint(
              'Regular security monitoring and vulnerability assessments.',
            ),

            _sectionTitle('9. Your Rights Under DPDP Act 2023'),
            _bodyText(
              'As a Data Principal under India\'s Digital Personal Data '
                  'Protection Act, 2023, you have the following rights:',
            ),
            _bulletPoint(
              'Right to access — request a summary of your personal data '
                  'we hold and how it is used.',
            ),
            _bulletPoint(
              'Right to correction — request correction of inaccurate or '
                  'incomplete personal data.',
            ),
            _bulletPoint(
              'Right to erasure — request deletion of your personal data, '
                  'subject to legal retention requirements.',
            ),
            _bulletPoint(
              'Right to grievance redressal — raise a complaint with our '
                  'Grievance Officer (see Section 11).',
            ),
            _bulletPoint(
              'Right to nominate — nominate another person to exercise your '
                  'rights in the event of your death or incapacity.',
            ),
            _bulletPoint(
              'Right to withdraw consent — you may withdraw consent at any '
                  'time. Withdrawal does not affect the lawfulness of processing '
                  'before withdrawal.',
            ),
            _bodyText(
              'To exercise any of these rights, contact our Grievance Officer '
                  'listed in Section 11. We will respond within 30 days.',
            ),

            _sectionTitle('10. Children\'s Privacy'),
            _bodyText(
              'Our App is not intended for use by individuals under the age '
                  'of 16. We do not knowingly collect personal data from children. '
                  'If you believe a child has provided us with personal data, '
                  'please contact our Grievance Officer immediately and we will '
                  'delete the data within 72 hours.',
            ),

            _sectionTitle('11. Grievance Officer'),
            _bodyText(
              'In accordance with the Information Technology (Intermediary '
                  'Guidelines and Digital Media Ethics Code) Rules, 2021 and the '
                  'Digital Personal Data Protection Act, 2023, we have appointed '
                  'a Grievance Officer:',
            ),
            _grievanceCard(),
            _bodyText(
              'You may raise a grievance at any time. We will acknowledge '
                  'your complaint within 48 hours and resolve it within 30 days '
                  'of receipt.',
            ),
            _bodyText(
              'If you are not satisfied with our response, you may approach '
                  'the Data Protection Board of India once constituted, or the '
                  'appropriate Consumer Disputes Redressal Forum.',
            ),

            _sectionTitle('12. Changes to This Policy'),
            _bodyText(
              'We may update this Privacy Policy from time to time. When we '
                  'make changes, we will update the Effective Date above and '
                  'notify registered users via the App. Your continued use of the '
                  'App after changes become effective constitutes your acceptance.',
            ),

            _sectionTitle('13. Contact Us'),
            _bodyText(
              'If you have any questions or concerns about this Privacy Policy '
                  'or our data practices, contact:',
            ),
            _contactCard(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Summary row ───────────────────────────────────────────────────────────────
  Widget _dataRow(IconData icon, String label, String desc, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.pink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.appBarText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: required
                  ? Colors.black.withOpacity(0.10)
                  : Colors.grey.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              required ? 'Required' : 'Optional',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: required ? Colors.black : AppColors.appBarText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Third-party row ───────────────────────────────────────────────────────────
  Widget _thirdPartyRow(String name, String purpose, String policyUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.extension_outlined, size: 16, color: Colors.pink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  purpose,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.appBarText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  policyUrl,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Retention row ─────────────────────────────────────────────────────────────
  Widget _retentionRow(String dataType, String period) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_outlined, size: 14, color: Colors.black),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: '$dataType: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: period),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Grievance card ────────────────────────────────────────────────────────────
  Widget _grievanceCard() => Container(
    margin: const EdgeInsets.only(top: 8, bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.shield_outlined, color: Colors.black, size: 18),
            SizedBox(width: 8),
            Text(
              'Grievance Officer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const Divider(height: 16, color: AppColors.divider),
        const _ContactRow(
          icon: Icons.person_outline,
          text: 'Name: [Durga Bhavani ]',
        ),
        const SizedBox(height: 6),
        const _ContactRow(
          icon: Icons.business_outlined,
          text: 'Durga Bhavani Mart',
        ),
        const SizedBox(height: 6),
        const _ContactRow(
          icon: Icons.location_on_outlined,
          text:
          'Address: 67/163,Near Market,Veerabhadra Swamy Temple,Rayachoti. AP - 516269',
        ),
        const SizedBox(height: 6),
        const _ContactRow(
          icon: Icons.email_outlined,
          text: 'grievance@myteknoland.com',
        ),
        const SizedBox(height: 6),
        const _ContactRow(
          icon: Icons.phone_outlined,
          text: '+91 9701657580',
        ),
        const SizedBox(height: 6),
        const _ContactRow(
          icon: Icons.access_time_outlined,
          text: 'Response time: Within 30 days of receipt',
        ),
      ],
    ),
  );

  // ── Reusable text widgets ─────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
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
        color: Colors.black,
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
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black.withOpacity(0.2)),
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
            backgroundColor: Colors.black,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black,
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
      border: Border.all(color: Colors.black.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Durga Bhavani Mart',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        _ContactRow(
          icon: Icons.location_on_outlined,
          text:
          'Address: 67/163,Near Market,Veerabhadra Swamy Temple,Rayachoti. AP - 516269',
        ),
        SizedBox(height: 6),
        _ContactRow(icon: Icons.phone_outlined, text: '+91 9701657580 '),
        SizedBox(height: 6),
        _ContactRow(
          icon: Icons.email_outlined,
          text: 'support@myteknoland.com',
        ),
        SizedBox(height: 6),
        _ContactRow(
          icon: Icons.language_outlined,
          text: 'https://dbmarts.com/privacy-policy',
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
        Icon(icon, size: 16, color: Colors.pink),
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