import 'package:customer/constant/constant.dart';
import 'package:customer/models/referral_model.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class ReferFriendController extends GetxController {
  Rx<ReferralModel> referralModel = ReferralModel().obs;

  RxBool isLoading = true.obs;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    ReferralModel? value = await FireStoreUtils.getReferralUserBy();
    if (value != null && (value.referralCode ?? '').isNotEmpty) {
      referralModel.value = value;
    } else {
      // Foydalanuvchida referral yozuvi yo'q bo'lsa, yangi kod bilan yaratamiz
      final newReferral = ReferralModel(
        id: FireStoreUtils.getCurrentUid(),
        referralBy: '',
        referralCode: Constant.getReferralCode(),
      );
      await FireStoreUtils.referralAdd(newReferral);
      referralModel.value = newReferral;
    }
    isLoading.value = false;
  }

  /// Ulashish/nusxalash uchun ishlatiladigan kod (null emas)
  String get displayReferralCode => referralModel.value.referralCode ?? '';
}
