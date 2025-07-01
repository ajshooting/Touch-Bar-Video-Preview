//
//  WindowController.swift
//  Touch Bar Preview
//
//  This Software is released under the MIT License
//
//  Copyright (c) 2017 Alexander Käßner
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  For more information see: https://github.com/touchbar/Touch-Bar-Preview
//

import Cocoa
import AVFoundation

@available(OSX 10.12.2, *)
extension NSTouchBar.CustomizationIdentifier {
    static let touchBarPreview = NSTouchBar.CustomizationIdentifier("com.alexkaessner.touch-bar-preview.touchBar")
}

@available(OSX 10.12.2, *)
extension NSTouchBarItem.Identifier {
    static let touchBarImageViewItem = NSTouchBarItem.Identifier("com.alexkaessner.touch-bar-preview.imageView")
}

class WindowController: NSWindowController {

    @IBOutlet var touchBarImageView: NSImageView!
    @IBOutlet weak var emptyLabel: NSTextField!
    
    @IBOutlet weak var imageViewSpaceConstraintLeft: NSLayoutConstraint!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    
    var titlebarAccessoryViewController : NSTitlebarAccessoryViewController!
    
    // Properties for video playback
    private var videoFrames: [NSImage] = []
    private var frameTimer: Timer?
    private var player: AVPlayer?
    private var currentFrameIndex = 0
    private var loopCount = 0
    private var isVideoPaused = false
    private var currentVideoURL: URL?
    private var targetFrameRate: Float = 15.0
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        if let ddvc: ViewController = self.window?.contentViewController as? ViewController {
            ddvc.windowDelegate = self
            print("Set windowDelegate for ViewController")
        } else {
            print("Error: Failed to get ViewController")
        }
        
        // Responder setting to receive key events
        self.window?.makeFirstResponder(self)
        self.window?.acceptsMouseMovedEvents = true
        
        // Accessory view controller to hold the "Download UI Kit" button as part of the window's titlebar.
        titlebarAccessoryViewController = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "titleBarAccessory")) as? NSTitlebarAccessoryViewController
        if let titlebarAccessoryViewController = titlebarAccessoryViewController {
            titlebarAccessoryViewController.layoutAttribute = .right
            self.window?.addTitlebarAccessoryViewController(titlebarAccessoryViewController)
        }
        
        // Touch Bar setup
        if #available(OSX 10.12.2, *) {
            // Touch Bar is automatically set up by makeTouchBar()
            print("Touch Bar support started")
        }
    }
    
    // MARK: - Touch Bar Setup
    
    // Touch Bar setup is done in makeTouchBar()
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        print("makeTouchBar called - normal mode")
        
        // Always use normal mode Touch Bar
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = .touchBarPreview
        touchBar.defaultItemIdentifiers = [.touchBarImageViewItem]
        touchBar.customizationAllowedItemIdentifiers = [.touchBarImageViewItem]
        touchBar.principalItemIdentifier = .touchBarImageViewItem
        
        // Settings for full-width display
        if #available(OSX 10.13, *) {
            touchBar.templateItems = Set([])
        }
        
        return touchBar
    }
    
    // MARK: - Key Events
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space key
            toggleVideoPlayback()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func toggleVideoPlayback() {
        guard !videoFrames.isEmpty else { return }
        
        if isVideoPaused {
            resumeVideoPlayback()
        } else {
            pauseVideoPlayback()
        }
    }
    
    private func pauseVideoPlayback() {
        guard !isVideoPaused else { return }
        
        isVideoPaused = true
        frameTimer?.invalidate()
        frameTimer = nil
        player?.pause()
        
        print("Video playback paused")
        if let viewController = self.window?.contentViewController as? ViewController {
            viewController.bottomBarInfoLable.stringValue = "Paused - Press space to resume"
        }
    }
    
    private func resumeVideoPlayback() {
        guard isVideoPaused else { return }
        
        isVideoPaused = false
        player?.play()
        
        print("Video playback resumed")
        if let viewController = self.window?.contentViewController as? ViewController {
            let fileName = currentVideoURL?.lastPathComponent ?? "Video"
            viewController.bottomBarInfoLable.stringValue = "Playing: \(fileName) - Press space to pause"
        }
        
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / TimeInterval(targetFrameRate), repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            guard self.currentFrameIndex < self.videoFrames.count && !self.videoFrames.isEmpty else {
                timer.invalidate()
                self.restartVideoPlayback()
                return
            }
            
            let currentFrame = self.videoFrames[self.currentFrameIndex]
            
            // Update main window ImageView
            if let mainImageView = (self.window?.contentViewController as? ViewController)?.imagePreviewView {
                mainImageView.image = currentFrame
            }
            
            // Update Touch Bar ImageView
            self.touchBarImageView?.image = currentFrame
            
            self.currentFrameIndex += 1
        }
    }
    
    
    // MARK: - Touch Bar
    
    @available(OSX 10.12.2, *)
    func showImageInTouchBar(with url: URL) {
        // Stop video playback
        stopVideoPlayback()
        
        if let touchbarImage = NSImage(contentsOf:url) {
            touchBarImageView?.image = touchbarImage
            
            // Settings for Touch Bar full-width display
            touchBarImageView?.imageScaling = .scaleAxesIndependently
            imageViewSpaceConstraintLeft?.constant = 0
            imageViewWidthConstraint?.constant = 685  // Touch Bar full width
            emptyLabel?.isHidden = true
        }
    }
    
    @available(OSX 10.12.2, *)
    func playVideoInTouchBar(with url: URL) {
        // Stop previous playback
        stopVideoPlayback()
        
        print("Starting: Video file processing - \(url.lastPathComponent)")
        
        let asset = AVAsset(url: url)
        
        // Pre-check asset loading possibility
        asset.loadValuesAsynchronously(forKeys: ["tracks", "duration", "playable", "hasProtectedContent"]) {
            var error: NSError? = nil
            let tracksStatus = asset.statusOfValue(forKey: "tracks", error: &error)
            let durationStatus = asset.statusOfValue(forKey: "duration", error: &error)
            let playableStatus = asset.statusOfValue(forKey: "playable", error: &error)
            
            DispatchQueue.main.async {
                // Basic loading check
                if tracksStatus == .failed || durationStatus == .failed || playableStatus == .failed {
                    print("Error: Failed to load video file - \(error?.localizedDescription ?? "Unknown error")")
                    if let viewController = self.window?.contentViewController as? ViewController {
                        viewController.bottomBarInfoLable.stringValue = "Error: Video file is corrupted or not supported"
                    }
                    return
                }
                
                // Playability check
                if !asset.isPlayable {
                    print("Error: Video file cannot be played (DRM protected, etc.)")
                    if let viewController = self.window?.contentViewController as? ViewController {
                        viewController.bottomBarInfoLable.stringValue = "Error: Protected video files cannot be played"
                    }
                    return
                }
                
                // Check for video track existence
                let videoTracks = asset.tracks(withMediaType: .video)
                if videoTracks.isEmpty {
                    print("Error: No video track found")
                    if let viewController = self.window?.contentViewController as? ViewController {
                        viewController.bottomBarInfoLable.stringValue = "Error: No video track found (audio-only file?)"
                    }
                    return
                }
                
                self.processVideoAsset(asset, url: url)
            }
        }
    }
    
    private func processVideoAsset(_ asset: AVAsset, url: URL) {
        // Check basic video information
        let duration = asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        print("Video duration: \(durationSeconds) seconds")
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("Error: No video track found")
            if let viewController = self.window?.contentViewController as? ViewController {
                viewController.bottomBarInfoLable.stringValue = "Error: No video track found"
            }
            return
        }
        
        let videoSize = videoTrack.naturalSize
        print("Original video size: \(videoSize.width) x \(videoSize.height)")
        
        // Handle videos that are too short
        guard durationSeconds > 0.1 else {
            print("Error: Video is too short")
            if let viewController = self.window?.contentViewController as? ViewController {
                viewController.bottomBarInfoLable.stringValue = "Error: Video is too short (requires 0.1+ seconds)"
            }
            return
        }
        
        // Prepare audio playback
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // Set up audio playback only if audio tracks exist
        let audioTracks = asset.tracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            print("Audio tracks found (\(audioTracks.count) tracks)")
            // Adjust audio volume (slightly reduced for Touch Bar use)
            player?.volume = 0.7
        } else {
            print("No audio tracks found (silent video)")
            player?.volume = 0
        }
        
        // Get video frame rate (default 15fps, adjusted for Touch Bar)
        let originalFrameRate = videoTrack.nominalFrameRate
        let targetFrameRate: Float = min(max(originalFrameRate, 5.0), 15.0) // Limited to 5-15fps range
        print("Original frame rate: \(originalFrameRate)fps, Target frame rate: \(targetFrameRate)fps")
        
        // Extract frames asynchronously (for faster processing)
        DispatchQueue.global(qos: .userInitiated).async {
            print("Starting frame extraction...")
            
            // Initial progress display
            DispatchQueue.main.async {
                if let viewController = self.window?.contentViewController as? ViewController {
                    viewController.bottomBarInfoLable.stringValue = "Converting video..."
                }
            }
            
            // Progress update callback
            let progressCallback: (Int, Int) -> Void = { current, total in
                DispatchQueue.main.async {
                    if let viewController = self.window?.contentViewController as? ViewController {
                        let percentage = Int((Double(current) / Double(total)) * 100)
                        viewController.bottomBarInfoLable.stringValue = "Converting: \(percentage)% (\(current)/\(total) frames)"
                    }
                }
            }
            
            let startTime = Date()
            self.videoFrames = self.extractFrames(from: asset, targetFrameRate: targetFrameRate, progressCallback: progressCallback)
            let processingTime = Date().timeIntervalSince(startTime)
            
            print("Extracted frames: \(self.videoFrames.count), processing time: \(String(format: "%.2f", processingTime)) seconds")
            
            DispatchQueue.main.async {
                guard !self.videoFrames.isEmpty else {
                    print("Error: No frames were extracted")
                    if let viewController = self.window?.contentViewController as? ViewController {
                        viewController.bottomBarInfoLable.stringValue = "Error: Failed to extract video frames"
                    }
                    return
                }
                
                print("Touch Bar playback started")
                
                // Reset playback state
                self.isVideoPaused = false
                self.currentVideoURL = url
                self.targetFrameRate = targetFrameRate
                
                // Update display for playback start
                if let viewController = self.window?.contentViewController as? ViewController {
                    viewController.bottomBarInfoLable.stringValue = "Playing video: \(url.lastPathComponent) (\(self.videoFrames.count) frames) - Press space to pause"
                }
                
                // Touch Bar layout adjustment - full width display
                self.touchBarImageView?.imageScaling = .scaleAxesIndependently
                self.imageViewSpaceConstraintLeft?.constant = 0
                self.imageViewWidthConstraint?.constant = 685  // Touch Bar full width
                self.emptyLabel?.isHidden = true
                
                // Start playback
                self.player?.play()
                self.currentFrameIndex = 0
                self.frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / TimeInterval(targetFrameRate), repeats: true) { [weak self] timer in
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }
                    
                    guard self.currentFrameIndex < self.videoFrames.count && !self.videoFrames.isEmpty else {
                        timer.invalidate()
                        // Loop playback
                        self.restartVideoPlayback()
                        return
                    }
                    
                    let currentFrame = self.videoFrames[self.currentFrameIndex]
                    
                    // Update main window ImageView
                    if let mainImageView = (self.window?.contentViewController as? ViewController)?.imagePreviewView {
                        mainImageView.image = currentFrame
                    }
                    
                    // Update Touch Bar ImageView
                    self.touchBarImageView?.image = currentFrame
                    
                    self.currentFrameIndex += 1
                }
            }
        }
    }
    
    private func extractFrames(from asset: AVAsset, targetFrameRate: Float, progressCallback: @escaping (Int, Int) -> Void) -> [NSImage] {
        print("extractFrames started")
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        // Get original video resolution
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("Video track not found")
            return []
        }
        
        let originalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let adjustedSize = CGSize(width: abs(originalSize.width), height: abs(originalSize.height))
        
        print("Original video resolution: \(adjustedSize)")
        
        // Resolution setting: Based on actual Touch Bar display size
        let touchBarWidth: CGFloat = 685   // Actual Touch Bar display width
        let touchBarHeight: CGFloat = 30   // Actual Touch Bar display height
        
        let minWidth = touchBarWidth * 4   // 4x resolution for sufficient quality
        let minHeight = touchBarHeight * 4
        
        let targetWidth = max(adjustedSize.width, minWidth)
        let targetHeight = max(adjustedSize.height, minHeight)
        
        imageGenerator.maximumSize = CGSize(width: targetWidth, height: targetHeight)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        imageGenerator.apertureMode = .cleanAperture
        
        print("Frame extraction resolution: \(targetWidth) x \(targetHeight)")
        
        let videoDuration = asset.duration
        let durationSeconds = CMTimeGetSeconds(videoDuration)
        let frameInterval = 1.0 / Double(targetFrameRate)
        let totalFrames = Int(durationSeconds / frameInterval)
        
        print("Video duration: \(durationSeconds) seconds, frame interval: \(frameInterval) seconds, total frames: \(totalFrames)")
        
        // Limit maximum frame count (to control memory usage)
        let maxFrames = min(totalFrames, 450) // Maximum 30 seconds equivalent (15fps)
        var frames: [NSImage] = []
        
        // Use higher precision timescale
        let timeScale: CMTimeScale = 600
        
        // Synchronous frame extraction (ensures reliable execution)
        for i in 0..<maxFrames {
            let timeSeconds = Double(i) * frameInterval
            let time = CMTime(seconds: timeSeconds, preferredTimescale: timeScale)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let croppedImage = self.cropImageForTouchBar(image: NSImage(cgImage: cgImage, size: .zero))
                frames.append(croppedImage)
                
                // Progress update (every 10 frames)
                if (i + 1) % 10 == 0 || i == maxFrames - 1 {
                    progressCallback(i + 1, maxFrames)
                }
                
            } catch {
                // Duplicate previous frame for error frames (for smooth playback)
                if !frames.isEmpty, let lastFrame = frames.last {
                    frames.append(lastFrame)
                }
            }
        }
        
        print("extractFrames completed: \(frames.count) frames extracted")
        return frames
    }
    
    private func stopVideoPlayback() {
        print("Video playback stopped")
        frameTimer?.invalidate()
        frameTimer = nil
        player?.pause()
        player = nil
        videoFrames.removeAll()
        currentFrameIndex = 0
        loopCount = 0
        isVideoPaused = false
        currentVideoURL = nil
        
        // Reset Touch Bar state
        touchBarImageView?.image = nil
        
        // Reset UI
        if let viewController = self.window?.contentViewController as? ViewController {
            viewController.bottomBarInfoLable.stringValue = "Touch Bar Preview"
        }
    }
    
    private func restartVideoPlayback() {
        guard !videoFrames.isEmpty else { return }
        
        loopCount += 1
        print("Loop playback started (Loop \(loopCount))")
        player?.seek(to: kCMTimeZero)
        player?.play()
        currentFrameIndex = 0
        
        // Update display for loop playback
        if let viewController = self.window?.contentViewController as? ViewController {
            viewController.bottomBarInfoLable.stringValue = "Looping video (Loop \(loopCount))"
        }
        
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / TimeInterval(self.targetFrameRate), repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            guard self.currentFrameIndex < self.videoFrames.count && !self.videoFrames.isEmpty else {
                timer.invalidate()
                self.restartVideoPlayback()
                return
            }
            
            let currentFrame = self.videoFrames[self.currentFrameIndex]
            
            // Update main window ImageView
            if let mainImageView = (self.window?.contentViewController as? ViewController)?.imagePreviewView {
                mainImageView.image = currentFrame
            }
            
            // Update Touch Bar ImageView
            self.touchBarImageView?.image = currentFrame
            
            self.currentFrameIndex += 1
        }
    }
    
    private func cropImageForTouchBar(image: NSImage) -> NSImage {
        let targetSize = NSSize(width: 685, height: 30)  // Touch Bar full width size
        let sourceSize = image.size
        
        // Calculate aspect ratio
        let sourceAspectRatio = sourceSize.width / sourceSize.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        // Create high-quality image
        let croppedImage = NSImage(size: targetSize)
        croppedImage.lockFocus()
        
        // High-quality rendering settings
        if let context = NSGraphicsContext.current?.cgContext {
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.interpolationQuality = .high
        }
        
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true
        
        let targetRect = NSRect(origin: .zero, size: targetSize)
        
        // Crop to fit Touch Bar full width
        var cropRect: NSRect
        
        if sourceAspectRatio > targetAspectRatio {
            // If original image is wider, fit to height and crop center horizontally
            let cropWidth = sourceSize.height * targetAspectRatio
            cropRect = NSRect(
                x: (sourceSize.width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: sourceSize.height
            )
        } else {
            // If original image is taller, fit to width and crop center vertically
            let cropHeight = sourceSize.width / targetAspectRatio
            cropRect = NSRect(
                x: 0,
                y: (sourceSize.height - cropHeight) / 2,
                width: sourceSize.width,
                height: cropHeight
            )
        }
        
        // High-quality drawing
        image.draw(in: targetRect, from: cropRect, operation: .copy, fraction: 1.0, respectFlipped: false, hints: [
            .interpolation: NSImageInterpolation.high.rawValue
        ])
        
        croppedImage.unlockFocus()
        return croppedImage
    }
}

// MARK: - NSTouchBarDelegate

@available(OSX 10.12.2, *)
extension WindowController: NSTouchBarDelegate {
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .touchBarImageViewItem:
            // Touch Bar item
            let item = NSCustomTouchBarItem(identifier: identifier)
            
            // Use existing ImageView defined as IBOutlet
            if let existingImageView = touchBarImageView {
                // Settings for Touch Bar full-width display
                existingImageView.imageScaling = .scaleAxesIndependently
                existingImageView.imageAlignment = .alignCenter
                
                item.view = existingImageView
                item.customizationLabel = "Touch Bar Preview"
                return item
            }
            
            // Fallback: Create new ImageView
            let imageView = NSImageView()
            imageView.imageScaling = .scaleAxesIndependently  // Full width display
            imageView.imageAlignment = .alignCenter
            
            // Size settings for Touch Bar full width usage
            let fullWidth: CGFloat = 685   // Touch Bar full width
            let height: CGFloat = 30       // Touch Bar height
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            // Set constraints for full width usage
            let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: fullWidth)
            let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: height)
            
            widthConstraint.priority = NSLayoutConstraint.Priority.required
            heightConstraint.priority = NSLayoutConstraint.Priority.required
            
            widthConstraint.isActive = true
            heightConstraint.isActive = true
            
            item.view = imageView
            item.customizationLabel = "Touch Bar Preview"
            
            return item
            
        default:
            return nil
        }
    }
}

