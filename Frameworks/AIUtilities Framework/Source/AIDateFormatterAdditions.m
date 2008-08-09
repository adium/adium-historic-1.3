//
//  AIDateFormatterAdditions.m
//  Adium
//
//  Created by Evan Schoenberg on Wed Oct 01 2003.
//

#import "AIDateFormatterAdditions.h"
#import "AIApplicationAdditions.h"
#import "AIDateAdditions.h"
#import "AIStringUtilities.h"
#import "AITigercompatibility.h"

#define ONE_WEEK AILocalizedStringFromTableInBundle(@"1 week", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define MULTIPLE_WEEKS AILocalizedStringFromTableInBundle(@"%i weeks", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define ONE_DAY AILocalizedStringFromTableInBundle(@"1 day", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define MULTIPLE_DAYS AILocalizedStringFromTableInBundle(@"%i days", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define ONE_HOUR AILocalizedStringFromTableInBundle(@"1 hour", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define MULTIPLE_HOURS AILocalizedStringFromTableInBundle(@"%i hours", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define ONE_MINUTE AILocalizedStringFromTableInBundle(@"1 minute", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define MULTIPLE_MINUTES AILocalizedStringFromTableInBundle(@"%i minutes", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define ONE_SECOND AILocalizedStringFromTableInBundle(@"1 second", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)
#define MULTIPLE_SECONDS AILocalizedStringFromTableInBundle(@"%1.0lf seconds", nil, [NSBundle bundleWithIdentifier:AIUTILITIES_BUNDLE_ID], nil)

typedef enum {
    NONE,
    SECONDS,
    AMPM,
    BOTH
} StringType;

@implementation NSDateFormatter (AIDateFormatterAdditions)

+ (NSDateFormatter *)localizedDateFormatter
{
	return [[[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSDateFormatString] 
								   allowNaturalLanguage:NO] autorelease];
}
+ (NSDateFormatter *)localizedShortDateFormatter
{
	return [[[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString] 
								   allowNaturalLanguage:NO] autorelease];
}

+ (NSDateFormatter *)localizedDateFormatterShowingSeconds:(BOOL)seconds showingAMorPM:(BOOL)showAmPm
{
    NSString	*format = [self localizedDateFormatStringShowingSeconds:seconds showingAMorPM:showAmPm];
	
	return [[[NSDateFormatter alloc] initWithDateFormat:format allowNaturalLanguage:NO] autorelease];
}

+ (NSString *)localizedDateFormatStringShowingSeconds:(BOOL)seconds showingAMorPM:(BOOL)showAmPm
{
    static NSString 	*cache[4] = {nil,nil,nil,nil}; //Cache for the 4 combinations of date string
    static NSString     *oldTimeFormatString = nil;

    NSString            *currentTimeFormatString = [[NSUserDefaults standardUserDefaults] stringForKey:NSTimeFormatString];

    //if the time format string changed, clear the cache, then save the current one
    if (![currentTimeFormatString isEqualToString:oldTimeFormatString]) {
        for (unsigned i = 0; i < 4; i++) {
			[cache[i] release];
			cache[i]=nil;
		}
        
        [oldTimeFormatString release];
        oldTimeFormatString = [currentTimeFormatString retain];
    }
    
    StringType		type;
    
    //Determine the type of string requested
    if (!seconds && !showAmPm) type = NONE;
    else if (seconds && !showAmPm) type = SECONDS;
    else if (!seconds & showAmPm) type = AMPM;
    else type = BOTH;

    //Cache the string if it's not already cached
    if (!cache[type]) {	
		//use system-wide defaults for date format
		NSMutableString *localizedDateFormatString = [currentTimeFormatString mutableCopy];

		if (!showAmPm) { 
			//potentially could use stringForKey:NSAMPMDesignation as space isn't always the separator between time and %p
			[localizedDateFormatString replaceOccurrencesOfString:@" %p" 
													withString:@"" 
													options:NSLiteralSearch 
													range:NSMakeRange(0,[localizedDateFormatString length])];
		}

		if (!seconds) {
			NSUInteger secondSeparatorIndex = [localizedDateFormatString rangeOfString:@"%S" options:NSBackwardsSearch].location;
			
			if ( (secondSeparatorIndex != NSNotFound) && (secondSeparatorIndex > 0) ) {
				NSString *secondsSeparator = [localizedDateFormatString substringWithRange:NSMakeRange(secondSeparatorIndex-1,1)];
				[localizedDateFormatString replaceOccurrencesOfString:[NSString stringWithFormat:@"%@%@",secondsSeparator,@"%S"] 
													withString:@""
													options:NSLiteralSearch
													range:NSMakeRange(0,[localizedDateFormatString length])];
			}
		}

		//Cache the result
		cache[type] = [[localizedDateFormatString autorelease] copy];
	}

    return cache[type];
}




+ (NSString *)stringForTimeIntervalSinceDate:(NSDate *)inDate
{
    return ([self stringForTimeIntervalSinceDate:inDate showingSeconds:YES abbreviated:NO]);
}

/*!
 *@brief format time for the interval since the given date
 *
 *@param inDate Date which starts the interval
 *@param showSeconds switch to determine if seconds should be shown
 *@param abbreviate switch to chose if w/d/h/ or weeks/days/hours/minutes is used to indicate the unit
 *
 *@result a localized NSString containing the Interval in weeks, days, hours or minutes (the largest usable)
 */
 
+ (NSString *)stringForTimeIntervalSinceDate:(NSDate *)inDate showingSeconds:(BOOL)showSeconds abbreviated:(BOOL)abbreviate;
{
    return [self stringForTimeInterval:[[NSDate date] timeIntervalSinceDate:inDate]
						showingSeconds:showSeconds
						   abbreviated:abbreviate
						  approximated:NO];
}


/*!
 *@brief format time for the interval between two dates
 *
 *@param firstDate first date of the interval
 *@param secondDate second date of the interval
 *
 *@result a localized NSString containing the Interval in weeks, days, hours or minutes (the largest usable)
 */
 
+ (NSString *)stringForApproximateTimeIntervalBetweenDate:(NSDate *)firstDate andDate:(NSDate *)secondDate
{
	return  [self stringForTimeInterval:[firstDate timeIntervalSinceDate:secondDate]
						 showingSeconds:NO
							abbreviated:NO
						   approximated:YES];
}

/*!
 *@brief format time for an interval
 *
 *@param interval NSTimeInterval to format
 *@param abbreviate switch to chose if w/d/h/ or weeks/days/hours/minutes is used to indicate the unit
 *
 *@result a localized NSString containing the Interval in weeks, days, hours or minutes (the largest usable)
 */
 
+ (NSString *)stringForApproximateTimeInterval:(NSTimeInterval)interval abbreviated:(BOOL)abbreviate
{
	return  [self stringForTimeInterval:interval
						 showingSeconds:NO
							abbreviated:abbreviate
						   approximated:YES];
}

/*!
 *@brief format time for an interval
 *
 *@param interval NSTimeInterval to format
 *
 *@result a localized NSString containing the interval in weeks, days, hours and minutes
 */
 
+ (NSString *)stringForTimeInterval:(NSTimeInterval)interval
{
	return  [self stringForTimeInterval:interval
						 showingSeconds:NO
							abbreviated:NO
						   approximated:NO];
}

/*!
 *@brief format time for an interval
 *
 *
 *
 *@param interval NSTimeInterval to format
 *@param showSeconds switch to determine if seconds should be shown
 *@param abbreviate switch to chose if w/d/h/ or weeks/days/hours/minutes is used to indicate the unit
 *@param approximate switch to chose if all parts should be shown or only the largest available part. If Hours is the largest available part, Minutes are also shown if applicable.
 *
 *@result a localized NSString containing the Interval formated according to the switches
 */ 

+ (NSString *)stringForTimeInterval:(NSTimeInterval)interval showingSeconds:(BOOL)showSeconds abbreviated:(BOOL)abbreviate approximated:(BOOL)approximate
{
    int				weeks = 0, days = 0, hours = 0, minutes = 0;
	NSTimeInterval	seconds = 0; 
	NSString		*weeksString = nil, *daysString = nil, *hoursString = nil, *minutesString = nil, *secondsString = nil;

	[NSDate convertTimeInterval:interval
	                    toWeeks:&weeks
	                       days:&days
	                      hours:&hours
	                    minutes:&minutes
	                    seconds:&seconds];

	//build the strings for the parts
	if (abbreviate) {
		//Note: after checking with a linguistics student, it appears that we're fine leaving it as w, h, etc... rather than localizing.
		weeksString		= [NSString stringWithFormat: @"%iw",weeks];
		daysString		= [NSString stringWithFormat: @"%id",days];
		hoursString		= [NSString stringWithFormat: @"%ih",hours];
		minutesString	= [NSString stringWithFormat: @"%im",minutes];
		secondsString	= [NSString stringWithFormat: @"%.0fs",seconds];
	} else {
		weeksString		= (weeks == 1)		? ONE_WEEK		: [NSString stringWithFormat:MULTIPLE_WEEKS, weeks];
		daysString		= (days == 1)		? ONE_DAY		: [NSString stringWithFormat:MULTIPLE_DAYS, days];
		hoursString		= (hours == 1)		? ONE_HOUR		: [NSString stringWithFormat:MULTIPLE_HOURS, hours];
		minutesString	= (minutes == 1)	? ONE_MINUTE	: [NSString stringWithFormat:MULTIPLE_MINUTES, minutes];
		secondsString	= (seconds == 1)	? ONE_SECOND	: [NSString stringWithFormat:MULTIPLE_SECONDS, seconds];
	}

	//assemble the parts
	NSMutableArray *parts = [NSMutableArray arrayWithCapacity:5];
	if (approximate) {
		/* We want only one of these. For example, 5 weeks, 5 days, 5 hours, 5 minutes, and 5 seconds should just be "5 weeks".
		 * Exception: Hours should display hours and minutes. 5 hours, 5 minutes, and 5 seconds is "5 hours and 5 minutes".
		 */
		if (weeks)
			[parts addObject:weeksString];
		else if (days)
			[parts addObject:daysString];
		else if (hours) {
			[parts addObject:hoursString];
			if (minutes)
				[parts addObject:minutesString];
		}
		else if (minutes)
			[parts addObject:minutesString];
		else if (showSeconds && (seconds >= 0.01))
			[parts addObject:secondsString];
	} else {
		//We want all of these that aren't zero.
		if (weeks)
			[parts addObject:weeksString];
		if (days)
			[parts addObject:daysString];
		if (hours)
			[parts addObject:hoursString];
		if (minutes)
			[parts addObject:minutesString];
		if (showSeconds && (seconds >= 0.01))
			[parts addObject:secondsString];
	}

	return [parts componentsJoinedByString:@" "];
}

@end
