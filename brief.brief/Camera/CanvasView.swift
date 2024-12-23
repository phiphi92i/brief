//
//  CanvasView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 08/12/2023.
//

import SwiftUI


struct CanvasView: View{
    @EnvironmentObject var snapModel: SnapViewModel
    var animation: Namespace.ID
    // MARK: Keyboard Status
    @FocusState var showKeyboard: Bool
    // MARK: Gesture State
    @GestureState var location: CGPoint = .zero
    
    

    
    var body: some View{
        GeometryReader{proxy in
            let size = proxy.size
            let safeAreaInsets = proxy.safeAreaInsets

            ZStack{
                Color.black
                
                ForEach($snapModel.stack){$item in
                    StackItemView(item: item,size: size)
                        .contentShape(Rectangle())
                        .rotationEffect(item.rotation)
                        .scaleEffect(item.scale)
                        .scaleEffect(snapModel.currentlyDraggingItem.id == item.id && snapModel.isDeleteAvailable ? 0.0001 : 1)
                        .offset(item.gestureTranslation)
                        .overlay(content: {
                            GeometryReader{proxy in
                                Color.clear
                                    .onAppear{
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                                            item.initialLocation = .init(x: proxy.frame(in: .global).minX, y: proxy.frame(in: .global).minY)
                                        }
                                    }
                            }
                        })
                        .gesture(
                            DragGesture()
                                .updating($location, body: { value, out, _ in
                                    out = value.location
                                })
                                .onChanged{value in
                                    item.gestureTranslation = CGSize(width: item.lastGestureTranslation.width + value.translation.width, height: item.lastGestureTranslation.height + value.translation.height)
                                    snapModel.currentlyDraggingItem = item
                                }.onEnded{value in
                                    item.lastGestureTranslation = item.gestureTranslation
                                    if snapModel.isDeleteAvailable{
                                        snapModel.deleteItem()
                                    }
                                    snapModel.currentlyDraggingItem = .init()
                                }
                        )
                        .gesture(
                            MagnificationGesture(minimumScaleDelta: 0)
                                 .onChanged({ value in
                                     item.scale = item.lastScale + (value - 1)
                                 }).onEnded({ value in
                                     item.lastScale = item.scale
                                 })
                                 .simultaneously(with:
                                    RotationGesture(minimumAngleDelta: .zero)
                                         .onChanged({ angle in
                                             item.rotation = item.lastRotation + angle
                                         }).onEnded({ angle in
                                             item.lastRotation = item.rotation
                                         })
                                )
                                .simultaneously(with:
                                    TapGesture().onEnded({ _ in
                                        if !item.isImage && !item.isEmoji && snapModel.selectedStackItem.id != item.id{
                                            withAnimation{
                                                snapModel.showTextEditor = true
                                            }
                                            snapModel.selectedStackItem = item
                                            showKeyboard = true
                                        }
                                    })
                                )
                        )
                }
                
                // MARK: Delete Button
                if location != .zero {
                    GeometryReader{proxy in
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(snapModel.isDeleteAvailable ? .white : .red, snapModel.isDeleteAvailable ? .red : .white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .onChange(of: location, perform: { newValue in
                                let newPoint = CGPoint(x: snapModel.currentlyDraggingItem.initialLocation.x + location.x, y: snapModel.currentlyDraggingItem.initialLocation.y + location.y)
                                withAnimation(.easeInOut.speed(1.5)){
                                    if proxy.frame(in: .global).contains(newPoint){
                                        if !snapModel.isDeleteAvailable{
                                            snapModel.isDeleteAvailable = true
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                    }else{
                                        snapModel.isDeleteAvailable = false
                                    }
                                }
                            })
                    }
                    .frame(width: 50, height: 50)
                    .padding(.bottom, safeAreaInsets.bottom) // Apply safe area insets
                    .frame(maxHeight: .infinity,alignment: .bottom)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
    
    // MARK: Stack Item View
    @ViewBuilder
    func StackItemView(item: StackItem, size: CGSize) -> some View {
        Group {
            if item.isEmoji {
                Text(item.text)
                    .font(.system(size: 110))
            } else if item.isImage {
                item.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            } else {
                // Use a VStack to combine the Text and a custom underline
                VStack(spacing: 0) {
                    Text(item.text)
                        .font(.title)
                        .fontWeight(item.isBold ? .bold : .regular)
                        .if(item.isItalic) { $0.italic() }
                        .foregroundColor(item.textColor)
                        .multilineTextAlignment(.center)

                    // Add a Rectangle as an underline if needed
                    if item.isUnderline {
                        Rectangle()
                            .fill(item.textColor) // Use the same color as the text
                            .frame(height: 1) // Control the thickness of the underline
                    }
                }
                .opacity(snapModel.selectedStackItem.id == item.id ? 0 : 1)
            }
        }
    }
}
    
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}



