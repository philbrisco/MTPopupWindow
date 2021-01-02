//
//  MTPopupSwift5.swift
//  FlasDrillZoid
//
//  Created by Phillip Brisco on 4/10/20.
//  Copyright © 2020 Phillip Brisco. All rights reserved.
//
// Vwrsion 5 (IOS 13.x)  Changed from the deprecated UIWebKit protocol to the
//  WKWebKit protocol

import Foundation
import UIKit
import QuartzCore
import AVFoundation
import WebKit

@objc protocol MTPopupWindowDelegate {
    @objc optional func willShowMTPopupWindow(sender  : MTPopupWindow);
    @objc optional func didShowMTPopupWindow(sender   : MTPopupWindow);
    @objc optional func willCloseMTPopupWindow(sender : MTPopupWindow);
    @objc optional func didCloseMTPopupWindow(sender  : MTPopupWindow);
}

let kCloseBtnDiameter : CGFloat  = 30
let kDefaultMargin : CGFloat     = 18
var kWindowMarginSize            = CGSize()

@available(iOS 13.0, *)
class MTPopupWindow: UIView, WKUIDelegate, WKNavigationDelegate {
    
    var fileName = String ();
    private var delegate    : MTPopupWindowDelegate?;
    private var usesSafari  = Bool();
    private var webView     = WKWebView();
    private var dimView     : UIView?;
    private var bgView      : UIView?;
    private var loader      : UIActivityIndicatorView?;
    private var audioClick  : AVAudioPlayer? = nil;
    var insetW: CGFloat = 0
    var insetH: CGFloat = 0
    var closeBtnTopInset: CGFloat = 0
    var closeBtnRightInset: CGFloat = 0

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    func initialize () {
        _ = CGSize (width: kDefaultMargin, height: kDefaultMargin)
    }
    
    func setWindowMargin (margin : CGSize) {
        kWindowMarginSize = margin;
    }
    
    func showWindowWithHTMLFile (fileName : String) -> MTPopupWindow {
        let view : UIView =
            UIApplication.shared.windows.filter {$0.isKeyWindow}.first! as UIView

        return self.showWindowWithHtmlFile(fileName: fileName, insideView: view)
    }

    func showWindowWithHtmlFile (fileName: String, insideView: UIView) -> MTPopupWindow {
        let keyWindow = UIApplication.shared.connectedScenes
        .map({$0 as? UIWindowScene})
        .compactMap({$0})
        .first?.windows.first
        
        if keyWindow?.windowScene?.statusBarManager?.isStatusBarHidden == false
        {
            self.setWindowMargin(margin: CGSize(width: kWindowMarginSize.width, height: 50))
        }
        
        let popup : MTPopupWindow = initWithFile (fName: fileName as NSString) as! MTPopupWindow
            
           return popup
       }
    
    func initWithFile (fName : NSString) -> AnyObject {
        self.fileName = fName as String;
        return MTPopupWindow();
    }
    
    func setupUI () {
        webView.layer.borderWidth = 2.0
        webView.layer.borderColor = UIColor.black.cgColor;
        webView.layer.cornerRadius = 15.0
        webView.backgroundColor = UIColor.white;
        webView.layer.backgroundColor = UIColor.white.cgColor
        webView.layer.masksToBounds = true
    }
    
    func webView (_ webView : WKWebView, didFailLoadWithError error: Error) {var alertController = UIAlertController()
           var scaryAction = UIAlertAction()
           
           alertController = UIAlertController(title: "Webview Error", message: "The requested document cannot be loaded, try again later", preferredStyle: .alert)
           scaryAction = UIAlertAction(title: "OK", style: .default, handler: nil)
           alertController.addAction(scaryAction)
           
           if let parentVC = getTopViewController() {
               parentVC.present(alertController, animated: true, completion: nil)
           }

    }
    
    func showInView (v:UIView) {
        dimView = UIView();
        v.addSubview(dimView!);
        dimView!.layoutMaximizeInView(v: v, inset: 0)
            
        bgView = UIView();
        v.addSubview(bgView!);
        bgView?.layoutMaximizeInView(v: v, insetH: insetH, insetW: insetW)
            
        webView.scrollView.bounces = false;
        webView.backgroundColor = UIColor.white;
        webView.alpha = 0.0;
        webView.uiDelegate = self;
        webView.navigationDelegate = self
        self.addSubview(webView);
            
        webView.layoutMaximizeInView(v: self, inset: 0)

        if fileName[..<fileName.index(fileName.startIndex, offsetBy: 4)] == "http" {

            // Load Internet web page
            loader = UIActivityIndicatorView (style: UIActivityIndicatorView.Style.medium)
                self.addSubview(loader!)
                loader?.layoutCenterInView(v: self)
                loader?.startAnimating()

            //           webView.scalesPageToFit = true;
        
                webView.load(NSURLRequest(url: NSURL (string: fileName)! as URL) as URLRequest)
        } else {
            // Load a local file
            let error : NSError? = nil;
            let range = self.fileName.range(of: "[^.]*", options: .regularExpression, range: nil, locale: nil)
            let fName: String! = String(fileName[(range)!])

            let url = Bundle.main.url(forResource: fName, withExtension: "html")

            let req = NSURLRequest(url: url!)

            if (error != nil) {
                print ("Error loading \(fileName) \(error!)")
            } else {
                webView.load(req as URLRequest)
            }
        }
            
        let btnStuff = MTPopupWindowCloseButton()

        btnStuff.closeBtnTopInset = closeBtnTopInset  // offsets from the top
        btnStuff.closeBtnRightInset = closeBtnRightInset // Ofset from the right
        let btnClose : MTPopupWindowCloseButton = btnStuff.buttonInView(v: self) as! MTPopupWindowCloseButton
        btnClose.addTarget(self, action: #selector(MTPopupWindow.closePopupWindow), for: UIControl.Event.touchUpInside)
            
        btnClose.buttonAnime()
            
        let theHeight = btnClose.frame.height
        let theWidth = btnClose.frame.width
        let theX = btnClose.frame.maxX
        let theY = btnClose.frame.maxY
        let theRect = CGRect(x: theX, y: theY - 20, width: theWidth, height: theHeight)
            btnClose.frame = theRect
        delegate?.willShowMTPopupWindow!(sender: self)
            animatePopup(v: self);
    }
    
    func show () {
        let view: UIView = (UIApplication.shared.connectedScenes
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows.first)!
            
    //     let view : UIView = (UIApplication.shared.keyWindow?.rootViewController?.view)!;
         self.showInView(v: view)
     }
     
     func animatePopup (v : UIView) {
         let fauxView = UIView();

         fauxView.backgroundColor = UIColor.red;
         bgView?.addSubview(fauxView);
         fauxView.layoutMaximizeInView(v: bgView!, inset: kDefaultMargin)
    
         let options: UIView.AnimationOptions = [.transitionFlipFromRight, .allowUserInteraction, .beginFromCurrentState]
         
         UIView.transition(with: bgView!, duration: 0.4, options: options, animations: {
             fauxView.removeFromSuperview()
             self.bgView?.addSubview(self)

             self.layoutMaximizeInView(v: self.bgView!, insetSize: kWindowMarginSize)
             self.dimView?.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
             self.webView.alpha = 1.0
             }, completion: {(finished: Bool) -> () in   // Can also be "finished in"

                 if (self.responds(to: #selector(MTPopupWindowDelegate.didShowMTPopupWindow(sender:)))) {
                     self.delegate!.didShowMTPopupWindow!(sender: self)
                 }

         })
     }
    
    @objc func closePopupWindow () {
        
        if (self.responds(to: #selector(MTPopupWindowDelegate.willCloseMTPopupWindow(sender:)))) {
            delegate!.willCloseMTPopupWindow!(sender: self);
        }
        
        if (audioClick != nil) {
            playClickSound()
        }

        let options : UIView.AnimationOptions = [.transitionFlipFromRight, .allowUserInteraction, .beginFromCurrentState]
        
        UIView.transition(with: bgView!, duration: 0.4, options: options, animations:  {
            self.dimView?.backgroundColor = UIColor.clear;
            self.removeFromSuperview();
            
            }, completion: {finished in     // can also be "(finished (Bool) -> ()) in"
                self.bgView!.removeFromSuperview()
                self.bgView = nil
                self.dimView!.removeFromSuperview()
                self.dimView = nil
                
                if (self.responds(to: #selector(MTPopupWindowDelegate.didCloseMTPopupWindow(sender:)))) {
                    self.delegate!.didCloseMTPopupWindow!(sender: self);
                }
                
        })
    }
    
    func webViewDidFinishLoad(_ webView: WKWebView) {
           
           if (loader != nil) {
               loader?.removeFromSuperview();
           }
           
       }
       
       func didFailLoadWithError(error: NSError) {
           var alertController = UIAlertController()
           var scaryAction = UIAlertAction()
           
           alertController = UIAlertController(title: "Webview Error", message: "The requested document cannot be loaded, try again later", preferredStyle: .alert)
           scaryAction = UIAlertAction(title: "OK", style: .default, handler: nil)
           alertController.addAction(scaryAction)
           
           if let parentVC = getTopViewController() {
               parentVC.present(alertController, animated: true, completion: nil)
           }
    }
    
    func webView (webView: WKWebView, request: NSURLRequest, navigationType: WKNavigationType) -> Bool {

        if (self.usesSafari) {
            let requestURL : NSURL = request.url! as NSURL
            
            let tmpName: String = requestURL.scheme!
            let hasPrefix: String? =  String(tmpName[..<tmpName.index(tmpName.startIndex, offsetBy: 4)])

            if (hasPrefix != nil && hasPrefix! == "http" && navigationType == WKNavigationType.linkActivated){
                let tryTheURL: NSNumber? = UIApplication.shared.canOpenURL(requestURL as URL) as NSNumber
                return (tryTheURL == nil) ? true : false
            }
            return true
            
        }
        return true
            
    }
    
    func clickBtnSound (fileName: String?, fileType: String?) {
         
         if (fileName != nil) {
             
             if (fileType != nil) {
                 let filePath : String? =  Bundle.main.path(forResource: fileName!, ofType: fileType!);
                 
                 if (filePath != nil) {
                     let fileUrl : NSURL? = NSURL.fileURL(withPath: filePath!) as NSURL;
                     
                     if (fileUrl != nil) {
                         if (audioClick == nil) {
                             do {
                                 try audioClick = AVAudioPlayer(contentsOf: fileUrl! as URL)
                                 audioClick!.numberOfLoops = 1;
                                 audioClick!.prepareToPlay();
                             } catch let error as NSError {
                                 print (error.localizedDescription)
                             }
                         }
                         
                     }
                     
                 }
                 
             }
             
         }
     }
    
    func playClickSound () {
        
        if (audioClick != nil && !audioClick!.isPlaying) {
            audioClick!.play();
        }
        
    }
}

class MTPopupWindowCloseButton : UIButton, MTPopupWindowDelegate {
    var closeBtnTopInset: CGFloat = 0
    var closeBtnRightInset: CGFloat = 0
    
    func buttonInView (v : UIView) -> UIButton {
        let closeBtnTopOffset: CGFloat = 5 + closeBtnTopInset
        let closeBtnOffset : CGFloat = 5 + closeBtnRightInset
        let closeBtn: MTPopupWindowCloseButton = MTPopupWindowCloseButton(type: .custom) as MTPopupWindowCloseButton

        if (closeBtn.responds(to: #selector(setter: UIView.translatesAutoresizingMaskIntoConstraints))) {
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
        v.replaceConstraint(c: hheight, v: v);

        return closeBtn
    }
    
    override func draw(_ rect: CGRect) {

        if let ctx: CGContext = UIGraphicsGetCurrentContext() {
            ctx.addEllipse(in: rect.offsetBy(dx: 0, dy: 0))

            ctx.setFillColor(UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1).cgColor.components!)
            
            ctx.fillPath()
            
            ctx.addEllipse(in: rect.insetBy(dx: 3, dy: 3))
            ctx.setFillColor(UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1).cgColor.components!)
            
            ctx.addEllipse(in: rect.insetBy(dx: 4, dy: 4))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            ctx.fillPath()
            
            ctx.setStrokeColor(UIColor(red: 1, green: 0, blue: 0, alpha: 1).cgColor.components!)
            ctx.setLineWidth(3.0)
            
            ctx.move(to: CGPoint(x: kCloseBtnDiameter/4, y: kCloseBtnDiameter/4))
            ctx.addLine(to: CGPoint(x: kCloseBtnDiameter/4*3, y: kCloseBtnDiameter/4*3))
            ctx.strokePath()
            
            ctx.setStrokeColor(UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1).cgColor.components!)
            ctx.setLineWidth(3.0)
            
            ctx.move(to: CGPoint(x: kCloseBtnDiameter/4*3, y: kCloseBtnDiameter/4))
            ctx.addLine(to: CGPoint(x: kCloseBtnDiameter/4, y: kCloseBtnDiameter/4*3))
            ctx.strokePath()
            
            UIGraphicsEndPDFContext()
        }

    }
    
}

extension UIView {
    
    func layoutMaximizeInView (v : UIView, inset : CGFloat) {
        self.layoutMaximizeInView (v: v, insetSize: CGSize(width: inset, height: inset))
    }
    
    func layoutMaximizeInView (v : UIView, insetH: CGFloat, insetW: CGFloat) {
        self.layoutMaximizeInView (v: v, insetSize: CGSize(width: insetW, height: insetH))
    }
    
    func layoutMaximizeInView (v : UIView, insetSize : CGSize) {

        if (self.responds(to: #selector(setter: UIView.translatesAutoresizingMaskIntoConstraints))) {
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
    
    func layoutCenterInView (v : UIView) {
        
        if (self.responds(to: #selector(setter: UIView.translatesAutoresizingMaskIntoConstraints))) {
            translatesAutoresizingMaskIntoConstraints = false
        }

        let centerX = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1.0, constant: 0.0);
        
        let centerY = NSLayoutConstraint (item: self, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: v, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1.0, constant: 0.0);
        
        replaceConstraint(c: centerX, v: v);
        replaceConstraint(c: centerY, v: v);
    }
    
    func replaceConstraint (c : NSLayoutConstraint, v : UIView) {
        
        for c1 in v.constraints {
            
            if (c1.firstItem as! UIView == c.firstItem as! UIView && c1.firstAttribute == c.firstAttribute) {
                v.removeConstraint(c1 as NSLayoutConstraint)
            }
            
        }
        
        v.addConstraint(c);
    }
    
    // Do a spring dance for the close button when it first appears
    func buttonAnime (duration: TimeInterval = 5.0) {
        self.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: CGFloat(0.1),
            initialSpringVelocity: CGFloat(2.0),
            options: UIView.AnimationOptions.allowUserInteraction,
            animations: {
                self.transform = CGAffineTransform.identity
        },
            completion: { Void in()  }
        )
    }
    
}


extension UIApplication {

    /// The app's key window taking into consideration apps that support multiple scenes.
    var keyWindowInConnectedScenes: UIWindow? {
        return windows.first(where: { $0.isKeyWindow })
    }
}
