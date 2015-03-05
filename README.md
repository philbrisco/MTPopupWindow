# MTPopupWindow
Swift port of Marin Todorov's Objective-C class library

This allows the use of Marin Todorov's excellent library in Swift projects without having to resort to bridging headers.
MTPopup easily creates popup windows for use in a program. The implementation can be as simple as creating an instance of the
class, giving it the name of the HTML file to be displayed in the popup window and telling the instance to display the page,
thusly:

    var winPop = MTPopupWindow()
    winPop.fileName = "about.html"
    winPop.showInView(self.view)

As can be seen above, an instantiation of the class is assigned to the variable 'winPop', the instance property 'fileName' is
assigned the name of an HTML file that is stored in the application's bundle and the instance method 'showInView' is called to
display the file referenced by the 'fileName'.  As an added enhancment, the ability to add a sound when the window's close 
button is touched has been added. The method 'clickBtnSound' is called with the name of a sound file and its type. This should 
be placed before the 'showInView' method is called:

    var winPop = MTPopupWindow()
    winPop.clickBtnSound("Click", fileType: "wav")
    winPop.fileName = "about.html"
    winPop.showInView(self.view)

Setting up MTPopupWindow for use in a project simply requires dropping the MTPopupWindow.Swift file into the desired project.
