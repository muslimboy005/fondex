import 'package:driver/constant/constant.dart';
import 'package:driver/models/language_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/preferences.dart';
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
          // Filter only Russian and Uzbek languages
          if (languageModel.slug == 'ru' || languageModel.slug == 'uz') {
            languageList.add(languageModel);
          }
        }

        if (Preferences.getString(Preferences.languageCodeKey).toString().isNotEmpty) {
          LanguageModel pref = Constant.getLanguage();
          // If saved language is not Russian or Uzbek, default to Uzbek
          if (pref.slug != 'ru' && pref.slug != 'uz') {
            // Find Uzbek language or default to first available
            for (var element in languageList) {
              if (element.slug == 'uz') {
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
              }
            }
          }
        } else {
          // Default to Uzbek if no language is saved
          for (var element in languageList) {
            if (element.slug == 'uz') {
              selectedLanguage.value = element;
              break;
            }
          }
          if (selectedLanguage.value.slug == null && languageList.isNotEmpty) {
            selectedLanguage.value = languageList.first;
          }
        }
      }
    });

    isLoading.value = false;
  }
}
