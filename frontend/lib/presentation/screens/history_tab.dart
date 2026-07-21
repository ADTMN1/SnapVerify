import 'package:flutter/material.dart';
import '../../core/tailwind.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: TextStyle(
                  color: TwColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildTransferItem(
                  name: 'Bolt Food',
                  amount: '-26.81',
                  currency: 'lei',
                  time: '12:15',
                  color: TwColors.emerald500,
                  initials: 'Bolt\nFood',
                ),
                const SizedBox(height: 16),
                _buildTransferItem(
                  name: 'Marie',
                  amount: '-100.00',
                  currency: '\$',
                  time: '26 March, 16:24',
                  isImage: true,
                ),
                const SizedBox(height: 16),
                _buildTransferItem(
                  name: 'Uber',
                  amount: '-19.46',
                  currency: '\$',
                  secondaryCurrency: '18 €',
                  time: 'Yesterday, 16:42',
                  color: TwColors.slate900,
                  initials: 'Uber',
                ),
                const SizedBox(height: 16),
                _buildTransferItem(
                  name: 'Starbucks',
                  amount: '-8.50',
                  currency: '\$',
                  time: '25 March, 09:30',
                  color: TwColors.emerald600,
                  initials: 'SB',
                ),
                const SizedBox(height: 16),
                _buildTransferItem(
                  name: 'Amazon',
                  amount: '-45.99',
                  currency: '\$',
                  time: '24 March, 18:15',
                  color: TwColors.slate700,
                  initials: 'AZ',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferItem({
    required String name,
    required String amount,
    required String currency,
    String? secondaryCurrency,
    required String time,
    Color? color,
    String? initials,
    bool isImage = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: TwColors.slate800,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color ?? TwColors.slate700,
              borderRadius: BorderRadius.circular(28),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop',
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      initials ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            color == TwColors.slate900 ? TwColors.white : TwColors.slate900,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: TwColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: TwColors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amount $currency',
                style: const TextStyle(
                  color: TwColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (secondaryCurrency != null)
                Text(
                  secondaryCurrency,
                  style: TextStyle(
                    color: TwColors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
