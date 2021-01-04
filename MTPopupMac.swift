//
//  MTPopupMac.swift
//  partTrakr
//
//  Created by Phillip Brisco on 12/29/20.
//
// Ported MTPopup from IOS to OSX.
//
// The MTPopupMac view is an NSView version of MTPopup for UIView and IOS.  It
// popups an overlay view that contains a rendered HTML file or URL.  This is very
// good for putting help files on each screen in an easily read format.
//
// This very usefule (IMHO) class was originally created by Marin Todorov in
// Objective-C several years ago.  I ported it to swift in IOS (and let him see
// what I had done).  I've kept up with it (more or less) ever since.
//
// This version took care of the following issues:
//
//  2.1
//  multiple help screens were allowed to be displayed in each window.  This has been
//  fixed.  Only one help screen per window is allowed.
//
//  2.1
//  Issue with dismissing of help screens (when multiple windows were displaying help
//  screens) in a random or unexpected order has been fixed.  Now only the key
//  window help is dismissed.
//
//  2.1
//  Shut down access to non-interfacing functions, classes and variables by making
//  them private or fileprivate.

import WebKit
import Cocoa
import AVFoundation

@objc protocol MTPopupWindowDelegate {
    @objc optional func willShowMTPopupWindow(sender  : MTPopupWindow);
    @objc optional func didShowMTPopupWindow(sender   : MTPopupWindow);
    @objc optional func willCloseMTPopupWindow(sender : MTPopupWindow);
    @objc optional func didCloseMTPopupWindow(sender  : MTPopupWindow);
}

let kCloseBtnDiameter : CGFloat  = 50
let kDefaultMargin : CGFloat     = 0
var kWindowMarginSize            = CGSize()

// Set up event handler to take care of local keydown events.
fileprivate class MTEventMonitor {
    
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> NSEvent?
    
    public init (mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
    
    public func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
    }
}

class MTPopupWindow: NSView, WKUIDelegate, WKNavigationDelegate, NSApplicationDelegate, NSTextFieldDelegate {

    override var acceptsFirstResponder: Bool {
        return true
    }
    
    var fileName = String ()
    private var delegate    : MTPopupWindowDelegate?
    private var usesSafari  = Bool()
    private var webView     = WKWebView();
    private var dimView     : NSView?
    private var bgView      : NSView?
    private var loader      = NSProgressIndicator()
    private var audioClick  : AVAudioPlayer? = nil
    private var audioSwoosh  : AVAudioPlayer? = nil
    private var btnClose    = MTPopupWindowCloseButton()
    private var theText     = NSTextField(frame: NSMakeRect(20, 20, 200, 40))
    var insetW: CGFloat = 0
    var insetH: CGFloat = 0
    var closeBtnTopInset: CGFloat = 0
    var closeBtnRightInset: CGFloat = 0
    private var locEventHandler: MTEventMonitor?
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        theText.delegate = self
        loader.removeFromSuperview()
        setupUI()
        locEventHandler = MTEventMonitor(mask: [.keyDown], handler: { (NSEvent) -> NSEvent? in
            
            // Allow any non-modified key (command, shift, option, control, functio,)
            // etc.) key to ONLY disappear the help screen.
            if NSEvent.modifierFlags.rawValue > 256 {
                return NSEvent
            } else {

                // Only close the help if this is the key window, otherwise just
                // pass the event to the window controller to do it's magic.
                if (self.window?.isKeyWindow)! {
                    self.closePopupWindow()
                    self.locEventHandler?.stop()
                    return nil
                } else {
                    return NSEvent
                }

            }
        })
        locEventHandler?.start()
    }
    
    private func initialize () {
        _ = CGSize (width: kDefaultMargin, height: kDefaultMargin)
    }
    
    private func setWindowMargin (margin : CGSize) {
        kWindowMarginSize = margin;
    }
    
    private func showWindowWithHTMLFile (fileName : String) -> MTPopupWindow {
        let view : NSView =
            NSApplication.shared.windows.filter {$0.isKeyWindow}.first!.contentView!
        view.wantsLayer = true
        return self.showWindowWithHtmlFile(fileName: fileName, insideView: view)
    }
    
    private func showWindowWithHtmlFile (fileName: String, insideView: NSView) -> MTPopupWindow {
        
        let popup : MTPopupWindow = initWithFile (fName: fileName as NSString) as! MTPopupWindow

        return popup
    }

    private func initWithFile (fName : NSString) -> AnyObject {
        self.fileName = fName as String;
        return MTPopupWindow();
    }
    
    private func setupUI () {
        webView.wantsLayer = true
        webView.layer?.borderWidth = 5.0
        webView.layer?.borderColor = NSColor.black.cgColor;
        webView.layer?.cornerRadius = 20.0
        webView.layer?.backgroundColor = NSColor.orange.cgColor
        webView.layer?.masksToBounds = true
        webView.alphaValue = 1.0
    }

    private func showAlert (_ message: String, details: String) {
        guard let mySelf = NSApplication.shared.mainWindow else { return }
        if NSApp.keyWindow != nil {
            let alert = NSAlert()

            alert.messageText = message
            alert.informativeText = details
            alert.icon = NSImage(named: "wickedWitch")
            alert.window.minSize = .init(width: 480, height: 200)
            errorPlayer.play()
            closePopupWindow()
            
            alert.beginSheetModal(for: mySelf, completionHandler: { response in
                self.playClickSound()
            })
        }
    }
    
    func webView (_ webView : WKWebView, didFailLoadWithError error: Error) {
        showAlert("Webview Error", details: "The requested document cannot be loaded, try again later.")
    }
    
    private func showInView (v:NSView) {
        dimView = NSView();
        dimView?.identifier = NSUserInterfaceItemIdentifier(rawValue: "MTPopup")
        v.addSubview(dimView!)
        dimView!.layoutMaximizeInView(v: v, inset: 0)
        
        bgView = NSView();
        v.addSubview(bgView!);
        bgView?.layoutMaximizeInView(v: v, insetH: insetH, insetW: insetW)
 
        self.wantsLayer = true
        self.addSubview(webView);

        self.webView.layer?.backgroundColor = .black
        self.webView.layer?.borderColor = NSColor.red.cgColor
        self.webView.alphaValue = 1.0
        self.webView.uiDelegate = self;
        self.webView.navigationDelegate = self
        self.webView.layoutMaximizeInView(v: self, inset: 0)

        if fileName[..<fileName.index(fileName.startIndex, offsetBy: 4)] == "http" {

            // Load Internet web page
            loader.style = .spinning
            self.addSubview(loader)
            loader.layoutCenterInView(v: self)

            // Stop the spinner after 10 seconds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.loader.animator().stopAnimation(self)
            }

            webView.load(NSURLRequest(url: NSURL (string: fileName)! as URL) as URLRequest)
        } else {
            // Load a local file
            let range = self.fileName.range(of: "[^.]*", options: .regularExpression, range: nil, locale: nil)
            let fName: String! = String(fileName[(range)!])

            guard let url = Bundle.main.url(forResource: fName, withExtension: "html") else {
                self.showAlert("Local Page Not Found", details: "Ensure that the html page entered is part of the application's resources.")
                locEventHandler?.stop()
                return
            }
            
            do {
                _ = try String(contentsOf: url, encoding: .ascii)
            } catch let error {
                self.showAlert("Local Page Problems", details: error.localizedDescription)
                return
            }
            
            guard let req = NSURLRequest (url: url) as NSURLRequest? else {
                return
            }

            webView.load(req as URLRequest)
        }

        let btnStuff = MTPopupWindowCloseButton()

        btnStuff.closeBtnTopInset = closeBtnTopInset  // offsets from the top
        btnStuff.closeBtnRightInset = closeBtnRightInset // Ofset from the right
        btnClose = btnStuff.buttonInView(v: webView) as! MTPopupWindowCloseButton
                
        btnClose.target = self
        btnClose.action = #selector(MTPopupWindow.closePopupWindow)
             
        let theHeight = btnClose.frame.height
        let theWidth = btnClose.frame.width
        let theX = btnClose.frame.maxX
        let theY = btnClose.frame.maxY
        let theRect = CGRect(x: theX, y: theY - 20, width: theWidth, height: theHeight)
        btnClose.frame = theRect

        self.addSubview(theText)

        // Sort of a hack here, but I wasn't able to get the underlying view's
        // text field to relinquih firstresponder status unless I had a
        // textfield for it to pass the status to it.  Needed the DispathQueue
        // to sync things up so that I could assign firstresponder status.
        // The red color is for debugging purposes and won't be seen by the
        // user as it is hidden.
        theText.backgroundColor = NSColor.red
            
        DispatchQueue.main.async {
            self.theText.isHidden = true
            self.theText.becomeFirstResponder()
        }

        delegate?.willShowMTPopupWindow!(sender: self)
        animatePopup(v: self)
    }
    
    func show () {
        let view: NSView = (NSApplication.shared.keyWindow?.contentView)!

        for subView in view.subviews {

            if subView.identifier!
                .rawValue == "MTPopup" {
                audioClick = nil
                print ("gothereno")
                closePopupWindow()
                return
            }

        }
        
        print ("gothere maybe")
        self.playClickSwoosh()
        self.showInView(v: view)
    }
    
    private func animatePopup (v : NSView) {
        let fauxView = NSView();
        
        fauxView.wantsLayer = true
        fauxView.layer?.backgroundColor = NSColor.red.cgColor
        bgView?.addSubview(fauxView);
        bgView?.wantsLayer = true
        bgView?.layer?.backgroundColor = .clear
        bgView?.alphaValue = 1.0
        fauxView.layoutMaximizeInView(v: bgView!, inset: kDefaultMargin)
        fauxView.layer?.backgroundColor = NSColor.brown.cgColor
        fauxView.alphaValue = 1.0

        NSAnimationContext.runAnimationGroup({ context in
            let rotation = CABasicAnimation(keyPath: "transform")
            rotation.duration = 0.75
            rotation.repeatCount = 0
            let angle: CGFloat = CGFloat(-2 * Double.pi)
            rotation.valueFunction = CAValueFunction(name: .rotateZ)
            rotation.fromValue = CGFloat(-Double.pi)
            rotation.toValue = angle
            self.layer!.transform = CATransform3DRotate(self.layer!.transform, angle, 0, 0, 1.0)
            self.layer?.add(rotation, forKey: "transform.rotation.z")
        }, completionHandler: {
            self.layer?.affineTransform()
            self.btnClose.buttonAnime(duration: 5.0)

            if (self.responds(to: #selector(MTPopupWindowDelegate.didShowMTPopupWindow(sender:)))) {
                    self.delegate!.didShowMTPopupWindow!(sender: self)
           }
        })
        
        fauxView.removeFromSuperview()
        self.bgView?.addSubview(self)

        self.layoutMaximizeInView(v: self.bgView!, insetSize: kWindowMarginSize)
        self.dimView?.layer?.backgroundColor = (NSColor.init(cgColor: CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)) as! CGColor)
        self.webView.alphaValue = 1.0
        self.alphaValue = 1.0
     }
    
    @objc func closePopupWindow () {

        if (self.responds(to: #selector(MTPopupWindowDelegate.willCloseMTPopupWindow(sender:)))) {
            delegate!.willCloseMTPopupWindow!(sender: self)
        }
        
        playClickSound()

        NSAnimationContext.runAnimationGroup({ context in
            let rotation = CABasicAnimation(keyPath: "transform")
            rotation.duration = 0.75
            rotation.repeatCount = 0
            let angle: CGFloat = CGFloat(-2 * Double.pi)
            rotation.valueFunction = CAValueFunction(name: .rotateZ)
            rotation.fromValue = angle
            rotation.toValue = CGFloat(-Double.pi)
            self.layer?.transform = CATransform3DRotate(self.layer!.transform, angle, 0, 0, 1.0)
            self.layer?.add(rotation, forKey: "transform.rotation.z")

            // Delaying removing self from superview removes annoying scene flash.
            // Deadline has to be less than rotation.duration.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.dimView?.layer?.backgroundColor = NSColor.clear.cgColor
                self.removeFromSuperview();
            }

        }, completionHandler: {
            self.bgView?.removeFromSuperview()
            self.bgView = nil
            self.dimView?.removeFromSuperview()
            self.dimView = nil
            self.locEventHandler?.stop()

            if (self.responds(to: #selector(MTPopupWindowDelegate.didCloseMTPopupWindow(sender:)))) {
                    self.delegate!.didCloseMTPopupWindow!(sender: self)
            }

        })

    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loader.stopAnimation(self)
        showAlert("Page Error", details: String(error.localizedDescription))
        self.isHidden = true
        locEventHandler?.stop()
        loader.removeFromSuperview()
        closePopupWindow()
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        loader.startAnimation(self)
   }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("End loading")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }
    
    func webView (webView: WKWebView, request: NSURLRequest, navigationType: WKNavigationType) -> Bool {

        if (self.usesSafari) {
            let requestURL : NSURL = request.url! as NSURL
            
            let tmpName: String = requestURL.scheme!
            let hasPrefix: String? =  String(tmpName[..<tmpName.index(tmpName.startIndex, offsetBy: 4)])

            if (hasPrefix != nil && hasPrefix! == "http" && navigationType == WKNavigationType.linkActivated){
                return true
            }
            
        }
        
        return true
    }
    
    // Set up the click sound audio.
    func clickBtnSound (fileName: String?, fileType: String?) {
         
         if (fileName != nil && fileType != nil) {
            guard let filePath : String =  Bundle.main.path(forResource: fileName!, ofType: fileType!) else {return}
                 
            guard let fileUrl: NSURL = NSURL.fileURL(withPath: filePath) as NSURL? else {return}
                     
            if (audioClick == nil) {
                do {
                    try audioClick = AVAudioPlayer(contentsOf: (fileUrl) as URL)
                    audioClick!.numberOfLoops = 1;
                    audioClick!.prepareToPlay();
                } catch let error {
                    showAlert("Sound Error", details: error.localizedDescription)
                }
                    
            }
                                      
         }
     }
    
    private func playClickSound () {

        if (audioClick != nil && !audioClick!.isPlaying) {
            audioClick!.play();
        }
        
    }
    
    // Set up swoosh sound
    func clickBtnSwoosh (fileName: String?, fileType: String?) {
         
         if (fileName != nil && fileType != nil) {
            guard let filePath : String =  Bundle.main.path(forResource: fileName!, ofType: fileType!) else {return}
                 
            guard let fileUrl: NSURL = NSURL.fileURL(withPath: filePath) as NSURL? else {return}
                     
            if (audioSwoosh == nil) {
                do {
                    try audioSwoosh = AVAudioPlayer(contentsOf: (fileUrl) as URL)
                    audioSwoosh!.numberOfLoops = 0;
                    audioSwoosh!.prepareToPlay();
                } catch let error {
                    showAlert("Sound Error", details: error.localizedDescription)
                }
                    
            }
                                      
         }
     }
    
    private func playClickSwoosh () {

        if (audioSwoosh != nil && !audioSwoosh!.isPlaying) {
            audioSwoosh!.play();
        }
        
    }
    
}

// Layout constraints for close button.
fileprivate class MTPopupWindowCloseButton : NSButton, MTPopupWindowDelegate {
    var closeBtnTopInset: CGFloat = 0
    var closeBtnRightInset: CGFloat = 0
    
    func buttonInView (v : NSView) -> NSButton {
        let closeBtnTopOffset: CGFloat = 5 + closeBtnTopInset
        let closeBtnOffset : CGFloat = 5 + closeBtnRightInset
        let closeBtn: MTPopupWindowCloseButton = MTPopupWindowCloseButton(frame: .init()) as MTPopupWindowCloseButton

        if (closeBtn.responds(to: #selector(setter: NSView.translatesAutoresizingMaskIntoConstraints))) {
            closeBtn.translatesAutoresizingMaskIntoConstraints = false
        }

        v.addSubview(closeBtn)
        
        let rightc = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1.0, constant: -closeBtnOffset)
        
        let topc = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: closeBtnTopOffset)
        
        let wwidth = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.width, multiplier: 0.0, constant: kCloseBtnDiameter)
        
        let hheight = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.height, multiplier: 0.0, constant: kCloseBtnDiameter)
        
        v.replaceConstraint(c: topc, v: v)
        v.replaceConstraint(c: rightc, v: v)
        v.replaceConstraint(c: wwidth, v: v)
        v.replaceConstraint(c: hheight, v: v)
        
        return closeBtn
    }
    
    // Draw the window close button
    override func draw (_ rect: CGRect) {
        let line = NSBezierPath()
        let oval1 = NSBezierPath()
        
        oval1.appendOval(in: rect.insetBy(dx: 0, dy: 0))
        NSColor.init(calibratedRed: 0.0, green: 0.0, blue: 5.0, alpha: 1).setFill()
        oval1.fill()
        
        let oval2 = NSBezierPath()
        oval2.appendOval(in: rect.insetBy(dx: 5, dy: 5))
        NSColor.init(calibratedRed: 0.0, green: 0.7, blue: 0.7, alpha: 1.0).setFill()
        oval2.fill()

        let oval3 = NSBezierPath()
        oval3.appendOval(in: rect.insetBy(dx: 8, dy: 8))
        NSColor.init(calibratedRed: 0.8, green: 0.8, blue: 0.2, alpha: 1).setFill()
        oval3.fill()

        NSColor.init(calibratedRed: 1, green: 0, blue: 0, alpha: 1).setStroke()
        line.lineWidth = 3
        
        line.move(to: CGPoint(x: kCloseBtnDiameter/4, y: kCloseBtnDiameter/4))
        line.line(to: CGPoint(x: kCloseBtnDiameter/4*3, y: kCloseBtnDiameter/4*3))
        line.stroke()
        
        line.move(to: CGPoint(x: kCloseBtnDiameter/4*3, y: kCloseBtnDiameter/4))
        line.line(to: CGPoint(x: kCloseBtnDiameter/4, y: kCloseBtnDiameter/4*3))
        line.stroke()
    }
    
}

fileprivate extension NSView {

    func layoutMaximizeInView (v : NSView, inset : CGFloat) {
        self.layoutMaximizeInView (v: v, insetSize: CGSize(width: inset, height: inset))
    }
    
    func layoutMaximizeInView (v : NSView, insetH: CGFloat, insetW: CGFloat) {
        self.layoutMaximizeInView (v: v, insetSize: CGSize(width: insetW, height: insetH))
    }
    
    func layoutMaximizeInView (v : NSView, insetSize : CGSize) {

        if (self.responds(to: #selector(setter: NSView.translatesAutoresizingMaskIntoConstraints))) {
            translatesAutoresizingMaskIntoConstraints = false
        }

        let bottomX = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: .equal, toItem: v, attribute: .bottom, multiplier: 1.0, constant: 0.0)

        let centerX = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1.0, constant: 0.0);

        let wwidth = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.width, multiplier: 1.0, constant: -insetSize.width);
        
        let hheight = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.height, multiplier: 1.0, constant: -insetSize.height);

        replaceConstraint(c: centerX, v: v);
        replaceConstraint(c: bottomX, v: v)
        replaceConstraint(c: wwidth, v: v);
        replaceConstraint(c: hheight, v: v);
    }
    
    func layoutCenterInView (v : NSView) {
        
        if (self.responds(to: #selector(setter: NSView.translatesAutoresizingMaskIntoConstraints))) {
            translatesAutoresizingMaskIntoConstraints = false
        }

        let centerX = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1.0, constant: 0.0);
        
        let centerY = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1.0, constant: 0.0);
        
        replaceConstraint(c: centerX, v: v);
        replaceConstraint(c: centerY, v: v);
    }
    
    func replaceConstraint (c : NSLayoutConstraint, v : NSView) {
        
        for c1 in v.constraints {
            
            if (c1.firstItem as! NSView == c.firstItem as! NSView && c1.firstAttribute == c.firstAttribute) {
                v.removeConstraint(c1 as NSLayoutConstraint)
            }
            
        }
        
        v.addConstraint(c);
    }
    
    // Do a spring dance for the close button when it first appears
    func buttonAnime (duration: TimeInterval = 5.0) {
        NSAnimationContext.runAnimationGroup({ context in
            
            let animation = CAKeyframeAnimation(keyPath: "transform")
            animation.beginTime = CACurrentMediaTime()
            animation.duration = 0.13
            animation.repeatCount = 3
            animation.autoreverses = true

            animation.values = [
                NSValue(caTransform3D: CATransform3DMakeScale(0.85, 0.85, 0.85)),
                NSValue(caTransform3D: CATransform3DMakeScale(1.5, 1.5, 1.5))
            ]

            self.layer?.add(animation, forKey: "transform")
        }, completionHandler: {
            self.layer?.affineTransform()
        })

    }
    
}
