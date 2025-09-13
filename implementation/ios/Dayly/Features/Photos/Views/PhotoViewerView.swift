import SwiftUI

struct PhotoViewerView: View {
    let groupId: UUID
    let groupName: String
    
    @StateObject private var viewModel: PhotoViewerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex = 0
    @State private var showingOverlay = true
    @State private var hideOverlayTimer: Timer?
    
    init(groupId: UUID, groupName: String) {
        self.groupId = groupId
        self.groupName = groupName
        self._viewModel = StateObject(wrappedValue: PhotoViewerViewModel(groupId: groupId))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.photos.isEmpty && !viewModel.isLoading {
                EmptyPhotosView(groupName: groupName)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoView(photo: photo)
                            .tag(index)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingOverlay.toggle()
                                    resetHideTimer()
                                }
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { _ in
                    // Haptic feedback on swipe
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
            
            // Overlay with metadata
            if showingOverlay && !viewModel.photos.isEmpty {
                VStack {
                    // Top bar
                    HStack {
                        // Close button
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        // Group name
                        Text(groupName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                        
                        Spacer()
                        
                        // Page indicator
                        if viewModel.photos.count > 1 {
                            Text("\(currentIndex + 1) / \(viewModel.photos.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom metadata
                    if currentIndex < viewModel.photos.count {
                        let photo = viewModel.photos[currentIndex]
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // Sender info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(photo.senderName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(photo.timeAgo)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                // Expiry info
                                if let expiryTime = photo.expiresIn {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Expires in")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(expiryTime)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.8), Color.clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: 150)
                        )
                    }
                }
                .transition(.opacity)
            }
            
            // Loading overlay
            if viewModel.isLoading && viewModel.photos.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .task {
            await viewModel.loadPhotos()
            startHideTimer()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
        .onDisappear {
            hideOverlayTimer?.invalidate()
        }
    }
    
    private func startHideTimer() {
        hideOverlayTimer?.invalidate()
        hideOverlayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingOverlay = false
            }
        }
    }
    
    private func resetHideTimer() {
        if showingOverlay {
            startHideTimer()
        } else {
            hideOverlayTimer?.invalidate()
        }
    }
}

struct PhotoViewerView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoViewerView(groupId: UUID(), groupName: "Family")
    }
}
