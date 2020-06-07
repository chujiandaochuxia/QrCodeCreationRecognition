# QrCodeCreationRecognition
![image](https://github.com/yiruchujian/QrCodeCreationRecognition/blob/master/WechatIMG4.jpeg)
使用方式 如果只需要扫码功能 将QrCodeScanningViewController控制器拖进项目即可
如果需要 创建二维码 保存到相册 将QRCodeImageProtocol 拖进项目 遵守协议 调用 setupQRCodeImage(_ text: String, headerImage: UIImage?)
即可生成
