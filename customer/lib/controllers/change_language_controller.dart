import 'package:customer/constant/constant.dart';
import 'package:customer/models/language_model.dart';
import '../service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:get/get.dart';

import '../constant/collection_name.dart';

class ChangeLanguageController extends GetxController {
  Rx<LanguageModel> selectedLanguage = LanguageModel().obs;
  RxList<LanguageModel> languageList = <LanguageModel>[].obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getLanguage();

    super.onInit();
  }

  Future<void> getLanguage() async {
    await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("languages").get().then((event) {
      if (event.exists) {
        List languageListTemp = event.data()!["list"];
        for (var element in languageListTemp) {
          LanguageModel languageModel = LanguageModel.fromJson(element);
          // Filter out English language - only show Russian and Uzbek
          if (languageModel.slug != 'en' && languageModel.slug != 'english') {
            languageList.add(languageModel);
          }
        }

        if (Preferences.getString(Preferences.languageCodeKey).toString().isNotEmpty) {
          LanguageModel pref = Constant.getLanguage();
          // If saved language is English, default to Russian
          if (pref.slug == 'en' || pref.slug == 'english') {
            // Find Russian language or default to first available
            for (var element in languageList) {
              if (element.slug == 'ru') {
                selectedLanguage.value = element;
                break;
              }
            }
            if (selectedLanguage.value.slug == null && languageList.isNotEmpty) {
              selectedLanguage.value = languageList.first;
            }
          } else {
            for (var element in languageList) {
              if (element.slug == pref.slug) {
                selectedLanguage.value = element;
                break;
              }
            }
          }
        }
      }
    });

    isLoading.value = false;
  }
}
