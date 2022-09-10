import 'package:flutter/material.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:provider/provider.dart';
import 'package:uber_lite/dataModels/address.dart';
import 'package:uber_lite/dataModels/place_prediction.dart';
import 'package:uber_lite/dataProvider/app_data.dart';
import 'package:uber_lite/helpers/request_helper.dart';
import 'package:uber_lite/widgets/ProgressDialog.dart';

import '../brand_colors.dart';
import '../global_variables.dart';

class PlacePredictionTile extends StatelessWidget {
  final PlacePrediction placePrediction;
  PlacePredictionTile({required this.placePrediction});

  void getPlaceDetails(String placeId, context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) =>
          ProgressDialog(status: 'Please wait...'),
      barrierDismissible: false,
    );

    String url =
        'https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeId&key=$mapKeyWithBilling';

    var response = await RequestHelper.getRequest(url);

    Navigator.pop(context);

    if (response == 'failed') {
      return;
    }

    if (response['status'] == 'OK') {
      Address thisPlace = Address(
        placeName: response['result']['name'],
        latitude: response['result']['geometry']['location']['lat'],
        longitude: response['result']['geometry']['location']['lng'],
        placeId: placeId,
        placeFormattedAddress: response['result']['formatted_address'],
      );

      Provider.of<AppData>(context, listen: false)
          .updateDestinationAddress(thisPlace);

      Navigator.pop(context, 'getDirection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      padding: EdgeInsets.all(0),
      onPressed: () {
        getPlaceDetails(placePrediction.placeId ?? '', context);
      },
      child: Container(
        child: Column(
          children: [
            SizedBox(
              height: 8,
            ),
            Row(
              children: [
                Icon(
                  OMIcons.locationOn,
                  color: BrandColors.colorDimText,
                ),
                SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placePrediction.mainText ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(
                        height: 2,
                      ),
                      Text(
                        placePrediction.secondaryText ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 12, color: BrandColors.colorDimText),
                      ),
                    ],
                  ),
                )
              ],
            ),
            SizedBox(
              height: 8,
            ),
          ],
        ),
      ),
    );
  }
}
