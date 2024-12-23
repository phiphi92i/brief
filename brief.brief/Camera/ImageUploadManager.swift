//
//  ImageUploadManager.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 02/02/2024.
//

import Foundation
import FirebaseStorage

class ImageUploadManager: ObservableObject {
    @Published var uploadProgress: Double = 0

    func uploadImage(_ imageData: Data, completion: @escaping (Result<URL, Error>) -> Void) {
        let storageRef = Storage.storage().reference().child("uploadedImages/\(UUID().uuidString).jpg")
        let uploadTask = storageRef.putData(imageData, metadata: nil) { metadata, error in
            guard let _ = metadata else { // replace 'null' with '_'
                completion(.failure(error ?? NSError(domain: "ImageUploadError", code: -1, userInfo: nil)))
                return
            }

            storageRef.downloadURL { url, error in
                if let downloadURL = url {
                    completion(.success(downloadURL))
                } else {
                    completion(.failure(error ?? NSError(domain: "ImageUploadError", code: -2, userInfo: nil)))
                }
            }
        }

        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let progress = snapshot.progress else { return } // Explicitly unwrap the optional
            self?.uploadProgress = progress.fractionCompleted * 100 // use 'progress.fractionCompleted'
        }
    }
}
