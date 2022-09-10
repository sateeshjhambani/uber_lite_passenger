import 'package:firebase_database/firebase_database.dart';

class User {
  late String fullname;
  late String phone;
  late String email;
  late String id;

  User(
      {required this.fullname,
      required this.phone,
      required this.email,
      required this.id});

  User.fromSnapshot(DataSnapshot dataSnapshot) {
    dynamic object = dataSnapshot.value!;
    id = dataSnapshot.key ?? '';
    phone = object['phone'];
    email = object['email'];
    fullname = object['fullname'];
  }
}
