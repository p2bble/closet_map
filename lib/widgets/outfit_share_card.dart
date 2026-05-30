import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing.dart';
import '../models/outfit.dart';

class OutfitShareCard extends StatelessWidget {
  final Outfit outfit;
  final List<Clothing> clothes;

  const OutfitShareCard({
    super.key,
    required this.outfit,
    required this.clothes,
  });

  @override
  Widget build(BuildContext context) {
    final totalPrice =
        clothes.fold<double>(0, (sum, c) => sum + (c.purchasePrice ?? 0));
    final brands = clothes
        .where((c) => c.brand != null && c.brand!.isNotEmpty)
        .map((c) => c.brand!)
        .toSet()
        .toList();
    final cpwList = clothes
        .where((c) => c.costPerWear != null)
        .map((c) => c.costPerWear!)
        .toList();
    final avgCpw = cpwList.isEmpty
        ? null
        : cpwList.reduce((a, b) => a + b) / cpwList.length;

    final dt = outfit.createdAt;
    final dateStr =
        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

    return Container(
      width: 360,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(dateStr),
          _buildImageGrid(),
          _buildInfoSection(brands, totalPrice, avgCpw),
        ],
      ),
    );
  }

  Widget _buildHeader(String dateStr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5C8FFF), Color(0xFF3B6CE0)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                outfit.name ?? 'OOTD',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const Text(
            '옷장지도',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    final imgs = clothes.where((c) => c.imagePath != null).take(6).toList();

    if (imgs.isEmpty) {
      return Container(
        height: 120,
        color: const Color(0xFFF5F5F5),
        child:
            const Icon(Icons.checkroom, size: 48, color: Color(0xFFDDDDDD)),
      );
    }

    if (imgs.length == 1) {
      return SizedBox(
        height: 240,
        child: Image.file(
          File(imgs[0].imagePath!),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }

    if (imgs.length == 2) {
      return Row(
        children: imgs
            .map((c) => Expanded(
                  child: SizedBox(
                    height: 180,
                    child: Image.file(File(c.imagePath!), fit: BoxFit.cover),
                  ),
                ))
            .toList(),
      );
    }

    // 3~6개: 3열 그리드
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: imgs.length,
      itemBuilder: (_, i) =>
          Image.file(File(imgs[i].imagePath!), fit: BoxFit.cover),
    );
  }

  Widget _buildInfoSection(
      List<String> brands, double totalPrice, double? avgCpw) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...clothes.take(5).map(_itemRow),
          if (clothes.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '+ ${clothes.length - 5}개 더',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
            ),
          if (brands.isNotEmpty || totalPrice > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
            if (brands.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: brands.map(_brandChip).toList(),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (totalPrice > 0) ...[
                  _statChip('총 구매가', '${_formatPrice(totalPrice)}원'),
                  const SizedBox(width: 8),
                ],
                if (avgCpw != null)
                  _statChip('평균 CPW', '${_formatPrice(avgCpw)}원/회'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(Clothing c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: c.color != null
                  ? Color(c.color!.colorValue)
                  : const Color(0xFFDDDDDD),
              shape: BoxShape.circle,
              border:
                  Border.all(color: const Color(0xFFEEEEEE), width: 0.8),
            ),
          ),
          Expanded(
            child: Text(
              c.name,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (c.brand != null && c.brand!.isNotEmpty)
            Text(
              c.brand!,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF9E9E9E)),
            ),
        ],
      ),
    );
  }

  Widget _brandChip(String brand) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        brand,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF3B6CE0),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 1),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000) {
      final man = (price / 10000).floor();
      final rem = (price % 10000).round();
      return rem == 0 ? '$man만' : '$man만 $rem';
    }
    return price.round().toString();
  }
}
