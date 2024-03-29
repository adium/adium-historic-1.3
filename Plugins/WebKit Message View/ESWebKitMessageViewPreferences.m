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

#import "ESWebKitMessageViewPreferences.h"
#import "AIWebKitMessageViewPlugin.h"
#import "AIWebkitMessageViewStyle.h"
#import "AIWebKitPreviewMessageViewController.h"
#import "AIPreviewChat.h"
#import "ESWebView.h"
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIContentStatus.h>
#import <Adium/AIListContact.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIService.h>
#import <Adium/JVFontPreviewField.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIColorAdditions.h>
#import <AIUtilities/AIFontAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <AIUtilities/AIBundleAdditions.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageViewWithImagePicker.h>

#import "AIPreviewContentMessage.h"

#define WEBKIT_PREVIEW_CONVERSATION_FILE	@"Preview"
#define	PREF_GROUP_DISPLAYFORMAT			@"Display Format"  //To watch when the contact name display format changes

@interface ESWebKitMessageViewPreferences (PRIVATE)
- (void)_setBackgroundImage:(NSImage *)image;
- (NSMenu *)_stylesMenu;
- (NSMenu *)_variantsMenu;
- (NSMenu *)_backgroundImageTypeMenu;
- (void)_addBackgroundImageTypeChoice:(NSInteger)tag toMenu:(NSMenu *)menu withTitle:(NSString *)title;
- (void)_configureChatPreview;
- (AIChat *)previewChatWithDictionary:(NSDictionary *)previewDict fromPath:(NSString *)previewPath listObjects:(NSDictionary **)outListObjects;
- (void)_fillContentOfChat:(AIChat *)inChat withDictionary:(NSDictionary *)previewDict fromPath:(NSString *)previewPath listObjects:(NSDictionary *)listObjects;
- (NSMutableDictionary *)_addParticipants:(NSDictionary *)participants toChat:(AIChat *)inChat fromPath:(NSString *)previewPath;
- (void)_applySettings:(NSDictionary *)chatDict toChat:(AIPreviewChat *)inChat withParticipants:(NSDictionary *)participants;
- (void)_addContent:(NSArray *)chatArray toChat:(AIChat *)inChat withParticipants:(NSDictionary *)participants;
- (void)_setDisplayFontFace:(NSString *)face size:(NSNumber *)size;
@end

@class AIPreviewChat;

@implementation ESWebKitMessageViewPreferences

- (NSString *)paneIdentifier
{
	return @"Messages";
}
- (NSString *)paneName{
	return AILocalizedString(@"Messages", "Title of the messages preferences");
}
- (NSString *)nibName{
    return @"WebKitPreferencesView";
}
- (NSImage *)paneIcon
{
	return [NSImage imageNamed:@"pref-messages"];
}

/*!
 * @brief Configure the preference view
 */
- (void)viewDidLoad
{
	viewIsOpen = YES;
	previewListObjectsDict = nil;

	//Configure our menus
	[popUp_backgroundImageType setMenu:[self _backgroundImageTypeMenu]];
	[popUp_styles setMenu:[self _stylesMenu]];
	
	//Other controls
	[fontPreviewField_currentFont setShowFontFace:YES];
	[fontPreviewField_currentFont setShowPointSize:YES];

	//We want to be able to obtain bigger images than the image picker will feed us
	[imageView_backgroundImage setUsePictureTaker:NO];
		
	//Configure the chat preview
	[self _configureChatPreview];

	//Configure our controls to represent the global preferences
	NSDictionary	*prefDict = [[adium preferenceController] preferencesForGroup:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];	
	[checkBox_showUserIcons setState:([[previewController messageStyle] allowsUserIcons] ?
									  [[prefDict objectForKey:KEY_WEBKIT_SHOW_USER_ICONS] boolValue] :
									  NSOffState)];
	[checkBox_showHeader setState:[[prefDict objectForKey:KEY_WEBKIT_SHOW_HEADER] boolValue]];
	[checkBox_showMessageColors setState:([[previewController messageStyle] allowsColors] ?
										  [[prefDict objectForKey:KEY_WEBKIT_SHOW_MESSAGE_COLORS] boolValue] :
										  NSOffState)];
	[checkBox_showMessageFonts setState:[[prefDict objectForKey:KEY_WEBKIT_SHOW_MESSAGE_FONTS] boolValue]];

	//Allow the alpha component to be set for our background color
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
	
	[self configureControlDimming];
}

/*!
 * @brief Close the preference view
 */
- (void)viewWillClose
{
	//Hide the alpha component
	[[NSColorPanel sharedColorPanel] setShowsAlpha:NO];

	[[adium notificationCenter] removeObserver:self];
	[previewListObjectsDict release]; previewListObjectsDict = nil;

	[previewController release]; previewController = nil;
	[view_previewLocation setFrame:[preview frame]];
	[[preview superview] replaceSubview:preview with:view_previewLocation];	
	[preview release]; preview = nil;
	//Matches the retain performed in -[ESWebKitMessageViewPreferences _configureChatPreview]
	[view_previewLocation release];

	viewIsOpen = NO;
}

- (void)messageStyleXtrasDidChange
{
	if (viewIsOpen) {
		NSDictionary *prefDict = [[adium preferenceController] preferencesForGroup:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
		
		[popUp_styles setMenu:[self _stylesMenu]];
		[popUp_styles selectItemWithRepresentedObject:[prefDict objectForKey:KEY_WEBKIT_STYLE]];
	}
}

//Preferences ----------------------------------------------------------------------------------------------------------
#pragma mark Preferences
/*!
 * @brief Update our preference view to reflect changed preferences
 */
- (void)preferencesChangedForGroup:(NSString *)group key:(NSString *)key object:(AIListObject *)object
					preferenceDict:(NSDictionary *)prefDict firstTime:(BOOL)firstTime
{
	if (!viewIsOpen) return;

	if ([group isEqualToString:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY]) {
		NSString	*style;
		NSString	*variant;

		//Ensure our style/variant menus are showing the correct selection
		style = [prefDict objectForKey:KEY_WEBKIT_STYLE];
		if (!style || ![popUp_styles selectItemWithRepresentedObject:style]) {
			style = [[plugin messageStyleBundleWithIdentifier:style] bundleIdentifier];
			[popUp_styles selectItemWithRepresentedObject:style];
		}

		//When the active style changes, rebuild our variant menu for the new style
		if (!key || [key isEqualToString:KEY_WEBKIT_STYLE]) {
			[popUp_variants setMenu:[self _variantsMenu]];
		}

		//Only enable if there are multiple variant choices
		[popUp_variants setEnabled:([popUp_variants numberOfItems] > 0)];

		variant = [prefDict objectForKey:[plugin styleSpecificKey:@"Variant" forStyle:style]];
		if (!variant || ![popUp_variants selectItemWithRepresentedObject:variant]) {
			variant = [AIWebkitMessageViewStyle defaultVariantForBundle:[plugin messageStyleBundleWithIdentifier:style]];
			[popUp_variants selectItemWithRepresentedObject:variant];
		}
		
		//Configure our style-specific controls to represent the current style
		NSString	*fontFamily = [prefDict objectForKey:[plugin styleSpecificKey:@"FontFamily" forStyle:style]];
		if (!fontFamily) fontFamily = [[plugin messageStyleBundleWithIdentifier:style] objectForInfoDictionaryKey:KEY_WEBKIT_DEFAULT_FONT_FAMILY];
		if (!fontFamily) fontFamily = [[NSFont systemFontOfSize:0] familyName];
		
		NSNumber	*fontSize = [prefDict objectForKey:[plugin styleSpecificKey:@"FontSize" forStyle:style]];
		if (!fontSize) fontSize = [[plugin messageStyleBundleWithIdentifier:style] objectForInfoDictionaryKey:KEY_WEBKIT_DEFAULT_FONT_SIZE];
		if (!fontSize) fontSize = [NSNumber numberWithInteger:[[NSFont systemFontOfSize:0] pointSize]];

		NSFont	*defaultFont = [NSFont cachedFontWithName:fontFamily size:[fontSize integerValue]];
		[fontPreviewField_currentFont setFont:defaultFont];

		//Style-specific background prefs
		NSData	*backgroundImage = [[adium preferenceController] preferenceForKey:[plugin styleSpecificKey:@"Background" forStyle:style]
																		   group:PREF_GROUP_WEBKIT_BACKGROUND_IMAGES];
		if (backgroundImage) {
			[imageView_backgroundImage setImage:[[[NSImage alloc] initWithData:backgroundImage] autorelease]];
		} else {
			[imageView_backgroundImage setImage:nil];
		}

		NSColor	*backgroundColor = [[prefDict objectForKey:[plugin styleSpecificKey:@"BackgroundColor" forStyle:style]] representedColor];
		[colorWell_customBackgroundColor setColor:(backgroundColor ? backgroundColor : [NSColor whiteColor])] ;

		[checkBox_useCustomBackground setState:[[prefDict objectForKey:[plugin styleSpecificKey:@"UseCustomBackground" forStyle:style]] boolValue]];
		[popUp_backgroundImageType compatibleSelectItemWithTag:[[prefDict objectForKey:[plugin styleSpecificKey:@"BackgroundType" forStyle:style]] integerValue]];

		//Disable the custom background controls if the style doesn't support them
		BOOL	allowCustomBackground = [[previewController messageStyle] allowsCustomBackground];
		[checkBox_useCustomBackground setEnabled:allowCustomBackground];
		[colorWell_customBackgroundColor setEnabled:allowCustomBackground];
		[imageView_backgroundImage setEnabled:allowCustomBackground];
		[popUp_backgroundImageType setEnabled:allowCustomBackground];
		
		//Disable the header control if this style doesn't have a header
		[checkBox_showHeader setEnabled:[[previewController messageStyle] hasHeader]];

		//Disable user icon toggling if the style doesn't support them
		[checkBox_showUserIcons setEnabled:[[previewController messageStyle] allowsUserIcons]];
		
		[checkBox_showMessageColors setEnabled:[[previewController messageStyle] allowsColors]];
	}
}

/*!
 * @brief Save changed preferences
 */
- (IBAction)changePreference:(id)sender
{
	if (viewIsOpen) {
		if (sender == checkBox_showUserIcons) {
			[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
												 forKey:KEY_WEBKIT_SHOW_USER_ICONS
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
		} else if (sender == checkBox_showHeader) {
			[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
												 forKey:KEY_WEBKIT_SHOW_HEADER
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
		} else if (sender == checkBox_showMessageColors) {
			[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
												 forKey:KEY_WEBKIT_SHOW_MESSAGE_COLORS
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
		} else if (sender == checkBox_showMessageFonts) {
			[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
												 forKey:KEY_WEBKIT_SHOW_MESSAGE_FONTS
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
		} else if (sender == checkBox_useCustomBackground) {
			[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
												 forKey:[plugin styleSpecificKey:@"UseCustomBackground" 
																		forStyle:[[popUp_styles selectedItem] representedObject]]
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
		} else if (sender == colorWell_customBackgroundColor) {
			[[adium preferenceController] setPreference:[[colorWell_customBackgroundColor color] stringRepresentation]
												 forKey:[plugin styleSpecificKey:@"BackgroundColor"
																		forStyle:[[popUp_styles selectedItem] representedObject]]
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
		} else if (sender == popUp_backgroundImageType) {
			[[adium preferenceController] setPreference:[NSNumber numberWithInteger:[[popUp_backgroundImageType selectedItem] tag]]
												 forKey:[plugin styleSpecificKey:@"BackgroundType"
																		forStyle:[[popUp_styles selectedItem] representedObject]]
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];	
			
		} else if (sender == popUp_styles) {
			[[adium preferenceController] setPreference:[[sender selectedItem] representedObject]
												 forKey:KEY_WEBKIT_STYLE
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
		} else if (sender == popUp_variants) {
			NSString *activeStyle = [[adium preferenceController] preferenceForKey:KEY_WEBKIT_STYLE
																			 group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
			
			[[adium preferenceController] setPreference:[[sender selectedItem] representedObject]
												 forKey:[plugin styleSpecificKey:@"Variant" forStyle:activeStyle]
												  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
		}
		
		[self configureControlDimming];
	}
}

- (void)configureControlDimming
{
	BOOL customBackground = [checkBox_useCustomBackground state];
	[popUp_backgroundImageType setEnabled:customBackground];
	[imageView_backgroundImage setEnabled:customBackground];
	[colorWell_customBackgroundColor setEnabled:customBackground];
}

/*!
 * @brief Save changes to the font field
 */
- (void)fontPreviewField:(JVFontPreviewField *)field didChangeToFont:(NSFont *)font
{
	[self _setDisplayFontFace:[font fontName] size:[NSNumber numberWithInteger:[font pointSize]]];
}

- (IBAction)resetDisplayFontToDefault:(id)sender
{
	[self _setDisplayFontFace:nil size:0];
}

/*!
 * @brief Set the display font of the active style.
 *
 * @param face New font face, nil to remove custom font
 * @param size New font size, nil to remove custom size
 */
- (void)_setDisplayFontFace:(NSString *)face size:(NSNumber *)size
{
	NSString *activeStyle = [[adium preferenceController] preferenceForKey:KEY_WEBKIT_STYLE
																	 group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
	
	[[adium preferenceController] setPreference:face
										 forKey:[plugin styleSpecificKey:@"FontFamily" forStyle:activeStyle]
										  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
	[[adium preferenceController] setPreference:size
										 forKey:[plugin styleSpecificKey:@"FontSize" forStyle:activeStyle]
										  group:PREF_GROUP_WEBKIT_MESSAGE_DISPLAY];
	
}

/*!
 * @brief Save changes to the background image
 */
- (void)imageViewWithImagePicker:(AIImageViewWithImagePicker *)picker didChangeToImage:(NSImage *)image
{
	[self _setBackgroundImage:image];
}

/*!
 * @brief Remove the background image
 */
- (void)deleteInImageViewWithImagePicker:(AIImageViewWithImagePicker *)picker
{
	[self _setBackgroundImage:nil];
}

/*!
 * @brief Set the background image of the active style.
 *
 * @param image New background image, nil to remove background image
 */
- (void)_setBackgroundImage:(NSImage *)image
{
	NSString	*style = [[popUp_styles selectedItem] representedObject];

	/* Save the new image.  We store the images in a separate preference group since they may get big.
	 * This will let loading other groups not be affected by its presence.
	 */
	[[adium preferenceController] setPreference:[image PNGRepresentation]
										 forKey:[plugin styleSpecificKey:@"Background" forStyle:style]
										  group:PREF_GROUP_WEBKIT_BACKGROUND_IMAGES];
}

/*!
 * @brief Builds and returns a menu of available styles
 */
- (NSMenu *)_stylesMenu
{
	NSMenu			*menu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""];
	NSMutableArray	*menuItemArray = [NSMutableArray array];
	NSArray			*availableStyles = [[plugin availableMessageStyles] allValues];
	NSEnumerator	*enumerator;
	NSBundle		*style;
	NSMenuItem		*menuItem;
	
	enumerator = [availableStyles objectEnumerator];
	while ((style = [enumerator nextObject])) {
		menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[style name]
																		target:nil
																		action:nil
																 keyEquivalent:@""];
		[menuItem setRepresentedObject:[style bundleIdentifier]];
		[menuItemArray addObject:menuItem];
		[menuItem release];
	}
	
	[menuItemArray sortUsingSelector:@selector(titleCompare:)];
	
	enumerator = [menuItemArray objectEnumerator];
	while ((menuItem = [enumerator nextObject])) {
		[menu addItem:menuItem];
	}
	
	return [menu autorelease];
}

/*! 
 * @brief Build & return a menu of variants for the passed style
 */
- (NSMenu *)_variantsMenu
{
	NSMenu			*menu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""];
	NSEnumerator	*enumerator = [[[previewController messageStyle] availableVariants] objectEnumerator];
	NSString		*variant;

	//Add a menu item for each variant
	while ((variant = [enumerator nextObject])) {
		[menu addItemWithTitle:variant
						target:nil
						action:nil
				 keyEquivalent:@""
			 representedObject:variant];
	}

	return [menu autorelease];
}

/*!
 * @brief Build & return a menu of choices for background display
 */
- (NSMenu *)_backgroundImageTypeMenu
{
	NSMenu	*menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];	

	[self _addBackgroundImageTypeChoice:BackgroundNormal toMenu:menu withTitle:AILocalizedString(@"Normal","Background image display preference: The image will be displayed normally")];
	[self _addBackgroundImageTypeChoice:BackgroundCenter toMenu:menu withTitle:AILocalizedString(@"Centered","Background image display preference: The image will be centered in the window")];
	[self _addBackgroundImageTypeChoice:BackgroundTile toMenu:menu withTitle:AILocalizedString(@"Tiled","Background image display preference: The image will be tiled (repeated) in the window to fill available space")];
	[self _addBackgroundImageTypeChoice:BackgroundTileCenter toMenu:menu withTitle:AILocalizedString(@"Tiled (Centered)","Background image display preference: The image will be tiled and centered in the window")];
	[self _addBackgroundImageTypeChoice:BackgroundScale toMenu:menu withTitle:AILocalizedString(@"Scaled", "Background image display preference: The image will be increased or decreased in size to fit the window")];
			
	return [menu autorelease];
}
- (void)_addBackgroundImageTypeChoice:(NSInteger)tag toMenu:(NSMenu *)menu withTitle:(NSString *)title
{
	NSMenuItem	*menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:title
																				 action:nil
																		  keyEquivalent:@""];
	[menuItem setTag:tag];
	[menu addItem:menuItem];
	[menuItem release];
}


//Chat Preview ---------------------------------------------------------------------------------------------------------
#pragma mark Chat Preview
/*!
 * @brief Configure our chat preview
 */
- (void)_configureChatPreview
{
	NSDictionary	*previewDict;
	NSString		*previewFilePath;
	NSString		*previewPath;
	AIChat			*previewChat;

	//Create our fake chat and message controller for the live preview
	previewFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:WEBKIT_PREVIEW_CONVERSATION_FILE ofType:@"plist"];
	previewDict = [[NSDictionary alloc] initWithContentsOfFile:previewFilePath];
	previewPath = [previewFilePath stringByDeletingLastPathComponent];
	
	NSDictionary *listObjects;
	previewChat = [self previewChatWithDictionary:previewDict fromPath:previewPath listObjects:&listObjects];
	previewController = [[AIWebKitPreviewMessageViewController messageDisplayControllerForChat:previewChat
																					withPlugin:plugin] retain];

	//Enable live refreshing of our preview
	[previewController setShouldReflectPreferenceChanges:YES];	
	[previewController setPreferencesChangedDelegate:self];
	
	//Add fake users and content to our chat
	[self _fillContentOfChat:previewChat withDictionary:previewDict fromPath:previewPath listObjects:listObjects];
	[previewDict release];
	
	//Place the preview chat in our view
	preview = [[previewController messageView] retain];
	[preview setFrame:[view_previewLocation frame]];
	//Will be released in viewWillClose
	[view_previewLocation retain];
	[[view_previewLocation superview] replaceSubview:view_previewLocation with:preview];

	//Disable drag and drop onto the preview chat - Jeff doesn't need your porn :)
	if ([preview respondsToSelector:@selector(setAllowsDragAndDrop:)]) {
		[(ESWebView *)preview setAllowsDragAndDrop:NO];
	}

	//Disable forwarding of events so the preferences responder chain works properly
	if ([preview respondsToSelector:@selector(setShouldForwardEvents:)]) {
		[(ESWebView *)preview setShouldForwardEvents:NO];		
	}	
}


- (AIChat *)previewChatWithDictionary:(NSDictionary *)previewDict fromPath:(NSString *)previewPath listObjects:(NSDictionary **)outListObjects
{
	AIPreviewChat *previewChat = [AIPreviewChat previewChat];
	[previewChat setDisplayName:AILocalizedString(@"Sample Conversation", "Title for the sample conversation")];

	//Process and create all participants
	*outListObjects = [self _addParticipants:[previewDict objectForKey:@"Participants"]
									  toChat:previewChat fromPath:previewPath];

	//Setup the chat, and its source/destination
	[self _applySettings:[previewDict objectForKey:@"Chat"]
				  toChat:previewChat withParticipants:*outListObjects];
	
	return previewChat;
}

/*!
 * @brief Fill the content of the specified chat using content archived in the dictionary
 */
- (void)_fillContentOfChat:(AIChat *)inChat withDictionary:(NSDictionary *)previewDict fromPath:(NSString *)previewPath listObjects:(NSDictionary *)listObjects
{
	//Add the archived chat content
	[self _addContent:[previewDict objectForKey:@"Preview Messages"]
			   toChat:inChat withParticipants:listObjects];
}

/*!
 * @brief Add participants
 */
- (NSMutableDictionary *)_addParticipants:(NSDictionary *)participants toChat:(AIChat *)inChat fromPath:(NSString *)previewPath
{
	NSMutableDictionary	*listObjectDict = [NSMutableDictionary dictionary];
	NSEnumerator		*enumerator = [participants objectEnumerator];
	NSDictionary		*participant;
	AIService			*aimService = [[adium accountController] firstServiceWithServiceID:@"AIM"];
	
	while ((participant = [enumerator nextObject])) {
		NSString		*UID, *alias, *userIconName;
		AIListContact	*listContact;
		
		//Create object
		UID = [participant objectForKey:@"UID"];
		listContact = [[AIListContact alloc] initWithUID:UID service:aimService];
		
		//Display name
		if ((alias = [participant objectForKey:@"Display Name"])) {
			[[adium notificationCenter] postNotificationName:Contact_ApplyDisplayName
													  object:listContact
													userInfo:[NSDictionary dictionaryWithObject:alias forKey:@"Alias"]];
		}
		
		//User icon
		if ((userIconName = [participant objectForKey:@"UserIcon Name"])) {
			[listContact setValue:[previewPath stringByAppendingPathComponent:userIconName]
								  forProperty:@"UserIconPath"
								  notify:YES];
		}
		
		[listObjectDict setObject:listContact forKey:UID];
		[listContact release];
	}
	
	return listObjectDict;
}

/*!
 * @brief Chat settings
 */
- (void)_applySettings:(NSDictionary *)chatDict toChat:(AIPreviewChat *)inChat withParticipants:(NSDictionary *)participants
{
	NSString			*dateOpened, *type, *name, *UID;
	
	//Date opened
	if ((dateOpened = [chatDict objectForKey:@"Date Opened"])) {
		[inChat setDateOpened:[NSDate dateWithNaturalLanguageString:dateOpened]];
	}
	
	//Source/Destination
	type = [chatDict objectForKey:@"Type"];
	if ([type isEqualToString:@"IM"]) {
		if ((UID = [chatDict objectForKey:@"Destination UID"])) {
			[inChat addObject:[participants objectForKey:UID]];
		}
		if ((UID = [chatDict objectForKey:@"Source UID"])) {
			[inChat setAccount:(AIAccount *)[participants objectForKey:UID]];
		}
	} else {
		if ((name = [chatDict objectForKey:@"Name"])) {
			[inChat setName:name];
		}
	}
	
	//We don't want the interface controller to try to open this fake chat
	[inChat setIsOpen:YES];
}

/*!
 * @brief Chat content
 */
- (void)_addContent:(NSArray *)chatArray toChat:(AIChat *)inChat withParticipants:(NSDictionary *)participants
{
	NSEnumerator		*enumerator;
	NSDictionary		*messageDict;
	
	enumerator = [chatArray objectEnumerator];
	while ((messageDict = [enumerator nextObject])) {
		AIContentObject		*content = nil;
		AIListObject		*source;
		NSString			*from, *msgType;
		NSAttributedString  *message;
		
		msgType = [messageDict objectForKey:@"Type"];
		from = [messageDict objectForKey:@"From"];

		source = (from ? [participants objectForKey:from] : nil);

		if ([msgType isEqualToString:CONTENT_MESSAGE_TYPE]) {
			//Create message content object
			AIListObject		*dest;
			NSString			*to;
			BOOL				outgoing;

			message = [AIHTMLDecoder decodeHTML:[messageDict objectForKey:@"Message"]];
			to = [messageDict objectForKey:@"To"];
			outgoing = [[messageDict objectForKey:@"Outgoing"] boolValue];

			//The other person is always the one we're chatting with right now
			dest = [participants objectForKey:to];
			content = [AIPreviewContentMessage messageInChat:inChat
												  withSource:source
												 destination:dest
														date:[NSDate dateWithNaturalLanguageString:[messageDict objectForKey:@"Date"]]
													 message:message
												   autoreply:[[messageDict objectForKey:@"Autoreply"] boolValue]];

			//AIContentMessage won't know whether the message is outgoing unless we tell it since neither our source
			//nor our destination are AIAccount objects.
			[(AIPreviewContentMessage *)content setIsOutgoing:outgoing];

		} else if ([msgType isEqualToString:CONTENT_STATUS_TYPE]) {
			//Create status content object
			NSString			*statusMessageType;
			
			message = [AIHTMLDecoder decodeHTML:[messageDict objectForKey:@"Message"]];
			statusMessageType = [messageDict objectForKey:@"Status Message Type"];
			
			//Create our content object
			content = [AIContentStatus statusInChat:inChat
										 withSource:source
										destination:nil
											   date:[NSDate dateWithNaturalLanguageString:[messageDict objectForKey:@"Date"]]
											message:message
										   withType:statusMessageType];
		}

		if (content) {			
			[content setTrackContent:NO];
			[content setPostProcessContent:NO];
			[content setDisplayContentImmediately:NO];
			
			[[adium contentController] displayContentObject:content
										usingContentFilters:YES
												immediately:YES];
		}
	}

	//We finished adding untracked content
	[[adium notificationCenter] postNotificationName:Content_ChatDidFinishAddingUntrackedContent
											  object:inChat];
}

@end
