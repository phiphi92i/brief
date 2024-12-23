//
//  SnapViewModel.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 08/12/2023.
//

import SwiftUI
import UIKit  // Import UIKit for UIImage

class SnapViewModel: ObservableObject {
    // MARK: Image Editing Properties
    @Published var selectedImage: (Image, Data)?
    @Published var showEditorView: Bool = false
    
    // MARK: Canvas Editor Properties
    @Published var showTextEditor: Bool = false
    @Published var selectedStackItem: StackItem = .init()
    @Published var showEmojiView: Bool = false
    @Published var allEmojis: [String] = []
    @Published var stack: [StackItem] = []
    @Published var currentlyDraggingItem: StackItem = .init()
    @Published var isDeleteAvailable: Bool = false
    
    // MARK: Generated Image
    @Published var generatedImage: UIImage?
    @Published var imageAlert: Bool = false

    init() {
        fetchEmojis()
    }
    
    // MARK: Process Captured Image
    func processCapturedImage(_ image: UIImage) {
        let imageData = image.jpegData(compressionQuality: 1.0) ?? Data()
        self.selectedImage = (Image(uiImage: image), imageData)
        self.showEditorView.toggle()
    }

    // MARK: Fetch Emojis
    private func fetchEmojis() {
        for i in 0x1F601...0x1F64F {
            let emoji = String(UnicodeScalar(i) ?? "-")
            allEmojis.append(emoji)
        }
    }

    
    // MARK: Adding Text To Canvas
    func addTextToStack(){
        if let index = stack.firstIndex(where: { item in
            item.id == selectedStackItem.id
        }){
            stack[index] = selectedStackItem
        }else{
            stack.append(selectedStackItem)
        }
        selectedStackItem = .init()
    }
    
    // MARK: Clearing All Data
    func clearData(){
        stack.removeAll()
        selectedImage = nil
        selectedStackItem = .init()
    }
    
    // MARK: Deleting Item From Stack
    func deleteItem(){
        if let index = stack.firstIndex(where: { item in
            item.id == currentlyDraggingItem.id
        }){
            stack.remove(at: index)
        }
    }
}
