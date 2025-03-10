import 'package:anx_reader/main.dart';
import 'package:anx_reader/providers/statistic_data.dart';
import 'package:anx_reader/utils/date/convert_seconds.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatisticChart extends ConsumerStatefulWidget {
  final List<int> readingTime;
  final List<String> xLabels;

  const StatisticChart(
      {super.key, required this.readingTime, required this.xLabels});

  @override
  ConsumerState<StatisticChart> createState() => _StatisticChartState();
}

class _StatisticChartState extends ConsumerState<StatisticChart> {
  int? touchedIndex;
  final Color bottomColor =
      Theme
          .of(navigatorKey.currentState!.context)
          .colorScheme
          .primary;

  final Color topColor = Theme
      .of(navigatorKey.currentState!.context)
      .colorScheme
      .primary
      .withOpacity(0.5);

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        barTouchData: barTouchData,
        titlesData: titlesData,
        borderData: borderData,
        barGroups: barGroups,
        gridData: const FlGridData(show: false),
        alignment: BarChartAlignment.spaceAround,
        maxY: widget.readingTime
            .reduce((value, element) => value > element ? value : element) *
            1.2,
      ),
    );
  }

  BarTouchData get barTouchData {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (BarChartGroupData group) {
          return Colors.white.withOpacity(0);
        },
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          if (touchedIndex != null && group.x.toInt() == touchedIndex) {
            return BarTooltipItem(
              convertSeconds(widget.readingTime[group.x.toInt()]),
              TextStyle(
                color: topColor,
                fontWeight: FontWeight.bold,
              ),
            );
          }
          return null;
        },
      ),
      touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
        if (response?.spot != null) {
          setState(() {
            touchedIndex = response!.spot!.touchedBarGroupIndex;
            if (event is FlTapUpEvent) {
              if (widget.readingTime.length == 12) {
                ref
                    .read(statisticDataProvider.notifier)
                    .touchMonth(touchedIndex!);
              } else {
                ref
                    .read(statisticDataProvider.notifier)
                    .touchDay(widget.xLabels.length, touchedIndex!);
              }
            }
          });
        }
      },
    );
  }

  FlTitlesData get titlesData =>
      FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: getTitles,
          ),
        ),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      );

  FlBorderData get borderData =>
      FlBorderData(
        show: false,
      );

  LinearGradient get _barsGradient =>
      LinearGradient(
        colors: [
          bottomColor,
          topColor,
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );

  List<BarChartGroupData> get barGroups {
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < widget.readingTime.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: widget.readingTime[i].toDouble(),
              gradient: _barsGradient,
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }
    return barGroups;
  }

  SideTitleWidget getTitles(double value, TitleMeta meta) {
    var style = TextStyle(
      color: bottomColor,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    return SideTitleWidget(
        meta: meta,
        child: Text(
          widget.xLabels[value.toInt()],
          style: style,
        ));
  }
}
