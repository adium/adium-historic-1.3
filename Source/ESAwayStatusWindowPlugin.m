//
//  ESAwayStatusWindowPlugin.m
//  Adium
//
//  Created by Evan Schoenberg on 4/12/05.
//  Copyright 2006 The Adium Team. All rights reserved.
//

#import "ESAwayStatusWindowPlugin.h"
#import "ESAwayStatusWindowController.h"
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIPreferenceControllerProtocol.h>
#import "AISoundController.h"
#import "AIStatusController.h"
#import <Adium/AIAccount.h>
#import <Adium/AIListObject.h>

/*!
 * @class ESAwayStatusWindowPlugin
 * @brief Component to manage the status window optionally displayed when one or more accounts are away
 *
 * XXX - This comopnent should move to being an external, included, disabled by default plugin, with more
 * options added when it is enabled.
 */
@implementation ESAwayStatusWindowPlugin

/*!
 * @brief Install
 */
- (void)installPlugin
{
	showStatusWindow = FALSE;
	awayAccounts = [[NSMutableSet alloc] init];
	
	//Observe preference changes for updating if we should show the status window
	[[adium preferenceController] registerPreferenceObserver:self 
													forGroup:PREF_GROUP_STATUS_PREFERENCES];
}

- (void)uninstallPlugin
{
	[[adium preferenceController] unregisterPreferenceObserver:self];
	[[adium contactController] unregisterListObjectObserver:self];
}

/*!
 * @brief Deallocate
 */
- (void)dealloc
{
	[awayAccounts release];

	[super dealloc];
}

/*!
 * @brief Preferences changed
 *
 * Note whether we are supposed to should show the status window, and toggle it if necessary
 */
- (void)preferencesChangedForGroup:(NSString *)group key:(NSString *)key
							object:(AIListObject *)object preferenceDict:(NSDictionary *)prefDict firstTime:(BOOL)firstTime
{
	BOOL oldShowStatusWindow = showStatusWindow;
	
	showStatusWindow = [[prefDict objectForKey:KEY_STATUS_SHOW_STATUS_WINDOW] boolValue];
	
	if (showStatusWindow != oldShowStatusWindow) {
		if (showStatusWindow) {
			/* Register as a list object observer, which will update all objects for us immediately leading to the proper
			 * status window toggling. */
			[[adium contactController] registerListObjectObserver:self];
		} else {
			//Hide the status window if it is currently visible
			[ESAwayStatusWindowController updateStatusWindowWithVisibility:NO];
			
			//Clear our away account tracking
			[awayAccounts removeAllObjects];
			
			//Stop observing list objects
			[[adium contactController] unregisterListObjectObserver:self];
		}
	}

	if (showStatusWindow) {
		[ESAwayStatusWindowController setAlwaysOnTop:[[prefDict objectForKey:KEY_STATUS_STATUS_WINDOW_ON_TOP] boolValue]];
		[ESAwayStatusWindowController setHideInBackground:[[prefDict objectForKey:KEY_STATUS_STATUS_WINDOW_HIDE_IN_BACKGROUND] boolValue]];
	}
}

/*!
 * @brief Account status changed.
 *
 * Show or hide our status window as appropriate
 */
- (NSSet *)updateListObject:(AIListObject *)inObject keys:(NSSet *)inModifiedKeys silent:(BOOL)silent
{
	if ([inObject isKindOfClass:[AIAccount class]] &&
	   (!inModifiedKeys || [inModifiedKeys containsObject:@"StatusState"] || [inModifiedKeys containsObject:@"Online"])) {
		if ([inObject online] && ([inObject statusType] != AIAvailableStatusType)) {
			[awayAccounts addObject:inObject];
		} else {
			[awayAccounts removeObject:inObject];
		}

		/* We wait until the next run loop so we can have processed multiple changing accounts at once before updating
		 * our display, preventing flickering through changes as the global state changes and thereby modifies multiple
		 * account states in a single invocation.
		 */
		[NSObject cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(processStatusUpdate)
												   object:nil];
		[self performSelector:@selector(processStatusUpdate)
				   withObject:nil
				   afterDelay:0];
	}

	//We don't modify any keys
	return nil;
}

- (void)processStatusUpdate
{
	//Tell the window to update, showing/hiding as necessary
	[ESAwayStatusWindowController updateStatusWindowWithVisibility:([awayAccounts count] > 0)];	
}

@end
