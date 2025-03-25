import 'package:flutter/material.dart';
import '../models/checkin_model.dart';

class CheckInCard extends StatelessWidget {
  final CheckInModel checkIn;

  const CheckInCard({Key? key, required this.checkIn}) : super(key: key);

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                checkIn.username.isNotEmpty ?
                checkIn.username[0].toUpperCase() : '?',
              ),
            ),
            title: Text(
              checkIn.displayName ?? checkIn.username,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('@${checkIn.username}'),
            trailing: Text(
              _formatTimestamp(checkIn.createdAt),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          if (checkIn.photoUrl != null)
            Image.network(
              checkIn.photoUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkIn.restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (checkIn.caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(checkIn.caption!),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${checkIn.likeCount} likes'),
                    const SizedBox(width: 16),
                    Text('${checkIn.commentCount} comments'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 