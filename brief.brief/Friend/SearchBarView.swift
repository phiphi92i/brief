//
//  SearchBarView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 27/06/2023.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var onCommit: () -> Void

    var body: some View {
        HStack {
            TextField("Search friends...", text: $text, onCommit: onCommit)
                .font(.headline)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
    }
}
