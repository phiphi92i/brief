//
//  UITextField.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 14/06/2023.
//

import SwiftUI



struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: UIViewRepresentableContext<CustomTextField>) -> UITextField {
        let textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<CustomTextField>) {
        uiView.text = text
        uiView.textColor = UIColor.white
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
