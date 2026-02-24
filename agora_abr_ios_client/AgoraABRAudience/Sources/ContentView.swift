import SwiftUI

struct ContentView: View {
    @StateObject private var manager = AgoraAudienceManager()

    @State private var appId = ""
    @State private var channel = ""
    @State private var token = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Join") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Agora App ID", text: $appId)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textFieldStyle(.roundedBorder)

                            TextField("Channel", text: $channel)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textFieldStyle(.roundedBorder)

                            TextField("Token (optional)", text: $token)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textFieldStyle(.roundedBorder)

                            Picker("Video Layer", selection: $manager.layerMode) {
                                ForEach(LayerMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: manager.layerMode) { mode in
                                manager.applyLayerMode(mode)
                            }

                            HStack {
                                Button("Join") {
                                    manager.join(appId: appId, channel: channel, token: token)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(manager.isJoined)

                                Button("Leave") {
                                    manager.leave()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!manager.isJoined)
                            }
                        }
                    }

                    GroupBox("Remote Video") {
                        if manager.remoteUsers.isEmpty {
                            Text("No remote publishers yet")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(manager.remoteUsers, id: \.self) { uid in
                                    ZStack(alignment: .bottomLeading) {
                                        let subtitle = manager.remoteStats[uid]?.summary ?? "waiting for stats..."

                                        RemoteVideoView(uid: uid, manager: manager)
                                            .frame(height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        Text("uid=\(uid) | \(subtitle)")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(.black.opacity(0.55))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .padding(8)
                                    }
                                }
                            }
                        }
                    }

                    GroupBox("Log") {
                        VStack(alignment: .leading, spacing: 8) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(manager.logs.indices, id: \.self) { index in
                                            Text(manager.logs[index])
                                                .font(.system(.footnote, design: .monospaced))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(index)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .onChange(of: manager.logs.count) { _ in
                                    // Auto-scroll to bottom as new logs arrive
                                    if let last = manager.logs.indices.last {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            proxy.scrollTo(last, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 220)
                    }
                }
                .padding()
            }
            .navigationTitle("Agora AV Subscriber")
        }
    }
}
