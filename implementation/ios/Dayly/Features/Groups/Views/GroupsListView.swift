import SwiftUI
import UIKit

struct GroupsListView: View {
    @StateObject private var viewModel = GroupsViewModel()
    @State private var showCreateGroup = false
    @State private var selectedGroupForCamera: GroupViewModel?
    @State private var selectedGroupForPhotos: GroupViewModel?
    @State private var selectedGroupForViewing: GroupViewModel?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading && viewModel.groups.isEmpty {
                        ProgressView("Loading groups...")
                            .padding()
                    } else if viewModel.groups.isEmpty {
                        EmptyGroupsView()
                            .padding(.top, 50)
                    } else {
                        ForEach(viewModel.groups) { group in
                            GroupCard(
                                group: group,
                                uploadProgress: viewModel.uploadProgress[group.id]
                            )
                            .onTapGesture {
                                // Open camera for this group
                                selectedGroupForCamera = group
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // Haptic feedback
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                
                                // Show today's photos
                                selectedGroupForViewing = group
                            }
                        }
                    }
                    
                    if viewModel.groups.count < 5 {
                        CreateGroupButton()
                            .onTapGesture {
                                showCreateGroup = true
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Dayly")
            .refreshable {
                await viewModel.loadGroups()
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView()
                    .environmentObject(viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
        }
        .task {
            await viewModel.loadGroups()
        }
        .fullScreenCover(item: $selectedGroupForCamera) { group in
            CameraView(group: group)
        }
        .fullScreenCover(item: $selectedGroupForViewing) { group in
            PhotoViewerView(groupId: group.id, groupName: group.name)
        }
    }
}

struct EmptyGroupsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Groups Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create a group to start sharing\nyour daily moments")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct CreateGroupButton: View {
    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
            Text("Create New Group")
                .fontWeight(.medium)
            Spacer()
        }
        .foregroundColor(.accentColor)
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

struct GroupsListView_Previews: PreviewProvider {
    static var previews: some View {
        GroupsListView()
    }
}
