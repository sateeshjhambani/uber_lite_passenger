import '../dataModels/nearby_driver.dart';

class FireHelper {
  static List<NearbyDriver> nearbyDriverList = [];

  static void removeFromList(String key) {
    int index = nearbyDriverList.indexWhere((element) => element.key == key);
    if (index != -1) nearbyDriverList.removeAt(index);
  }

  static void updateNearbyLocation(NearbyDriver nearbyDriver) {
    int index = nearbyDriverList
        .indexWhere((element) => element.key == nearbyDriver.key);
    if (index != -1) {
      nearbyDriverList[index].latitude = nearbyDriver.latitude;
      nearbyDriverList[index].longitude = nearbyDriver.longitude;
    }
  }
}
