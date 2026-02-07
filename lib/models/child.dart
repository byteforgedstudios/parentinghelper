class Child {
  final int? id;
  final String name;
  final int stars;

  Child({this.id, required this.name, this.stars = 0});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'stars': stars,
      };

  factory Child.fromMap(Map<String, dynamic> map) => Child(
        id: map['id'],
        name: map['name'],
        stars: map['stars'],
      );
}
