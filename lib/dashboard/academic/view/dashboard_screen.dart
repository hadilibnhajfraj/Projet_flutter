import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dash_master_toolkit/services/kpi_service.dart';
import 'package:dash_master_toolkit/dashboard/academic/model/kpi_model.dart';

class DashboardScreen extends StatefulWidget {
  final String token;

  const DashboardScreen({super.key, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final service = KPIService(baseUrl: "http://localhost:4000");

  KPIModel? data;
  bool loading = true;
  String? selectedUser;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);

    final res = await service.fetchKPI(
      widget.token,
      userId: selectedUser,
    );

    setState(() {
      data = res;
      loading = false;
    });
  }

  double safe(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// 🔥 STATUT MAPPING
  String mapStatut(String? s) {
    switch (s) {
      case "Preparation":
        return "Préparation";
      case "En cours":
        return "En cours";
      case "Termine":
        return "Terminé";
      default:
        return s ?? "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userStats = data?.userStats ?? [];
    final statutStats = data?.statutStats ?? [];

    final total = userStats.fold<double>(
      0.0,
      (double sum, dynamic e) => sum + safe(e["count"]),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard KPI")),

      /// 🔥 RESPONSIVE FIX
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 300, child: _buildPie(userStats, total)),
                  _buildLegend(userStats, total),
                  SizedBox(height: 300, child: _buildBar(statutStats)),
                ],
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(height: 400, child: _buildPie(userStats, total)),
              ),
              Expanded(
                flex: 1,
                child: _buildLegend(userStats, total),
              ),
              Expanded(
                flex: 3,
                child: SizedBox(height: 400, child: _buildBar(statutStats)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ================= PIE =================
  Widget _buildPie(List userStats, double total) {
    if (userStats.isEmpty || total == 0) {
      return const Center(child: Text("No data"));
    }

    return PieChart(
      PieChartData(
        sections: userStats.map<PieChartSectionData>((u) {
          final count = safe(u["count"]);

          if (count == 0) {
            return PieChartSectionData(
              value: 0.0001,
              title: "",
              color: Colors.transparent,
            );
          }

          final percent = (count / total * 100);

          return PieChartSectionData(
            value: count,
            title: "${percent.toStringAsFixed(1)}%",
            radius: 100,
            color: _color(u["userName"]),
          );
        }).toList(),

        centerSpaceRadius: 50,

        pieTouchData: PieTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (response == null ||
                response.touchedSection == null) return;

            final index =
                response.touchedSection!.touchedSectionIndex;

            /// 🔥 FIX INDEX -1
            if (index < 0 || index >= userStats.length) return;

            setState(() {
              selectedUser = userStats[index]["userId"];
            });

            load();
          },
        ),
      ),
    );
  }

  /// ================= BAR =================
  Widget _buildBar(List statutStats) {
    if (statutStats.isEmpty) {
      return const Center(child: Text("No data"));
    }

    final maxY = statutStats
            .map((e) => safe(e["count"]))
            .fold(0.0, (a, b) => a > b ? a : b) +
        2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,

        barGroups: statutStats.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;

          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: safe(e["count"]),
                width: 25,
                borderRadius: BorderRadius.circular(6),
                color: Colors.orange,
              )
            ],
          );
        }).toList(),

        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();

                if (i < 0 || i >= statutStats.length) {
                  return const SizedBox();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    mapStatut(statutStats[i]["statut"]),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),

        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  /// ================= LEGEND =================
  Widget _buildLegend(List userStats, double total) {
    return ListView.builder(
      itemCount: userStats.length,
      itemBuilder: (_, i) {
        final u = userStats[i];
        final count = safe(u["count"]);
        final percent = total == 0 ? 0 : (count / total * 100);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _color(u["userName"]),
          ),
          title: Text(u["userName"] ?? "User"),
          subtitle:
              Text("${count.toInt()} (${percent.toStringAsFixed(1)}%)"),
        );
      },
    );
  }

  Color _color(String? key) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    if (key == null) return Colors.grey;

    return colors[key.hashCode.abs() % colors.length];
  }
}