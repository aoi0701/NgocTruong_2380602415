// ignore_for_file: camel_case_types

class productPost {
  productPost({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    required this.description,
    this.categoryId,
    this.categoryName,
  });

  final int? id;
  final String? name;
  final double? price;
  final String? image;
  final String? description;
  final int? categoryId;
  final String? categoryName;

  factory productPost.fromJson(Map<String, dynamic> json) {
    return productPost(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      name: json['name'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      image: json['image'] as String?,
      description: json['description'] as String?,
      categoryId: json['categoryId'] is int
          ? json['categoryId'] as int
          : int.tryParse('${json['categoryId']}'),
      categoryName: json['categoryName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'price': price,
        'image': image,
        'description': description,
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryName != null) 'categoryName': categoryName,
      };
}
