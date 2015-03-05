// The MTPopupWindow class library is licensed under the terms of the Creative Commons 0 (CC0) license
//
// MTPopupWindow is a Swift port of Marin Todorov's Objective-C class library of the same name.  This port
// consists of one file designed to be dropped directly into a project and used without worrying about
// creating the bridging headers needed when using it in a Swift project.
//
// Phillip Brisco   Added new methods to set up and play a sound when the close button is clicked.
//                  To implement a click sound, use the clickBtnSound method (passing in the name
//                  of the sound to be played and it's type.
import Foundation
import UIKit
import QuartzCore
import AVFoundation

@objc protocol MTPopupWindowDelegate {
    optional func willShowMTPopupWindow(sender  : MTPopupWindow);
    optional func didShowMTPopupWindow(sender   : MTPopupWindow);
    optional func willCloseMTPopupWindow(sender : MTPopupWindow);
    optional func didCloseMTPopupWindow(sender  : MTPopupWindow);
}

let kCloseBtnDiameter : CGFloat  = 30
let kDefaultMargin : CGFloat     = 18
var kWindowMarginSize            = CGSize()

class MTPopupWindow : UIView, UIWebViewDelegate {
    var fileName = String ();
    private var delegate    : MTPopupWindowDelegate?;
    private var usesSafari  = Bool();
    private var webView     = UIWebView();
    private var dimView     : UIView?;
    private var bgView      : UIView?;
    private var loader      : UIActivityIndicatorView?;
    private var audioClick  : AVAudioPlayer? = nil;
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    override init () {
        super.init()
        setupUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    func initialize () {
        let kWindowMarginSize = CGSizeMake(kDefaultMargin, kDefaultMargin);
    }
    
    func setWindowMargin (margin : CGSize) {
        kWindowMarginSize = margin;
    }
    
    func showWindowWithHTMLFile (fileName : String) -> MTPopupWindow {
        var view : UIView = UIApplication.sharedApplication().keyWindow?.rootViewController as UIView;
        return self.showWindowWithHtmlFile(fileName, insideView: view)
    }
    
    func showWindowWithHtmlFile (fileName: String, insideView: UIView) -> MTPopupWindow {
        
        if (UIApplication.sharedApplication().statusBarHidden == false) {
            self.setWindowMargin(CGSizeMake(kWindowMarginSize.width, 50));
        }
        
        let popup : MTPopupWindow = initWithFile(fileName) as MTPopupWindow
        return popup
    }
    
    func initWithFile (fName : NSString) -> AnyObject {
        self.fileName = fName;
        return MTPopupWindow();
    }
    
    func setupUI () {
        self.layer.borderWidth = 2.0
        self.layer.borderColor = UIColor.blackColor().CGColor;
        self.layer.cornerRadius = 15.0
        self.backgroundColor = UIColor.whiteColor();
    }
    
    func webView (webView : UIWebView, didFailWithError error: NSError!) {
        let alert = UIAlertView();
        alert.title = "Webview Error"
        alert.message = "The requested document cannot be loaded, try again later"
        alert.delegate = nil
        alert.addButtonWithTitle("Ok");
        alert.show();
    }
    
    func showInView (v:UIView) {
        dimView = UIView();
        v.addSubview(dimView!);
        dimView!.layoutMaximizeInView(v, inset: 0)
        
        bgView = UIView();
        v.addSubview(bgView!);
        bgView?.layoutMaximizeInView(v, inset: 0);
        
        webView.scrollView.bounces = false;
        webView.backgroundColor = UIColor.clearColor();
        webView.alpha = 0.0;
        webView.delegate = self;
        self.addSubview(webView);
        
        webView.layoutMaximizeInView(self, inset: 15)

        if (prefix(self.fileName,4) == "http") {
            
            // Load Internet web page
            loader = UIActivityIndicatorView (activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
            self.addSubview(loader!)
            loader?.layoutCenterInView(self)
            loader?.startAnimating()
            
            webView.scalesPageToFit = true;
            webView.loadRequest(NSURLRequest(URL: NSURL (string: fileName)!));
        } else {
            
            // Load a local file
            let error : NSError? = nil;
            let range = self.fileName.rangeOfString("[^.]*", options: .RegularExpressionSearch)
            let fName = self.fileName.substringWithRange(range!)
            let url = NSBundle.mainBundle().URLForResource(fName, withExtension: "html")
            let req = NSURLRequest(URL: url!)
            
            if (error != nil) {
                println ("Error loading \(fileName) \(error!)")
            } else {
                webView.loadRequest(req)
            }
        }

        let btnStuff = MTPopupWindowCloseButton()
        let btnClose : MTPopupWindowCloseButton = btnStuff.buttonInView(self) as MTPopupWindowCloseButton
        btnClose.addTarget(self, action: Selector("closePopupWindow"), forControlEvents: UIControlEvents.TouchUpInside)
        delegate?.willShowMTPopupWindow!(self)
        animatePopup(self);
    }

    func show () {
        let view : UIView = (UIApplication.sharedApplication().keyWindow?.rootViewController?.view)!;
        self.showInView(view)
    }
    
    func animatePopup (v : UIView) {
        let fauxView = UIView();
        
        fauxView.backgroundColor = UIColor.redColor();
        bgView?.addSubview(fauxView);
        fauxView.layoutMaximizeInView(bgView!, inset: kDefaultMargin);
        
        let options : UIViewAnimationOptions = UIViewAnimationOptions.TransitionFlipFromRight|UIViewAnimationOptions.AllowUserInteraction | UIViewAnimationOptions.BeginFromCurrentState
        
        UIView.transitionWithView(bgView!, duration: 0.4, options: options, animations: {
            fauxView.removeFromSuperview()
            self.bgView?.addSubview(self)
            
            self.layoutMaximizeInView(self.bgView!, insetSize: kWindowMarginSize)
            self.dimView?.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
            self.webView.alpha = 1.0
            
            }, completion: {(finished: Bool) -> () in   // Can also be "finished in"

                if (self.respondsToSelector(Selector("didShowMTPopupWindow:"))) {
                    self.delegate!.didShowMTPopupWindow!(self)
                }

        })
    }
    
    func closePopupWindow () {
        
        if (self.respondsToSelector(Selector("willCloseMTpopupWindow:"))) {
            delegate!.willCloseMTPopupWindow!(self);
        }
        
        if (audioClick != nil) {
            playClickSound()
        }

        let options : UIViewAnimationOptions = UIViewAnimationOptions.TransitionFlipFromRight | UIViewAnimationOptions.AllowUserInteraction | UIViewAnimationOptions.BeginFromCurrentState;
        
        UIView.transitionWithView(bgView!, duration: 0.4, options: options, animations:  {
            self.dimView?.backgroundColor = UIColor.clearColor();
            self.removeFromSuperview();
            
            }, completion: {finished in     // can also be "(finished (Bool) -> ()) in"
                self.bgView!.removeFromSuperview()
                self.bgView = nil
                self.dimView!.removeFromSuperview()
                self.dimView = nil
                
                if (self.respondsToSelector(Selector("didCloseMTPopupWindow:"))) {
                    self.delegate!.didCloseMTPopupWindow!(self);
                }
                
        })
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        
        if (loader != nil) {
            loader?.removeFromSuperview();
        }
        
    }
    
    func didFailLoadWithError(error: NSError) {
        let alert = UIAlertView();
        alert.title = "Webview Error"
        alert.message = "The requested document cannot be loaded, try again later"
        alert.delegate = nil
        alert.addButtonWithTitle("Close");
        alert.show();
    }

    func webView (webView : UIWebView, request : NSURLRequest, navigationType : UIWebViewNavigationType) -> Bool {
        
        if (self.usesSafari) {
            var requestURL : NSURL = request.URL
            var hasPrefix : String? = prefix(requestURL.scheme!, 4)
            
            if (hasPrefix != nil && hasPrefix! == "http" && navigationType == UIWebViewNavigationType.LinkClicked){
                let tryTheURL : NSNumber? = UIApplication.sharedApplication().openURL(requestURL)
                return (tryTheURL == nil) ? true : false
            }
            return true
        
        }
        return true
        
    }
    
    func clickBtnSound (fileName: String?, fileType: String?) {
        
        if (fileName != nil) {
            
            if (fileType != nil) {
                var filePath : String? =  NSBundle.mainBundle().pathForResource(fileName!, ofType: fileType!);
                
                if (filePath != nil) {
                    var fileUrl : NSURL? = NSURL.fileURLWithPath(filePath!);
                    
                    if (fileUrl != nil) {
                        if (audioClick == nil) {
                            audioClick = AVAudioPlayer(contentsOfURL: fileUrl, error: nil);
                            audioClick!.numberOfLoops = 1;
                            audioClick!.prepareToPlay();
                        }
                        
                    }
                    
                }
                
            }
            
        }
    }
    
    func playClickSound () {
        
        if (audioClick != nil && !audioClick!.playing) {
            audioClick!.play();
        }
        
    }
    
}

class MTPopupWindowCloseButton : UIButton, MTPopupWindowDelegate {
    
    func buttonInView (v : UIView) -> UIButton {
        let closeBtnOffset : CGFloat = 5;
        let closeBtn : MTPopupWindowCloseButton = MTPopupWindowCloseButton.buttonWithType(UIButtonType.Custom) as MTPopupWindowCloseButton

        if (closeBtn.respondsToSelector(Selector("setTranslatesAutoresizingMaskIntoConstraints:"))) {
            closeBtn.setTranslatesAutoresizingMaskIntoConstraints(false)
        }
        
        v.addSubview(closeBtn)
    
        let rightc = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutAttribute.Right, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.Right, multiplier: 1.0, constant: -closeBtnOffset)
        
        let topc = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutAttribute.Top, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.Top, multiplier: 0.0, constant: closeBtnOffset)
        
        let wwidth = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.Width, multiplier: 0.0, constant: kCloseBtnDiameter)
        
        let hheight = NSLayoutConstraint (item: closeBtn, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.Height, multiplier: 0.0, constant: kCloseBtnDiameter)
        
        v.replaceConstraint(topc, v: v)
        v.replaceConstraint(rightc, v: v)
        v.replaceConstraint(wwidth, v: v)
        v.replaceConstraint(hheight, v: v);

        return closeBtn
    }
    
    override func drawRect(rect: CGRect) {
        
        let ctx : CGContextRef = UIGraphicsGetCurrentContext()
        CGContextAddEllipseInRect(ctx, CGRectOffset(rect, 0, 0))
        CGContextSetFillColor(ctx, CGColorGetComponents(UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1).CGColor))
        CGContextFillPath(ctx)
        
        CGContextAddEllipseInRect(ctx, CGRectInset(rect, 3,3))
        CGContextSetFillColor(ctx, CGColorGetComponents(UIColor (red: 0.3, green: 0.3, blue: 0.3, alpha: 1).CGColor))

        CGContextAddEllipseInRect(ctx, CGRectInset(rect, 4, 4))
        CGContextSetFillColor(ctx, CGColorGetComponents(UIColor (red: 1.0, green: 1.0, blue: 1.0, alpha: 1).CGColor))
        CGContextFillPath(ctx)

        CGContextSetStrokeColorWithColor(ctx, UIColor (red: 0.2, green: 0.2, blue: 0.2, alpha: 1).CGColor)
        CGContextSetLineWidth(ctx, 3.0)
        CGContextMoveToPoint(ctx, kCloseBtnDiameter/4, kCloseBtnDiameter/4)
        CGContextAddLineToPoint(ctx, kCloseBtnDiameter/4*3, kCloseBtnDiameter/4*3)
        CGContextStrokePath(ctx)
        
        CGContextSetStrokeColorWithColor(ctx, UIColor (red: 0.2, green: 0.2, blue: 0.2, alpha: 1).CGColor)
        CGContextSetLineWidth(ctx, 3.0)
        CGContextMoveToPoint(ctx, kCloseBtnDiameter/4*3, kCloseBtnDiameter/4)
        CGContextAddLineToPoint(ctx, kCloseBtnDiameter/4, kCloseBtnDiameter/4*3)
        CGContextStrokePath(ctx)
    }
    
}

extension UIView {
    func layoutMaximizeInView (v : UIView, inset : CGFloat) {
        self.layoutMaximizeInView (v, insetSize: CGSizeMake(inset, inset));
    }
    
    func layoutMaximizeInView (v : UIView, insetSize : CGSize) {
        
        if (self.respondsToSelector(Selector("setTranslatesAutoresizingMaskIntoConstraints:"))) {
            setTranslatesAutoresizingMaskIntoConstraints(false);
        }
        
        let centerX = NSLayoutConstraint (item: self, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.CenterX, multiplier: 1.0, constant: 0.0);
        
        let centerY = NSLayoutConstraint (item: self, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.CenterY, multiplier: 1.0, constant: 0.0);
        
        let wwidth = NSLayoutConstraint (item: self, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.Width, multiplier: 1.0, constant: -insetSize.width);
        
        let hheight = NSLayoutConstraint (item: self, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.Height, multiplier: 1.0, constant: -insetSize.height);
        
        replaceConstraint(centerX, v: v);
        replaceConstraint(centerY, v: v);
        replaceConstraint(wwidth, v: v);
        replaceConstraint(hheight, v: v);
    }
    
    func layoutCenterInView (v : UIView) {
        
        if (self.respondsToSelector(Selector("setTranslatesAutoresizingMaskIntoConstraints:"))) {
            setTranslatesAutoresizingMaskIntoConstraints(false);
        }
        
        let centerX = NSLayoutConstraint (item: self, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.CenterX, multiplier: 1.0, constant: 0.0);
        
        let centerY = NSLayoutConstraint (item: self, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: v, attribute: NSLayoutAttribute.CenterY, multiplier: 1.0, constant: 0.0);
        
        replaceConstraint(centerX, v: v);
        replaceConstraint(centerY, v: v);
    }
    
    func replaceConstraint (c : NSLayoutConstraint, v : UIView) {
        
        for c1 in v.constraints() {
            
            if (c1.firstItem as UIView == c.firstItem as UIView && c1.firstAttribute == c.firstAttribute) {
                v.removeConstraint(c1 as NSLayoutConstraint)
            }
            
        }
        
        v.addConstraint(c);
    }
}
