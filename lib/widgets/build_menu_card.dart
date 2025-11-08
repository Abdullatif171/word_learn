// lib/widgets/build_menu_card.dart
import 'package:flutter/material.dart';

class BuildMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color; // Bu rengi ikon/vurgu için kullanacağız
  final VoidCallback onTap;

  const BuildMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      // main.dart'taki CardTheme'i kullanacak (yüzey rengi, kenarlık vb.)
      clipBehavior: Clip.antiAlias, // İçeriğin kenarlıktan taşmasını önle
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: color, // Pirinç veya Bakır rengi
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface // Açık renk metin
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7), // Soluk metin
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}