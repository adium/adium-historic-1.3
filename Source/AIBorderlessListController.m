//
//  AIBorderlessListController.m
//  Adium
//
//  Created by Evan Schoenberg on 1/8/06.
//

#import "AIBorderlessListController.h"
#import "AIListOutlineView.h"

@implementation AIBorderlessListController

- (id)initWithContactList:(AIListObject<AIContainingObject> *)aContactList
			inOutlineView:(AIListOutlineView *)inContactListView
			 inScrollView:(AIAutoScrollView *)inScrollView_contactList
				 delegate:(id<AIListControllerDelegate>)inDelegate
{
	if ((self = [super initWithContactList:aContactList
							 inOutlineView:inContactListView
							  inScrollView:inScrollView_contactList
								  delegate:inDelegate])) {
		emptyListHiding = NO;
		[self contactOrderChanged:nil];
	}
	
	return self;
}

- (void)configureViewsAndTooltips
{
	[super configureViewsAndTooltips];
	
	[self contactOrderChanged:nil];
}
/*!
 * @brief When the contact order changes, check to ensure we have 1 or more visible rows
 *
 * If we have no rows visible, hide the contact list, redisplaying it when rows are visible again.
 * orderOut: doesn't appear to work for borderless windows, so we just go to an alpha value of 0.
 */
- (void)contactOrderChanged:(NSNotification *)notification
{
	[super contactOrderChanged:notification];

	int numberOfRows = [contactListView numberOfRows];

	if (numberOfRows && emptyListHiding) {	
		emptyListHiding = NO;		
		[[contactListView window] setAlphaValue:previousAlpha];
		[[contactListView window] orderFront:nil];

	} else if (!numberOfRows && !emptyListHiding) {	
		emptyListHiding = YES;
		previousAlpha = [[contactListView window] alphaValue];
		[[contactListView window] setAlphaValue:0.0];
	}
}

@end
