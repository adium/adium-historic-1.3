//
//  AIImageAdditions.m
//  Adium
//
//  Created by Evan Schoenberg on Tue Dec 02 2003.
//

#import "AIImageAdditions.h"

@interface NSImage (AIImageAdditions_PRIVATE)
- (NSBitmapImageRep *)bitmapRep;
@end

@implementation NSImage (AIImageAdditions)

+ (NSImage *)imageNamed:(NSString *)name forClass:(Class)inClass loadLazily:(BOOL)flag
{
	NSBundle	*ownerBundle;
    NSString	*imagePath;
    NSImage		*image;
	
    //Get the bundle
    ownerBundle = [NSBundle bundleForClass:inClass];
	
    //Open the image
    imagePath = [ownerBundle pathForImageResource:name];   
	if(flag)
		image = [[NSImage alloc] initByReferencingFile:imagePath];
	else
		image = [[NSImage alloc] initWithContentsOfFile:imagePath];
	
    return [image autorelease];	
}

// Returns an image from the owners bundle with the specified name
+ (NSImage *)imageNamed:(NSString *)name forClass:(Class)inClass
{	
	return [self imageNamed:name forClass:inClass loadLazily:NO];
}

+ (NSImage *)imageForSSL
{
	static NSImage *SSLIcon = nil;
	if (!SSLIcon) {
		NSBundle *securityInterfaceFramework = [NSBundle bundleWithIdentifier:@"com.apple.securityinterface"];
		if (!securityInterfaceFramework) securityInterfaceFramework = [NSBundle bundleWithPath:@"/System/Library/Frameworks/SecurityInterface.framework"];

		SSLIcon = [[NSImage alloc] initByReferencingFile:[securityInterfaceFramework pathForImageResource:@"CertSmallStd"]];
	}
	return SSLIcon;
}

//Create and return an opaque bitmap image rep, replacing transparency with [NSColor whiteColor]
- (NSBitmapImageRep *)opaqueBitmapImageRep
{
	NSImage				*tempImage = nil;
	NSBitmapImageRep	*imageRep = nil;
	NSSize				size = [self size];
	
	//Work with a temporary image so we don't modify self
	tempImage = [[[NSImage allocWithZone:[self zone]] initWithSize:size] autorelease];
	
	//Lock before drawing to the temporary image
	[tempImage lockFocus];
	
	//Fill with a white background
	[[NSColor whiteColor] set];
	NSRectFill(NSMakeRect(0, 0, size.width, size.height));
	
	//Draw the image
	[self compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
	
	//We're done drawing
	[tempImage unlockFocus];
	
	NSEnumerator *repEnumerator = [[tempImage representations] objectEnumerator];
	NSImageRep *rep = nil;	
	
	//Find an NSBitmapImageRep from the temporary image
	while ((rep = [repEnumerator nextObject])) {
		if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
			imageRep = (NSBitmapImageRep *)rep;
		}
	}
	
	//Make one if necessary
	if (!imageRep) {
		imageRep = [NSBitmapImageRep imageRepWithData:[tempImage TIFFRepresentation]];
    }
	
	// 10.6 behavior: Drawing into a new image copies the display's color profile in.
	// Remove the color profile so we don't bloat the image size.
	[imageRep setProperty:NSImageColorSyncProfileData withValue:nil];
	
	return imageRep;
}

- (NSBitmapImageRep *)largestBitmapImageRep
{
	//Find the biggest image
	NSEnumerator *repsEnum = [[self representations] objectEnumerator];
	NSBitmapImageRep *bestRep = nil;
	NSImageRep *rep;
	Class NSBitmapImageRepClass = [NSBitmapImageRep class];
	float maxWidth = 0;
	while ((rep = [repsEnum nextObject])) {
		if ([rep isKindOfClass:NSBitmapImageRepClass]) {
			float thisWidth = [rep size].width;
			if (thisWidth >= maxWidth) {
				//Cast explanation: GCC warns about us returning an NSImageRep here, presumably because it could be some other kind of NSImageRep if we don't check the class. Fortunately, we have such a check. This cast silences the warning.
				bestRep = (NSBitmapImageRep *)rep;
				maxWidth = thisWidth;
			}
		}
	}
	
	//We don't already have one, so forge one from our TIFF representation.
	if (!bestRep)
		bestRep = [NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
	
	return bestRep;
}

- (NSData *)JPEGRepresentation
{	
	return [self JPEGRepresentationWithCompressionFactor:1.0];
}

- (NSData *)JPEGRepresentationWithCompressionFactor:(float)compressionFactor
{
	/* JPEG does not support transparency, but NSImage does. We need to create a non-transparent NSImage
	* before creating our representation or transparent parts will become black.  White is preferable.
	*/
	return ([[self opaqueBitmapImageRep] representationUsingType:NSJPEGFileType 
													  properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor] 
																							 forKey:NSImageCompressionFactor]]);	
}
- (NSData *)JPEGRepresentationWithMaximumByteSize:(unsigned)maxByteSize
{
	/* JPEG does not support transparency, but NSImage does. We need to create a non-transparent NSImage
	 * before creating our representation or transparent parts will become black.  White is preferable.
	 */
	NSBitmapImageRep *opaqueBitmapImageRep = [self opaqueBitmapImageRep];
	NSData *data = nil;
	for (float compressionFactor = 0.99; compressionFactor > 0.4; compressionFactor -= 0.01) {
		data = [opaqueBitmapImageRep representationUsingType:NSJPEGFileType 
												  properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor] 
																						 forKey:NSImageCompressionFactor]];
		if (data && ([data length] <= maxByteSize)) {
			break;
		} else {
			data = nil;
		}
	}

	return data;
}

- (NSData *)PNGRepresentation
{
	/* PNG is easy; it supports everything TIFF does, and NSImage's PNG support is great. */
	NSBitmapImageRep	*bitmapRep =  [self largestBitmapImageRep];

	return ([bitmapRep representationUsingType:NSPNGFileType properties:nil]);
}

- (NSData *)BMPRepresentation
{
	/* BMP does not support transparency, but NSImage does. We need to create a non-transparent NSImage
	 * before creating our representation or transparent parts will become black.  White is preferable.
	 */

	return ([[self opaqueBitmapImageRep] representationUsingType:NSBMPFileType properties:nil]);
}

- (NSBitmapImageRep *)getBitmap
{
	[self lockFocus];
	
	NSSize size = [self size];
	NSRect rect = NSMakeRect(0.0, 0.0, size.width, size.height);
	NSBitmapImageRep	*bm = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:rect] autorelease];
	
	[self unlockFocus];
	
	return bm;
}

//
// NOTE: Black & White images fail miserably
// So we must get their data and blast that into a deeper cache
// Yucky, so we wrap this all up inside this object...
//
- (NSBitmapImageRep *)bitmapRepForGIFRepresentation
{
	NSArray *reps = [self representations];
	int i = [reps count];
	while (i--) {
		NSBitmapImageRep *rep = (NSBitmapImageRep *)[reps objectAtIndex:i];
		if ([rep isKindOfClass:[NSBitmapImageRep class]] &&
			([rep bitsPerPixel] > 2))
			return rep;
	}
	return [self getBitmap];
}

- (NSData *)GIFRepresentation
{
	//This produces ugly output.  Very ugly.

	NSData	*GIFRepresentation = nil;
	
	NSBitmapImageRep *bm = [self bitmapRepForGIFRepresentation]; 
	
	if (bm) {
		NSDictionary *properties =  [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:YES], NSImageDitherTransparency,
			nil];
		
		NSSize size = [self size];
		
		if (size.width > 0 && size.height > 0) {
			
			@try {
				GIFRepresentation = [bm representationUsingType:NSGIFFileType
													 properties:properties];
			}
			@catch(id exc) {
				GIFRepresentation = nil;	// must have failed
			}
		}
	}

	return GIFRepresentation;
}
	
+ (AIBitmapImageFileType)fileTypeOfData:(NSData *)inData
{
	const char *data = [inData bytes];
	unsigned len = [inData length];
	AIBitmapImageFileType fileType = AIUnknownFileType;

	if (len >= 4) {
		if (!strncmp((char *)data, "GIF8", 4))
			fileType = AIGIFFileType;
		else if (!strncmp((char *)data, "\xff\xd8\xff", 3)) /* 4th may be e0 through ef */
			fileType = AIJPEGFileType;
		else if (!strncmp((char *)data, "\x89PNG", 4))
			fileType = AIPNGFileType;
		else if (!strncmp((char *)data, "MM", 2) ||
				 !strncmp((char *)data, "II", 2))
			fileType = AITIFFFileType;
		else if (!strncmp((char *)data, "BM", 2))
			fileType = AIBMPFileType;
	}
	
	return fileType;
}

+ (NSString *)extensionForBitmapImageFileType:(AIBitmapImageFileType)inFileType
{
	NSString *extension = nil;
	switch (inFileType) {
		case AIUnknownFileType:
			break;
		case AITIFFFileType:
			extension = @"tif";
			break;
		case AIBMPFileType:
			extension = @"bmp";
			break;
		case AIGIFFileType:
			extension = @"gif";
			break;
		case AIJPEGFileType:
			extension = @"jpg";
			break;
		case AIPNGFileType:
			extension = @"png";
			break;
		case AIJPEG2000FileType:
			extension = @"jp2";
			break;
	}
	
	return extension;
}

@end
