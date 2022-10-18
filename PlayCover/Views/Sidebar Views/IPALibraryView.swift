//
//  IPALibrary.swift
//  PlayCover
//
//  Created by Isaac Marovitz on 07/08/2022.
//

import SwiftUI

struct IPALibraryView: View {
    @EnvironmentObject var ipaSourceVM: IPASourceVM

    @Binding var selectedBackgroundColor: Color
    @Binding var selectedTextColor: Color

    @State private var gridLayout = [GridItem(.adaptive(minimum: 130, maximum: .infinity))]
    @State private var searchString = ""
    @State private var isList = UserDefaults.standard.bool(forKey: "IPALibrayView")
    @State private var selected: StoreAppData?
    @State private var addSourcePresented = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                ScrollView {
                    if !isList {
                        LazyVGrid(columns: gridLayout, alignment: .center) {
                            ForEach(ipaSourceVM.filteredApps, id: \.bundleID) { app in
                                StoreAppView(selectedBackgroundColor: $selectedBackgroundColor,
                                             selectedTextColor: $selectedTextColor,
                                             selected: $selected,
                                             app: app,
                                             isList: isList)
                                .environmentObject(DownloadVM.shared)
                            }
                        }
                        .padding()
                        Spacer()
                    } else {
                        VStack {
                            ForEach(ipaSourceVM.filteredApps, id: \.bundleID) { app in
                                StoreAppView(selectedBackgroundColor: $selectedBackgroundColor,
                                             selectedTextColor: $selectedTextColor,
                                             selected: $selected,
                                             app: app,
                                             isList: isList)
                                .environmentObject(DownloadVM.shared)
                            }
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            if ipaSourceVM.sources.count == 0 {
                VStack {
                    Spacer()
                    Text("ipaLibrary.noSources.title")
                        .font(.title)
                        .padding(.bottom, 2)
                    Text("ipaLibrary.noSources.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("ipaLibrary.noSources.button", action: {
                        addSourcePresented.toggle()
                    })
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onTapGesture {
            selected = nil
        }
        .navigationTitle("sidebar.ipaLibrary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    addSourcePresented.toggle()
                }, label: {
                    Image(systemName: "plus")
                        .help("playapp.addSource")
                })
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("", selection: $isList) {
                    Image(systemName: "square.grid.2x2")
                        .tag(false)
                    Image(systemName: "list.bullet")
                        .tag(true)
                }.pickerStyle(.segmented)
            }
        }
        .searchable(text: $searchString, placement: .toolbar)
        .onChange(of: searchString) { value in
            uif.searchText = value
            ipaSourceVM.fetchApps()
        }
        .onChange(of: isList, perform: { value in
            UserDefaults.standard.set(value, forKey: "IPALibrayView")
        })
        .sheet(isPresented: $addSourcePresented) {
            AddSourceView(addSourceSheet: $addSourcePresented)
                .environmentObject(ipaSourceVM)
        }
    }
}
