//
//  KeymapSourceSettings.swift
//  PlayCover
//
//  Created by Nick on 2022-10-04.
//

import SwiftUI

struct KeymapSourceSettings: View {
    @State var selected = Set<UUID>()
    @State var selectedNotEmpty = false
    @State var addSourceSheet = false
    @State var triggerUpdate = false
    @EnvironmentObject var keymapSourceVM: KeymapSourceVM

    var body: some View {
        Form {
            HStack {
                List(keymapSourceVM.sources, id: \.id, selection: $selected) { source in
                    SourceView(source: source)
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
                Spacer()
                    .frame(width: 20)
                VStack {
                    Button(action: {
                        addSource()
                    }, label: {
                        Text("preferences.button.addSource")
                            .frame(width: 130)
                    })
                    Button(action: {
                        keymapSourceVM.deleteSource(&selected)
                    }, label: {
                        Text("preferences.button.deleteSource")
                            .frame(width: 130)
                    })
                    .disabled(!selectedNotEmpty)
                    Spacer()
                        .frame(height: 20)
                    Button(action: {
                        keymapSourceVM.moveSourceUp(&selected)
                    }, label: {
                        Text("preferences.button.moveSourceUp")
                            .frame(width: 130)
                    })
                    .disabled(!selectedNotEmpty)
                    Button(action: {
                        keymapSourceVM.moveSourceDown(&selected)
                    }, label: {
                        Text("preferences.button.moveSourceDown")
                            .frame(width: 130)
                    })
                    .disabled(!selectedNotEmpty)
                    Spacer()
                        .frame(height: 20)
                    Button(action: {
                        keymapSourceVM.resolveSources()
                    }, label: {
                        Text("preferences.button.resolveSources")
                            .frame(width: 130)
                    })
                }
            }
        }
        .onChange(of: selected) { _ in
            if selected.count > 0 {
                selectedNotEmpty = true
            } else {
                selectedNotEmpty = false
            }
        }
        .padding(20)
        .frame(width: 600, height: 300, alignment: .center)
        .sheet(isPresented: $addSourceSheet) {
            AddKeymappingSourceView(addSourceSheet: $addSourceSheet)
                .environmentObject(keymapSourceVM)
        }
    }

    func addSource() {
        addSourceSheet.toggle()
    }
}

struct AddKeymappingSourceView: View {
    @State var newSource = "https://api.github.com/repos/PlayCover/keymaps/contents/keymapping"
    @State var newSourceURL: URL?
    @State var sourceValidationState = SourceValidation.checking
    @Binding var addSourceSheet: Bool
    @EnvironmentObject var keymapSourceVM: KeymapSourceVM

    var body: some View {
        VStack {
            TextField(text: $newSource, label: {Text("preferences.textfield.url")})
            Spacer()
                .frame(height: 20)
            HStack {
                switch sourceValidationState {
                case .valid:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("preferences.popover.valid")
                        .font(.system(.subheadline))
                case .badurl:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("preferences.popover.badurl")
                        .font(.system(.subheadline))
                case .badjson:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("preferences.popover.badjson")
                        .font(.system(.subheadline))
                case .checking:
                    ProgressView()
                }
                Spacer()
                Button(action: {
                    addSourceSheet.toggle()
                }, label: {
                    Text("button.Cancel")
                })
                Button(action: {
                    if newSourceURL != nil {
                        keymapSourceVM.appendSourceData(
                            SourceData(source: newSourceURL!.absoluteString))
                        addSourceSheet.toggle()
                    }
                }, label: {
                    Text("button.OK")
                })
                .tint(.accentColor)
                .keyboardShortcut(.defaultAction)
                .disabled(sourceValidationState != .valid)
            }
        }
        .padding()
        .frame(width: 400, height: 100)
        .onChange(of: newSource) { source in
            validateSource(source)
        }
        .onAppear {
            validateSource(newSource)
        }
    }

    func validateSource(_ source: String) {
        sourceValidationState = .checking

        DispatchQueue.global(qos: .userInteractive).async {
            guard let url = URL(string: source) else {
                sourceValidationState = .badurl
                return
            }
            newSourceURL = url

            do {
                if newSourceURL!.scheme == nil {
                    newSourceURL = URL(string: "https://" + url.absoluteString)!
                }

                let contents = try String(contentsOf: newSourceURL!)
                let jsonData = contents.data(using: .utf8)!
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let data = try decoder.decode([KeymapFolderSourceData].self, from: jsonData)

                    for index in 0..<data.count {
                        let keymapContents = try String(contentsOf: URL(string: data[index].url)!)
                        let keymapJsonData = keymapContents.data(using: .utf8)!
                        let keymapData = try decoder.decode([KeymapSourceData].self, from: keymapJsonData)

                        let fetchedKeymaps = keymapData.filter {
                            $0.downloadUrl.contains(".playmap")
                        }

                        if fetchedKeymaps.count > 0 {
                            sourceValidationState = .valid
                            return
                        }
                    }
                } catch {
                    sourceValidationState = .badjson
                    return
                }
            } catch {
                sourceValidationState = .badurl
                return
            }
        }
    }
}

struct KeymappingSourceSettings_Previews: PreviewProvider {
    static var previews: some View {
        KeymapSourceSettings()
    }
}
