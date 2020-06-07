//
//  ViewController.swift
//  QrCodeCreationRecognition
//
//  Created by DYZ on 2020/6/7.
//  Copyright © 2020 DYZ. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController ,QRCodeImageProtocol {
    private let torchButton: UIButton = {
        let button = UIButton()
        button.setTitle("创建二维码", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitleColor(UIColor.white, for: .selected)
        button.setTitleColor(UIColor.black, for: .normal)
        button.setTitleColor(UIColor.black, for: .selected)
        button.addTarget(self, action: #selector(onclickTorchButton), for: .touchUpInside)
        return button
    }()
    private let qrCodeRecognitionButton: UIButton = {
        let button = UIButton()
        button.setTitle("识别二维码", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitleColor(UIColor.white, for: .selected)
        button.setTitleColor(UIColor.black, for: .normal)
        button.setTitleColor(UIColor.black, for: .selected)
        button.addTarget(self, action: #selector(onclickTorcQrCodeRecognitionButton), for: .touchUpInside)
        return button
    }()
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "扫描创建"
        self.view.backgroundColor = UIColor.white
        setupView()
    }
    private func setupView() {
        self.view.addSubview(torchButton)
        torchButton.frame = CGRect(x: 100, y: 200, width: 200, height: 40)
        self.view.addSubview(qrCodeRecognitionButton)
        qrCodeRecognitionButton.frame = CGRect(x: 100, y: 400, width: 200, height: 40)
    }
    // MARK: -  onclick
    @objc private func onclickTorchButton() {
        let image = setupQRCodeImage("http://www.baidu.com", headerImage: nil)
        saveImageToPhotoLibrary(image: image)
    }
    @objc private func onclickTorcQrCodeRecognitionButton() {
        let vc = QrCodeScanningViewController(animationStyle: .grid, scannerColor: .green)
        vc.scanningSucessCallback = { [weak self] code in
            print("二维码中信息 \(code) ")
        }
        vc.didReceiveErrorCallback = { [weak self] error in
            print("获取输入源错误 \(error) ")
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        self.present(nav, animated: true, completion: nil)
    }
    
    private func saveImageToPhotoLibrary(image: UIImage?) {
        guard let img = image else {
            return
        }
        // 判断权限
        switch PHPhotoLibrary.authorizationStatus() {
            case .authorized:
                self.saveImage(image: img)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { [weak self](status) in
                    if status == .authorized {
                        self?.saveImage(image: img)
                    } else {
                        print("User denied")
                    }
                }
                
            case .restricted, .denied:
                if let url = URL.init(string: UIApplication.openSettingsURLString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.openURL(url)
                }
            }
        @unknown default:
            return
        }
    }
    private func saveImage(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { [weak self](isSuccess, error) in
            DispatchQueue.main.async {
                if isSuccess {// 成功
                    print("Success")
                }
            }
        })
    }
}

