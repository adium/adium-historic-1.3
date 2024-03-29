/* 
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AIAutoReplyPlugin.h"
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIPreferenceControllerProtocol.h>
#import "AIStatusController.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentObject.h>

/*!
 * @class AIAutoReplyPlugin
 * @brief Provides AutoReply functionality for the state system
 *
 * This class implements the state system behavior for auto-reply.  If auto-reply status is active on an account, 
 * initial messages recieved on that account will be replied to automatically.  Subsequent messages will not receive
 * a reply unless the chat window is closed.
 *
 * This is the expected behavior on certain protocols such as AIM, and considered a convenience on other protocols.
 */
@implementation AIAutoReplyPlugin

/*!
 * @brief Initialize the auto-reply system
 *
 * Initialize the auto-reply system to monitor account status.  When an account auto-reply flag is set we begin to
 * monitor chat messaging and auto-reply as necessary.
 */
- (void)installPlugin
{
	//Init
	receivedAutoReply = [[NSMutableSet alloc] init];
	
	//Add observers
	[[adium notificationCenter] addObserver:self
								   selector:@selector(didReceiveContent:) 
									   name:CONTENT_MESSAGE_RECEIVED object:nil];
	[[adium notificationCenter] addObserver:self
								   selector:@selector(didSendContent:)
									   name:CONTENT_MESSAGE_SENT object:nil];
	[[adium notificationCenter] addObserver:self
								   selector:@selector(chatWillClose:)
									   name:Chat_WillClose object:nil];
	
	[[adium contactController] registerListObjectObserver:self];
}

/*!
 * Deallocate
 */
- (void)dealloc
{
	[[adium contactController] unregisterListObjectObserver:self];
	[receivedAutoReply release];
	
	[super dealloc];
}

/*!
 * @brief Account status changed.
 *
 * Update our chat monitoring in response to account status changes.  
 *
 * TODO: If there are no accounts with an auto-reply flag set we SHOULD stop monitoring messages for optimal performance.
 */
- (NSSet *)updateListObject:(AIListObject *)inObject keys:(NSSet *)inModifiedKeys silent:(BOOL)silent
{
	if ([inObject isKindOfClass:[AIAccount class]] &&
	   [inModifiedKeys containsObject:@"StatusState"]) {
			
		//Reset our list of contacts who have already received an auto-reply
		[receivedAutoReply release]; receivedAutoReply = [[NSMutableSet alloc] init];
		
		//Don't want to remove from the new set any chats which previously closed and are pending removal
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
	}
    
    return nil;
}

/*!
 * @brief Respond to a received message
 *
 * Respond to a received message by sending out the current auto-reply.  We only send the auto-reply once to each
 * contact, and then their name is added to a list and additional received messages are ignored.
 */
- (void)didReceiveContent:(NSNotification *)notification
{
    AIContentObject 	*contentObject = [[notification userInfo] objectForKey:@"AIContentObject"];
    AIChat				*chat = [contentObject chat];
	
	/* We will not respond to the received message if it is an auto-reply, over a chat where we have already responded,
	 * or over a group chat.
	 * Additionally, it's not sensible to send autoreplies if the arriving message
	 * was an offline message we're getting as we connect and it's older than 5 minutes
	 * (or the person sending it is no longer online) -RAF
	 * For AIM accounts, we know it is an offline message if it starts with "[Offline IM sent". Of course, a user could send a message like that...
	 *	but said user deserves not to receive an auto-reply.
	 */
	if ([[contentObject type] isEqualToString:CONTENT_MESSAGE_TYPE] &&
	   ![(AIContentMessage *)contentObject isAutoreply] &&
	   ![receivedAutoReply containsObject:[chat uniqueChatID]] &&
	   ![chat isGroupChat] &&
		(abs([[contentObject date] timeIntervalSinceNow]) < 300) &&
		!([[[contentObject source] serviceClass] isEqualToString:@"AIM-compatible"] && [[[contentObject message] string] hasPrefix:@"[Offline IM sent"])) {
		//300 is 5 minutes in seconds
		
		[self sendAutoReplyFromAccount:[contentObject destination]
							 toContact:[contentObject source]
								onChat:chat];

		[receivedAutoReply addObject:[chat uniqueChatID]];
	}
}

/*!
 * @brief Send an auto-reply
 *
 * Sends our current auto-reply to the specified contact.
 * @param source Account sending the object
 * @param destination Contact receiving the object
 * @param chat Chat the communication is occuring over
 */
- (void)sendAutoReplyFromAccount:(id)source toContact:(id)destination onChat:(AIChat *)chat
{
	AIContentMessage	*responseContent = nil;
	NSAttributedString 	*autoReply = [[[chat account] statusState] autoReply];
	BOOL				supportsAutoreply = [source supportsAutoReplies];
		
	if (autoReply) {
		if (!supportsAutoreply) {
			//Tthe service isn't natively expecting an autoresponse, so make it a bit clearer what's going on
			NSMutableAttributedString *mutableAutoReply = [[autoReply mutableCopy] autorelease];
			[mutableAutoReply replaceCharactersInRange:NSMakeRange(0, 0) 
											withString:AILocalizedString(@"(Autoreply) ", 
												"Prefix to place before autoreplies on services which do not natively support them")];
			autoReply = mutableAutoReply;
		}

		responseContent = [AIContentMessage messageInChat:chat
											   withSource:source
											  destination:destination
													 date:nil
												  message:autoReply
												autoreply:supportsAutoreply];
		
		[[adium contentController] sendContentObject:responseContent];
	}
}

/*!
 * @brief Respond to our user sending messages
 *
 * For convenience, when our user messages a contact while away we exclude that contact from receiving our auto-away
 * on future messages.
 */
- (void)didSendContent:(NSNotification *)notification
{
    AIContentObject	*contentObject = [[notification userInfo] objectForKey:@"AIContentObject"];
	AIChat			*chat = [contentObject chat];
   
    if ([[contentObject type] isEqualToString:CONTENT_MESSAGE_TYPE]) {
		[receivedAutoReply addObject:[chat uniqueChatID]];
    }
}

- (void)removeChatIDFromReceivedAutoReply:(id)uniqueChatID
{
	[receivedAutoReply removeObject:uniqueChatID];
}

/*!
 * @brief Respond to a chat closing
 *
 * Once a chat is closed we forget about whether it has received an auto-response.  If the chat is re-opened, it will
 * receive our auto-response again.  This behavior is not necessarily desired, but is a side effect of basing our
 * already-received list on chats and not contacts.  However, many users have come to expect this behavior and it's
 * presence is neither strongly negative or positive.
 */
- (void)chatWillClose:(NSNotification *)notification
{
	/* Don't remove the chat until 30 seconds from now to prevent the classic situation in which you close the window,
	 * the contact messages you one last message, and a needless autoreply is sent
	 */
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(removeChatIDFromReceivedAutoReply:)
											   object:[[notification object] uniqueChatID]];
	[self performSelector:@selector(removeChatIDFromReceivedAutoReply:)
			   withObject:[[notification object] uniqueChatID]
			   afterDelay:30.0];
}

@end
