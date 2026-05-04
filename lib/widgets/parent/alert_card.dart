import 'package:flutter/material.dart';

class AlertCard extends StatefulWidget {
  final String source;
  final Color sourceColor;
  final IconData icon;
  final String timeAgo;
  final String title;
  final String description;

  const AlertCard({
    super.key,
    required this.source,
    required this.sourceColor,
    required this.icon,
    required this.timeAgo,
    required this.title,
    required this.description,
  });

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row
          Row(
            children: [
              Icon(widget.icon, color: widget.sourceColor, size: 16),
              const SizedBox(width: 8),
              Text(
                widget.source,
                style: TextStyle(
                  color: widget.sourceColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.timeAgo,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Title
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          // Expandable Description
          if (_isExpanded) ...[
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
