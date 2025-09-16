import 'package:flutter/material.dart';

class BusTrackingPage extends StatelessWidget {
  final String busName;
  final List<String> stops;
  final int currentStopIndex;
  final int availableSeats;
  final List<String> arrivalTimes;

  const BusTrackingPage({
    super.key,
    required this.busName,
    required this.stops,
    required this.currentStopIndex,
    this.availableSeats = 12,
    List<String>? arrivalTimes,
  }) : arrivalTimes = arrivalTimes ?? const [];

  @override
  Widget build(BuildContext context) {
    // Generate default arrival times if none provided
    final List<String> displayTimes = arrivalTimes.isNotEmpty
        ? arrivalTimes
        : _generateDefaultTimes();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              busName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(
                  Icons.event_seat,
                  size: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  '$availableSeats seats available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: availableSeats > 10
                  ? Colors.green
                  : availableSeats > 5
                  ? Colors.orange
                  : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              availableSeats > 10
                  ? 'Available'
                  : availableSeats > 5
                  ? 'Few Left'
                  : 'Almost Full',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stops.length,
          itemBuilder: (context, index) {
            return _buildStopItem(index, displayTimes);
          },
        ),
      ),
    );
  }

  Widget _buildStopItem(int index, List<String> displayTimes) {
    final bool isCurrentStop = index == currentStopIndex;
    final bool isPastStop = index < currentStopIndex;
    final bool isFinalStop = index == stops.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column with line and icon
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top line (except for first stop)
                if (index != 0)
                  Container(
                    width: 4,
                    height: 20,
                    color: isPastStop || isCurrentStop
                        ? Colors.blue
                        : Colors.grey[300],
                  ),

                // Stop icon
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getStopColor(index),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _getStopIcon(index),
                ),

                // Bottom line (except for last stop)
                if (!isFinalStop)
                  Container(
                    width: 4,
                    height: 40,
                    color: isPastStop
                        ? Colors.blue
                        : Colors.grey[300],
                  ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Stop information
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentStop
                      ? Colors.blue
                      : Colors.grey.shade200,
                  width: isCurrentStop ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stops[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrentStop
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isCurrentStop
                                ? Colors.blue.shade700
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      // Arrival time
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getTimeBackgroundColor(index),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTimeIcon(index),
                              size: 12,
                              color: _getTimeTextColor(index),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              displayTimes[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getTimeTextColor(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _getStatusChip(index),
                      const Spacer(),
                      if (isCurrentStop)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_bus,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Bus Here Now",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Additional info for current stop
                  if (isCurrentStop) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.shade100,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Estimated departure: ${_getEstimatedDeparture(index, displayTimes)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStopColor(int index) {
    if (index == currentStopIndex) {
      return Colors.blue.shade600;
    } else if (index < currentStopIndex) {
      return Colors.green.shade500;
    } else if (index == stops.length - 1) {
      return Colors.orange.shade500;
    } else {
      return Colors.grey.shade400;
    }
  }

  Widget _getStopIcon(int index) {
    if (index == currentStopIndex) {
      return Icon(
        Icons.directions_bus,
        size: 14,
        color: Colors.white,
      );
    } else if (index < currentStopIndex) {
      return Icon(
        Icons.check,
        size: 14,
        color: Colors.white,
      );
    } else if (index == stops.length - 1) {
      return Icon(
        Icons.flag,
        size: 14,
        color: Colors.white,
      );
    } else {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    }
  }

  Widget _getStatusChip(int index) {
    String status;
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (index == currentStopIndex) {
      status = "Current Stop";
      backgroundColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue.shade700;
      borderColor = Colors.blue.withOpacity(0.3);
    } else if (index < currentStopIndex) {
      status = "Completed";
      backgroundColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green.shade700;
      borderColor = Colors.green.withOpacity(0.3);
    } else if (index == stops.length - 1) {
      status = "Final Stop";
      backgroundColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange.shade700;
      borderColor = Colors.orange.withOpacity(0.3);
    } else {
      status = "Upcoming";
      backgroundColor = Colors.grey.withOpacity(0.1);
      textColor = Colors.grey.shade700;
      borderColor = Colors.grey.withOpacity(0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getTimeBackgroundColor(int index) {
    if (index == currentStopIndex) {
      return Colors.green.shade50;
    } else if (index < currentStopIndex) {
      return Colors.grey.shade100;
    } else {
      return Colors.blue.shade50;
    }
  }

  Color _getTimeTextColor(int index) {
    if (index == currentStopIndex) {
      return Colors.green.shade700;
    } else if (index < currentStopIndex) {
      return Colors.grey.shade600;
    } else {
      return Colors.blue.shade700;
    }
  }

  IconData _getTimeIcon(int index) {
    if (index == currentStopIndex) {
      return Icons.access_time_filled;
    } else if (index < currentStopIndex) {
      return Icons.history;
    } else {
      return Icons.schedule;
    }
  }

  String _getEstimatedDeparture(int index, List<String> displayTimes) {
    if (index < displayTimes.length && index == currentStopIndex) {
      // Parse the arrival time and add 2 minutes for departure
      try {
        List<String> timeParts = displayTimes[index].split(':');
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);

        minute += 2; // Add 2 minutes for departure
        if (minute >= 60) {
          hour += 1;
          minute -= 60;
        }

        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'In 2 mins';
      }
    }
    return 'In 2 mins';
  }

  List<String> _generateDefaultTimes() {
    List<String> times = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < stops.length; i++) {
      DateTime arrivalTime = now.add(Duration(minutes: i * 7)); // 7 minutes between stops
      String timeString = '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';
      times.add(timeString);
    }

    return times;
  }
}