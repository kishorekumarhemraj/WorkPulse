import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';

class BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<BreakdownItem> items;
  final String emptyMessage;

  const BreakdownCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.emptyMessage = 'No tracked data for this period',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getColors(context).divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getColors(context).textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: TextStyle(fontSize: 12, color: AppTheme.getColors(context).textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 5 ? 5 : items.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final color = ColorUtils.parseHex(item.colorHex);
                final durationStr = TimerService.formatDuration(item.duration, includeSeconds: false);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.iconName != null) ...[
                          Icon(IconUtils.getIcon(item.iconName), size: 13, color: color),
                          SizedBox(width: 6),
                        ] else ...[
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.getColors(context).textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          durationStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getColors(context).textPrimary,
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${item.percentage.toStringAsFixed(1)}%',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (item.percentage / 100.0).clamp(0.0, 1.0),
                        backgroundColor: AppTheme.getColors(context).card,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
