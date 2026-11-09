enum ChestRarity { common, rare, epic, legendary }

class DailyQuest {
  final String id;
  final String title;
  final int xpReward;
  bool isCompleted;
  bool isRewardClaimed;
  ChestRarity? chestRarity;

  DailyQuest({
    required this.id,
    required this.title,
    required this.xpReward,
    this.isCompleted = false,
    this.isRewardClaimed = false,
    this.chestRarity,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'xpReward': xpReward,
        'isCompleted': isCompleted,
        'isRewardClaimed': isRewardClaimed,
        'chestRarity': chestRarity?.name,
      };

  factory DailyQuest.fromJson(Map<String, dynamic> j) => DailyQuest(
        id: j['id'] as String,
        title: j['title'] as String,
        xpReward: (j['xpReward'] as num).toInt(),
        isCompleted: j['isCompleted'] as bool? ?? false,
        isRewardClaimed: j['isRewardClaimed'] as bool? ?? false,
        chestRarity: j['chestRarity'] != null
            ? ChestRarity.values.firstWhere(
                (e) => e.name == j['chestRarity'],
                orElse: () => ChestRarity.common,
              )
            : null,
      );
}