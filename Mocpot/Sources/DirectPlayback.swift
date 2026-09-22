import AppKit
import CMPV
import OpenGL.GL3

/// The control queue never waits on AppKit or the render thread.
final class MPVLibrary {
    static let shared: MPVLibrary? = try? MPVLibrary()
    let library: UnsafeMutableRawPointer
    let create: @convention(c) () -> OpaquePointer?
    let initialize: @convention(c) (OpaquePointer?) -> Int32
    let terminate: @convention(c) (OpaquePointer?) -> Void
    let option: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32
    let set: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32
    let get: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, mpv_format, UnsafeMutableRawPointer?) -> Int32
    let string: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
    let free: @convention(c) (UnsafeMutableRawPointer?) -> Void
    let command: @convention(c) (OpaquePointer?, UInt64, UnsafePointer<UnsafePointer<CChar>?>?) -> Int32
    let event: @convention(c) (OpaquePointer?, Double) -> UnsafeMutablePointer<mpv_event>?
    let renderCreate: @convention(c) (UnsafeMutablePointer<OpaquePointer?>?, OpaquePointer?, UnsafeMutablePointer<mpv_render_param>?) -> Int32
    let render: @convention(c) (OpaquePointer?, UnsafeMutablePointer<mpv_render_param>?) -> Int32
    let renderFree: @convention(c) (OpaquePointer?) -> Void
    let renderCallback: @convention(c) (OpaquePointer?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?, UnsafeMutableRawPointer?) -> Void

    init(path: String? = nil) throws {
        let url = (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("DirectPlayback/libmpv.2.dylib")
        guard let library = dlopen(path ?? ProcessInfo.processInfo.environment["MOCPOT_MPV_LIBRARY"] ?? url.path, RTLD_NOW | RTLD_LOCAL) else {
            throw FormatCompatibility.Failure(message: "直接播放组件无法加载。请安装完整版本。")
        }
        self.library = library
        func symbol<T>(_ name: String, _: T.Type) throws -> T {
            guard let pointer = dlsym(library, name) else { throw FormatCompatibility.Failure(message: "播放组件缺少 \(name)") }
            return unsafeBitCast(pointer, to: T.self)
        }
        create = try symbol("mpv_create", type(of: create))
        initialize = try symbol("mpv_initialize", type(of: initialize))
        terminate = try symbol("mpv_terminate_destroy", type(of: terminate))
        option = try symbol("mpv_set_option_string", type(of: option))
        set = try symbol("mpv_set_property_string", type(of: set))
        get = try symbol("mpv_get_property", type(of: get))
        string = try symbol("mpv_get_property_string", type(of: string))
        free = try symbol("mpv_free", type(of: free))
        command = try symbol("mpv_command_async", type(of: command))
        event = try symbol("mpv_wait_event", type(of: event))
        renderCreate = try symbol("mpv_render_context_create", type(of: renderCreate))
        render = try symbol("mpv_render_context_render", type(of: render))
        renderFree = try symbol("mpv_render_context_free", type(of: renderFree))
        renderCallback = try symbol("mpv_render_context_set_update_callback", type(of: renderCallback))
    }
}

final class DirectPlayback {
    struct Track { let id: Int; let title: String; let language: String }
    struct State {
        var time: Double = 0, duration: Double = 0
        var width = 0, height = 0
        var loaded = false, paused = true, seeking = false, ended = false
        var subtitleText = ""
        var error: String?
        var audio: [Track] = [], subtitles: [Track] = []
    }
    let api: MPVLibrary
    let handle: OpaquePointer
    let url: URL
    private let queue = DispatchQueue(label: "com.mocpot.direct.control", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var state = State()
    private var closed = false
    private var terminated = false // Access only on the control queue.
    private var started = false
    private var appliedProperties: [String: String] = [:]
    var onState: ((State) -> Void)?
    weak var view: DirectVideoView?

    init(url: URL, library: MPVLibrary? = MPVLibrary.shared) throws {
        guard let api = library, let handle = api.create() else { throw FormatCompatibility.Failure(message: "无法初始化直接播放组件。") }
        self.api = api; self.handle = handle; self.url = url
        // No user mpv config, scripts, network playlists or automatic external-file loading.
        for (key, value) in ["vo": "libmpv", "config": "no", "load-scripts": "no", "ytdl": "no", "osc": "no", "input-default-bindings": "no", "input-vo-keyboard": "no", "terminal": "no", "audio-display": "no", "autoload-files": "no", "sub-auto": "no", "audio-file-auto": "no", "osd-level": "0", "sid": "no", "sub-visibility": "no", "pause": "yes", "keep-open": "yes", "hwdec": "auto-safe", "demuxer-max-bytes": "67108864", "demuxer-max-back-bytes": "16777216", "demuxer-lavf-o": "protocol_whitelist=file,pipe", "access-references": "no"] {
            _ = api.option(handle, key, value)
        }
        if ["ts", "mts", "m2ts"].contains(url.pathExtension.lowercased()) { _ = api.option(handle, "hr-seek-demuxer-offset", "2") }
        guard api.initialize(handle) >= 0 else { api.terminate(handle); throw FormatCompatibility.Failure(message: "直接播放组件初始化失败。") }
    }

    func start() {
        guard !closed, !started else { return }
        started = true
        command(["loadfile", url.path, "replace"])
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(100))
        source.setEventHandler { [weak self] in self?.poll() }
        timer = source
        source.resume()
    }

    func set(_ name: String, _ value: String) {
        guard !closed else { return }
        if name != "pause", appliedProperties[name] == value { return }
        appliedProperties[name] = value
        let api = api, handle = handle
        queue.async { _ = api.set(handle, name, value) }
    }
    func command(_ arguments: [String]) {
        guard !closed else { return }
        let api = api, handle = handle
        queue.async {
            let strings = arguments.map { strdup($0)! }
            defer { strings.forEach { Darwin.free($0) } }
            let pointers: [UnsafePointer<CChar>?] = strings.map { UnsafePointer($0) } + [nil]
            pointers.withUnsafeBufferPointer { _ = api.command(handle, 0, $0.baseAddress) }
        }
    }
    func property(_ name: String) async -> String {
        guard !closed else { return "" }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in continuation.resume(returning: terminated ? "" : value(name)) }
        }
    }
    func seek(_ time: Double) { command(["seek", String(time), "absolute+exact"]) }
    func shutdown() {
        guard !closed else { return }
        closed = true
        onState = nil
        timer?.cancel(); timer = nil
        view?.releaseRenderer()
        let api = api, handle = handle
        queue.async { [self] in terminated = true; api.terminate(handle) }
    }
    deinit { if !closed { let api = api, handle = handle; timer?.cancel(); queue.async { api.terminate(handle) } } }

    private func value(_ name: String) -> String {
        guard let pointer = api.string(handle, name) else { return "" }
        defer { api.free(pointer) }
        return String(cString: pointer)
    }
    private func number(_ name: String) -> Double {
        var result = 0.0
        _ = api.get(handle, name, MPV_FORMAT_DOUBLE, &result)
        return result.isFinite ? result : 0
    }
    private func poll() {
        guard !terminated else { return }
        var ended = false
        while let event = api.event(handle, 0)?.pointee, event.event_id != MPV_EVENT_NONE {
            if event.event_id == MPV_EVENT_FILE_LOADED { state.loaded = true }
            if event.event_id == MPV_EVENT_END_FILE, let data = event.data?.assumingMemoryBound(to: mpv_event_end_file.self).pointee {
                if data.reason == MPV_END_FILE_REASON_ERROR { state.error = "无法直接解码这个文件（错误 \(data.error)）。" }
                if data.reason == MPV_END_FILE_REASON_EOF { ended = true }
            }
        }
        state.subtitleText = value("sub-text")
        state.time = number("time-pos"); state.duration = number("duration")
        state.width = Int(number("video-params/dw")); state.height = Int(number("video-params/dh"))
        state.paused = value("pause") == "yes"; state.seeking = value("seeking") == "yes"
        let eof = value("eof-reached") == "yes"
        ended = ended || (eof && !state.ended)
        state.ended = eof
        if state.loaded && state.audio.isEmpty && state.subtitles.isEmpty {
            for index in 0..<min(128, Int(number("track-list/count"))) {
                let prefix = "track-list/\(index)/"
                let id = Int(number(prefix + "id")), kind = value(prefix + "type")
                let title = value(prefix + "title"), language = value(prefix + "lang")
                let track = Track(id: id, title: title.isEmpty ? "\(kind == "audio" ? "音轨" : "内嵌字幕") \(id)" : title, language: language)
                if kind == "audio" { state.audio.append(track) }
                if kind == "sub" { state.subtitles.append(track) }
            }
        }
        var snapshot = state
        snapshot.ended = ended
        DispatchQueue.main.async { [weak self] in guard let self, !self.closed else { return }; self.onState?(snapshot) }
    }
}
