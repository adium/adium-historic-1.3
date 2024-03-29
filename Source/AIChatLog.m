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

#import "AIChatLog.h"
#import "AILoginController.h"
#import "AIAbstractLogViewerWindowController.h"
#import "AILoggerPlugin.h"
#import "AICalendarDate.h"

#import <AIUtilities/NSCalendarDate+ISO8601Parsing.h>

@implementation AIChatLog

static NSCalendarDate *dateFromFileName(NSString *fileName);

- (id)initWithPath:(NSString *)inPath from:(NSString *)inFrom to:(NSString *)inTo serviceClass:(NSString *)inServiceClass
{
    if ((self = [super init])) {
		relativePath = [inPath retain];
		from = [inFrom retain];
		to = [inTo retain];
		serviceClass = [inServiceClass retain];
		rankingPercentage = 0;
	}

    return self;
}

- (id)initWithPath:(NSString *)inPath
{
	NSString *parentPath = [inPath stringByDeletingLastPathComponent];
	NSString *toUID = [parentPath lastPathComponent];
	NSString *serviceAndFromUID = [[parentPath stringByDeletingLastPathComponent] lastPathComponent];

	NSString *myServiceClass, *fromUID;

	//Determine the service and fromUID - should be SERVICE.ACCOUNT_NAME
	//Check against count to guard in case of old, malformed or otherwise odd folders & whatnot sitting in log base
	NSArray *serviceAndFromUIDArray = [serviceAndFromUID componentsSeparatedByString:@"."];
	
	if ([serviceAndFromUIDArray count] >= 2) {
		myServiceClass = handleSpecialCasesForUIDAndServiceClass(toUID, [serviceAndFromUIDArray objectAtIndex:0]);
		
		//Use substringFromIndex so we include the rest of the string in the case of a UID with a . in it
		fromUID = [serviceAndFromUID substringFromIndex:([serviceClass length] + 1)]; //One off for the '.'

	} else {
		//Fallback: blank non-nil serviceClass; folderName as the fromUID
		myServiceClass = @"";
		fromUID = serviceAndFromUID;
	}

	return [self initWithPath:inPath
						 from:fromUID
						   to:toUID
				 serviceClass:myServiceClass];
}

- (void)dealloc
{
    [relativePath release];
    [from release];
    [to release];
	[serviceClass release];
    [date release];
    
    [super dealloc];
}

- (NSString *)relativePath{
    return relativePath;
}
- (NSString *)from{
    return from;
}
- (NSString *)to{
    return to;
}
- (NSString *)serviceClass{
	return serviceClass;
}
- (NSCalendarDate *)date{
	//Determine the date of this log lazily
	if (!date) {
		date = [dateFromFileName([relativePath lastPathComponent]) retain];

		if (!date) {
			//Sometimes the filename doesn't have a date (e.g., “jdoe ((null)).chatlog”). In such cases, if it's a chatlog, parse it and get the date from the first element that has one.
			//We don't do this first because NSXMLParser uses +[NSData dataWithContentsOfURL:], which is painful for large log files.
			if ([[relativePath pathExtension] isEqualToString:@"chatlog"]) {
				NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[[[adium loginController] userDirectory] stringByAppendingPathComponent:PATH_LOGS] stringByAppendingPathComponent:relativePath]]];
				[parser setDelegate:self];
				[parser parse];
				[parser release];
			}
		}
	}
		
    return date;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	//Stop at the first element with a date.
	NSString *dateString = nil;
	if ((dateString = [attributeDict objectForKey:@"time"])) {
		date = [[NSCalendarDate calendarDateWithString:dateString strictly:YES] retain];
		if (date)
			[parser abortParsing];
	}
}

- (float)rankingPercentage
{
	return rankingPercentage;
}
- (void)setRankingPercentage:(float)inRankingPercentage
{
	rankingPercentage = inRankingPercentage;
}

- (void)setRankingValueOnArbitraryScale:(float)inRankingValue
{
	rankingValue = inRankingValue;
}
- (float)rankingValueOnArbitraryScale
{
	return rankingValue;
}

- (BOOL)isFromSameDayAsDate:(NSCalendarDate *)inDate
{
	return [[self date] dayOfCommonEra] == [inDate dayOfCommonEra];
}

#pragma mark Sort Selectors

//Sort by To, then Date
- (NSComparisonResult)compareTo:(AIChatLog *)inLog
{
    NSComparisonResult  result = [to caseInsensitiveCompare:[inLog to]];
    if (result == NSOrderedSame) {
		NSTimeInterval		interval = [date timeIntervalSinceDate:[inLog date]];
		
		if (interval < 0) {
			result = NSOrderedAscending;
		} else if (interval > 0) {
			result = NSOrderedDescending;
		}
	}
	
    return result;
}
- (NSComparisonResult)compareToReverse:(AIChatLog *)inLog
{
    NSComparisonResult  result = [[inLog to] caseInsensitiveCompare:to];
    if (result == NSOrderedSame) {
		NSTimeInterval		interval = [date timeIntervalSinceDate:[inLog date]];
		
		if (interval < 0) {
			result = NSOrderedAscending;
		} else if (interval > 0) {
			result = NSOrderedDescending;
		}
	}
	
    return result;
}
//Sort by From, then Date
- (NSComparisonResult)compareFrom:(AIChatLog *)inLog
{
    NSComparisonResult  result = [from caseInsensitiveCompare:[inLog from]];
    if (result == NSOrderedSame) {
		NSTimeInterval		interval = [date timeIntervalSinceDate:[inLog date]];
		
		if (interval < 0) {
			result = NSOrderedAscending;
		} else if (interval > 0) {
			result = NSOrderedDescending;
		}
	} 
	
    return result;
}
- (NSComparisonResult)compareFromReverse:(AIChatLog *)inLog
{
    NSComparisonResult  result = [[inLog from] caseInsensitiveCompare:from];
    if (result == NSOrderedSame) {
		NSTimeInterval		interval = [date timeIntervalSinceDate:[inLog date]];
		
		if (interval < 0) {
			result = NSOrderedAscending;
		} else if (interval > 0) {
			result = NSOrderedDescending;
		}
	}
    
    return result;
}

//Sort by From, then Date
- (NSComparisonResult)compareService:(AIChatLog *)inLog
{
    NSComparisonResult  result = [serviceClass caseInsensitiveCompare:[inLog serviceClass]];
    if (result == NSOrderedSame) {
		NSTimeInterval		interval = [date timeIntervalSinceDate:[inLog date]];
		
		if (interval < 0) {
			result = NSOrderedAscending;
		} else if (interval > 0) {
			result = NSOrderedDescending;
		}
	} 
	
    return result;
}
- (NSComparisonResult)compareServiceReverse:(AIChatLog *)inLog
{
    NSComparisonResult  result = [[inLog serviceClass] caseInsensitiveCompare:serviceClass];
    if (result == NSOrderedSame) {
		NSTimeInterval		interval = [date timeIntervalSinceDate:[inLog date]];
		
		if (interval < 0) {
			result = NSOrderedAscending;
		} else if (interval > 0) {
			result = NSOrderedDescending;
		}
	}
    
    return result;
}

//Sort by Date, then To
- (NSComparisonResult)compareDate:(AIChatLog *)inLog
{
	NSComparisonResult  result;
	NSTimeInterval		interval = [[self date] timeIntervalSinceDate:[inLog date]];
	
	if (interval < 0) {
		result = NSOrderedAscending;
	} else if (interval > 0) {
		result = NSOrderedDescending;
	} else {
		result = [to caseInsensitiveCompare:[inLog to]];
    }
	
    return result;
}
- (NSComparisonResult)compareDateReverse:(AIChatLog *)inLog
{
	NSComparisonResult  result;
	NSTimeInterval		interval = [[inLog date] timeIntervalSinceDate:[self date]];

	if (interval < 0) {
		result = NSOrderedAscending;
	} else if (interval > 0) {
		result = NSOrderedDescending;
	} else {
		result = [[inLog to] caseInsensitiveCompare:to];
    }
	
    return result;
}

-(NSComparisonResult)compareRank:(AIChatLog *)inLog
{
	NSComparisonResult  result;
	float				otherRankingPercentage = [inLog rankingPercentage];
	
	if (rankingPercentage > otherRankingPercentage) {
		result = NSOrderedDescending;		
	} else if (rankingPercentage < otherRankingPercentage) {
		result = NSOrderedAscending;	
	} else {
		result = [to caseInsensitiveCompare:[inLog to]];
    }
	
	return result;
}
-(NSComparisonResult)compareRankReverse:(AIChatLog *)inLog
{
	NSComparisonResult  result;
	float				otherRankingPercentage = [inLog rankingPercentage];
	
	if (rankingPercentage > otherRankingPercentage) {
		result = NSOrderedAscending;		
	} else if (rankingPercentage < otherRankingPercentage) {
		result = NSOrderedDescending;				
	} else {
		result = [[inLog to] caseInsensitiveCompare:to];
    }
	
	return result;
}

#pragma mark Date utilities

//Scan an Adium date string, supahfast C style
static BOOL scandate(const char *sample,
					 unsigned long *outyear, unsigned long *outmonth,  unsigned long *outdate,
					 BOOL *outHasTime, unsigned long *outhour, unsigned long *outminute, unsigned long *outsecond,
					 signed long *outtimezone)
{
	BOOL success = YES;
	unsigned long component;

    //Read a date, followed by a '('.
	//First, find the '('.
	while (*sample != '(') {
    	if (!*sample) {
    		success = NO;
    		goto fail;
		} else {
			++sample;
		}
    }
	
	//current character is a '(' now, so skip over it.
    ++sample; //start with the next character
	
    /*get the year*/ {
		while (*sample && (*sample < '0' || *sample > '9')) ++sample;
		if (!*sample) {
			success = NO;
			goto fail;
		}
		component = strtoul(sample, (char **)&sample, 10);
		if (outyear) *outyear = component;
    }
    
    /*get the month*/ {
		while (*sample && (*sample < '0' || *sample > '9')) ++sample;
		if (!*sample) {
			success = NO;
			goto fail;
		}
		component = strtoul(sample, (char **)&sample, 10);
		if (outmonth) *outmonth = component;
    }
    
    /*get the date*/ {
		while (*sample && (*sample < '0' || *sample > '9')) ++sample;
		if (!*sample) {
			success = NO;
			goto fail;
		}
		component = strtoul(sample, (char **)&sample, 10);
		if (outdate) *outdate = component;
    }

    if (*sample == 'T') {
		++sample; //start with the next character
		if (outHasTime) *outHasTime = YES;
		
		/*get the hour*/ {
			while (*sample && (*sample < '0' || *sample > '9')) ++sample;
			if (!*sample) {
				success = NO;
				goto fail;
			}
			component = strtoul(sample, (char **)&sample, 10);
			if (outhour) *outhour = component;
		}

		/*get the minute*/ {
			while (*sample && (*sample < '0' || *sample > '9')) ++sample;
			if (!*sample) {
				success = NO;
				goto fail;
			}
			component = strtoul(sample, (char **)&sample, 10);
			if (outminute) *outminute = component;
		}

		/*get the second*/ {
			while (*sample && (*sample < '0' || *sample > '9')) ++sample;
			if (!*sample) {
				success = NO;
				goto fail;
			}
			component = strtoul(sample, (char **)&sample, 10);
			if (outsecond) *outsecond = component;
		}

		/*get the time zone*/ {
			while (*sample && ((*sample < '0' || *sample > '9') && *sample != '-' && *sample != '+')) ++sample;
			if (!*sample) {
				success = NO;
				goto fail;
			}
			signed long timezone_sign = 1;
			if(*sample == '+') {
				++sample;
			} else if(*sample == '-') {
				timezone_sign = -1;
				++sample;
			} else if (*sample) {
				//There's something here, but it's not a time zone. Bail.
				success = NO;
				goto fail;
			}
			signed long timezone_hr = 0;
			if (*sample >= '0' || *sample <= '9') {
				timezone_hr += *(sample++) - '0';
			}
			if (*sample >= '0' || *sample <= '9') {
				timezone_hr *= 10;
				timezone_hr += *(sample++) - '0';
			}
			signed long timezone_min = 0;
			if (*sample >= '0' || *sample <= '9') {
				timezone_min += *(sample++) - '0';
			}
			if (*sample >= '0' || *sample <= '9') {
				timezone_min *= 10;
				timezone_min += *(sample++) - '0';
			}
			if (outtimezone) *outtimezone = (timezone_hr * 60 + timezone_min) * timezone_sign;
		}
	}
	
fail:
	return success;
}

//Given an Adium log file name, return an NSCalendarDate with year, month, and day specified
static NSCalendarDate *dateFromFileName(NSString *fileName)
{
	unsigned long   year = 0;
	unsigned long   month = 0;
	unsigned long   day = 0;
	unsigned long   hour = 0;
	unsigned long   minute = 0;
	unsigned long   second = 0;
	  signed long   timezone = NSNotFound;
	BOOL			hasTime = NO;
	  
	if (scandate([fileName UTF8String], &year, &month, &day, &hasTime, &hour, &minute, &second, &timezone)) {
		if (year && month && day) {
			AICalendarDate *calendarDate;
			
			calendarDate = [AICalendarDate dateWithYear:year
												  month:month
													day:day
												   hour:hour
												 minute:minute
												 second:second
											   timeZone:((timezone == NSNotFound) ? nil : [NSTimeZone timeZoneForSecondsFromGMT:(timezone * 60)])];
			[calendarDate setGranularity:(hasTime ? AISecondGranularity : AIDayGranularity)];

			return calendarDate;
		}
	}
	
	return nil;
}

@end
