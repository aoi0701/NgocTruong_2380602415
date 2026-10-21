class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
  });

  final int id;
  final String name;
  final String description;
  final double price;

  factory Product.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    final price = json['price'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        description is! String ||
        price is! num ||
        !price.isFinite ||
        price < 0) {
      throw const FormatException(
        'Sản phẩm cần id, name, description và price dạng số không âm.',
      );
    }
    return Product(
      id: id,
      name: name,
      description: description,
      price: price.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
  };
}
