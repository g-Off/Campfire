Campfire Plugin for Apples iChat Messenger application on Mac OS X 10.7+

### Installation
If you've built from source then install to /Library/iChat/PlugIns or ~/Library/iChat/PlugIns and relaunch both iChat and the imagent service application.

If you grabbed the Installer then just run that. It will automatically try and restart the imagent process on its own. If the service does not become available in iChat you may need to restart that as well. As a last resort please try restarting your Mac.

### Usage
#### Setup
1. Open iChat Preferences (&#8984;+,)
2. Click the '+' button below accounts to add a new account
3. Select 'Campfire' from the Account Types
4. Enter your Campfire username/password and your Campfire server (without http:// or https://)
5. If your account requires SSL please make sure to check off the 'Use SSL' box (I believe all accounts should use SSL)
6. Done

#### Chatting
A "Campfire" group is added to your buddy list and a user "Console" should appear. You can chat with the Console user. You can get a list of all the rooms by sending the message '/list' to Console. You'll see a list of room identifiers and the room name, find the room identifier of the room you want to join and then:

1. File > Go to Chat Room… (or &#8984;+R)
2. Select the Campfire account and enter the room identifier
3. Hit the 'Go' button
4. Chat Away!

### Building
Make sure before building you've either done your git clone with the --recursive option or a 'git submodule init' followed by a 'git submodule update'  
Campfire.xcworkspace should now open and build

### Debugging
Process for debugging iChat plugin is a bit involved, my method is below. If anyone can improve on this I would love to know.

* Modify Campfire debug scheme. Set the executable to IMServicePlugInAgent.app (located in /System/Library/Frameworks/IMServicePlugIn.framework/)
* Set the scheme Launch option to Wait for IMServicePluginAgent.app to launch
* Hit Run
* Now copy the built plugin (you can find the path that plugin is built to in the Xcode Organizer) into /Library/iChat/PlugIns
* Quit iChat
* Kill the imagent application
*Relaunch iChat, debugger should now be attached to the application and you should be able to set breakpoints and debug as normal.

Recommended to disable other services you use in iChat while debugging so your contacts don't get annoyed with you constantly going online/offline

### Known Issues
* User avatars may not appear upon relaunch. iChat uses a caching mechanism for user avatars and doesn't seem to always re-request the image upon subsequent launches.
* Currently contact list is not updating when contacts come "online" or go "offline" (Campfire doesn't really support this but online/offline status is determined by if the user is present in any of the chats as the user)
* No support for uploads. Some code is partially in place with the goal to automatically download attachments to cache location and post a message in the chatroom with a file:// link
* Disconnecting from another client results in user appearing to have left chat room (however they remain connected)

### License
Licensed under the 3-clause BSD.