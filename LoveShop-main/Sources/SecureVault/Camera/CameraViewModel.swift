import AVFoundation
import UIKit
import Combine
import CoreLocation

final class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var error: String?
    @Published var isTorchOn: Bool = false
    @Published var quickMode: Bool = false

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var completion: ((UIImage, CLLocation?, CLHeading?) -> Void)?

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Camera unavailable"
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    func startSession() {
        if !session.isRunning { session.startRunning() }
    }

    func stopSession() {
        if session.isRunning { session.stopRunning() }
    }

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        isTorchOn.toggle()
        device.torchMode = isTorchOn ? .on : .off
        device.unlockForConfiguration()
    }

    /// Возвращает СЫРОЕ фото без впечатанного водяного знака.
    /// Координаты/азимут зафиксированы на момент съёмки и передаются отдельно,
    /// а сам watermark (включая подпись-шаблон) накладывается позже —
    /// либо сразу (быстрый режим), либо при сохранении в редакторе
    /// (это позволяет выбрать актуальный шаблон уже после съёмки).
    func capturePhoto(completion: @escaping (UIImage, CLLocation?, CLHeading?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let img = UIImage(data: data) else { return }

        let loc = LocationManager.shared.location
        let hdg = LocationManager.shared.heading
        DispatchQueue.main.async {
            self.completion?(img, loc, hdg)
        }
    }
}
