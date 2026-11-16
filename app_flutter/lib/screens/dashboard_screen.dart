import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'connexion_screen.dart';
import 'recoltes_screen.dart';
import 'pertes_screen.dart';
import 'profil_screen.dart';
import 'outils_screen.dart';
import 'analyse_ia_screen.dart';
import 'scanner_screen.dart';
import 'assistant_agricole_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  int _currentIndex = 0;

  final _titles = const ['Vue d’ensemble', 'Récoltes', 'Pertes', 'Pilotage', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AccueilTab(api: _api, onNavigate: (i) => setState(() => _currentIndex = i)),
      const RecoltesScreen(embedded: true),
      const PertesScreen(embedded: true),
      const OutilsScreen(),
      const ProfilScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo-samou-mbeymi.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.agriculture_rounded),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titles[_currentIndex], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Text('Samou Mbeymi', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) {
              if (value == 'logout') _deconnexion();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Déconnexion')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.grass_outlined), selectedIcon: Icon(Icons.grass_rounded), label: 'Récoltes'),
          NavigationDestination(icon: Icon(Icons.warning_amber_rounded), selectedIcon: Icon(Icons.warning_rounded), label: 'Pertes'),
          NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment_rounded), label: 'Pilotage'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }

  Future<void> _deconnexion() async {
    await _api.deconnexion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ConnexionScreen()),
      (_) => false,
    );
  }
}

class _AccueilTab extends StatefulWidget {
  final ApiService api;
  final ValueChanged<int> onNavigate;
  const _AccueilTab({required this.api, required this.onNavigate});

  @override
  State<_AccueilTab> createState() => _AccueilTabState();
}

class _AccueilTabState extends State<_AccueilTab> {
  TableauBord? _data;
  bool _loading = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      final json = await widget.api.tableauBord();
      if (!mounted) return;
      setState(() => _data = TableauBord.fromJson(json));
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_erreur != null || _data == null) {
      return _ErrorState(message: _erreur ?? 'Impossible de charger les données.', onRetry: _charger);
    }

    final d = _data!;
    final ratio = (d.tauxPerte / 100).clamp(0.0, 1.0);
    final status = d.tauxPerte <= 5 ? 'Très bonne maîtrise' : d.tauxPerte <= 12 ? 'À surveiller' : 'Action recommandée';
    final statusColor = d.tauxPerte <= 5 ? AppColors.success : d.tauxPerte <= 12 ? AppColors.accent : AppColors.loss;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _charger,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1480), child: _HeroCard(data: d))),
          const SizedBox(height: 16),
          _QuickActions(onPilotage: () => widget.onNavigate(3), onRecolte: () => widget.onNavigate(1), onPerte: () => widget.onNavigate(2)),
          const SizedBox(height: 14),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyseIARisqueScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Analyse intelligente', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('Évaluer le risque de pertes d’une récolte', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Outils intelligents', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'Des outils complémentaires pour accompagner vos récoltes.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ScannerScreen()),
                          ),
                          icon: const Icon(Icons.photo_camera_outlined, size: 18),
                          label: const Text('Analyser une photo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AssistantAgricoleScreen(
                              onNavigate: (destination) => widget.onNavigate(destination == 5 ? 4 : destination),
                            )),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Assistant agricole'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssistantAgricoleScreen(
                            onNavigate: (destination) {
                              if (destination == 0) {
                                widget.onNavigate(0);
                              } else if (destination == 1 || destination == 2) {
                                widget.onNavigate(destination);
                              } else if (destination == 5) {
                                widget.onNavigate(4);
                              } else {
                                widget.onNavigate(3);
                              }
                            },
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Assistant agricole — poser une question'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Vos indicateurs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 680 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: columns == 4 ? 1.85 : 1.28,
                children: [
                  _MetricCard(icon: Icons.grass_rounded, label: 'Récoltes', value: '${d.nbRecoltes}', color: AppColors.primary),
                  _MetricCard(icon: Icons.scale_rounded, label: 'Récolté', value: _kg(d.totalRecolteKg), color: AppColors.accent),
                  _MetricCard(icon: Icons.remove_circle_outline_rounded, label: 'Perdu', value: _kg(d.totalPerteKg), color: AppColors.loss),
                  _MetricCard(icon: Icons.pie_chart_rounded, label: 'Taux de perte', value: '${d.tauxPerte.toStringAsFixed(1)}%', color: AppColors.info),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('Indice de maîtrise des pertes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)),
                        child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 11,
                      value: ratio,
                      backgroundColor: AppColors.bg,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${d.totalPerteKg.toStringAsFixed(1)} kg perdus sur ${d.totalRecolteKg.toStringAsFixed(1)} kg enregistrés.',
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AlertsCard(data: d),
          const SizedBox(height: 18),
          _EvolutionCard(data: d),
          const SizedBox(height: 18),
          _LossCausesCard(data: d),
        ],
      ),
    );
  }


  String _kg(double value) => value >= 1000 ? '${(value / 1000).toStringAsFixed(1)} t' : '${value.toStringAsFixed(0)} kg';
}

class _HeroCard extends StatelessWidget {
  final TableauBord data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final icon = Container(
          width: compact ? 52.0 : 66.0,
          height: compact ? 52.0 : 66.0,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(Icons.agriculture_rounded, size: compact ? 28 : 34, color: AppColors.accent),
        );
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
              child: const Text('TABLEAU DE BORD AGRICOLE', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
            ),
            const SizedBox(height: 13),
            const Text('Bonjour 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Gardons chaque kilo sous contrôle.', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.15)),
            const SizedBox(height: 9),
            Text('${data.nbPertes} signalement${data.nbPertes > 1 ? 's' : ''} enregistré${data.nbPertes > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFFD7E8DF), fontSize: 12)),
          ],
        );
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 18 : 24),
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/hero-banner.png'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              colorFilter: ColorFilter.mode(Color(0x66052E24), BlendMode.darken),
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: compact
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Align(alignment: Alignment.topRight, child: icon), const SizedBox(height: 4), text])
              : Row(children: [Expanded(child: text), const SizedBox(width: 20), icon]),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 19)),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.15, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}



class _AlertsCard extends StatelessWidget {
  final TableauBord data;
  const _AlertsCard({required this.data});
  @override Widget build(BuildContext context) {
    final a = data.alertes.isEmpty ? null : data.alertes.first;
    final level = a?['niveau']?.toString() ?? 'success';
    final color = level == 'danger' ? AppColors.loss : level == 'warning' ? AppColors.accent : AppColors.primary;
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(13)),child:Icon(level=='danger'?Icons.error_outline:level=='warning'?Icons.warning_amber_rounded:Icons.check_circle_outline,color:color)),
      const SizedBox(width:12), Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a?['titre']?.toString() ?? 'Situation',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(a?['message']?.toString() ?? data.recommandation,style:const TextStyle(color:AppColors.inkSoft,fontSize:12,height:1.4))]))
    ])));
  }
}

class _EvolutionCard extends StatelessWidget {
  final TableauBord data;
  const _EvolutionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pts = data.evolutionMensuelle;
    if (pts.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Évolution de l’activité', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Production et pertes sur les 12 derniers mois.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: .7),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 9, color: AppColors.inkSoft)),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= pts.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(pts[index].mois, style: const TextStyle(fontSize: 8, color: AppColors.inkSoft)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (int i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].productionPct)],
                      isCurved: true,
                      barWidth: 3,
                      color: AppColors.primary,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: [for (int i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].pertePct)],
                      isCurved: true,
                      barWidth: 3,
                      color: AppColors.loss,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppColors.primary, label: 'Production'),
                SizedBox(width: 18),
                _LegendDot(color: AppColors.loss, label: 'Pertes'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget{final Color color;final String label;const _LegendDot({required this.color,required this.label});@override Widget build(BuildContext c)=>Row(children:[Container(width:8,height:8,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:5),Text(label,style:const TextStyle(fontSize:10,color:AppColors.inkSoft))]);}

class _LossCausesCard extends StatelessWidget {
  final TableauBord data;
  const _LossCausesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = data.pertesParType;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Principales causes de pertes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Identifiez rapidement les postes à améliorer.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const _EmptyInsight()
          else
            ...items.take(5).map((item) {
              final label = item['label']?.toString() ?? item['type_perte']?.toString() ?? 'Autre';
              final total = double.tryParse(item['total_kg']?.toString() ?? '0') ?? 0;
              final max = items.map((e) => double.tryParse(e['total_kg']?.toString() ?? '0') ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
              final progress = max == 0 ? 0.0 : (total / max).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(children: [
                  Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))), Text('${total.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.loss))]),
                  const SizedBox(height: 7),
                  ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(minHeight: 7, value: progress, backgroundColor: AppColors.bg, color: AppColors.loss)),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onPilotage;
  final VoidCallback onRecolte;
  final VoidCallback onPerte;
  const _QuickActions({required this.onPilotage, required this.onRecolte, required this.onPerte});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Actions rapides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Action(icon: Icons.assessment_outlined, title: 'Pilotage', subtitle: 'Consulter', color: AppColors.primary, onTap: onPilotage)),
        const SizedBox(width: 10),
        Expanded(child: _Action(icon: Icons.add_circle_outline_rounded, title: 'Récolte', subtitle: 'Ajouter', color: AppColors.success, onTap: onRecolte)),
        const SizedBox(width: 10),
        Expanded(child: _Action(icon: Icons.warning_amber_rounded, title: 'Perte', subtitle: 'Signaler', color: AppColors.loss, onTap: onPerte)),
      ]),
    ]);
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color == AppColors.loss ? AppColors.lossSoft : color == AppColors.accent ? AppColors.accentSoft : color == AppColors.info ? AppColors.infoSoft : AppColors.successSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: .13)),),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            Text(subtitle, style: const TextStyle(color: AppColors.inkSoft, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

class _EmptyInsight extends StatelessWidget {
  const _EmptyInsight();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(16)),
      child: const Row(children: [
        Icon(Icons.check_circle_rounded, color: AppColors.success),
        SizedBox(width: 12),
        Expanded(child: Text('Aucune perte enregistrée. Continuez à surveiller vos récoltes.', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.lossSoft, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.cloud_off_rounded, color: AppColors.loss, size: 30)),
          const SizedBox(height: 16),
          const Text('Données indisponibles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
          const SizedBox(height: 18),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
        ]),
      ),
    );
  }
}
