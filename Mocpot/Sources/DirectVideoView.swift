import SwiftUI
import AppKit
import OpenGL.GL3
import CMPV

struct DirectPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    let playback: DirectPlayback
    var body: some View {
        PlaybackChrome {
            DirectVideoContainer(playback: playback, viewModel: viewModel)
        }
    }
}
struct DirectVideoContainer: NSViewRepresentable {
    let playback: DirectPlayback
    let viewModel: PlayerViewModel
    func makeNSView(context: Context) -> DirectVideoView {
        let view = DirectVideoView(playback: playback)
        view.viewModel = viewModel
        return view
    }
    func updateNSView(_ view: DirectVideoView, context: Context) {
        view.viewModel = viewModel
        view.needsDisplay = true
    }
    static func dismantleNSView(_ view: DirectVideoView, coordinator: ()) { view.releaseRenderer() }
}

final class DirectVideoView: NSOpenGLView {
    private static let glLibrary = dlopen("/System/Library/Frameworks/OpenGL.framework/OpenGL", RTLD_NOW)!
    let playback: DirectPlayback
    weak var viewModel: PlayerViewModel?
    private var renderer: OpaquePointer?
    private var texture: GLuint = 0, framebuffer: GLuint = 0, program: GLuint = 0, vao: GLuint = 0
    private var textureWidth = 0, textureHeight = 0
    var yaw: Float = 0, pitch: Float = 0, fieldOfView: Float = 80
    private var dragDistance: CGFloat = 0
    private var pendingClick: DispatchWorkItem?
    private(set) var renderedFrames = 0
    private(set) var hasVideoFrame = false

    init(playback: DirectPlayback) {
        self.playback = playback
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(NSOpenGLPFAAccelerated), UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAColorSize), 24, UInt32(NSOpenGLPFAAlphaSize), 8, 0]
        super.init(frame: .zero, pixelFormat: NSOpenGLPixelFormat(attributes: attributes)!)!
        wantsBestResolutionOpenGLSurface = true
        playback.view = self
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func prepareOpenGL() {
        super.prepareOpenGL()
        guard renderer == nil, let context = openGLContext else { return }
        context.makeCurrentContext()
        var interval: GLint = 1
        context.setValues(&interval, for: .swapInterval)
        var initParams = mpv_opengl_init_params(get_proc_address: { _, name in
            guard let name else { return nil }; return dlsym(DirectVideoView.glLibrary, name)
        }, get_proc_address_ctx: nil)
        let result = "opengl".withCString { apiName in
            withUnsafeMutablePointer(to: &initParams) { pointer in
                var parameters = [mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(mutating: apiName)),
                                  mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: pointer), mpv_render_param()]
                return playback.api.renderCreate(&renderer, playback.handle, &parameters)
            }
        }
        guard result >= 0, renderer != nil else {
            viewModel?.isLoading = false
            viewModel?.playbackError = "无法创建视频渲染器（\(result)）。"
            return
        }
        playback.api.renderCallback(renderer, { opaque in
            guard let opaque else { return }
            let view = Unmanaged<DirectVideoView>.fromOpaque(opaque).takeUnretainedValue()
            DispatchQueue.main.async { [weak view] in view?.needsDisplay = true }
        }, Unmanaged.passUnretained(self).toOpaque())
        program = makeProgram()
        glGenVertexArrays(1, &vao)
        glGenTextures(1, &texture)
        glGenFramebuffers(1, &framebuffer)
        playback.start()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let renderer, let context = openGLContext, program != 0 else { return }
        context.makeCurrentContext()
        let size = convertToBacking(bounds).size
        let width = max(1, Int(size.width)), height = max(1, Int(size.height))
        let sourceWidth = max(1, viewModel?.videoMetadata.width ?? width)
        let sourceHeight = max(1, viewModel?.videoMetadata.height ?? height)
        let scale = min(1.0, 4096.0 / Double(max(sourceWidth, sourceHeight)))
        let tw = max(1, Int(Double(sourceWidth) * scale)), th = max(1, Int(Double(sourceHeight) * scale))
        if tw != textureWidth || th != textureHeight {
            textureWidth = tw; textureHeight = th
            glBindTexture(GLenum(GL_TEXTURE_2D), texture)
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA8, GLsizei(tw), GLsizei(th), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
            glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), texture, 0)
        }
        var fbo = mpv_opengl_fbo(fbo: Int32(framebuffer), w: Int32(tw), h: Int32(th), internal_format: GL_RGBA8)
        withUnsafeMutablePointer(to: &fbo) { pointer in
            var params = [mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: pointer), mpv_render_param()]
            _ = playback.api.render(renderer, &params)
        }
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        glViewport(0, 0, GLsizei(width), GLsizei(height))
        glClearColor(0, 0, 0, 1); glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glUseProgram(program); glBindVertexArray(vao)
        glActiveTexture(GLenum(GL_TEXTURE0)); glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        glUniform1i(glGetUniformLocation(program, "video"), 0)
        glUniform1f(glGetUniformLocation(program, "aspect"), Float(width) / Float(height))
        glUniform1f(glGetUniformLocation(program, "sourceAspect"), Float(tw) / Float(th))
        glUniform3f(glGetUniformLocation(program, "camera"), yaw, pitch, fieldOfView * .pi / 180)
        let vr = viewModel?.vrMode != VRMode.none && viewModel?.vrMode != nil
        var mode: GLint = vr ? 1 : 0
        if !vr, viewModel?.threeDMode == .sideBySide { mode = 2 }
        if !vr, viewModel?.threeDMode == .overUnder { mode = 3 }
        glUniform1i(glGetUniformLocation(program, "mode"), mode)
        let fill = viewModel?.videoLayout == .fill || viewModel?.videoLayout == .centerCrop
        glUniform1i(glGetUniformLocation(program, "layoutMode"), viewModel?.videoLayout == .stretch ? 2 : (fill ? 1 : 0))
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        glBindVertexArray(0); glUseProgram(0)
        context.flushBuffer()
        renderedFrames += 1
        if (viewModel?.videoMetadata.width ?? 0) > 0 { hasVideoFrame = true }
    }

    func screenshotPNG() -> Data? {
        guard renderer != nil else { return nil }
        openGLContext?.makeCurrentContext()
        let size = convertToBacking(bounds).size
        let w = Int(size.width), h = Int(size.height)
        guard w > 0, h > 0, w <= 16384, h <= 16384,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32), let destination = bitmap.bitmapData else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        glReadBuffer(GLenum(GL_FRONT))
        glReadPixels(0, 0, GLsizei(w), GLsizei(h), GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &pixels)
        pixels.withUnsafeBytes { source in
            for row in 0..<h { memcpy(destination.advanced(by: row * w * 4), source.baseAddress!.advanced(by: (h - 1 - row) * w * 4), w * 4) }
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    func releaseRenderer() {
        pendingClick?.cancel()
        guard let renderer else { return }
        openGLContext?.makeCurrentContext()
        playback.api.renderCallback(renderer, nil, nil)
        playback.api.renderFree(renderer)
        self.renderer = nil
        glDeleteTextures(1, &texture); glDeleteFramebuffers(1, &framebuffer)
        glDeleteVertexArrays(1, &vao); glDeleteProgram(program)
        program = 0
    }
    private func makeProgram() -> GLuint {
        let vertex = """
        #version 150
        out vec2 uv;
        void main() {
            vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
            uv = p; gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
        }
        """
        let fragment = """
        #version 150
        uniform sampler2D video;
        uniform float aspect, sourceAspect;
        uniform vec3 camera;
        uniform int mode, layoutMode;
        in vec2 uv; out vec4 color;
        void main() {
            vec2 t = uv;
            float a = aspect;
            if (mode == 1) {
                vec2 p = (uv * 2.0 - 1.0) * tan(camera.z * 0.5);
                vec3 d = normalize(vec3(p.x * aspect, p.y, -1.0));
                float c = cos(camera.y), s = sin(camera.y);
                d.yz = mat2(c, s, -s, c) * d.yz;
                c = cos(camera.x); s = sin(camera.x);
                d.xz = mat2(c, s, -s, c) * d.xz;
                t = vec2(atan(d.x, -d.z) / 6.2831853 + 0.5, asin(clamp(d.y,-1.0,1.0)) / 3.14159265 + 0.5);
            } else {
                if (mode == 2) { t.x = fract(t.x * 2.0); a *= 0.5; }
                if (mode == 3) { t.y = fract(t.y * 2.0); a *= 2.0; }
                vec2 scale = vec2(1.0);
                if (layoutMode == 0) { if (a > sourceAspect) scale.x = a / sourceAspect; else scale.y = sourceAspect / a; }
                if (layoutMode == 1) { if (a > sourceAspect) scale.y = sourceAspect / a; else scale.x = a / sourceAspect; }
                t = (t - 0.5) * scale + 0.5;
            }
            t.y = 1.0 - t.y;
            color = any(lessThan(t, vec2(0))) || any(greaterThan(t, vec2(1))) ? vec4(0,0,0,1) : texture(video, t);
        }
        """
        func compile(_ source: String, _ type: GLenum) -> GLuint {
            let shader = glCreateShader(type)
            source.withCString { string in var pointer: UnsafePointer<GLchar>? = string; glShaderSource(shader, 1, &pointer, nil) }
            glCompileShader(shader)
            var okay: GLint = 0; glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &okay)
            if okay == 0 { glDeleteShader(shader); return 0 }
            return shader
        }
        let v = compile(vertex, GLenum(GL_VERTEX_SHADER)), f = compile(fragment, GLenum(GL_FRAGMENT_SHADER))
        guard v != 0, f != 0 else { return 0 }
        let program = glCreateProgram(); glAttachShader(program, v); glAttachShader(program, f)
        glLinkProgram(program); glDeleteShader(v); glDeleteShader(f)
        return program
    }
    override func mouseDown(with event: NSEvent) { pendingClick?.cancel(); dragDistance = 0 }
    override func mouseDragged(with event: NSEvent) {
        guard viewModel?.vrMode != VRMode.none else { return }
        dragDistance += abs(event.deltaX) + abs(event.deltaY)
        yaw -= Float(event.deltaX) * 0.006
        pitch = max(-1.45, min(1.45, pitch + Float(event.deltaY) * 0.006))
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            if viewModel?.vrMode != VRMode.none { yaw = 0; pitch = 0; fieldOfView = 80; needsDisplay = true }
            else { viewModel?.performClickAction(doubleClick: true) }
        } else if dragDistance < 3 {
            let task = DispatchWorkItem { [weak self] in self?.viewModel?.performClickAction() }
            pendingClick = task; DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: task)
        }
    }
    override func scrollWheel(with event: NSEvent) {
        if viewModel?.vrMode != VRMode.none && viewModel?.scrollAction == "缩放" { fieldOfView = max(35, min(110, fieldOfView + Float(event.scrollingDeltaY) * 0.15)); needsDisplay = true }
        else { viewModel?.handleScroll(event.scrollingDeltaY) }
    }
    override func rightMouseDown(with event: NSEvent) { viewModel?.handleRightClick(event, in: self) }
    override func magnify(with event: NSEvent) {
        guard viewModel?.pinchToZoom == true else { return }
        if viewModel?.vrMode != VRMode.none { fieldOfView = max(35, min(110, fieldOfView - Float(event.magnification) * 60)); needsDisplay = true }
        else { viewModel?.videoZoom = max(0.25, min(4, (viewModel?.videoZoom ?? 1) * (1 + event.magnification))) }
    }
    override func swipe(with event: NSEvent) { viewModel?.handleSwipe(event.deltaX) }
}
