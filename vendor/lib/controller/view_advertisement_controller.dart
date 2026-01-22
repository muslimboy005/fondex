import 'package:get/get.dart';
import 'package:vendor/models/advertisement_model.dart';

class ViewAdvertisementController extends GetxController {
  @override
  void onInit() {
    getArgument();
    // TODO: implement onInit
    super.onInit();
  }

  Rx<AdvertisementModel> advertisementModel = AdvertisementModel().obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      advertisementModel.value = argumentData['advsModel'];
    }
  }
}
