//
//  ImagePicker.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 20/09/2023.
//

import SwiftUI
import CropViewController
import TOCropViewController
import PhotosUI

public enum mediaPickerType {
    case images
    case videos
    case imagesAndVideos
    
    var filterType: PHPickerFilter {
        switch self {
        case .images:
            return .images
        case .videos:
            return .videos
        case .imagesAndVideos:
            return .any(of: [.images, .videos])
        }
    }
}

struct MediaPicker: UIViewControllerRepresentable {
    
    @ObservedObject var mediaItems: PickedMediaItems
    var limit = 1
    var filter: mediaPickerType
    
    var didFinishPicking: (_ didSelectItems: Bool, _ items: PickedMediaItems?) -> Void
    
    init(limit: Int = 1, filter: mediaPickerType = .images, _ didFinish: @escaping(_ didSelectItems: Bool, _ items: PickedMediaItems?) -> Void) {
        self.mediaItems = PickedMediaItems()
        self.limit = limit
        self.filter = filter
        self.didFinishPicking = didFinish
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(with: self, limit: self.limit)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = self.filter.filterType
        config.selectionLimit = self.limit
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        
    }
    
    class Coordinator: PHPickerViewControllerDelegate {
        
        var parent: MediaPicker
        var limit: Int = 1
        
        init(with mediaPicker: MediaPicker, limit: Int = 1) {
            self.parent = mediaPicker
            self.limit = limit
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else { self.parent.didFinishPicking(false, nil); return }
            
            for result in results {
                let itemProvider = result.itemProvider
                guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first,
                      let utType = UTType(typeIdentifier) else { continue }
                
                if utType.conforms(to: .image) {
                    self.getPhoto(from: itemProvider, isLivePhoto: false) { image in
                        DispatchQueue.main.async {
                            if let image = image {
                                self.parent.mediaItems.append(item: PhotoPickerModel(with: image))
                                self.parent.didFinishPicking(true, self.parent.mediaItems)
                                picker.dismiss(animated: true, completion: nil)
                            } else {
                                self.parent.didFinishPicking(false, nil)
                                picker.dismiss(animated: true, completion: nil)
                            }
                        }
                    }
                } else {
                    self.getVideo(from: itemProvider, typeIdentifier: typeIdentifier) { url in
                        DispatchQueue.main.async {
                            if let url = url {
                                self.parent.mediaItems.append(item: PhotoPickerModel(with: url))
                                self.parent.didFinishPicking(true, self.parent.mediaItems)
                                picker.dismiss(animated: true, completion: nil)
                            } else {
                                self.parent.didFinishPicking(false, nil)
                                picker.dismiss(animated: true, completion: nil)
                            }
                        }
                    }
                }
                
            }
        }
        
        private func getPhoto(from itemProvider: NSItemProvider, isLivePhoto: Bool, _ completion: @escaping((UIImage?) -> Void)) {
            let objectType: NSItemProviderReading.Type = !isLivePhoto ? UIImage.self : PHLivePhoto.self
                        
            if itemProvider.canLoadObject(ofClass: objectType) {
                itemProvider.loadObject(ofClass: objectType) { object, error in
                    if let _ = error {
                        completion(nil)
                    }
                    
                    if !isLivePhoto {
                        if let image = object as? UIImage {
                            completion(image)
                        } else {
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                }
            } else {
                completion(nil)
            }
        }
        
        
        private func getVideo(from itemProvider: NSItemProvider, typeIdentifier: String, _ completion: @escaping((URL?) -> Void)) {
            itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let _ = error {
                    completion(nil)
                }
                
                guard let url = url else { completion(nil); return }
                
                let duration = AVURLAsset(url: url).duration.seconds
                if duration > 30 {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Error", message: "Please Select a video under 30 seconds", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                        UIApplication.topViewController()?.present(alert, animated: true, completion: nil)
                    }
                    completion(nil)
                    return
                }
                
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                guard let targetURL = documentsDirectory?.appendingPathComponent(url.lastPathComponent) else { return }
                
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    
                    try FileManager.default.copyItem(at: url, to: targetURL)
                    
                    DispatchQueue.main.async {
                        completion(targetURL)
                    }
                } catch {
                    completion(nil)
                }
            }
        }
    }
}

struct PhotoPickerModel {
    enum MediaType {
        case photo, video, livePhoto
    }
    
    var id: String
    var photo: UIImage?
    var url: URL?
    var livePhoto: PHLivePhoto?
    var mediaType: MediaType = .photo
    
    init(with photo: UIImage) {
        id = UUID().uuidString
        self.photo = photo
        mediaType = .photo
    }
    
    init(with videoURL: URL) {
        id = UUID().uuidString
        url = videoURL
        mediaType = .video
    }
    
    init(with livePhoto: PHLivePhoto) {
        id = UUID().uuidString
        self.livePhoto = livePhoto
        mediaType = .livePhoto
    }
    
    mutating func delete() {
        switch mediaType {
        case .photo: photo = nil
        case .livePhoto: livePhoto = nil
        case .video:
            guard let url = url else { return }
            try? FileManager.default.removeItem(at: url)
            self.url = nil
        }
    }
}


class PickedMediaItems: ObservableObject {
    @Published var items = [PhotoPickerModel]()
    
    func append(item: PhotoPickerModel) {
        items.append(item)
    }
    
    func deleteAll() {
        for (index, _) in items.enumerated() {
            items[index].delete()
        }
        
        items.removeAll()
    }
}

struct ImageCropper: UIViewControllerRepresentable {
    
    @Binding var image: UIImage
    @Binding var visible: Bool
    var done: (UIImage) -> Void
    
    class Coordinator: NSObject, CropViewControllerDelegate {
        
        let parent: ImageCropper
        
        init (_ parent: ImageCropper) {
            self.parent = parent
        }
        
        func cropViewController(_ cropViewController: CropViewController, didCropToCircularImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
            withAnimation {
                parent.visible = false
            }
            parent.done(image)
        }
        
        func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
            withAnimation {
                parent.visible = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let img = self.image
        let cropViewController = CropViewController(croppingStyle: .circular, image: img)
        cropViewController.delegate = context.coordinator
        return cropViewController
    }
}
