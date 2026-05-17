import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/storage_place.dart';
import '../models/storage_zone.dart';
import '../services/database_service.dart';

class ZoneEditorScreen extends StatefulWidget {
  final StoragePlace place;
  const ZoneEditorScreen({super.key, required this.place});

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  final _db = DatabaseService();
  List<StorageZone> _zones = [];
  ui.Image? _uiImage;

  Offset? _dragStart;   // relative coords (0-1)
  Offset? _dragCurrent; // relative coords (0-1)

  @override
  void initState() {
    super.initState();
    _loadZones();
    _loadImage();
  }

  Future<void> _loadZones() async {
    final zones = await _db.getZonesForPlace(widget.place.id!);
    if (mounted) setState(() => _zones = zones);
  }

  Future<void> _loadImage() async {
    if (widget.place.imagePath == null) return;
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

  void _onPanStart(DragStartDetails d, Rect imageRect) {
    if (imageRect.isEmpty || !imageRect.contains(d.localPosition)) return;
    setState(() {
      _dragStart = _toRelative(d.localPosition, imageRect);
      _dragCurrent = _dragStart;
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Rect imageRect) {
    if (_dragStart == null) return;
    setState(() => _dragCurrent = _toRelative(d.localPosition, imageRect));
  }

  Future<void> _onPanEnd(DragEndDetails _) async {
    final start = _dragStart;
    final end = _dragCurrent;
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
    if (start == null || end == null) return;

    final minX = min(start.dx, end.dx);
    final minY = min(start.dy, end.dy);
    final w = (start.dx - end.dx).abs();
    final h = (start.dy - end.dy).abs();
    if (w < 0.05 || h < 0.05) return;

    final name = await _showNameDialog(null);
    if (name == null || name.isEmpty || !mounted) return;

    final zone = StorageZone(
      storagePlaceId: widget.place.id!,
      name: name,
      x: minX,
      y: minY,
      w: w,
      h: h,
      colorValue: StorageZone.colorForIndex(_zones.length),
      sortOrder: _zones.length,
    );
    final id = await _db.insertZone(zone);
    if (mounted) setState(() => _zones.add(zone.copyWith(id: id)));
  }

  Future<void> _onTapUp(TapUpDetails d, Rect imageRect) async {
    if (imageRect.isEmpty || !imageRect.contains(d.localPosition)) return;
    final rel = _toRelative(d.localPosition, imageRect);
    for (int i = _zones.length - 1; i >= 0; i--) {
      if (_zones[i].containsPoint(rel.dx, rel.dy)) {
        await _showZoneOptions(_zones[i], i);
        return;
      }
    }
  }

  Future<String?> _showNameDialog(String? initial) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? '구역 이름 입력' : '이름 변경'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '예: 1번 서랍, 왼쪽 행거, 위 선반',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _showZoneOptions(StorageZone zone, int index) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Color(zone.colorValue),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(zone.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('이름 변경'),
              onTap: () async {
                Navigator.pop(ctx);
                final name = await _showNameDialog(zone.name);
                if (name != null && name.isNotEmpty && name != zone.name) {
                  final updated = zone.copyWith(name: name);
                  await _db.updateZone(updated);
                  if (mounted) setState(() => _zones[index] = updated);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await _db.deleteZone(zone.id!);
                if (mounted) setState(() => _zones.removeAt(index));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.place.name} 구역 설정'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('완료'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPhotoArea(),
          _buildInstructions(),
          Expanded(child: _buildZoneList()),
        ],
      ),
    );
  }

  Widget _buildPhotoArea() {
    if (widget.place.imagePath == null) {
      return Container(
        height: 160,
        color: Colors.grey.shade100,
        child: Center(
          child: Text('사진이 없습니다. 장소 편집에서 사진을 추가해주세요.',
              style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }
    if (_naturalSize == null) {
      return SizedBox(
        height: 280,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(File(widget.place.imagePath!), fit: BoxFit.cover),
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
            .clamp(200.0, MediaQuery.of(context).size.height * 0.55);
        final containerSize = Size(containerW, containerH);
        final imageRect = _computeImageRect(containerSize);

        return SizedBox(
          width: containerW,
          height: containerH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPanStart(d, imageRect),
            onPanUpdate: (d) => _onPanUpdate(d, imageRect),
            onPanEnd: _onPanEnd,
            onTapUp: (d) => _onTapUp(d, imageRect),
            child: Stack(
              children: [
                Container(color: Colors.black87),
                Positioned.fill(
                  child: Image.file(
                    File(widget.place.imagePath!),
                    fit: BoxFit.contain,
                  ),
                ),
                CustomPaint(
                  size: containerSize,
                  painter: _ZonePainter(
                    zones: _zones,
                    imageRect: imageRect,
                    dragStart: _dragStart,
                    dragCurrent: _dragCurrent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructions() {
    return ColoredBox(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.touch_app, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '사진 위를 드래그해 구역을 그리세요  •  구역을 탭하면 편집',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneList() {
    if (_zones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('아직 구역이 없습니다',
                style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 4),
            Text('사진 위를 드래그해 구역을 그려보세요',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _zones.length,
      itemBuilder: (_, i) {
        final z = _zones[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Color(z.colorValue),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          title: Text(z.name, style: const TextStyle(fontSize: 14)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () async {
              await _db.deleteZone(z.id!);
              setState(() => _zones.removeAt(i));
            },
          ),
        );
      },
    );
  }
}

class _ZonePainter extends CustomPainter {
  final List<StorageZone> zones;
  final Rect imageRect;
  final Offset? dragStart;
  final Offset? dragCurrent;

  _ZonePainter({
    required this.zones,
    required this.imageRect,
    this.dragStart,
    this.dragCurrent,
  });

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
        _drawLabel(canvas, z.name, rect);
      }
    }

    if (dragStart != null && dragCurrent != null) {
      final minX = min(dragStart!.dx, dragCurrent!.dx);
      final minY = min(dragStart!.dy, dragCurrent!.dy);
      final w = (dragStart!.dx - dragCurrent!.dx).abs();
      final h = (dragStart!.dy - dragCurrent!.dy).abs();
      final rect = Rect.fromLTWH(
        imageRect.left + minX * imageRect.width,
        imageRect.top + minY * imageRect.height,
        w * imageRect.width,
        h * imageRect.height,
      );
      canvas.drawRect(rect, Paint()..color = Colors.white.withAlpha(60));
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withAlpha(200)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Rect rect) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width - 8);
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ZonePainter old) =>
      old.zones != zones ||
      old.imageRect != imageRect ||
      old.dragStart != dragStart ||
      old.dragCurrent != dragCurrent;
}
