//
//  ColourPickerView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 20/09/2023.
//

import Foundation
import SwiftUI


struct ColourPickerView: View {
    @State var chosenColor: Color
    
    @State private var isDragging: Bool = false
    @State private var startLocation: CGFloat = .zero
    @State private var dragOffset: CGSize = .zero
    
    var delegate: ColourPickerDelegate?
    
    init(chosenColor: Color, delegate: ColourPickerDelegate) {
        self._chosenColor = State(initialValue: chosenColor)
        self.delegate = delegate
    }
    
    private var colors: [Color] = {
        let hueValues = Array(0...359)
        return hueValues.map {
            Color(UIColor(hue: CGFloat($0) / 359.0 ,
                          saturation: 1.0,
                          brightness: 1.0,
                          alpha: 1.0))
        }
    }()
    
    private var circleWidth: CGFloat {
        isDragging ? 35 : 15
    }
    
    private var linearGradientHeight: CGFloat = 200
    
    /// Get the current color based on our current translation within the view
    private var currentColor: Color {
        Color(UIColor.init(hue: self.normalizeGesture() / linearGradientHeight, saturation: 1.0, brightness: 1.0, alpha: 1.0))
    }
    
    /// Normalize our gesture to be between 0 and 200, where 200 is the height.
    /// At 0, the users finger is on top and at 200 the users finger is at the bottom
    private func normalizeGesture() -> CGFloat {
        let offset = startLocation + dragOffset.height // Using our starting point, see how far we've dragged +- from there
        let maxY = max(0, offset) // We want to always be greater than 0, even if their finger goes outside our view
        let minY = min(maxY, linearGradientHeight) // We want to always max at 200 even if the finger is outside the view.
        
        return minY
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(gradient: Gradient(colors: colors),
                           startPoint: .top,
                           endPoint: .bottom)
                .frame(width: 10, height: linearGradientHeight)
                .cornerRadius(5)
                .shadow(radius: 8)
                .overlay(
                        RoundedRectangle(cornerRadius: 5).stroke(Color.white, lineWidth: 2.0)
                )
                .gesture(
                    DragGesture()
                        .onChanged({ (value) in
                            self.dragOffset = value.translation
                            self.startLocation = value.startLocation.y
                            self.chosenColor = self.currentColor
                            self.isDragging = true // 4
                        })
                        .onEnded({ (_) in
                            self.isDragging = false
                            self.delegate?.didChangeColour(to: self.currentColor)
                        })
            )
            
            Circle()
                .foregroundColor(self.currentColor)
                .frame(width: self.circleWidth, height: self.circleWidth, alignment: .center)
                .shadow(radius: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: self.circleWidth / 2.0).stroke(Color.white, lineWidth: 2.0)
                )
                .offset(x: self.isDragging ? -self.circleWidth : 0.0, y: self.normalizeGesture() - self.circleWidth / 2)
                .animation(Animation.spring().speed(2))
        }
        .padding(24)
    }
}

protocol ColourPickerDelegate {
    func didChangeColour(to colour: Color)
}
