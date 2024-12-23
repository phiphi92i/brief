//
//  ScannerView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 15/09/2023.
//

import UIKit
import SwiftUI

struct ScannerView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    var parentView: CodeScannerView

    func makeUIViewController(context: UIViewControllerRepresentableContext<ScannerView>) -> ScannerViewController {
        return ScannerViewController(parentView: parentView)
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: UIViewControllerRepresentableContext<ScannerView>) {
        // Update your view controller here
    }
}


