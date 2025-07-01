//
//  ViewController.swift
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
import UniformTypeIdentifiers

class ViewController: NSViewController {
    
    @IBOutlet var dropDestinationView: DropDestinationView!
    @IBOutlet weak var imagePreviewView: NSImageView!
    
    @IBOutlet weak var bottomBarInfoLable: NSTextField!
    @IBOutlet weak var bottomBarAlertImageWidth: NSLayoutConstraint!

    public var windowDelegate: WindowController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        dropDestinationView.delegate = self
        
        // "hide" alert icon in bottom bar
        bottomBarAlertImageWidth.constant = 0.0
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDockIconDrop), name: NSNotification.Name("dropFileOnDock"), object: nil)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @objc func handleDockIconDrop(notification: Notification) {
        
        let fileName = notification.object as! String
        let urlString = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        let url = URL(string: "file://\(urlString)")
        
        if (url != nil) {
            processImageURLs([url!])
            
            // hide the drag and drop icon
            NotificationCenter.default.post(name: NSNotification.Name("hideDragAndDropIcon"), object: nil)
        }else {
            print("could not import image from icon drag")
        }
    }

}

// MARK: - DropDestinationViewDelegate
extension ViewController: DropDestinationViewDelegate {
    
    func processImageURLs(_ urls: [URL]) {
        for (_,url) in urls.enumerated() {
            
            // Determine from file extension (alternative to UTI detection)
            let fileExtension = url.pathExtension.lowercased()
            
            if ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"].contains(fileExtension) {
                processVideoURL(url)
            } else if ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "pdf"].contains(fileExtension) {
                processImageURL(url)
            } else {
                // Check file's UTI (Uniform Type Identifier) to determine if it's image or video
                if #available(macOS 11.0, *) {
                    if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
                       let contentType = resourceValues.contentType {
                        
                        if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
                            processVideoURL(url)
                        } else if contentType.conforms(to: .image) {
                            processImageURL(url)
                        }
                    }
                } else {
                    // Fallback for macOS 10.x
                    if let resourceValues = try? url.resourceValues(forKeys: [.typeIdentifierKey]),
                       let uti = resourceValues.typeIdentifier {
                        
                        if uti.hasPrefix("video/") || uti.contains("movie") {
                            processVideoURL(url)
                        } else if uti.hasPrefix("image/") {
                            processImageURL(url)
                        }
                    }
                }
            }
        }
    }
    
    func processImageURL(_ url: URL) {
        // Existing image processing logic
        if #available(OSX 10.12.2, *) {
            windowDelegate?.showImageInTouchBar(with: url)
        }
        
        // create the image from the content URL
        if let image = NSImage(contentsOf:url) {
            
            imagePreviewView.image = image
            //print(image.size.width)
            
            // check if the image has the touch bar size (2170x60px)
            // and inform the user
            if image.size.width > TouchBarSizes.fullWidth || image.size.height > TouchBarSizes.fullHeight {
                bottomBarInfoLable.stringValue = "Image is too big! Should be 2170×60px."
                bottomBarInfoLable.toolTip = "The image is \(Int(image.size.width))x\(Int(image.size.height))px."
                
                // show alert icon in bottom bar
                bottomBarAlertImageWidth.constant = 20.0
                
            } else if image.size.width == TouchBarSizes.fullWidth && image.size.height == TouchBarSizes.fullHeight || image.size.width == TouchBarSizes.fullWidth/2 && image.size.height == TouchBarSizes.fullHeight/2 {
                bottomBarInfoLable.stringValue = "✓ Image is correct!"
                bottomBarInfoLable.toolTip = nil
                
                // "hide" alert icon in bottom bar
                bottomBarAlertImageWidth.constant = 0.0
                
            } else {
                bottomBarInfoLable.stringValue = "Image should be 2170×60px"
                bottomBarInfoLable.toolTip = nil
                
                // "hide" alert icon in bottom bar
                bottomBarAlertImageWidth.constant = 0.0
            }
        }
    }
    
    func processVideoURL(_ url: URL) {
        // Display during conversion
        DispatchQueue.main.async {
            self.bottomBarInfoLable.stringValue = "Converting video... Please wait"
            self.bottomBarAlertImageWidth.constant = 0.0
        }
        
        // Instruct WindowController to play video
        if #available(OSX 10.12.2, *) {
            windowDelegate?.playVideoInTouchBar(with: url)
        }
        
        // Generate and display video thumbnail
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: kCMTimeZero, actualTime: nil)
            let thumbnailImage = NSImage(cgImage: cgImage, size: .zero)
            
            DispatchQueue.main.async {
                self.imagePreviewView.image = thumbnailImage
            }
        } catch {
            if let cgImage = try? imageGenerator.copyCGImage(at: kCMTimeZero, actualTime: nil) {
                imagePreviewView.image = NSImage(cgImage: cgImage, size: .zero)
            }
            
            DispatchQueue.main.async {
                self.bottomBarInfoLable.stringValue = "Converting video... Please wait"
                self.bottomBarAlertImageWidth.constant = 0.0
            }
        }
    }
    
}

