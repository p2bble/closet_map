// 보관/꺼내기 이력 + 보관 시 체크리스트 결과 기록

enum StorageAction { stored, retrieved }

class StorageLog {
  final int? id;
  final int clothingId;
  final int? storagePlaceId;
  final StorageAction action;
  final bool? washedBefore;      // 보관 전 세탁 여부
  final bool? conditionGood;    // 상태 양호 여부
  final bool? mothballAdded;    // 방충제 넣음
  final String? memo;
  final DateTime actionAt;

  const StorageLog({
    this.id,
    required this.clothingId,
    this.storagePlaceId,
    required this.action,
    this.washedBefore,
    this.conditionGood,
    this.mothballAdded,
    this.memo,
    required this.actionAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'clothing_id': clothingId,
        'storage_place_id': storagePlaceId,
        'action': action.index,
        'washed_before': washedBefore == null ? null : (washedBefore! ? 1 : 0),
        'condition_good': conditionGood == null ? null : (conditionGood! ? 1 : 0),
        'mothball_added': mothballAdded == null ? null : (mothballAdded! ? 1 : 0),
        'memo': memo,
        'action_at': actionAt.toIso8601String(),
      };

  factory StorageLog.fromMap(Map<String, dynamic> m) => StorageLog(
        id: m['id'] as int?,
        clothingId: m['clothing_id'] as int,
        storagePlaceId: m['storage_place_id'] as int?,
        action: StorageAction.values[m['action'] as int],
        washedBefore: m['washed_before'] == null ? null : m['washed_before'] == 1,
        conditionGood: m['condition_good'] == null ? null : m['condition_good'] == 1,
        mothballAdded: m['mothball_added'] == null ? null : m['mothball_added'] == 1,
        memo: m['memo'] as String?,
        actionAt: DateTime.parse(m['action_at'] as String),
      );
}
