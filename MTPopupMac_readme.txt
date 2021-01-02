			      MTPopupMac

The MTPopupMac view is an NSView version of MTPopup for UIView and IOS.  It
popups an overlay view that contains a rendered HTML file or URL.  This is very
good for putting help files on each screen in an easily read format.

To use it, add it to your project by creating a new swift file and copying
and pasting the code from the MTPopupMac.swift into your new project file.

To use it, create an unclassed function like so:

func mainHelp () {
    
    var htmlFile = String()
    
    switch NSApplication.shared.keyWindow!.title {
    case "Configurations":
        htmlFile = "configsHelp.html"
    case "Parts":
        htmlFile = "partsHelp.html"
    case "Part Type":
        htmlFile = "partTypeHelp.html"
    case "Configuration Type":
        htmlFile = "configTypeHelp.html"
    case "Part Configuration":
        htmlFile = "partConfigHelp.html"
    case "Configuration List":
        htmlFile = "configListHelp.html"
    case "Part List":
        htmlFile = "partListHelp.html"
    case "Maintenance Type":
        htmlFile = "maintTypeHelp.html"
    case "Locations":
        htmlFile = "locationsHelp.html"
    case "Address Locations":
        htmlFile = "addrLocHelp.html"
    case "Contacts":
        htmlFile = "contactsHelp.html"
    case "Contact Locations":
        htmlFile = "contLocHelp.html"
    case "Contact Details":
        htmlFile = "contDetHelp.html"
    case "Part History":
        htmlFile = "partHistHelp.html"
    case "Part Locations":
        htmlFile = "partLocHelp.html"
    case "Scheduled Maintenance":
        htmlFile = "schedMaintHelp.html"
    default:
        htmlFile = "none"
    }
    
    let winPop = MTPopupWindow()
    let view: NSView = (NSApplication.shared.keyWindow?.contentView)!
    view.wantsLayer = true
    winPop.closeBtnTopInset = 15     // Push button down
    winPop.closeBtnRightInset = 15   // Push button to left
    winPop.clickBtnSound(fileName: "click", fileType: "wav")
    winPop.fileName = String(htmlFile)
    winPop.insetH = 0               // Offset for navigation bar
    winPop.insetW = 0               // Offset for width of window.        
    winPop.showInView(v: view)
    swooshPlayer.play()
}

The function checks to see what the title of the current window is, then uses
that to get the appropriate help file from a switch statement.  This is used
when the MTPopupMac menu is displayed as the top view of the current key window
when help is requested to be displayed.

Some of the insets were created in the IOS version to get around the navigation
bar.  There is no navigation bar in the Mac, but these are still kept around
just in case they should prove to be useful.
---------------------------------------------------
This very usefule (IMHO) class was originally created by Marin Todorov in
Objective-C several years ago.  I ported it to swift in IOS (and let him see
what I had done).  I've kept up with it ever since, the latest IOS version
being 5.

This port is better than the IOS ports and is technically more sophisticated,
but it is still version 1 for OSX.
--------------------------------------------------
Known issues:

When having multiple windows on the screen at any one time with the help
view running on each window, the dismissal of said help won't be in the expected
order (with the key window help disappearing first).  This is related to an
issue with addLocalMonitorForEvents.  I initially thought that it was handling
events per window, but it turns out that it is handling them per application.
It still dismisses all the windows it should but not just in the expected way.
Oh well...

Multiple help views can be loaded on a window.  This results in the necessity
of dismissing each one before you can see the original window.  Unless you just
dismiss the window, then redisplay it.  This is not a bad bug and, in fact,
I'm not totally sure it is one.  At any rate, it would probably be rare that
this one happens and is easily dealt with.
