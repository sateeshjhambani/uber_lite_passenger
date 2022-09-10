import 'package:firebase_auth/firebase_auth.dart' as Auth;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dataModels/user.dart';

String mapKey = 'AIzaSyA1MwvmY0ylcAnivpYpeMQi9mcGIPPGQ90';
String mapKeyWithBilling = 'AIzaSyDqK54Gfh-3Y7jr_Lin_y-LSua2zz9dcxc';
final CameraPosition googlePlex = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);
Auth.User? currentFirebaseUser;
User? currentUserInfo;
