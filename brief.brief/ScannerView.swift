//
//  ScannerView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 15/09/2023.
//

import SwiftUI

struct ScannerView: UIViewControllerRepresentable {
    var parentView: CodeScannerView

    func makeUIViewController(context: Context) -> ScannerViewController {
        return ScannerViewController(parentView: parentView)
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // Update your UIViewController
    }
}
