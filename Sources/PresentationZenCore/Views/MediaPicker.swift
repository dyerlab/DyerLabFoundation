//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MediaPicker.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2025.03.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import UIKit

/// A SwiftUI wrapper around `UIImagePickerController` for choosing or taking a single photo.
///
/// Present it in a sheet. When the user picks an image, it is scaled down
/// and encoded with ``DLImage/compressedData(maxWidth:quality:)``, written to
/// the binding, and the picker dismisses itself. Scaling keeps photos small
/// enough to store in SwiftData and sync through CloudKit.
///
/// ```swift
/// .sheet(isPresented: $showPicker) {
///     MediaPicker(image: $imageData, sourceType: .camera)
/// }
/// ```
public struct MediaPicker: UIViewControllerRepresentable {

    // MARK: - Properties

    /// Receives the picked image as JPEG data.
    @Binding public var image: Data?

    /// Where to pick from. Defaults to the photo library.
    public var sourceType: UIImagePickerController.SourceType

    /// The maximum width of the stored image, in pixels.
    public var maxWidth: CGFloat

    // MARK: - Initializers

    /// Creates a picker.
    /// - Parameters:
    ///   - image: Receives the picked image as JPEG data.
    ///   - sourceType: Where to pick from. Defaults to `.photoLibrary`. If the
    ///     source isn't available (such as `.camera` in the simulator), the photo library is used.
    ///   - maxWidth: The maximum width of the stored image. Defaults to 1280.
    public init(image: Binding<Data?>,
                sourceType: UIImagePickerController.SourceType = .photoLibrary,
                maxWidth: CGFloat = 1280) {
        self._image = image
        self.sourceType = sourceType
        self.maxWidth = maxWidth
    }

    // MARK: - Conformance

    /// Creates the image picker, limited to images.
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        return picker
    }

    /// Does nothing. The picker has no state to update.
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Creates the delegate that receives the picked image.
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// The image picker's delegate, which passes the picked image back to the ``MediaPicker``.
    @MainActor
    public final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

        /// The picker that owns this coordinator.
        let parent: MediaPicker

        /// Creates a coordinator for the given picker.
        init(_ parent: MediaPicker) {
            self.parent = parent
        }

        /// Compresses the picked image, writes it to the parent's binding, and dismisses the picker.
        public func imagePickerController(_ picker: UIImagePickerController,
                                          didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image.compressedData(maxWidth: parent.maxWidth)
            }
            picker.dismiss(animated: true)
        }

        /// Dismisses the picker without changing the binding.
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif
