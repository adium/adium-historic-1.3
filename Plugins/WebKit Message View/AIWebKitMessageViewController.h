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

#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIMetaContact.h>

@class AIWebKitMessageViewPlugin, AIWebkitMessageViewStyle, AIContentObject, ESWebView, DOMDocument;
@class AIChat, AIContentObject;
@class AIWebKitDelegate;

/*!
 *	@class AIWebKitMessageViewController AIWebKitMessageViewController.h
 *	@brief Main class for the webkit message view. Most of the good stuff happens here
 */
@interface AIWebKitMessageViewController : NSObject <AIMessageDisplayController> {
	AIWebKitDelegate			*delegateProxy;
	
	id							plugin;
	ESWebView					*webView;
	AIChat						*chat;
	BOOL						shouldReflectPreferenceChanges;
	BOOL						isUpdatingWebViewForCurrentPreferences;

	//Content processing
	AIContentObject				*previousContent;
	NSMutableArray				*contentQueue;
	NSMutableArray				*storedContentObjects;
	BOOL						webViewIsReady;
	
	//Style & Variant
	AIWebkitMessageViewStyle	*messageStyle;
	NSString					*activeStyle;
	NSString					*activeVariant;

	//User icon masking
	NSImage						*imageMask;
	NSMutableArray				*objectsWithUserIconsArray;
	NSMutableDictionary			*objectIconPathDict;
}

/*!
 *	@brief Create a new message view controller
 */
+ (AIWebKitMessageViewController *)messageDisplayControllerForChat:(AIChat *)inChat withPlugin:(AIWebKitMessageViewPlugin *)inPlugin;

/*!
 *	@brief Print the webview
 *
 *	WebView does not have a print method, and [[webView mainFrame] frameView] is implemented to print only the visible portion of the view. 
 *	We have to get the scrollview and from there the documentView to have access to all of the webView.
 */
- (void)adiumPrint:(id)sender;

//Webview
/*!
 *	@return  the ESWebView which should be inserted into the message window 
 */
- (NSView *)messageView;

/*!
 *	@return our scroll view
 */
- (NSView *)messageScrollView;

/*!
 *	@return our message style controller
 */
- (AIWebkitMessageViewStyle *)messageStyle;

/*!
 *	@brief Clears the view from displayed messages
 *
 *	Implements the method defined in protocol AIMessageDisplayController
 */
- (void)clearView;

/*!
 *	@brief Enable or disable updating to reflect preference changes
 *
 *	When disabled, the view will not update when a preferece changes that would require rebuilding the views content
 */
- (void)setShouldReflectPreferenceChanges:(BOOL)inValue;

/*!
 * @brief Set the HTML content for the "Chat" area.
 */
- (void)setChatContentSource:(NSString *)source;

/*!
 * @brief Get the HTML content for the "Chat" area.
 */
- (NSString *)chatContentSource;

- (void)preferencesChangedForGroup:(NSString *)group key:(NSString *)key object:(AIListObject *)object
					preferenceDict:(NSDictionary *)prefDict firstTime:(BOOL)firstTime;

@end
