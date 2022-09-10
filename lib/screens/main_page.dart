import 'dart:async';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:provider/provider.dart';
import 'package:uber_lite/brand_colors.dart';
import 'package:uber_lite/dataModels/direction_details.dart';
import 'package:uber_lite/dataModels/nearby_driver.dart';
import 'package:uber_lite/dataProvider/app_data.dart';
import 'package:uber_lite/helpers/fire_helper.dart';
import 'package:uber_lite/helpers/helper_methods.dart';
import 'package:uber_lite/screens/search_page.dart';
import 'package:uber_lite/styles/styles.dart';
import 'package:uber_lite/widgets/TaxiButton.dart';

import '../global_variables.dart';
import '../widgets/BrandDivider.dart';
import '../widgets/ProgressDialog.dart';

class MainPage extends StatefulWidget {
  static const String id = 'main_page';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController mapController;

  double mapBottomPadding = 0;
  double searchSheetHeight = Platform.isIOS ? 300 : 275;
  double rideDetailsSheetHeight = 0; // Platform.isIOS ? 260 : 235;
  double rideRequestingSheetHeight = 0; // Platform.isIOS ? 220 : 195;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  late Position currentPosition;

  List<LatLng> polylineCoordinates = [];
  Set<Polyline> _polylines = {};

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  BitmapDescriptor? nearbyIcon;

  DirectionDetails? tripDirectionDetails;

  bool drawerCanOpen = true;

  late DatabaseReference rideRef;

  bool nearbyDriverKeysLoaded = false;

  void setupPositionLocator() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
    currentPosition = position;

    LatLng pos = LatLng(position.latitude, position.longitude);
    CameraPosition cp = CameraPosition(target: pos, zoom: 14);
    mapController.animateCamera(CameraUpdate.newCameraPosition(cp));

    await HelperMethods.findCoordinateAddress(position, context);
    startGeoFireListener();
  }

  Future<void> getDirection() async {
    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;
    var destination =
        Provider.of<AppData>(context, listen: false).destinationAddress;

    var pickupLatLng = LatLng(pickup != null ? pickup.latitude : 0,
        pickup != null ? pickup.longitude : 0);
    var destinationLatLng = LatLng(
        destination != null ? destination.latitude : 0,
        destination != null ? destination.longitude : 0);

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) =>
          ProgressDialog(status: 'Please wait...'),
    );

    var thisDetails = await HelperMethods.getDirectionDetails(
        pickupLatLng, destinationLatLng);

    setState(() {
      tripDirectionDetails = thisDetails;
    });

    Navigator.pop(context);

    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> results =
        polylinePoints.decodePolyline(thisDetails?.encodedPoints ?? "");

    polylineCoordinates.clear();
    if (results.isNotEmpty) {
      for (var points in results) {
        polylineCoordinates.add(LatLng(points.latitude, points.longitude));
      }

      _polylines.clear();
      setState(() {
        Polyline polyLine = Polyline(
          polylineId: const PolylineId('polyId'),
          color: Color.fromARGB(255, 95, 109, 237),
          points: polylineCoordinates,
          jointType: JointType.round,
          width: 4,
          startCap: Cap.roundCap,
          geodesic: true,
        );

        _polylines.add(polyLine);
      });

      LatLngBounds bounds;
      if (pickupLatLng.latitude > destinationLatLng.latitude &&
          pickupLatLng.longitude > destinationLatLng.longitude) {
        bounds =
            LatLngBounds(southwest: destinationLatLng, northeast: pickupLatLng);
      } else if (pickupLatLng.longitude > destinationLatLng.longitude) {
        bounds = LatLngBounds(
            southwest:
                LatLng(pickupLatLng.latitude, destinationLatLng.longitude),
            northeast:
                LatLng(destinationLatLng.latitude, pickupLatLng.longitude));
      } else if (pickupLatLng.latitude > destinationLatLng.latitude) {
        bounds = LatLngBounds(
            southwest:
                LatLng(destinationLatLng.latitude, pickupLatLng.longitude),
            northeast:
                LatLng(pickupLatLng.latitude, destinationLatLng.longitude));
      } else {
        bounds =
            LatLngBounds(southwest: pickupLatLng, northeast: destinationLatLng);
      }

      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60),
      );

      Marker pickupMarker = Marker(
          markerId: MarkerId('pickup'),
          position: pickupLatLng,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow:
              InfoWindow(title: pickup?.placeName, snippet: 'My Location'));

      Marker destinationMarker = Marker(
          markerId: MarkerId('destination'),
          position: destinationLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
              title: destination?.placeName, snippet: 'Destination'));

      setState(() {
        _markers.add(pickupMarker);
        _markers.add(destinationMarker);
      });

      Circle pickupCircle = Circle(
          circleId: CircleId('pickup'),
          strokeColor: Colors.green,
          strokeWidth: 3,
          radius: 12,
          center: pickupLatLng,
          fillColor: BrandColors.colorGreen);

      Circle destinationCircle = Circle(
          circleId: CircleId('destination'),
          strokeColor: BrandColors.colorAccentPurple,
          strokeWidth: 3,
          radius: 12,
          center: destinationLatLng,
          fillColor: BrandColors.colorBlue);

      setState(() {
        _circles.add(pickupCircle);
        _circles.add(destinationCircle);
      });
    }
  }

  void showDetailSheet() async {
    await getDirection();

    setState(() {
      searchSheetHeight = 0;
      rideDetailsSheetHeight = Platform.isIOS ? 260 : 235;
      mapBottomPadding = Platform.isIOS ? 230 : 240;
      drawerCanOpen = false;
    });
  }

  void resetApp() {
    setState(() {
      polylineCoordinates.clear();
      _polylines.clear();
      _markers.clear();
      _circles.clear();
      rideDetailsSheetHeight = 0;
      rideRequestingSheetHeight = 0;
      searchSheetHeight = Platform.isIOS ? 300 : 275;
      mapBottomPadding = Platform.isIOS ? 270 : 280;
      drawerCanOpen = true;
      setupPositionLocator();
    });
  }

  void showRideRequestingSheet() {
    setState(() {
      rideDetailsSheetHeight = 0;
      rideRequestingSheetHeight = Platform.isIOS ? 220 : 195;
      mapBottomPadding = Platform.isIOS ? 190 : 200;

      drawerCanOpen = true;
    });

    createRideRequest();
  }

  void createRideRequest() {
    rideRef = FirebaseDatabase.instance.ref().child('rideRequest').push();

    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;
    var destination =
        Provider.of<AppData>(context, listen: false).destinationAddress;

    Map pickupMap = {
      'latitude': pickup != null ? pickup.latitude.toString() : '',
      'longitude': pickup != null ? pickup.longitude.toString() : '',
    };

    Map destinationMap = {
      'latitude': destination != null ? destination.latitude.toString() : '',
      'longitude': destination != null ? destination.longitude.toString() : '',
    };

    Map rideMap = {
      'created_at': DateTime.now().toString(),
      'rider_name': currentUserInfo != null ? currentUserInfo!.fullname : '',
      'rider_phone': currentUserInfo != null ? currentUserInfo!.phone : '',
      'pickup_address': pickup != null ? pickup.placeName : '',
      'destination_address': destination != null ? destination.placeName : '',
      'location': pickupMap,
      'destination': destinationMap,
      'payment_method': 'card',
      'driver_id': 'waiting'
    };

    rideRef.set(rideMap);
  }

  void cancelRequest() {
    rideRef.remove();
  }

  void startGeoFireListener() {
    Geofire.initialize('driversAvailable');
    Geofire.queryAtLocation(
            currentPosition.latitude, currentPosition.longitude, 20)
        ?.listen((map) {
      if (map != null) {
        var callBack = map['callBack'];
        print(map);
        switch (callBack) {
          case Geofire.onKeyEntered:
            NearbyDriver nearbyDriver = NearbyDriver(
                key: map['key'],
                latitude: map['latitude'],
                longitude: map['longitude']);
            FireHelper.nearbyDriverList.add(nearbyDriver);

            if (nearbyDriverKeysLoaded) {
              updateDriversOnMap();
            }
            break;

          case Geofire.onKeyExited:
            FireHelper.removeFromList(map['key']);
            updateDriversOnMap();
            break;

          case Geofire.onKeyMoved:
            NearbyDriver nearbyDriver = NearbyDriver(
                key: map['key'],
                latitude: map['latitude'],
                longitude: map['longitude']);
            FireHelper.updateNearbyLocation(nearbyDriver);
            updateDriversOnMap();
            break;

          case Geofire.onGeoQueryReady:
            nearbyDriverKeysLoaded = true;
            updateDriversOnMap();
            break;
        }
      }

      setState(() {});
    });
  }

  void updateDriversOnMap() {
    setState(() {
      _markers.clear();
    });

    Set<Marker> tempMarkers = <Marker>{};
    for (NearbyDriver driver in FireHelper.nearbyDriverList) {
      LatLng driverPosition = LatLng(driver.latitude, driver.longitude);
      tempMarkers.add(
        Marker(
            markerId: MarkerId('driver${driver.key}'),
            position: driverPosition,
            icon: nearbyIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
            rotation: HelperMethods.generateRandomNumber(360)),
      );
    }

    setState(() {
      _markers = tempMarkers;
    });
  }

  void createMarker() {
    if (nearbyIcon == null) {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(
        context,
        size: Size(2, 2),
      );
      BitmapDescriptor.fromAssetImage(
        imageConfiguration,
        Platform.isIOS ? 'images/car_ios' : 'images/car_android',
      ).then((icon) {
        nearbyIcon = icon;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    HelperMethods.getCurrentUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    createMarker();

    return Scaffold(
      key: _scaffoldKey,
      drawer: Container(
        width: 250,
        color: Colors.white,
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.all(0),
            children: [
              Container(
                color: Colors.white,
                height: 160,
                child: DrawerHeader(
                  child: Row(
                    children: [
                      Image.asset(
                        'images/user_icon.png',
                        height: 60,
                        width: 60,
                      ),
                      SizedBox(
                        width: 15,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'My Name',
                            style: TextStyle(
                                fontSize: 20, fontFamily: 'Brand-Bold'),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Text('View Profile')
                        ],
                      )
                    ],
                  ),
                  decoration: BoxDecoration(color: Colors.white),
                ),
              ),
              BrandDivider(),
              SizedBox(
                height: 10,
              ),
              ListTile(
                leading: Icon(OMIcons.cardGiftcard),
                title: Text(
                  'Free Rides',
                  style: kDrawerItemStyle,
                ),
              ),
              ListTile(
                leading: Icon(OMIcons.creditCard),
                title: Text(
                  'Payments',
                  style: kDrawerItemStyle,
                ),
              ),
              ListTile(
                leading: Icon(OMIcons.history),
                title: Text(
                  'Ride History',
                  style: kDrawerItemStyle,
                ),
              ),
              ListTile(
                leading: Icon(OMIcons.contactSupport),
                title: Text(
                  'Support',
                  style: kDrawerItemStyle,
                ),
              ),
              ListTile(
                leading: Icon(OMIcons.info),
                title: Text(
                  'About',
                  style: kDrawerItemStyle,
                ),
              )
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            padding: EdgeInsets.only(bottom: mapBottomPadding),
            initialCameraPosition: googlePlex,
            mapType: MapType.normal,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            polylines: _polylines,
            markers: _markers,
            circles: _circles,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              mapController = controller;
              setState(() {
                mapBottomPadding = Platform.isIOS ? 270 : 280;
              });

              setupPositionLocator();
            },
          ),

          Positioned(
            top: 50,
            left: 15,
            child: GestureDetector(
              onTap: () {
                drawerCanOpen
                    ? _scaffoldKey.currentState?.openDrawer()
                    : resetApp();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        spreadRadius: 0.5,
                        offset: Offset(0.7, 0.7))
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: Icon(
                    drawerCanOpen ? Icons.menu : Icons.arrow_back,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),

          // Search Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeIn,
              child: Container(
                height: searchSheetHeight,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        spreadRadius: 0.5,
                        offset: Offset(0.7, 0.7))
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        'Nice to see you!',
                        style: TextStyle(fontSize: 10),
                      ),
                      const Text(
                        'Where are you going',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Brand-Bold',
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      GestureDetector(
                        onTap: () async {
                          var response = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchPage(),
                            ),
                          );

                          if (response == 'getDirection') {
                            showDetailSheet();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                  offset: Offset(0.7, 0.7)),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.search,
                                  color: Colors.blueAccent,
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Text('Search Destination'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 22,
                      ),
                      Row(
                        children: [
                          const Icon(
                            OMIcons.home,
                            color: BrandColors.colorDimText,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Add Home'),
                              SizedBox(
                                height: 3,
                              ),
                              Text(
                                'Your residential address',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: BrandColors.colorDimText),
                              )
                            ],
                          )
                        ],
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      BrandDivider(),
                      const SizedBox(
                        height: 16,
                      ),
                      Row(
                        children: [
                          const Icon(
                            OMIcons.workOutline,
                            color: BrandColors.colorDimText,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Add Work'),
                              SizedBox(
                                height: 3,
                              ),
                              Text(
                                'Your office address',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: BrandColors.colorDimText),
                              )
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // RideDetails Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeIn,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 0.5,
                      offset: Offset(0.7, 0.7),
                    ),
                  ],
                ),
                height: rideDetailsSheetHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: BrandColors.colorAccent1,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Image.asset(
                                'images/taxi.png',
                                height: 70,
                                width: 70,
                              ),
                              const SizedBox(
                                width: 16,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Taxi',
                                    style: TextStyle(
                                        fontSize: 18, fontFamily: 'Brand-Bold'),
                                  ),
                                  Text(
                                    tripDirectionDetails != null
                                        ? tripDirectionDetails!.distanceText
                                        : '',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: BrandColors.colorTextLight),
                                  )
                                ],
                              ),
                              Expanded(
                                child: Container(),
                              ),
                              Text(
                                tripDirectionDetails != null
                                    ? '\$${HelperMethods.estimateFares(tripDirectionDetails!).toString()}'
                                    : '',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Brand-Bold',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 22,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: const [
                            Icon(
                              FontAwesomeIcons.moneyBill1,
                              size: 18,
                              color: BrandColors.colorTextLight,
                            ),
                            SizedBox(
                              width: 16,
                            ),
                            Text('Cash'),
                            SizedBox(
                              width: 5,
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: BrandColors.colorTextLight,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 22,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: TaxiButton(
                          title: 'Request Cab',
                          color: BrandColors.colorGreen,
                          onPressed: () {
                            showRideRequestingSheet();
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Request Ride Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSize(
              duration: Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 0.5,
                      offset: Offset(0.7, 0.7),
                    ),
                  ],
                ),
                height: rideRequestingSheetHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 10,
                      ),
                      SpinKitThreeBounce(
                        color: BrandColors.colorTextSemiLight,
                        size: 30,
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        'Requesting a Ride',
                        style: TextStyle(
                            color: BrandColors.colorTextSemiLight,
                            fontSize: 22,
                            fontFamily: 'Brand-Bold'),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      GestureDetector(
                        onTap: () {
                          cancelRequest();
                          resetApp();
                        },
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                                width: 1.0,
                                color: BrandColors.colorLightGrayFair),
                          ),
                          child: Icon(Icons.close, size: 25),
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: double.infinity,
                        child: Text(
                          'Cancel Ride',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
