//
//  AIContactInfoImageViewWithImagePicker.m
//  Adium
//
//  Created by Evan Schoenberg on 10/1/06.
//

#import "AIContactInfoImageViewWithImagePicker.h"
#import <AIUtilities/AIBezierPathAdditions.h>
#import <AIUtilities/AIImageAdditions.h>

@interface AIContactInfoImageViewWithImagePicker (PRIVATE)
- (void)resetCursorRects;
- (NSRect)_snapbackRectForFrame:(NSRect)cellFrame;
@end

@implementation AIContactInfoImageViewWithImagePicker

- (void)configureTracking
{
	resetImageTrackingTag = -1;
	[self resetCursorRects];			
}

- (id)initWithFrame:(NSRect)inFrame
{
	if ((self = [super initWithFrame:inFrame])) {
		[self configureTracking];
	}
	
	return self;
}

- (void)awakeFromNib
{
	if ([[self superclass] instancesRespondToSelector:@selector(awakeFromNib)]) {
        [super awakeFromNib];
	}
	
	[self configureTracking];
}

- (void)dealloc
{
	if (resetImageTrackingTag != -1) {
		[self removeTrackingRect:resetImageTrackingTag];
		resetImageTrackingTag = -1;
	}
	
	[super dealloc];
}


- (void)drawRect:(NSRect)inRect
{
	[NSGraphicsContext saveGraphicsState];
	
	inRect = NSInsetRect(inRect, 1, 1);
	
	NSBezierPath	*clipPath = [NSBezierPath bezierPathWithRoundedRect:inRect radius:3];
	
	[[NSColor windowFrameColor] set];
	[clipPath setLineWidth:1];
	[clipPath stroke];
	
	//Ensure we have an even/odd winding rule in effect
	[clipPath setWindingRule:NSEvenOddWindingRule];
	[clipPath addClip];
	
	[NSGraphicsContext saveGraphicsState];
	[super drawRect:inRect];
	[NSGraphicsContext restoreGraphicsState];

	// Draw snapback image
	if (showResetImageButton) {
		NSImage *snapbackImage = [NSImage imageNamed:@"SRSnapback" forClass:[self class]];
		NSRect snapBackRect = [self _snapbackRectForFrame:[self bounds]];
		if (resetImageHovered) {
			[[[NSColor blackColor] colorWithAlphaComponent:0.8] set];		
		} else {
			[[[NSColor blackColor] colorWithAlphaComponent:0.5] set];
		}
		
		[[NSBezierPath bezierPathWithOvalInRect:snapBackRect] fill];
		[snapbackImage dissolveToPoint:snapBackRect.origin fraction:1.0];
	}
		
	/*
	if (hovered) {
		[[[NSColor blackColor] colorWithAlphaComponent:0.40] set];
		[clipPath fill];
		
		//Draw the arrow
		NSBezierPath	*arrowPath = [NSBezierPath bezierPath];
		NSRect			frame = [self frame];
		[arrowPath moveToPoint:NSMakePoint(frame.size.width - ARROW_XOFFSET - ARROW_WIDTH, 
										   (ARROW_YOFFSET + ARROW_HEIGHT))];
		[arrowPath relativeLineToPoint:NSMakePoint(ARROW_WIDTH, 0)];
		[arrowPath relativeLineToPoint:NSMakePoint(-(ARROW_WIDTH/2), -(ARROW_HEIGHT))];
		
		[[NSColor whiteColor] set];
		[arrowPath fill];
	}
	*/

	[NSGraphicsContext restoreGraphicsState];
}

#pragma mark Snapback
- (NSRect)_snapbackRectForFrame:(NSRect)cellFrame
{	
	if (!showResetImageButton) return NSZeroRect;
	
	NSRect snapbackRect;
	NSImage *snapbackImage = [NSImage imageNamed:@"SRSnapback" forClass:[self class]];

	snapbackRect.origin = NSMakePoint(NSMaxX(cellFrame) - [snapbackImage size].width - 1, 2);
	snapbackRect.size = [snapbackImage size];

	return snapbackRect;
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	if ([[self window] isKeyWindow] || [self acceptsFirstMouse: theEvent]) {
		resetImageHovered = YES;
		[self display];
	}
	
	[super mouseEntered:theEvent];
}

- (void)mouseExited:(NSEvent*)theEvent
{	
	if ([[self window] isKeyWindow] || [self acceptsFirstMouse: theEvent]) {
		resetImageHovered = NO;
		[self display];
	}

	[super mouseEntered:theEvent];
}

- (void)mouseDown:(NSEvent *)inEvent
{
	NSPoint mouseLocation = [self convertPoint:[inEvent locationInWindow] fromView:nil];
	if ([self mouse:mouseLocation inRect:[self _snapbackRectForFrame:[self bounds]]]) {
		if ([[self delegate] respondsToSelector:@selector(deleteInImageViewWithImagePicker:)]) {
			[[self delegate] deleteInImageViewWithImagePicker:self];
		}

	} else {
		[super mouseDown:inEvent];
	}
}

- (void)setShowResetImageButton:(BOOL)inShowResetImageButton
{
	showResetImageButton = inShowResetImageButton;

	[self resetCursorRects];
}


#pragma mark Tracking rects
//Remove old tracking rects when we change superviews
- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
	if (resetImageTrackingTag != -1) {
		[self removeTrackingRect:resetImageTrackingTag];
		resetImageTrackingTag = -1;
	}
	
	[super viewWillMoveToSuperview:newSuperview];
}

- (void)viewDidMoveToSuperview
{
	[super viewDidMoveToSuperview];
	
	[self resetCursorRects];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	if (resetImageTrackingTag != -1) {
		[self removeTrackingRect:resetImageTrackingTag];
		resetImageTrackingTag = -1;
	}
	
	[super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	
	[self resetCursorRects];
}

- (void)frameDidChange:(NSNotification *)inNotification
{
	[self resetCursorRects];
}

//Reset our cursor tracking
- (void)resetCursorRects
{
	//Stop any existing tracking
	if (resetImageTrackingTag != -1) {
		[self removeTrackingRect:resetImageTrackingTag];
		resetImageTrackingTag = -1;
	}
	
	//Add a tracking rect if our superview and window are ready
	if (showResetImageButton && [self superview] && [self window]) {
		NSRect	snapbackRect = [self _snapbackRectForFrame:[self bounds]];
		NSPoint	mouseLocation = [self convertPoint:[[NSApp currentEvent] locationInWindow] fromView:nil];
		BOOL	mouseInside = [self mouse:mouseLocation inRect:snapbackRect];

		resetImageTrackingTag = [self addTrackingRect:snapbackRect owner:self userData:nil assumeInside:mouseInside];
		if (mouseInside) [self mouseEntered:nil];
	}
}

@end
