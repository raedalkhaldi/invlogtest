import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/checkin.dart';

class CheckInCard extends StatelessWidget {
  final CheckIn checkIn;
  final VoidCallback? onLike;

  const CheckInCard({
    super.key,
    required this.checkIn,
    this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    (checkIn.username.isNotEmpty ? checkIn.username[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkIn.displayName ?? checkIn.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${checkIn.username}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(checkIn.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (checkIn.placeName?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: '@${checkIn.username}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' checked in at '),
                      TextSpan(
                        text: checkIn.placeName!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (checkIn.caption != null && checkIn.caption!.isNotEmpty)
              Text(checkIn.caption!),
            if (checkIn.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  checkIn.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    checkIn.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: checkIn.isLiked ? Colors.red : null,
                  ),
                  onPressed: onLike,
                ),
                Text('${checkIn.likedBy.length}'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () {
                    // TODO: Implement comment functionality
                  },
                ),
                Text('${checkIn.comments.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.yMMMd().format(timestamp);
    }
  }
} 