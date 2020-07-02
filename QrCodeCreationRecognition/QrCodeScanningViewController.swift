//
//  QrCodeScanningViewController.swift
//  QrCodeCreationRecognition
//
//  Created by DYZ on 2020/6/7.
//  Copyright © 2020 DYZ. All rights reserved.
//

import UIKit
import AVFoundation

public enum ScanAnimationStyle {
    /// 单线扫描样式
    case `default`
    /// 网格扫描样式
    case grid
}
public enum CornerLocation {
    /// 默认与边框线同中心点
    case `default`
    /// 在边框线内部
    case inside
    /// 在边框线外部
    case outside
}

class QrCodeScanningViewController:  UIViewController {
    public var scanningSucessCallback:((_ code: String) -> ())?
    public var didReceiveErrorCallback:((_ error: Error) -> ())?
    /// 动画样式
    public let animationStyle: ScanAnimationStyle
    /// 边框 颜色
    public let scannerColor: UIColor
    /// 边框内扫描动画图片
    private lazy var animationImage: UIImage = UIImage(named: "ScanLine") ?? UIImage()
    
    private let torchButton: UIButton = {
        let button = UIButton()
        button.setTitle("打开手电", for: .normal)
        button.setTitle("关闭手电", for: .selected)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitleColor(UIColor.white, for: .selected)
        button.addTarget(self, action: #selector(onclickTorchButton), for: .touchUpInside)
        return button
    }()
    /// `AVCaptureMetadataOutput` metadata object types.
    private var metadata = [AVMetadataObject.ObjectType.qr, AVMetadataObject.ObjectType.ean13, AVMetadataObject.ObjectType.ean8, AVMetadataObject.ObjectType.code128]
//                    [AVMetadataObject.ObjectType.aztec,
//                    AVMetadataObject.ObjectType.code128,
//                    AVMetadataObject.ObjectType.code39,
//                    AVMetadataObject.ObjectType.code39Mod43,
//                    AVMetadataObject.ObjectType.code93,
//                    AVMetadataObject.ObjectType.dataMatrix,
//                    AVMetadataObject.ObjectType.ean13,
//                    AVMetadataObject.ObjectType.ean8,
//                    AVMetadataObject.ObjectType.face,
//                    AVMetadataObject.ObjectType.interleaved2of5,
//                    AVMetadataObject.ObjectType.itf14,
//                    AVMetadataObject.ObjectType.pdf417,
//                    AVMetadataObject.ObjectType.qr,
//                    AVMetadataObject.ObjectType.upce
//                   ]
    /// 捕获会话
    private var captureSession = AVCaptureSession()
    /// 获取手机摄像头
    private var captureDevice = AVCaptureDevice.default(for:  .video)
    /// 视频预览层
    private var videoPreviewLayer:  AVCaptureVideoPreviewLayer?
    /// 黑色遮罩
    private let bgview: UIView = {
        let view = UIView(frame:  CGRect(x: 0, y: DY_ScreenInfo.navigationHeight, width: DY_ScreenInfo.Width, height:  DY_ScreenInfo.Height-DY_ScreenInfo.navigationHeight))
        return view
    }()
    /// 扫描View
    private let scanView: ScanView = {
        let view = ScanView(frame:  CGRect(x: 0, y: DY_ScreenInfo.navigationHeight, width: DY_ScreenInfo.Width, height:  DY_ScreenInfo.Height-DY_ScreenInfo.navigationHeight))
        return view
    }()
    
    init(animationStyle: ScanAnimationStyle = .default,scannerColor: UIColor = .red) {
        self.animationStyle = animationStyle
        self.scannerColor = scannerColor
        super.init(nibName:  nil, bundle:  nil)
        if animationStyle == .default {
           self.animationImage = UIImage(named: "ScanLine") ?? UIImage()
        }else{
           self.animationImage = UIImage(named: "ScanNet") ?? UIImage()
        }
    }
    required init?(coder:  NSCoder) {
        fatalError("init(coder: ) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "扫一扫"
        self.navigationItem.leftBarButtonItem =  UIBarButtonItem.init(title: "返回", style: .plain, target: self, action: #selector(onclcikBack))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "相册", style: .plain, target: self, action: #selector(onclickPhotoAlbum))
        setupView()
    }
    override func viewDidAppear(_ animated:  Bool) {
        super.viewDidAppear(animated)
        scanView.startAnimation()
    }
    override func viewDidDisappear(_ animated:  Bool) {
        super.viewDidDisappear(animated)
        scanView.stopAnimation()
    }
    private func setupView() {
        view.backgroundColor = .white
        bgview.backgroundColor = .black
        view.addSubview(bgview)
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session:  captureSession)
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        videoPreviewLayer?.frame = bgview.layer.bounds
        guard let videoPreviewLayer = videoPreviewLayer else {
            return
        }
        ///视频只是个layer必须有view 来承载才能展示
        bgview.layer.insertSublayer(videoPreviewLayer, at:  0)
        scanView.scanAnimationImage = animationImage
        scanView.scanAnimationStyle = animationStyle
        scanView.cornerColor = scannerColor
        view.addSubview(scanView)
        setupCamera()
        setupTorchButton()
        startCapturing()
    }
    private func setupTorchButton() {
        self.view.addSubview(torchButton)
        torchButton.center.x = self.view.center.x - 50
        torchButton.center.y = self.view.center.y - 200
        torchButton.frame.size = CGSize(width: 100, height: 50)
    }
    /// 设置相机
    private func setupCamera() {
        setupSessionInput()
        setupSessionOutput()
    }
    /// 捕获设备输入流
    private  func setupSessionInput() {
        guard let device = captureDevice else {
            return
        }
        do {
            //获取手机摄像头
            let newInput = try AVCaptureDeviceInput(device:  device)
            captureSession.beginConfiguration()
            if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
                captureSession.removeInput(currentInput)
            }
            /////设置高质量采集
            captureSession.sessionPreset = AVCaptureSession.Preset.high
            captureSession.addInput(newInput)
            captureSession.commitConfiguration()
        }catch{
            didReceiveErrorCallback?(error)
        }
    }
    /// 捕获元数据输出流
    private func setupSessionOutput() {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue:  DispatchQueue.main)
        captureSession.addOutput(videoDataOutput)
        let output = AVCaptureMetadataOutput()
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue:  DispatchQueue.main)
        for type in metadata {
            if !output.availableMetadataObjectTypes.contains(type){
                return
            }
        }
        output.metadataObjectTypes = metadata
        videoPreviewLayer?.session = captureSession
        view.setNeedsLayout()
    }
    /// 开始扫描
    func startCapturing() {
        captureSession.startRunning()
    }
    /// 停止扫描
    func stopCapturing() {
        captureSession.stopRunning()
    }
    // MARK: -  onclick
    @objc private func onclickPhotoAlbum() {
        presentAlertController()
    }
    @objc private func onclcikBack() {
        dismissVC()
    }
    
    @objc private func onclickTorchButton() {
        torchButton.isSelected = !torchButton.isSelected
        //呼叫控制硬件
        do {
            try captureDevice?.lockForConfiguration()
            if captureDevice?.torchMode == .on {
                captureDevice?.torchMode = .off
            }else {
                captureDevice?.torchMode = .on
            }
            captureDevice?.unlockForConfiguration()
        } catch {
            
        }
    }
    private func dismissVC() {
        self.dismiss(animated: true, completion: { () -> Void in
        })
    }
    
}

extension QrCodeScanningViewController: UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    func presentAlertController() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cancelBtn = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        let selectPhotos = UIAlertAction(title: "选择相册", style: .default, handler: { (action:UIAlertAction) -> Void in //调用相册功能,打开相册
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            picker.modalPresentationStyle = .fullScreen
            self.present(picker, animated: true, completion: nil)
        })
        actionSheet.addAction(cancelBtn)
        actionSheet.addAction(selectPhotos)
        self.present(actionSheet, animated: true, completion: nil)
    }
    // MARK: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: { () -> Void in
        })
        let type: String = (info[UIImagePickerController.InfoKey.mediaType] as! String)
        if type == "public.image" {
            let image:UIImage = info[UIImagePickerController.InfoKey.editedImage] as! UIImage
            //创建图片扫描仪
            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            //获取到二维码数据
            let objects = detector?.features(in: CIImage.init(cgImage: image.cgImage!))
            if let object = objects?.first as? CIQRCodeFeature {
                scanningSucessCallback?(object.messageString ?? "")
                dismissVC()
            }else {
                print("当前图片没有识别到二维码")
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: { () -> Void in
        })
    }
}
// MARK:  - AVCaptureMetadataOutputObjectsDelegate
extension QrCodeScanningViewController:  AVCaptureMetadataOutputObjectsDelegate {
    //扫描到二维码时调用
    func metadataOutput(_ output:  AVCaptureMetadataOutput, didOutput metadataObjects:  [AVMetadataObject], from connection:  AVCaptureConnection) {
        stopCapturing()
//        也有可能是多个二维码数据
//        if metadataObjects.count > 0 {
//            let metadata: AVMetadataMachineReadableCodeObject = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
//        }
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }
        scanningSucessCallback?(object.stringValue ?? "")
        dismissVC()
    }
}
// MARK:  - AVCaptureVideoDataOutputSampleBufferDelegate
extension QrCodeScanningViewController:  AVCaptureVideoDataOutputSampleBufferDelegate {
    ///获取到的视频帧
    func captureOutput(_ output:  AVCaptureOutput, didOutput sampleBuffer:  CMSampleBuffer, from connection:  AVCaptureConnection) {
        let metadataDict = CMCopyDictionaryOfAttachments(allocator:  nil,target:  sampleBuffer, attachmentMode:  kCMAttachmentMode_ShouldPropagate)
        guard let metadata = metadataDict as? [String: Any],
            let exifMetadata = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
            let brightnessValue = exifMetadata[kCGImagePropertyExifBrightnessValue as String] as? Double else{
                return
        }
        // 判断光线强弱
//        if brightnessValue < -1.0 {
//            flashBtn.isHidden = false
//        }else{
//            if torchMode == .on{
//                flashBtn.isHidden = false
//            }else{
//                flashBtn.isHidden = true
//            }
//        }
    }
}
// MARK: -  ScanView 设置 扫描框
class ScanView:  UIView {
    /// 扫描动画图片
    lazy var scanAnimationImage = UIImage()
    /// 扫描样式
    public lazy var scanAnimationStyle = ScanAnimationStyle.default
    /// 边角位置，默认与边框线同中心点
    public lazy var cornerLocation = CornerLocation.default
    /// 边框线颜色，默认白色
    public var borderColor = UIColor.white
    /// 边框线宽度，默认0.2
    public lazy var borderLineWidth: CGFloat = 0.2
    /// 边角颜色，默认红色
    public lazy var cornerColor = UIColor.red
    /// 边角宽度，默认2.0
    public lazy var cornerWidth: CGFloat = 2.0
    /// 扫描区周边颜色的 alpha 值，默认 0.6
    public lazy var backgroundAlpha: CGFloat = 0.6
    /// 扫描区的宽度跟屏幕宽度的比
    public lazy var scanBorderWidthRadio: CGFloat = 0.6
    /// 扫描区的宽度
    lazy var scanBorderWidth = scanBorderWidthRadio * UIScreen.main.bounds.width
    lazy var scanBorderHeight = scanBorderWidth
    /// 扫描区的x值
    lazy var scanBorderX = 0.5 * (1 - scanBorderWidthRadio) * UIScreen.main.bounds.width
    /// 扫描区的y值
    lazy var scanBorderY = 0.4 * (UIScreen.main.bounds.height - scanBorderWidth)
    lazy var contentView = UIView(frame:  CGRect(x:  scanBorderX, y:  scanBorderY, width:  scanBorderWidth, height: scanBorderHeight))
    // 提示文字
    public lazy var tips = ""
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView(image:  self.scanAnimationImage.changeColor(self.cornerColor))
        return imageView
    }()
    override public init(frame:  CGRect) {
        super.init(frame:  frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = true
        addSubview(contentView)
    }
    required init?(coder aDecoder:  NSCoder) {
        fatalError("init(coder: ) has not been implemented")
    }
    override public func draw(_ rect:  CGRect) {
        super.draw(rect)
        drawScan(rect)
        setupTips()
    }
    
    func startAnimation() {
        let rect = CGRect(x:  0, y:  0, width:  scanBorderWidth, height: scanBorderHeight)
        ScanAnimation.shared.startWith(rect, contentView, imageView:  imageView)
    }
    func stopAnimation() {
        ScanAnimation.shared.stopStepAnimating()
    }
}
// MARK:  - CustomMethod
extension ScanView{
    func setupTips() {
        if tips == "" {
            return
        }
        let tipsLbl = UILabel.init()
        tipsLbl.text = tips
        tipsLbl.textColor = .white
        tipsLbl.textAlignment = .center
        tipsLbl.font = UIFont.systemFont(ofSize:  13)
        addSubview(tipsLbl)
        tipsLbl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([tipsLbl.centerXAnchor.constraint(equalTo:  self.centerXAnchor),tipsLbl.topAnchor.constraint(equalTo:  contentView.bottomAnchor, constant:  20),tipsLbl.widthAnchor.constraint(equalToConstant:  UIScreen.main.bounds.width),tipsLbl.heightAnchor.constraint(equalToConstant:  14)])
    }
    /// 绘制扫码效果
    func drawScan(_ rect:  CGRect) {
        /// 空白区域设置
        UIColor.black.withAlphaComponent(backgroundAlpha).setFill()
        UIRectFill(rect)
        let context = UIGraphicsGetCurrentContext()
        // 获取上下文，并设置混合模式 -> destinationOut
        context?.setBlendMode(.destinationOut)
        // 设置空白区
        let bezierPath = UIBezierPath(rect:  CGRect(x:  scanBorderX + 0.5 * borderLineWidth, y:  scanBorderY + 0.5 * borderLineWidth, width:  scanBorderWidth - borderLineWidth, height:  scanBorderHeight - borderLineWidth))
        bezierPath.fill()
        // 执行混合模式
        context?.setBlendMode(.normal)
        /// 边框设置
        let borderPath = UIBezierPath(rect:  CGRect(x:  scanBorderX, y:  scanBorderY, width:  scanBorderWidth, height:  scanBorderHeight))
        borderPath.lineCapStyle = .butt
        borderPath.lineWidth = borderLineWidth
        borderColor.set()
        borderPath.stroke()
        //角标长度
        let cornerLenght: CGFloat = 20
        let insideExcess = 0.5 * (cornerWidth - borderLineWidth)
        let outsideExcess = 0.5 * (cornerWidth + borderLineWidth)
        /// 左上角角标
        let leftTopPath = UIBezierPath()
        leftTopPath.lineWidth = cornerWidth
        cornerColor.set()
        if cornerLocation == .inside {
            leftTopPath.move(to:  CGPoint(x:  scanBorderX + insideExcess, y:  scanBorderY + cornerLenght + insideExcess))
            leftTopPath.addLine(to:  CGPoint(x:  scanBorderX + insideExcess, y:  scanBorderY + insideExcess))
            leftTopPath.addLine(to:  CGPoint(x:  scanBorderX + cornerLenght + insideExcess, y:  scanBorderY + insideExcess))
        }else if cornerLocation == .outside{
            leftTopPath.move(to:  CGPoint(x:  scanBorderX - outsideExcess, y:  scanBorderY + cornerLenght - outsideExcess))
            leftTopPath.addLine(to:  CGPoint(x:  scanBorderX - outsideExcess, y:  scanBorderY - outsideExcess))
            leftTopPath.addLine(to:  CGPoint(x:  scanBorderX + cornerLenght - outsideExcess, y:  scanBorderY - outsideExcess))
        }else{
            leftTopPath.move(to:  CGPoint(x:  scanBorderX, y:  scanBorderY + cornerLenght))
            leftTopPath.addLine(to:  CGPoint(x:  scanBorderX, y:  scanBorderY))
            leftTopPath.addLine(to:  CGPoint(x:  scanBorderX + cornerLenght, y:  scanBorderY))
        }
        leftTopPath.stroke()
        /// 左下角角标
        let leftBottomPath = UIBezierPath()
        leftBottomPath.lineWidth = cornerWidth
        cornerColor.set()
        if cornerLocation == .inside {
            leftBottomPath.move(to:  CGPoint(x:  scanBorderX + cornerLenght + insideExcess, y:  scanBorderY + scanBorderHeight - insideExcess))
            leftBottomPath.addLine(to:  CGPoint(x:  scanBorderX + insideExcess, y:  scanBorderY + scanBorderHeight - insideExcess))
            leftBottomPath.addLine(to:  CGPoint(x:  scanBorderX +  insideExcess, y:  scanBorderY + scanBorderHeight - cornerLenght - insideExcess))
        }else if cornerLocation == .outside{
            leftBottomPath.move(to:  CGPoint(x:  scanBorderX + cornerLenght - outsideExcess, y:  scanBorderY + scanBorderHeight + outsideExcess))
            leftBottomPath.addLine(to:  CGPoint(x:  scanBorderX - outsideExcess, y:  scanBorderY + scanBorderHeight + outsideExcess))
            leftBottomPath.addLine(to:  CGPoint(x:  scanBorderX - outsideExcess, y:  scanBorderY + scanBorderHeight - cornerLenght + outsideExcess))
        }else{
            leftBottomPath.move(to:  CGPoint(x:  scanBorderX + cornerLenght, y:  scanBorderY + scanBorderHeight))
            leftBottomPath.addLine(to:  CGPoint(x:  scanBorderX, y:  scanBorderY + scanBorderHeight))
            leftBottomPath.addLine(to:  CGPoint(x:  scanBorderX, y:  scanBorderY + scanBorderHeight - cornerLenght))
        }
        leftBottomPath.stroke()
        /// 右上角小图标
        let rightTopPath = UIBezierPath()
        rightTopPath.lineWidth = cornerWidth
        cornerColor.set()
        if cornerLocation == .inside {
            rightTopPath.move(to:  CGPoint(x:  scanBorderX + scanBorderWidth - cornerLenght - insideExcess, y:  scanBorderY + insideExcess))
            rightTopPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth - insideExcess, y:  scanBorderY + insideExcess))
            rightTopPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth - insideExcess, y:  scanBorderY + cornerLenght + insideExcess))
        } else if cornerLocation == .outside {
            rightTopPath.move(to:  CGPoint(x:  scanBorderX + scanBorderWidth - cornerLenght + outsideExcess, y:  scanBorderY - outsideExcess))
            rightTopPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth + outsideExcess, y:  scanBorderY - outsideExcess))
            rightTopPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth + outsideExcess, y:  scanBorderY + cornerLenght - outsideExcess))
        } else {
            rightTopPath.move(to:  CGPoint(x:  scanBorderX + scanBorderWidth - cornerLenght, y:  scanBorderY))
            rightTopPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth, y:  scanBorderY))
            rightTopPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth, y:  scanBorderY + cornerLenght))
        }
        rightTopPath.stroke()
        /// 右下角小图标
        let rightBottomPath = UIBezierPath()
        rightBottomPath.lineWidth = cornerWidth
        cornerColor.set()
        if cornerLocation == .inside {
            rightBottomPath.move(to:  CGPoint(x:  scanBorderX + scanBorderWidth - insideExcess, y:  scanBorderY + scanBorderHeight - cornerLenght - insideExcess))
            rightBottomPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth - insideExcess, y:  scanBorderY + scanBorderHeight - insideExcess))
            rightBottomPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth - cornerLenght - insideExcess, y:  scanBorderY + scanBorderHeight - insideExcess))
        } else if cornerLocation == .outside {
            rightBottomPath.move(to:  CGPoint(x:  scanBorderX + scanBorderWidth + outsideExcess, y:  scanBorderY + scanBorderHeight - cornerLenght + outsideExcess))
            rightBottomPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth + outsideExcess, y:  scanBorderY + scanBorderHeight + outsideExcess))
            rightBottomPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth - cornerLenght + outsideExcess, y:  scanBorderY + scanBorderHeight + outsideExcess))
        } else {
            rightBottomPath.move(to:  CGPoint(x:  scanBorderX + scanBorderWidth, y:  scanBorderY + scanBorderHeight - cornerLenght))
            rightBottomPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth, y:  scanBorderY + scanBorderHeight))
            rightBottomPath.addLine(to:  CGPoint(x:  scanBorderX + scanBorderWidth - cornerLenght, y:  scanBorderY + scanBorderHeight))
        }
        rightBottomPath.stroke()
    }
}
// MARK:  -  ScanAnimation
class ScanAnimation: NSObject{
    static let shared: ScanAnimation = {
        let instance = ScanAnimation()
        return instance
    }()
    lazy var animationImageView = UIImageView()
    var tempFrame: CGRect?
    var isAnimationing = false
    
    func startWith(_ rect: CGRect, _ parentView: UIView, imageView: UIImageView) {
        tempFrame = rect
        imageView.frame = tempFrame ?? CGRect.zero
        animationImageView = imageView
        parentView.addSubview(imageView)
        isAnimationing = true
        if imageView.image != nil {
            animation()
        }
    }
    @objc func animation() {
        guard isAnimationing else {
            return
        }
        var frame = tempFrame
        let hImg = animationImageView.image!.size.height * frame!.size.width / animationImageView.image!.size.width
        frame?.origin.y -= hImg
        frame?.size.height = hImg
        self.animationImageView.frame = frame ?? CGRect.zero
        self.animationImageView.alpha = 0.0
        
        UIView.animate(withDuration: 1.4, animations: {
            self.animationImageView.alpha = 1.0
            var frame = self.tempFrame!
            let hImg = self.animationImageView.frame.size.height * self.tempFrame!.size.width / self.animationImageView.frame.size.width
            frame.origin.y += (frame.size.height - hImg)
            frame.size.height = hImg
            self.animationImageView.frame = frame
        }, completion: { _ in
            self.perform(#selector(ScanAnimation.animation), with: nil, afterDelay: 0.3)
        })
    }

    func stopStepAnimating() {
        self.animationImageView.isHidden = true
        isAnimationing = false
    }
    deinit {
        stopStepAnimating()
    }
}

// MARK: -  ScreenInfo
struct DY_ScreenInfo {
    static let Frame = UIScreen.main.bounds
    static let Height = Frame.height
    static let Width = Frame.width
    static let Scale = Width / 375
    static let StatusBarHeght: CGFloat = statusBarHeight()
    static let bottomBarHeight:CGFloat = 60
    static let bottomBarAlpha:CGFloat = 0.98
    static let navigationHeight:CGFloat = navBarHeight()
    static let tabBarHeight:CGFloat = tabBarrHeight()
    static let Kmargin_15:CGFloat = 15
    static let Kmargin_10:CGFloat = 10
    static let Kmargin_5:CGFloat = 5
    static func getBorderWidth(_ width:CGFloat) -> CGFloat {
        return width / UIScreen.main.scale * 2
    }
    static func isIphoneX() -> Bool {
        let screenHeight = UIScreen.main.nativeBounds.size.height;
        if screenHeight == 2436 || screenHeight == 1792 || screenHeight == 2688 || screenHeight == 1624 {
            return true
        }
        return false
    }
    static private func navBarHeight() -> CGFloat {
        return isIphoneX() ? 88 : 64;
    }
    static private func tabBarrHeight() -> CGFloat {
        return isIphoneX() ? 83 : 49;
    }
    static private func statusBarHeight() -> CGFloat{
        return isIphoneX() ? 44 : 20
    }
}
// MARK: -  changeColor
extension UIImage {
    /// 更改图片颜色
    public func changeColor(_ color :  UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        color.setFill()
        let bounds = CGRect.init(x:  0, y:  0, width:  self.size.width, height:  self.size.height)
        UIRectFill(bounds)
        self.draw(in:  bounds, blendMode:  CGBlendMode.destinationIn, alpha:  1.0)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let image = tintedImage else {
            return UIImage()
        }
        return image
    }
}
