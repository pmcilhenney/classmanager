import SwiftUI
import AVFoundation
import UIKit

struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onCode = onCode
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) { }
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String)->Void)?
    
    private let session = AVCaptureSession()
    private var isClosed = false
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var orientationObserver: NSObjectProtocol?
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .headline)
        return label
    }()
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "xmark.circle.fill")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        button.layer.cornerRadius = 22
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Close QR scanner"
        button.accessibilityHint = "Dismisses the camera scanner without scanning a code."
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        installCloseButton()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            showScannerMessage("Waiting for camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.messageLabel.removeFromSuperview()
                        self.configureCamera()
                    } else {
                        self.showScannerMessage("Camera access is required to scan QR codes. You can enable it in Settings.")
                    }
                }
            }
        case .denied, .restricted:
            showScannerMessage("Camera access is required to scan QR codes. You can enable it in Settings.")
        @unknown default:
            showScannerMessage("The camera is unavailable on this device.")
        }
    }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showScannerMessage("The camera is unavailable on this device.")
            return
        }
        session.addInput(input)
        
        do {
            try device.lockForConfiguration()
            if device.activeFormat.videoMaxZoomFactor >= 1.0 {
                device.videoZoomFactor = 1.0
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            AppDebugLog.log("[QRScanner] Failed to configure camera: \(error)")
        }

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showScannerMessage("The camera scanner could not be started.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        self.previewLayer = preview
        view.bringSubviewToFront(closeButton)
        updateVideoOrientation()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.updateVideoOrientation()
            }
        }

        orientationObserver = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateVideoOrientation()
        }
    }

    private func showScannerMessage(_ message: String) {
        messageLabel.text = message
        if messageLabel.superview == nil {
            view.addSubview(messageLabel)
            NSLayoutConstraint.activate([
                messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
                messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
                messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }
        view.bringSubviewToFront(messageLabel)
        view.bringSubviewToFront(closeButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !isClosed,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let value = obj.stringValue, !value.isEmpty
        else { return }

        isClosed = true
        session.stopRunning()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onCode?(value)
        dismiss(animated: true)
    }
    
    private func updateVideoOrientation() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }
        guard let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: UIDevice.current.orientation) else { return }
        connection.videoOrientation = videoOrientation
        previewLayer?.frame = view.bounds
    }
    
    private func updateVideoOrientationForCurrentInterface() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }
        switch UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
        case .portrait: connection.videoOrientation = .portrait
        case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
        case .landscapeLeft: connection.videoOrientation = .landscapeLeft
        case .landscapeRight: connection.videoOrientation = .landscapeRight
        default: break
        }
    }

    deinit {
        if session.isRunning { session.stopRunning() }
        if let obs = orientationObserver { NotificationCenter.default.removeObserver(obs) }
    }

    private func installCloseButton() {
        view.addSubview(closeButton)
        closeButton.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func closeScanner() {
        guard !isClosed else { return }
        isClosed = true
        if session.isRunning { session.stopRunning() }
        dismiss(animated: true)
    }
}

private extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}
