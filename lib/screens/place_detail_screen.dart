import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../models/storage_place.dart';
import '../models/storage_zone.dart';
import '../services/database_service.dart';
import 'zone_editor_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  final StoragePlace place;
  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final _db = DatabaseService();
  List<Clothing> _clothes = [];
  List<StorageZone> _zones = [];
  ui.Image? _uiImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clothes = await _db.getClothes(placeId: widget.place.id);
    final zones = await _db.getZonesForPlace(widget.place.id!);
    if (mounted) {
      setState(() {
        _clothes = clothes;
        _zones = zones;
      });
    }
    if (widget.place.imagePath != null && _uiImage == null) { _loadImage(); }
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.place.imagePath!).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _uiImage = frame.image);
  }

  Size? get _naturalSize => _uiImage != null
      ? Size(_uiImage!.width.toDouble(), _uiImage!.height.toDouble())
      : null;

  Rect _computeImageRect(Size container) {
    final ns = _naturalSize;
    if (ns == null) return Rect.zero;
    final scale = min(container.width / ns.width, container.height / ns.height);
    final rendered = Size(ns.width * scale, ns.height * scale);
    return Offset(
          (container.width - rendered.width) / 2,
          (container.height - rendered.height) / 2,
        ) &
        rendered;
  }

  Offset _toRelative(Offset pos, Rect imageRect) => Offset(
        ((pos.dx - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
        ((pos.dy - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
      );

  Future<void> _onZoneTap(Offset localPos, Rect imageRect) async {
    if (imageRect.isEmpty || !imageRect.contains(localPos)) return;
    final rel = _toRelative(localPos, imageRect);
    for (int i = _zones.length - 1; i >= 0; i--) {
      if (_zones[i].containsPoint(rel.dx, rel.dy)) {
        await _showZoneClothes(_zones[i]);
        return;
      }
    }
  }

  Future<void> _showZoneClothes(StorageZone zone) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: _ZoneClothesSheet(
          zone: zone,
          db: _db,
          placeId: widget.place.id!,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          if (p.imagePath != null)
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: '구역 설정',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ZoneEditorScreen(place: p)),
              ).then((_) => _load()),
            ),
        ],
      ),
      body: _zones.isNotEmpty ? _buildZoneView(p) : _buildListView(p),
    );
  }

  // ── 구역 맵 뷰 ─────────────────────────────────
  Widget _buildZoneView(StoragePlace p) {
    return Column(
      children: [
        _buildZoneMap(p),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('구역 (${_zones.length}개)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('총 ${_clothes.length}벌',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _zones.length,
            itemBuilder: (_, i) {
              final z = _zones[i];
              return ListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(z.colorValue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(z.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showZoneClothes(z),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildZoneMap(StoragePlace p) {
    if (_naturalSize == null) {
      return SizedBox(
        height: 250,
        child: Stack(
          children: [
            if (p.imagePath != null)
              Positioned.fill(
                child:
                    Image.file(File(p.imagePath!), fit: BoxFit.cover),
              ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerW = constraints.maxWidth;
        final ns = _naturalSize!;
        final containerH = (containerW * ns.height / ns.width)
            .clamp(200.0, MediaQuery.of(context).size.height * 0.45);
        final containerSize = Size(containerW, containerH);
        final imageRect = _computeImageRect(containerSize);

        return SizedBox(
          width: containerW,
          height: containerH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onZoneTap(d.localPosition, imageRect),
            child: Stack(
              children: [
                Container(color: Colors.black87),
                Positioned.fill(
                  child: Image.file(File(p.imagePath!),
                      fit: BoxFit.contain),
                ),
                CustomPaint(
                  size: containerSize,
                  painter: _ZoneMapPainter(
                      zones: _zones, imageRect: imageRect),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 기존 리스트 뷰 (구역 없을 때) ─────────────────
  Widget _buildListView(StoragePlace p) {
    return ListView(
      children: [
        if (p.imagePath != null)
          Image.file(File(p.imagePath!),
              height: 200, width: double.infinity, fit: BoxFit.cover),
        if (p.memo != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(p.memo!,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('보관 중인 옷 (${_clothes.length}벌)',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (_clothes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('보관된 옷이 없습니다',
                  style: TextStyle(color: Colors.grey.shade400)),
            ),
          )
        else
          ..._clothes.map(
            (c) => ListTile(
              leading: c.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(c.imagePath!),
                          width: 44, height: 44, fit: BoxFit.cover))
                  : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.checkroom,
                          color: Colors.grey.shade400)),
              title: Text(c.name),
              subtitle: Text(c.category.label,
                  style: const TextStyle(fontSize: 12)),
              trailing: c.storageNote != null
                  ? Tooltip(
                      message: c.storageNote!,
                      child: Icon(Icons.sticky_note_2,
                          size: 18, color: Colors.orange.shade300))
                  : null,
            ),
          ),
      ],
    );
  }
}

// ── 구역 맵 페인터 ────────────────────────────────
class _ZoneMapPainter extends CustomPainter {
  final List<StorageZone> zones;
  final Rect imageRect;

  _ZoneMapPainter({required this.zones, required this.imageRect});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageRect.isEmpty) return;
    for (final z in zones) {
      final rect = Rect.fromLTWH(
        imageRect.left + z.x * imageRect.width,
        imageRect.top + z.y * imageRect.height,
        z.w * imageRect.width,
        z.h * imageRect.height,
      );
      canvas.drawRect(rect, Paint()..color = Color(z.colorValue));
      canvas.drawRect(
        rect,
        Paint()
          ..color = Color(z.colorValue).withAlpha(220)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      if (rect.width > 24 && rect.height > 18) {
        final tp = TextPainter(
          text: TextSpan(
            text: z.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: rect.width - 8);
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_ZoneMapPainter old) =>
      old.zones != zones || old.imageRect != imageRect;
}

// ── 구역별 옷 바텀시트 ─────────────────────────────
class _ZoneClothesSheet extends StatefulWidget {
  final StorageZone zone;
  final DatabaseService db;
  final int placeId;

  const _ZoneClothesSheet({
    required this.zone,
    required this.db,
    required this.placeId,
  });

  @override
  State<_ZoneClothesSheet> createState() => _ZoneClothesSheetState();
}

class _ZoneClothesSheetState extends State<_ZoneClothesSheet> {
  List<Clothing> _clothes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.db.getClothes(zoneId: widget.zone.id);
    if (mounted) {
      setState(() {
        _clothes = list;
        _loading = false;
      });
    }
  }

  Future<void> _addToZone() async {
    final allPlace = await widget.db.getClothes(placeId: widget.placeId);
    final candidates = allPlace
        .where((c) => c.storageZoneId != widget.zone.id)
        .toList();

    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가할 수 있는 옷이 없습니다')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구역에 옷 추가'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (_, i) {
              final c = candidates[i];
              return ListTile(
                dense: true,
                leading: c.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(File(c.imagePath!),
                            width: 36, height: 36, fit: BoxFit.cover))
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.checkroom,
                            size: 18, color: Colors.grey.shade400)),
                title: Text(c.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(c.category.label,
                    style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.add_circle_outline, size: 20),
                onTap: () async {
                  await widget.db.updateClothing(
                    c.copyWith(storageZoneId: widget.zone.id),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromZone(Clothing c) async {
    await widget.db.updateClothing(c.copyWith(storageZoneId: null));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(widget.zone.colorValue),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.zone.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '옷 추가',
                onPressed: _addToZone,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _clothes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.checkroom,
                              size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('이 구역에 배치된 옷이 없습니다',
                              style:
                                  TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _addToZone,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('옷 배치하기'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _clothes.length,
                      itemBuilder: (_, i) {
                        final c = _clothes[i];
                        return ListTile(
                          leading: c.imagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(File(c.imagePath!),
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover))
                              : Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius:
                                          BorderRadius.circular(6)),
                                  child: Icon(Icons.checkroom,
                                      color: Colors.grey.shade400)),
                          title: Text(c.name),
                          subtitle: Text(c.category.label,
                              style: const TextStyle(fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red, size: 20),
                            tooltip: '구역에서 제거',
                            onPressed: () => _removeFromZone(c),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
