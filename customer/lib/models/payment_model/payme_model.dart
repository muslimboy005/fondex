class PaymeModel {
  String? secretKey;
  String? paymeKey;
  String? paymeId;
  String? merchantId;
  bool? enable;
  bool? isEnabled;
  bool? isSandboxEnabled;
  bool? isWithdrawEnabled;

  PaymeModel({
    this.secretKey,
    this.paymeKey,
    this.paymeId,
    this.merchantId,
    this.enable,
    this.isEnabled,
    this.isSandboxEnabled,
    this.isWithdrawEnabled,
  });

  PaymeModel.fromJson(Map<String, dynamic> json) {
    secretKey = json['secret_key'];
    paymeKey = json['PAYME_KEY'];
    paymeId = json['PAYME_ID'];
    merchantId = json['merchant_id'];
    enable = json['enable'];
    isEnabled = json['isEnabled'];
    isSandboxEnabled = json['isSandboxEnabled'];
    isWithdrawEnabled = json['isWithdrawEnabled'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['secret_key'] = secretKey;
    data['PAYME_KEY'] = paymeKey;
    data['PAYME_ID'] = paymeId;
    data['merchant_id'] = merchantId;
    data['enable'] = enable;
    data['isEnabled'] = isEnabled;
    data['isSandboxEnabled'] = isSandboxEnabled;
    data['isWithdrawEnabled'] = isWithdrawEnabled;
    return data;
  }
}

