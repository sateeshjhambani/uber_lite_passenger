import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uber_lite/dataModels/direction_details.dart';
import 'package:uber_lite/dataProvider/app_data.dart';
import 'package:uber_lite/global_variables.dart';
import 'package:uber_lite/helpers/request_helper.dart';

import '../dataModels/address.dart';
import '../dataModels/user.dart' as AppUser;

class HelperMethods {
  static Future<String> findCoordinateAddress(
      Position position, context) async {
    String placeAddress = '';
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.mobile &&
        connectivityResult != ConnectivityResult.wifi) {
      return placeAddress;
    }

    String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKeyWithBilling';
    var response = await RequestHelper.getRequest(url);

    if (response != 'failed') {
      placeAddress = response['results'][0]['formatted_address'];

      Address pickupAddress = Address(
          latitude: position.latitude,
          longitude: position.longitude,
          placeName: placeAddress,
          placeFormattedAddress: placeAddress,
          placeId: '0');

      Provider.of<AppData>(context, listen: false)
          .updatePickupAddress(pickupAddress);
    }

    return placeAddress;
  }

  static Future<DirectionDetails?> getDirectionDetails(
      LatLng startPosition, LatLng endPosition) async {
    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${startPosition.latitude},${startPosition.longitude}&destination=${endPosition.latitude},${endPosition.longitude}&mode=driving&key=$mapKeyWithBilling';

    var response = await RequestHelper.getRequest(url);
    if (response == 'failed' || response['status'] != 'OK') {
      return null;
    }

    DirectionDetails directionDetails = DirectionDetails(
        distanceText: response['routes'][0]['legs'][0]['distance']['text'],
        distanceValue: response['routes'][0]['legs'][0]['distance']['value'],
        durationText: response['routes'][0]['legs'][0]['duration']['text'],
        durationValue: response['routes'][0]['legs'][0]['duration']['value'],
        encodedPoints: response['routes'][0]['overview_polyline']['points']);

    return directionDetails;
  }

  static int estimateFares(DirectionDetails details) {
    // per KM = $1,
    // per min = $0.5,
    // base fare = $3

    double baseFare = 3;
    double distanceFare = (details.distanceValue / 1000) * 1;
    double timeFare = (details.durationValue / 60) * 0.5;

    double totalFare = baseFare + distanceFare + timeFare;
    return totalFare.truncate();
  }

  static void getCurrentUserInfo() async {
    String userid = currentFirebaseUser!.uid;
    DatabaseReference userRef =
        FirebaseDatabase.instance.ref().child('users/$userid');
    userRef.once().then((event) {
      if (event.snapshot.value != null) {
        currentUserInfo = AppUser.User.fromSnapshot(event.snapshot);
      }
    });
  }

  static double generateRandomNumber(int max) {
    var randomGenerator = Random();
    int randInt = randomGenerator.nextInt(max);

    return randInt.toDouble();
  }
}
