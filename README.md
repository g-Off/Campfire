Campfire Plugin for Apples iChat Messenger application on Mac OS X 10.7+

Install to /Library/iChat/PlugIns or ~/Library/iChat/PlugIns and relaunch both iChat and the imagent service application.

### Known Issues
* User avatars may not appear upon relaunch. iChat uses a caching mechanism for user avatars and doesn't seem to always re-request the image upon subsequent launches.
* Currently contact list is not updating when contacts come "online" or go "offline" (Campfire doesn't really support this but online/offline status is determined by if the user is present in any of the chats as the user)
* No support for uploads. Some code is partially in place with the goal to automatically download attachments to cache location and post a message in the chatroom with a file:// link
* Disconnecting from another client results in user appearing to have left chat room (however they remain connected)

### License
Licensed under the 3-clause BSD.