//
//  AIDockingWindow.m
//  Adium
//
//  Created by Adam Iser on Sun May 02 2004.
//

#import "AIDockingWindow.h"
#import "AIEventAdditions.h"
#import "AITigerCompatibility.h"

#define WINDOW_DOCKING_DISTANCE 	12	//Distance in pixels before the window is snapped to an edge
#define IGNORED_X_RESISTS			3
#define IGNORED_Y_RESISTS			3

@interface AIDockingWindow (PRIVATE)
- (void)_initDockingWindow;
- (NSRect)dockWindowFrame:(NSRect)windowFrame toScreenFrame:(NSRect)screenFrame;
@end

@interface NSWindow (AIUNDOCUMENTED)
- (void)_toolbarPillButtonClicked:(id)sender;
@end

@implementation AIDockingWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	if ((self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag])) {
		[self _initDockingWindow];
	}

	return self;
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder])) {
		[self _initDockingWindow];
	}

	return self;
}
- (id)init
{
	if ((self = [super init])) {
		[self _initDockingWindow];
	}
	return self;
}

//Observe window movement
- (void)_initDockingWindow
{
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(windowDidMove:)
												 name:NSWindowDidMoveNotification 
											   object:self];
	resisted_XMotion = 0;
	resisted_YMotion = 0;
	oldWindowFrame = NSMakeRect(0,0,0,0);
	alreadyMoving = NO;
	dockingEnabled = YES;
}

//Stop observing movement
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowDidMoveNotification
												  object:self];
	[super dealloc];
}

//Watch the window move.  If it gets near an edge, dock it to that edge
- (void)windowDidMove:(NSNotification *)notification
{
	//Our setFrame call below will cause a re-entry into this function, we must guard against this
	if (!alreadyMoving && dockingEnabled && ![NSEvent shiftKey]) {
		alreadyMoving = YES;	
		
		//Attempt to dock this window the the visible frame first, and then to the screen frame
		NSRect	newWindowFrame = [self frame];
		NSRect  dockedWindowFrame;
		
		dockedWindowFrame = [self dockWindowFrame:newWindowFrame toScreenFrame:[[self screen] visibleFrame]];
		dockedWindowFrame = [self dockWindowFrame:dockedWindowFrame toScreenFrame:[[self screen] frame]];

		//If the window wants to dock, animate it into place
		if (!NSEqualRects(newWindowFrame, dockedWindowFrame)) {
			
			if (!NSIsEmptyRect(oldWindowFrame)) {
				BOOL	user_XMovingLeft = ((oldWindowFrame.origin.x - newWindowFrame.origin.x) >= 0);
				BOOL	docking_XMovingLeft = ((newWindowFrame.origin.x - dockedWindowFrame.origin.x) >= 0);
				
				//If the user is trying to move in the opposite X direction as the docking movement, use the user's movement
				if ((user_XMovingLeft && !docking_XMovingLeft) || (!user_XMovingLeft && docking_XMovingLeft)) {
					if (resisted_XMotion <= IGNORED_X_RESISTS) {
						dockedWindowFrame.origin.x = newWindowFrame.origin.x;
						resisted_XMotion = 0;
					} else {
						resisted_XMotion++;
					}
				} else {
					//They went with the flow
					resisted_XMotion = 0;
				}
				
				BOOL	user_YMovingDown = ((oldWindowFrame.origin.y - newWindowFrame.origin.y) >= 0);
				BOOL	docking_YMovingDown = ((newWindowFrame.origin.y - dockedWindowFrame.origin.y) >= 0);
				
				//If the user is trying to move in the opposite Y direction as the docking movement, use the user's movement
				if ((user_YMovingDown && !docking_YMovingDown) || (!user_YMovingDown && docking_YMovingDown)) {
					if (resisted_YMotion <= IGNORED_Y_RESISTS) {
						dockedWindowFrame.origin.y = newWindowFrame.origin.y;
						resisted_YMotion = 0;
					} else {
						resisted_YMotion++;
					}
				} else {
					resisted_YMotion = 0;
				}
			}
			
			[self setFrame:dockedWindowFrame display:YES animate:YES];
			oldWindowFrame = dockedWindowFrame;
			
		} else {
			resisted_XMotion = 0;
			resisted_YMotion = 0;	
			oldWindowFrame = NSMakeRect(0,0,0,0);
		}
		
		alreadyMoving = NO; //Clear the guard, we are now safe
	}
}

//Dock the passed window frame if it's close enough to the screen edges
- (NSRect)dockWindowFrame:(NSRect)windowFrame toScreenFrame:(NSRect)screenFrame
{
	//Left
	if (abs(NSMinX(windowFrame) - NSMinX(screenFrame)) < WINDOW_DOCKING_DISTANCE) {
		windowFrame.origin.x = screenFrame.origin.x;
	}
	
	//Bottom
	if (abs(NSMinY(windowFrame) - NSMinY(screenFrame)) < WINDOW_DOCKING_DISTANCE) {
		windowFrame.origin.y = screenFrame.origin.y;
	}
	
	//Right
	if (abs(NSMaxX(windowFrame) - NSMaxX(screenFrame)) < WINDOW_DOCKING_DISTANCE) {
		windowFrame.origin.x -= NSMaxX(windowFrame) - NSMaxX(screenFrame);
	}
	
	//Top
	if (abs(NSMaxY(windowFrame) - NSMaxY(screenFrame)) < WINDOW_DOCKING_DISTANCE) {
		windowFrame.origin.y -= NSMaxY(windowFrame) - NSMaxY(screenFrame);
	}
	
	return windowFrame;
}

- (void)toggleToolbarShown:(id)sender
{
	[super toggleToolbarShown:sender];
	
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(windowDidToggleToolbarShown:)]) {
		[[self delegate] performSelector:@selector(windowDidToggleToolbarShown:)
							  withObject:self];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AIWindowToolbarDidToggleVisibility
														object:self];
}

- (void)_toolbarPillButtonClicked:(id)sender
{
	[super _toolbarPillButtonClicked:sender];
	
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(windowDidToggleToolbarShown:)]) {
		[[self delegate] performSelector:@selector(windowDidToggleToolbarShown:)
							  withObject:self];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AIWindowToolbarDidToggleVisibility
														object:self];
}

- (void)setDockingEnabled:(BOOL)inEnabled
{
	dockingEnabled = inEnabled;
}

@end
