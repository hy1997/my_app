class Category {
  final int id;
  final int userId;
  final String name;
  final String icon;
  final String type;
  final int orderIndex;
  final String? description;
  final bool? isFixed;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.type,
    required this.orderIndex,
    this.description,
    this.isFixed,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'] ?? '📝',
      type: json['type'] ?? 'expense',
      orderIndex: json['orderIndex'] ?? 0,
      description: json['description'],
      isFixed: json['isFixed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'icon': icon,
      'type': type,
      'orderIndex': orderIndex,
      'description': description,
      'isFixed': isFixed,
    };
  }
} 