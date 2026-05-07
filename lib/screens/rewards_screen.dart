import 'package:flutter/material.dart';
import '../config/app_color.dart';
import '../services/get_rewards_service.dart';
import '../services/session_manager.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  bool   _isLoading   = true;
  int    _totalPoints = 0;
  String _error       = '';

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() { _isLoading = true; _error = ''; });

    final token = await SessionManager.getString('token') ?? '';
    if (token.isEmpty) {
      setState(() { _isLoading = false; _error = 'Session expired. Please log in again.'; });
      return;
    }

    final result = await GetRewardService.getReward(token: token);

    if (!mounted) return;
    setState(() {
      _isLoading   = false;
      _totalPoints = result.totalPoints;
      _error       = result.hasError ? result.error : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── White background ───────────────────────────────────────────────────
      backgroundColor: AppColors.white,
      appBar: AppBar(
        // ── White AppBar, black text & icon ───────────────────────────────
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Rewards',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.loader),
      )
          : _error.isNotEmpty
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            // ── Pink retry button ──────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _loadRewards,
              icon: const Icon(Icons.refresh, color: AppColors.buttonPrimaryText),
              label: const Text(
                'Retry',
                style: TextStyle(color: AppColors.buttonPrimaryText),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadRewards,
      color: AppColors.buttonPrimary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),

          // ── Points Card (gradient using AppColors brand colours) ──────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.pink, AppColors.pink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentDark.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(children: [
              const Icon(Icons.card_giftcard, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                '$_totalPoints',
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Total Points',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Status Message ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.appBarBg.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _totalPoints == 0
                      ? Icons.info_outline
                      : Icons.emoji_events_outlined,
                  color: AppColors.pink,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _totalPoints == 0
                      ? 'You have no reward points yet.\nStart shopping to earn points!'
                      : 'Keep shopping to earn more points\nand unlock exciting rewards!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.appBarText,
                    height: 1.5,
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Refresh hint ─────────────────────────────────────────────────
          const Center(
            child: Text(
              'Pull down to refresh your points',
              style: TextStyle(fontSize: 12, color: AppColors.pink),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}