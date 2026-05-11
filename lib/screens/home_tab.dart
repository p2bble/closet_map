import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing.dart';
import '../services/database_service.dart';
import '../services/season_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _db = DatabaseService();
  List<Clothing> _activeClothes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _db.getClothes(status: ClothingStatus.active);
    if (mounted) {
      setState(() {
        _activeClothes = all;
        _loading = false;
      });
    }
  }

  List<Clothing> get _seasonMatched =>
      _activeClothes.where((c) => SeasonService.matchesCurrent(c.seasons)).toList();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSeasonBanner(),
          const SizedBox(height: 16),
          _buildSummaryRow(),
          const SizedBox(height: 20),
          _buildActiveSection(),
        ],
      ),
    );
  }

  Widget _buildSeasonBanner() {
    final season = SeasonService.currentSeasonLabel();
    final emoji = const {
      '봄': '🌸',
      '여름': '☀️',
      '가을': '🍂',
      '겨울': '❄️',
    }[season] ?? '🌿';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withAlpha(180),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji 지금은 $season 시즌',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(SeasonService.seasonChangeMessage(),
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final storedCount = _activeClothes.length;
    final matchCount = _seasonMatched.length;

    return Row(
      children: [
        _summaryCard('꺼내져 있는 옷', '$storedCount벌', Icons.checkroom, Colors.blue),
        const SizedBox(width: 12),
        _summaryCard('이번 계절 옷', '$matchCount벌', Icons.wb_sunny, Colors.orange),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이번 계절 옷 (${_seasonMatched.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_seasonMatched.isEmpty)
          _buildEmpty()
        else
          ..._seasonMatched.map((c) => _clothingTile(c)),
      ],
    );
  }

  Widget _clothingTile(Clothing c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: c.imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(c.imagePath!),
                    width: 48, height: 48, fit: BoxFit.cover),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.checkroom, color: Colors.grey.shade400)),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${c.category.label}  ·  ${c.seasons.map((s) => s.label).join('/')}',
            style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.checkroom, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('이번 계절 옷이 없어요\n아래 탭에서 옷을 등록해보세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
