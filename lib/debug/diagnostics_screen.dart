import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'diagnostics_tracker.dart';

/// Diagnostics screen reachable only when kDebugMode is true.
/// Displays base URL, masked session state, SSE state, and the last 50 API calls.
/// In release mode, the contents are completely absent.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, this.debugModeOverride});

  /// Override used specifically for widget testing release mode absence.
  final bool? debugModeOverride;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final DiagnosticsTracker _tracker = DiagnosticsTracker.instance;
  String? _maskedToken;

  bool get _effectiveDebugMode => widget.debugModeOverride ?? kDebugMode;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onTrackerUpdate);
    _loadMaskedToken();
  }

  @override
  void dispose() {
    _tracker.removeListener(_onTrackerUpdate);
    super.dispose();
  }

  void _onTrackerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMaskedToken() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final rawToken = await auth.authedTokenForStream();
    if (mounted) {
      setState(() {
        _maskedToken = DiagnosticsTracker.maskToken(rawToken);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_effectiveDebugMode) {
      return const SizedBox.shrink();
    }

    final auth = Provider.of<AuthProvider>(context);
    final calls = _tracker.calls;

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: AppBar(
        title: const Text('Diagnostics (Debug Only)'),
        backgroundColor: AppColors.surfaceLayer1,
        actions: [
          IconButton(
            tooltip: 'Component library',
            icon: const Icon(Icons.widgets_outlined, size: 20),
            onPressed: () => Navigator.of(context).pushNamed('/components'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              _loadMaskedToken();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              _tracker.clear();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        children: [
          // Base URL card
          _buildInfoCard(
            title: 'Base URL',
            value: _tracker.baseUrl,
            icon: Icons.link,
          ),
          const SizedBox(height: AppSpacing.spaceSm),

          // Session State card (masked)
          _buildInfoCard(
            title: 'Session State (Masked)',
            value:
                '${_tracker.maskedSessionState(auth)}\nToken: ${_maskedToken ?? "none"}',
            icon: Icons.security,
          ),
          const SizedBox(height: AppSpacing.spaceSm),

          // SSE State card
          _buildInfoCard(
            title: 'SSE Stream State',
            value: _tracker.sseState,
            icon: Icons.stream,
            statusColor: _tracker.sseState == 'connected'
                ? AppColors.statusApproved
                : (_tracker.sseState.startsWith('error')
                      ? AppColors.crimson
                      : AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.spaceLg),

          // Last 50 API Calls header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent API Calls (${calls.length}/50)',
                style: AppTypography.headlineSm().copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (calls.isNotEmpty)
                Text(
                  'No bodies/query strings stored',
                  style: AppTypography.labelSm().copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),

          if (calls.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.spaceLg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceLayer1,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.subtleHairline),
              ),
              child: Text(
                'No API calls recorded yet.',
                style: AppTypography.bodySm().copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            ...calls.map(_buildCallTile),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLayer1,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.subtleHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: statusColor ?? AppColors.textSecondary),
          const SizedBox(width: AppSpacing.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelSm().copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodySm().copyWith(
                    color: statusColor ?? AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallTile(ApiCallRecord call) {
    Color statusColor;
    if (call.status >= 200 && call.status < 300) {
      statusColor = AppColors.statusApproved;
    } else if (call.status == 429) {
      statusColor = Colors.orange;
    } else if (call.status >= 400 && call.status < 500) {
      statusColor = Colors.amber;
    } else {
      statusColor = AppColors.crimson;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceXs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceMd,
        vertical: AppSpacing.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLayer1,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.subtleHairline),
      ),
      child: Row(
        children: [
          // Method chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: call.method == 'GET'
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              call.method,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: call.method == 'GET' ? Colors.blue : Colors.purple,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spaceSm),

          // Status code
          Text(
            call.status == -1 ? 'ERR' : '${call.status}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: AppSpacing.spaceSm),

          // Path (stripped of query)
          Expanded(
            child: Text(
              call.path,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm().copyWith(
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spaceSm),

          // Latency
          Text(
            '${call.latencyMs}ms',
            style: AppTypography.labelSm().copyWith(
              color: AppColors.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
