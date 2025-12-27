class Consultant {
  final String id; // UUID from auth.users
  final String name;
  final String email;
  final String specialization;

  Consultant({
    required this.id,
    required this.name,
    required this.email,
    required this.specialization,
  });

  factory Consultant.fromMap(Map<String, dynamic> map) {
    return Consultant(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      specialization: map['specialization'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'specialization': specialization,
  };

  @override
  String toString() =>
      'Consultant(id: $id, name: $name, email: $email, specialization: $specialization)';
}
