import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clothing.dart';
import '../models/outfit.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/season_service.dart';
import '../widgets/outfit_share_card.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _db = DatabaseService();
  static const _laundryThreshold = 3;

  List<Clothing> _activeClothes = [];
  List<Clothing> _neglectedClothes = [];
  List<Clothing> _laundryClothes = [];
  List<(Outfit, List<Clothing>)> _recentOutfits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _db.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _db.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final all = await _db.getClothes(status: ClothingStatus.active);
    final neglected = await _db.getNeglectedClothes(
      forSeason: SeasonService.currentSeason(),
    );
    final laundry = await _db.getLaundryNeededClothes(threshold: _laundryThreshold);
    final outfits = await _db.getRecentOutfits(limit: 3);
    if (mounted) {
      setState(() {
        _activeClothes = all;
        _neglectedClothes = neglected;
        _laundryClothes = laundry;
        _recentOutfits = outfits;
        _loading = false;
      });
    }
    _checkNeglectedNotification(neglected.length);
    _checkLaundryNotification(laundry.length);
  }

  Future<void> _checkLaundryNotification(int count) async {
    if (count == 0) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('last_laundry_notify_date');
    if (lastDate == today) return;
    await NotificationService().showLaundryAlert(count);
    await prefs.setString('last_laundry_notify_date', today);
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

  // ── 코디 공유 미리보기 ────────────────────────
  Future<void> _showSharePreview(Outfit outfit, List<Clothing> clothes) async {
    final repaintKey = GlobalKey();

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: RepaintBoundary(
                key: repaintKey,
                child: OutfitShareCard(outfit: outfit, clothes: clothes),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 디매 양식 텍스트 복사
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('디매 양식 텍스트 복사'),
                    onPressed: () {
                      final text = _buildOutfitText(clothes);
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('복사됐어요! 디매 게시글에 붙여넣기 하세요.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('닫기'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.ios_share, size: 16),
                          label: const Text('이미지 공유'),
                          onPressed: () async {
                            final bytes = await _captureToBytes(repaintKey);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (bytes != null && mounted) {
                              await _shareBytes(bytes, outfit.name);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _captureToBytes(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareBytes(Uint8List bytes, String? outfitName) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final file = File(
          '${tmpDir.path}/outfit_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: outfitName != null
            ? '$outfitName | 옷장지도'
            : '오늘의 코디 | 옷장지도',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유에 실패했어요.')),
        );
      }
    }
  }

  // ── 디매 양식 텍스트 생성 ──────────────────────
  String _buildOutfitText(List<Clothing> clothes) {
    final groups = <String, List<Clothing>>{
      '상의': [],
      '하의': [],
      '신발': [],
      '악세': [],
    };

    for (final c in clothes) {
      switch (c.category) {
        case ClothingCategory.top:
        case ClothingCategory.outer:
        case ClothingCategory.underwear:
        case ClothingCategory.etc:
          groups['상의']!.add(c);
        case ClothingCategory.bottom:
        case ClothingCategory.dress:
          groups['하의']!.add(c);
        case ClothingCategory.shoes:
          groups['신발']!.add(c);
        case ClothingCategory.accessory:
          groups['악세']!.add(c);
      }
    }

    final lines = <String>[];
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      final items = entry.value.map((c) {
        final brand = c.brand != null && c.brand!.isNotEmpty ? c.brand! : null;
        return brand != null ? '${c.name} / $brand' : c.name;
      }).join(', ');
      lines.add('${entry.key}: $items');
    }

    lines
      ..add('')
      ..add('내용: ');

    return lines.join('\n');
  }

  // ── 코디 기록 시트 ────────────────────────────
  Future<void> _showOutfitSheet() async {
    if (_activeClothes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('착용 중인 옷이 없어요. 먼저 옷을 등록해주세요.')),
      );
      return;
    }

    final result = await showModalBottomSheet<(Outfit, List<Clothing>)?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _OutfitBottomSheet(
        clothes: _activeClothes,
        onSave: (selected, name) async {
          final now = DateTime.now();
          final outfit = Outfit(name: name, createdAt: now);
          final outfitId = await _db.insertOutfit(outfit);
          final savedOutfit =
              Outfit(id: outfitId, name: name, createdAt: now);
          final savedClothes = <Clothing>[];
          for (final clothingId in selected) {
            await _db.insertOutfitItem(outfitId, clothingId);
            await _db.incrementWearCount(clothingId);
            savedClothes.add(
                _activeClothes.firstWhere((c) => c.id == clothingId));
          }
          AnalyticsService.logOutfitRecorded(clothesCount: savedClothes.length);
          _load();
          return (savedOutfit, savedClothes);
        },
      ),
    );

    if (result != null && mounted) {
      final (outfit, clothes) = result;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              outfit.name != null ? '"${outfit.name}" 저장됐어요!' : '코디가 저장됐어요!'),
          action: SnackBarAction(
            label: '공유하기',
            onPressed: () => _showSharePreview(outfit, clothes),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
          _buildLaundrySection(),
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

  // ── 세탁 알림 섹션 ───────────────────────────
  Widget _buildLaundrySection() {
    if (_laundryClothes.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLaundrySheet(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_laundry_service,
                      color: Colors.blue, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '세탁이 필요한 옷 ${_laundryClothes.length}벌',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: Colors.blue, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$_laundryThreshold회 이상 입은 옷이 있어요. 세탁 후 상쾌하게 입어보세요!',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _laundryClothes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = _laundryClothes[i];
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
      ),
    );
  }

  Future<void> _showLaundrySheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LaundryBottomSheet(
        clothes: _laundryClothes,
        onWashed: (id) async {
          await _db.markAsWashed(id);
          _load();
        },
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.ios_share,
                          size: 18, color: Color(0xFF5C8FFF)),
                      tooltip: '공유',
                      onPressed: () =>
                          _showSharePreview(outfit, clothes),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.grey),
                      onPressed: () async {
                        await _db.deleteOutfit(outfit.id!);
                        _load();
                      },
                    ),
                  ],
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

// ── 세탁 바텀시트 ────────────────────────────────────────────────────────────

class _LaundryBottomSheet extends StatefulWidget {
  final List<Clothing> clothes;
  final Future<void> Function(int id) onWashed;

  const _LaundryBottomSheet({required this.clothes, required this.onWashed});

  @override
  State<_LaundryBottomSheet> createState() => _LaundryBottomSheetState();
}

class _LaundryBottomSheetState extends State<_LaundryBottomSheet> {
  final _washedIds = <int>{};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.local_laundry_service, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('세탁 필요한 옷',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${widget.clothes.length}벌',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: widget.clothes.length,
              itemBuilder: (_, i) {
                final c = widget.clothes[i];
                final done = _washedIds.contains(c.id);
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: c.imagePath != null
                        ? Image.file(
                            File(c.imagePath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: c.color != null
                                ? Color(c.color!.colorValue)
                                : Colors.grey.shade200,
                            child: Icon(Icons.checkroom,
                                size: 24, color: Colors.grey.shade400),
                          ),
                  ),
                  title: Text(c.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : null,
                          color: done ? Colors.grey : null)),
                  subtitle: Text(
                    '${c.wearCountSinceWash}회 착용 · ${c.category.label}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: done
                      ? const Icon(Icons.check_circle,
                          color: Colors.blue, size: 28)
                      : OutlinedButton(
                          onPressed: () async {
                            await widget.onWashed(c.id!);
                            setState(() => _washedIds.add(c.id!));
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('세탁 완료',
                              style: TextStyle(fontSize: 12)),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 코디 기록 바텀시트 (카테고리 탭) ──────────────────────────────────────────

class _OutfitBottomSheet extends StatefulWidget {
  final List<Clothing> clothes;
  final Future<(Outfit, List<Clothing>)> Function(Set<int> selected, String? name) onSave;

  const _OutfitBottomSheet({required this.clothes, required this.onSave});

  @override
  State<_OutfitBottomSheet> createState() => _OutfitBottomSheetState();
}

class _OutfitBottomSheetState extends State<_OutfitBottomSheet>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _selected = <int>{};
  late final TabController _tabCtrl;

  static const _tabLabels = ['전체', '상의', '하의', '신발', '악세'];

  // 탭별 카테고리 필터 (null = 전체)
  static const _tabFilter = <List<ClothingCategory>?>[
    null,
    [ClothingCategory.top, ClothingCategory.outer, ClothingCategory.underwear],
    [ClothingCategory.bottom, ClothingCategory.dress],
    [ClothingCategory.shoes],
    [ClothingCategory.accessory],
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabLabels.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  List<Clothing> _filtered(int idx) {
    final filter = _tabFilter[idx];
    if (filter == null) return widget.clothes;
    return widget.clothes.where((c) => filter.contains(c.category)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 핸들 바
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 타이틀 + 코디명 입력
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('오늘의 코디 기록',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_selected.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selected.length}개 선택',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '코디 이름 (선택)',
                    hintText: '예: 월요일 출근룩',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          // 카테고리 탭바
          TabBar(
            controller: _tabCtrl,
            tabs: List.generate(_tabLabels.length, (i) {
              final count = _filtered(i)
                  .where((c) => _selected.contains(c.id))
                  .length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tabLabels[i]),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicatorWeight: 2.5,
          ),
          // 탭별 옷 목록
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: List.generate(_tabLabels.length, (tabIdx) {
                final clothes = _filtered(tabIdx);
                if (clothes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checkroom,
                            size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          '${_tabLabels[tabIdx]} 항목이 없어요',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: clothes.length,
                  itemBuilder: (_, i) {
                    final c = clothes[i];
                    final isSelected = _selected.contains(c.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) => setState(() =>
                          v! ? _selected.add(c.id!) : _selected.remove(c.id!)),
                      secondary: c.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(c.imagePath!),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.color != null
                                    ? Color(c.color!.colorValue)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.checkroom,
                                  size: 22, color: Colors.grey.shade400),
                            ),
                      title: Text(c.name,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        [
                          c.category.label,
                          if (c.brand != null && c.brand!.isNotEmpty)
                            c.brand!,
                          if (c.color != null) c.color!.label,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                );
              }),
            ),
          ),
          // 저장 버튼
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        final name = _nameCtrl.text.trim().isEmpty
                            ? null
                            : _nameCtrl.text.trim();
                        final result =
                            await widget.onSave(Set.of(_selected), name);
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context, result);
                      },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('기록 저장 (${_selected.length}개)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
