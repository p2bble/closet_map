import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clothing.dart';
import '../models/outfit.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/season_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _db = DatabaseService();
  List<Clothing> _activeClothes = [];
  List<Clothing> _neglectedClothes = [];
  List<(Outfit, List<Clothing>)> _recentOutfits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _db.getClothes(status: ClothingStatus.active);
    final neglected = await _db.getNeglectedClothes();
    final outfits = await _db.getRecentOutfits(limit: 3);
    if (mounted) {
      setState(() {
        _activeClothes = all;
        _neglectedClothes = neglected;
        _recentOutfits = outfits;
        _loading = false;
      });
    }
    _checkNeglectedNotification(neglected.length);
  }

  Future<void> _checkNeglectedNotification(int count) async {
    if (count == 0) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('last_neglect_notify_date');
    if (lastDate == today) return;
    await NotificationService().showNeglectedAlert(count);
    await prefs.setString('last_neglect_notify_date', today);
  }

  List<Clothing> get _seasonMatched =>
      _activeClothes.where((c) => SeasonService.matchesCurrent(c.seasons)).toList();

  String _formatDate(DateTime dt) {
    const months = [
      '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월',
    ];
    return '${months[dt.month - 1]} ${dt.day}일';
  }

  // ── 코디 기록 시트 ────────────────────────────
  Future<void> _showOutfitSheet() async {
    if (_activeClothes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('착용 중인 옷이 없어요. 먼저 옷을 등록해주세요.')),
      );
      return;
    }

    final selected = <int>{};
    final nameCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('오늘의 코디 기록',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '코디 이름 (선택)',
                        hintText: '예: 월요일 출근룩',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '착용한 옷 선택 (${selected.length}개)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _activeClothes.length,
                  itemBuilder: (_, i) {
                    final c = _activeClothes[i];
                    final isSelected = selected.contains(c.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) => setS(() =>
                          v! ? selected.add(c.id!) : selected.remove(c.id)),
                      secondary: c.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(c.imagePath!),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c.color != null
                                    ? Color(c.color!.colorValue)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.checkroom,
                                  size: 22, color: Colors.grey.shade400),
                            ),
                      title: Text(c.name,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        [
                          c.category.label,
                          if (c.color != null) c.color!.label,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            final outfit = Outfit(
                              name: nameCtrl.text.trim().isEmpty
                                  ? null
                                  : nameCtrl.text.trim(),
                              createdAt: DateTime.now(),
                            );
                            final outfitId = await _db.insertOutfit(outfit);
                            for (final clothingId in selected) {
                              await _db.insertOutfitItem(outfitId, clothingId);
                              await _db.incrementWearCount(clothingId);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('기록 저장 (${selected.length}개)'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          const SizedBox(height: 16),
          _buildNeglectedSection(),
          _buildOutfitSection(),
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
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(SeasonService.seasonChangeMessage(),
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _summaryCard('꺼내져 있는 옷', '${_activeClothes.length}벌',
            Icons.checkroom, Colors.blue),
        const SizedBox(width: 12),
        _summaryCard('이번 계절 옷', '${_seasonMatched.length}벌',
            Icons.wb_sunny, Colors.orange),
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
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
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

  // ── 방치 옷 섹션 ──────────────────────────────
  Widget _buildNeglectedSection() {
    if (_neglectedClothes.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.amber.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(
                  '오래 입지 않은 옷 ${_neglectedClothes.length}벌',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '6개월 이상 입지 않은 옷이 있어요. 정리를 고려해보세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _neglectedClothes.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _neglectedClothes[i];
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: c.imagePath != null
                            ? Image.file(
                                File(c.imagePath!),
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 38,
                                height: 38,
                                color: c.color != null
                                    ? Color(c.color!.colorValue)
                                    : Colors.grey.shade200,
                                child: Icon(Icons.checkroom,
                                    size: 20,
                                    color: Colors.grey.shade400),
                              ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 42,
                        child: Text(
                          c.name,
                          style: const TextStyle(fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 코디 기록 섹션 ────────────────────────────
  Widget _buildOutfitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('코디 기록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _showOutfitSheet,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('오늘 기록'),
            ),
          ],
        ),
        if (_recentOutfits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '오늘 입은 옷을 기록해보세요',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          )
        else
          ..._recentOutfits.map((record) {
            final (outfit, clothes) = record;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: SizedBox(
                  width: 88,
                  child: Row(
                    children: clothes.take(2).map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: c.imagePath != null
                              ? Image.file(
                                  File(c.imagePath!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  color: c.color != null
                                      ? Color(c.color!.colorValue)
                                      : Colors.grey.shade200,
                                  child: Icon(Icons.checkroom,
                                      size: 20,
                                      color: Colors.grey.shade400),
                                ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                title: Text(
                  outfit.name ?? '코디 · ${_formatDate(outfit.createdAt)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${clothes.length}가지  ·  ${_formatDate(outfit.createdAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.grey),
                  onPressed: () async {
                    await _db.deleteOutfit(outfit.id!);
                    _load();
                  },
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── 이번 계절 옷 섹션 ─────────────────────────
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
                  color: c.color != null
                      ? Color(c.color!.colorValue)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.checkroom,
                    color: c.color != null
                        ? Colors.white.withAlpha(180)
                        : Colors.grey.shade400)),
        title: Text(c.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            c.category.label,
            if (c.seasons.isNotEmpty) c.seasons.map((s) => s.label).join('/'),
          ].join('  ·  '),
          style: const TextStyle(fontSize: 12),
        ),
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
