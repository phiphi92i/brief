//
//  Nuke caching.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 09/04/2024.
//

//import Nuke
//import NukeUI
//import Foundation
//
//class CustomMemoryCache: ImageCache {
//    private let cache: NSCache<URL, UIImage> = {
//        let cache = NSCache<URL, UIImage>()
//        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
//        return cache
//    }()
//
//    func cachedImage(for key: ImageRequest) -> UIImage? {
//        return cache.object(forKey: key.url)
//    }
//
//    func storeCachedImage(_ image: UIImage, for key: ImageRequest) {
//        cache.setObject(image, forKey: key.url)
//    }
//
//    func removeAll() {
//        cache.removeAllObjects()
//    }
//}
//
//class CustomDiskCache: ImageCaching {
//    private let directoryURL: URL
//    private let cache: ImageCache
//
//    init(directoryURL: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!) {
//        self.directoryURL = directoryURL
//        self.cache = ImageCache(
//            configuration: Nuke.ImageCacheConfiguration(
//                pathGenerator: { request in
//                    return request.url?.lastPathComponent ?? "image"
//                },
//                costs: Nuke.ImageCacheConfiguration.Costs(
//                    memoryCost: 1,
//                    diskCost: { image in
//                        guard let data = image.pngData() else { return 0 }
//                        return data.count
//                    }
//                )
//            )
//        )
//    }
//
//    func cachedImage(for key: ImageRequest) -> UIImage? {
//        return cache.cachedImage(for: key)
//    }
//
//    func storeImage(_ image: UIImage, for key: ImageRequest) {
//        cache.storeImage(image, for: key)
//    }
//
//    func removeAll() {
//        cache.removeAll()
//        try? FileManager.default.removeItem(at: directoryURL)
//    }
//}
