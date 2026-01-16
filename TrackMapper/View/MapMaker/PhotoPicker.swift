//
//  PhotoPicker.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/4/25.
//

import SwiftUI
import PhotosUI

struct PhotoPicker: View {
    @State private var selectedItem: PhotosPickerItem?
    @Binding var selectedImage: UIImage?

    var body: some View {
        VStack {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Select an Image")
                    .padding()
                    .underline()
                    .foregroundColor(.blue.opacity(0.8))
            }
            .onChange(of: selectedItem) { _, newItem in
                if let newItem {
                    loadImage(from: newItem)
                }
            }
        }
        .padding()
    }

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.selectedImage = image
                }
            }
        }
    }
}
