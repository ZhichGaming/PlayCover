//
//  Store.swift
//  PlayCover
//
//  Created by Isaac Marovitz on 06/08/2022.
//

import Foundation

class StoreVM: ObservableObject {

    static let shared = StoreVM()

    private init() {
        sourcesUrl = PlayTools.playCoverContainer
            .appendingPathComponent("Sources")
            .appendingPathExtension("plist")
        keymapSourcesUrl = PlayTools.playCoverContainer
            .appendingPathComponent("Keymap Sources")
            .appendingPathExtension("plist")
        sources = []
        keymapSources = []
        if !decode(&sources, sourcesUrl) {
            encode(sources, sourcesUrl)
        }
        if !decode(&keymapSources, keymapSourcesUrl) {
            encode(keymapSources, keymapSourcesUrl)
        }
        resolveSources()
    }

    @Published var apps: [StoreAppData] = []
    @Published var filteredApps: [StoreAppData] = []
    @Published var sources: [SourceData] {
        didSet {
            encode(sources, sourcesUrl)
        }
    }

    @Published var keymaps: [KeymapData] = []
    @Published var keymapSources: [SourceData] {
        didSet {
            encode(keymapSources, keymapSourcesUrl)
        }
    }

    let sourcesUrl: URL
    let keymapSourcesUrl: URL

    @discardableResult
    public func decode(_ sources: inout [SourceData], _ sourceUrl: URL) -> Bool {
        do {
            let data = try Data(contentsOf: sourceUrl)
            sources = try PropertyListDecoder().decode([SourceData].self, from: data)

            return true
        } catch {
            print(error)
            return false
        }
    }

    @discardableResult
    public func encode(_ sources: [SourceData], _ sourcesUrl: URL) -> Bool {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml

        do {
            let data = try encoder.encode(sources)
            try data.write(to: sourcesUrl)

            return true
        } catch {
            print(error)
            return false
        }
    }

    func appendAppData(_ data: [StoreAppData]) {
        for element in data {
            if let index = apps.firstIndex(where: {$0.bundleID == element.bundleID}) {
                if apps[index].version < element.version {
                    apps[index] = element
                    continue
                }
            } else {
                apps.append(element)
            }
        }
        fetchApps()
    }

    func appendKeymapData(_ data: [KeymapFolderSourceData]) {
        for element in data {
            DispatchQueue.global(qos: .userInteractive).async {
                do {
                    let contents = try String(contentsOf: URL(string: element.url)!)
                    let jsonData = contents.data(using: .utf8)!
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let data: [KeymapSourceData] = try decoder.decode([KeymapSourceData].self, from: jsonData)

                    for source in data where source.name.contains(".playmap") {
                        var keymapData = KeymapData()
                        keymapData.bundleID = element.name
                        keymapData.htmlUrl = element.htmlUrl

                        keymapData.name = source.name.replacingOccurrences(of: ".playmap", with: "")
                        keymapData.url = source.downloadUrl
                        keymapData.repoName = self.getRepoName(source.downloadUrl)
                        DispatchQueue.main.async {
                            self.keymaps.append(keymapData)
                        }
                    }
                } catch {
                    Log.shared.error(error)
                }
            }
        }
    }

    func getRepoName(_ downloadLink: String) -> String {
        var downloadLink = downloadLink

        if let reposRange = downloadLink.range(of: "https://raw.githubusercontent.com/") {
            downloadLink.removeSubrange(downloadLink.startIndex..<reposRange.upperBound)
        }

        let sourceComponents = downloadLink.components(separatedBy: "/")

        return "\(sourceComponents[0])/\(sourceComponents[1]) (\(sourceComponents[2]))"
    }

    func fetchApps() {
        var result = apps
        if !uif.searchText.isEmpty {
            result = result.filter({
                $0.name.lowercased().contains(uif.searchText.lowercased())
            })
        }
        filteredApps = result
    }

    func resolveSources() {
        if !NetworkVM.isConnectedToNetwork() { return }

        for index in 0..<sources.endIndex {
            sources[index].status = .checking
            DispatchQueue.global(qos: .userInteractive).async {
                guard let url = URL(string: self.sources[index].source) else {
                    DispatchQueue.main.async {
                        self.sources[index].status = .badurl
                    }
                    return
                }

                do {
                    let contents = try String(contentsOf: url)
                    let jsonData = contents.data(using: .utf8)!
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let data: [StoreAppData] = try decoder.decode([StoreAppData].self, from: jsonData)
                        if data.count > 0 {
                            DispatchQueue.main.async {
                                self.sources[index].status = .valid
                                self.appendAppData(data)
                            }
                            return
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.sources[index].status = .badjson
                        }
                            return
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.sources[index].status = .badurl
                    }
                    return
                }
            }
        }

        for index in 0..<keymapSources.endIndex {
            keymapSources[index].status = .checking
            DispatchQueue.global(qos: .userInteractive).async {
                guard let url = URL(string: self.keymapSources[index].source) else {
                    DispatchQueue.main.async {
                        self.keymapSources[index].status = .badurl
                    }
                    return
                }

                do {
                    let contents = try String(contentsOf: url)
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
                                DispatchQueue.main.async {
                                    self.keymapSources[index].status = .valid
                                    self.appendKeymapData(data)
                                }
                                return
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.keymapSources[index].status = .badjson
                        }
                        return
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.keymapSources[index].status = .badurl
                    }
                    return
                }
            }
        }

        apps.removeAll()
        fetchApps()
    }

    func deleteSource(_ sources: inout [SourceData], _ selected: inout Set<UUID>) {
        // TODO: Fix crash
        sources.removeAll(where: { selected.contains($0.id) })
        selected.removeAll()
        resolveSources()
    }

    func moveSourceUp(_ sources: inout [SourceData], _ selected: inout Set<UUID>) {
        let selectedData = sources.filter({ selected.contains($0.id) })
        var index = sources.firstIndex(of: selectedData.first!)! - 1
        sources.removeAll(where: { selected.contains($0.id) })
        if index < 0 {
            index = 0
        }
        sources.insert(contentsOf: selectedData, at: index)
    }

    func moveSourceDown(_ sources: inout [SourceData], _ selected: inout Set<UUID>) {
        let selectedData = sources.filter({ selected.contains($0.id) })
        var index = sources.firstIndex(of: selectedData.first!)! + 1
        sources.removeAll(where: { selected.contains($0.id) })
        if index > sources.endIndex {
            index = sources.endIndex
        }
        sources.insert(contentsOf: selectedData, at: index)
    }

    func appendSourceData(_ sources: inout [SourceData], _ data: SourceData) {
        if sources.contains(where: { $0.source == data.source }) {
            Log.shared.error("This URL already exists!")
            return
        }

        sources.append(data)
        self.resolveSources()
    }
}

struct StoreAppData: Codable, Equatable {
    var bundleID: String
    let name: String
    let version: String
    let itunesLookup: String
    let link: String
}

struct KeymapFolderSourceData: Codable, Equatable {
    let name: String
    let url: String
    let htmlUrl: String
}

struct KeymapSourceData: Codable, Equatable {
    let name: String
    let downloadUrl: String
}

struct KeymapData: Codable, Equatable, Hashable {
    var bundleID: String = ""
    var name: String = ""
    var htmlUrl: String = ""
    var url: String = ""
    var repoName: String = ""
}
