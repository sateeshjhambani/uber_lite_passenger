class PlacePrediction {
  String? placeId;
  String? mainText;
  String? secondaryText;

  PlacePrediction({
    this.placeId,
    this.mainText,
    this.secondaryText,
  });

  PlacePrediction.fromJson(Map<String, dynamic> json) {
    placeId = json['place_id'];
    mainText = json['structured_formatting']['main_text'];
    secondaryText = json['structured_formatting']['secondary_text'];
  }
}
