//
//  EditorView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 08/12/2023.
//

import SwiftUI

//struct EditorView: View{
//    
//    @EnvironmentObject var snapModel: SnapViewModel
//    var selectedImage: (Image,Data)
//    // MARK: Environment Values
//    @Environment(\.self) var env
//    // MARK: KeyboardState
//    @FocusState var showKeyboard: Bool
//    @Namespace var animation
//    
//    
//    var body: some View{
//        
//        GeometryReader{proxy in
//            let size = proxy.size
//            ZStack(alignment: .top){
//                CanvasView(animation: animation,showKeyboard: _showKeyboard)
//                    .environmentObject(snapModel)
//                    .ignoresSafeArea()
//                
//                HStack(spacing: 0){
//                    Button {
//                        env.dismiss()
//                    } label: {
//                        Image(systemName: "xmark")
//                            .font(.title3)
//                            .padding()
//                            .contentShape(Rectangle())
//                    }
//                        
//                    Spacer()
//                    
//                    Button {
//                        snapModel.showEmojiView.toggle()
//                    } label: {
//                        Text("😄")
//                            .font(.title3)
//                            .padding()
//                            .frame(width: 0.0)
//                            .contentShape(Rectangle())
//                    }
//                    
//                    Button {
//                        withAnimation{
//                            snapModel.showTextEditor = true
//                        }
//                        showKeyboard = true
//                    } label: {
//                        Image(systemName: "character.cursor.ibeam")
//                            .font(.title3)
//                            .padding()
//                            .contentShape(Rectangle())
//                    }
//                    
//                    Button {
//                        generateImage(size: size)
//                    } label: {
//                        Image(systemName: "square.and.arrow.down.fill")
//                            .font(.title3)
//                            .padding()
//                            .contentShape(Rectangle())
//                    }
//                }
//                .foregroundColor(.white)
//                .opacity(showKeyboard ? 0 : 1)
//                
//                Color.black
//                    .opacity(snapModel.showTextEditor ? 0.5 : 0)
//                    .ignoresSafeArea()
//                
//                if snapModel.showTextEditor{
//                    ZStack{
//                        TextField("", text: $snapModel.selectedStackItem.text,axis: .vertical)
//                            .font(.title)
//                            .fontWeight(snapModel.selectedStackItem.isBold ? .bold : .regular)
//                            .italic(snapModel.selectedStackItem.isItalic)
//                            .underline(snapModel.selectedStackItem.isUnderline, color: snapModel.selectedStackItem.textColor)
//                            .foregroundColor(snapModel.selectedStackItem.textColor)
//                            .focused($showKeyboard)
//                            .multilineTextAlignment(.center)
//                            .matchedGeometryEffect(id: snapModel.selectedStackItem.id, in: animation)
//                        
//                        Button("Done"){
//                            withAnimation{
//                                snapModel.showTextEditor = false
//                            }
//                            showKeyboard = false
//                            snapModel.addTextToStack()
//                        }
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                        .padding()
//                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
//                    }
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//        .background {
//            Color.black
//                .ignoresSafeArea()
//        }
//        .sheet(isPresented: $snapModel.showEmojiView) {
//            EmojiView()
//                .presentationDetents([.height(100),.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .toolbar {
//            ToolbarItem(placement: .keyboard) {
//                KeyboardToolbar()
//            }
//        }
//        .alert("Image Generated Successfully!", isPresented: $snapModel.imageAlert) {}
//        .onAppear {
//            snapModel.stack.append(.init(image: selectedImage.0,isImage: true))
//        }
//    }
//    
//    // MARK: Keyboard ToolBar Content
//    @ViewBuilder
//    func KeyboardToolbar()->some View{
//        ScrollView(.horizontal, showsIndicators: false) {
//            let colors: [Color] = [.black,.white,.blue,.brown,.cyan,.gray,.green,.indigo,.mint,.orange,.pink,.purple,.red,.teal,.yellow]
//            HStack(spacing: 18){
//                Button {
//                    snapModel.selectedStackItem.isBold.toggle()
//                } label: {
//                    Image(systemName: "bold")
//                        .font(.title3)
//                        .fontWeight(snapModel.selectedStackItem.isBold ? .black : .regular)
//                        .foregroundColor(.primary)
//                }
//                
//                Button {
//                    snapModel.selectedStackItem.isItalic.toggle()
//                } label: {
//                    Image(systemName: "italic")
//                        .font(.title3)
//                        .fontWeight(snapModel.selectedStackItem.isItalic ? .black : .regular)
//                        .foregroundColor(.primary)
//                }
//                
//                Button {
//                    snapModel.selectedStackItem.isUnderline.toggle()
//                } label: {
//                    Image(systemName: "underline")
//                        .font(.title3)
//                        .fontWeight(snapModel.selectedStackItem.isUnderline ? .black : .regular)
//                        .foregroundColor(.primary)
//                }
//
//                ForEach(colors,id: \.self){color in
//                    Circle()
//                        .fill(color)
//                        .frame(width: 20, height: 20)
//                        .onTapGesture {
//                            snapModel.selectedStackItem.textColor = color
//                        }
//                }
//            }
//        }
//    }
//    
//    // MARK: Generating Image
//    func generateImage(size: CGSize){
//        let customView = CanvasView(animation: animation)
//            .environmentObject(snapModel)
//            .frame(width: size.width, height: size.height)
//        let imageRenderer = ImageRenderer(content: customView)
//        if let image = imageRenderer.uiImage{
//            snapModel.generatedImage = image
//            snapModel.imageAlert.toggle()
//        }
//    }
//    
//    // MARK: Emoji List View
//    @ViewBuilder
//    func EmojiView()->some View{
//        ScrollView(.vertical, showsIndicators: false) {
//            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), alignment: .center) {
//                ForEach(snapModel.allEmojis,id: \.self){emoji in
//                    Text(emoji)
//                        .font(.largeTitle)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical,10)
//                        .contentShape(Rectangle())
//                        .onTapGesture {
//                            snapModel.stack.append(.init(text: emoji,isEmoji: true))
//                            snapModel.showEmojiView.toggle()
//                        }
//                }
//            }
//            .padding()
//        }
//    }
//}
//
