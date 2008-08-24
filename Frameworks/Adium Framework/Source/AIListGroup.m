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

#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListGroup.h>
#import <Adium/AISortController.h>
#import <AIUtilities/AIArrayAdditions.h>

@interface AIListGroup (PRIVATE)
- (void)_recomputeVisibleCount;
@end

@implementation AIListGroup

//init
- (id)initWithUID:(NSString *)inUID
{
    if ((self = [super initWithUID:inUID service:nil])) {
		containedObjects = [[NSMutableArray alloc] init];
		expanded = YES;

		//Default invisible
		visibleCount = 0;
		visible = NO;
    }
	
    return self;
}

- (void)dealloc
{
	[containedObjects release]; containedObjects = nil;
	
	[super dealloc];
}

/* An object ID generated by Adium that is shared by all objects which are, to most intents and purposes, identical to
 * this object.  Ths ID is composed of the service ID and UID, so any object with identical services and object ID's
 * will have the same value here.
 */
- (NSString *)internalObjectID
{
	if (!internalObjectID) {
		internalObjectID = [[AIListObject internalObjectIDForServiceID:@"Group" UID:[self UID]] retain];
	}
	return internalObjectID;
}

/*!
 * @brief Generate a special identifier for this group based upon its contents
 *
 * This is useful for storing preferences which are related not to the name of this group (which might be arbitrary) but
 * rather to its contents. The contact list root always returns its own UID, but other groups will have a different 
 * contentsBasedIdentifier depending upon what other objects they contain.
 */
- (NSString *)contentsBasedIdentifier
{
	NSString *contentsBasedIdentifier;
	if (self == [[adium contactController] contactList]) {
		contentsBasedIdentifier = [self UID];

	} else {		
		NSArray *UIDArray = [[containedObjects valueForKey:@"UID"] sortedArrayUsingSelector:@selector(compare:)];
		contentsBasedIdentifier = [UIDArray componentsJoinedByString:@";"];
		if (![contentsBasedIdentifier length]) contentsBasedIdentifier = [self UID];
	}
	
	return contentsBasedIdentifier;
}

//Visibility -----------------------------------------------------------------------------------------------------------
#pragma mark Visibility
/*
 The visible objects contained in a group are always sorted to the top.  This allows us to easily retrieve only visible
 objects without having to physically remove invisible objects from the group.
 */
//Returns the number of visible objects in this group
- (unsigned)visibleCount
{
    return visibleCount;
}

//Cache the number of contained objects that are visible
- (void)_recomputeVisibleCount
{
	visibleCount = 0;
	
	NSEnumerator *containedObjectEnumerator = [[self containedObjects] objectEnumerator];
	AIListObject *containedObject = nil;
	
	while ((containedObject = [containedObjectEnumerator nextObject])){
		if ([containedObject visible]) {
			visibleCount++;
		}
	}
	
	[self setValue:(visibleCount ? [NSNumber numberWithInt:visibleCount] : nil)
				   forProperty:@"VisibleObjectCount"
				   notify:NotifyNow];
}

//Called when the visibility of an object in this group changes
- (void)visibilityOfContainedObject:(AIListObject *)inObject changedTo:(BOOL)inVisible
{
	//Update our visibility as a result of this change
	[self _recomputeVisibleCount];
	
	//Sort the contained object to or from the bottom (invisible section) of the group
	[[adium contactController] sortListObject:inObject];
}

/*!
 * @brief Get the visbile object at a given index
 *
 * Hidden contacts will be sorted to the bottom of our contained objects array,
 * so we can just acccess the array directly
 */
- (AIListObject *)visibleObjectAtIndex:(NSUInteger)index
{
	return (AIListObject *)[[self containedObjects] objectAtIndex:index];
}

//Object Storage ---------------------------------------------------------------------------------------------
#pragma mark Object Storage
//Return our contained objects
- (NSArray *)containedObjects
{
	return containedObjects;
}

//Number of containd objects
- (unsigned)containedObjectsCount
{
    return [containedObjects count];
}

//Test for the presence of an object in our group
- (BOOL)containsObject:(AIListObject *)inObject
{
	return [containedObjects containsObject:inObject];
}

- (BOOL)canContainOtherContacts {
    return NO;
}

- (BOOL)containsMultipleContacts {
    return NO;
}

//Retrieve an object by index
- (id)objectAtIndex:(unsigned)index
{
    return [containedObjects objectAtIndex:index];
}

//Retrieve the index of an object
- (int)indexOfObject:(AIListObject *)inObject
{
    return [containedObjects indexOfObject:inObject];
}

- (NSArray *)listContacts
{
	return containedObjects;
}

- (NSArray *)visibleListContacts
{
	return [self containedObjects];
}

//Remove all the objects from this group (PRIVATE: For contact controller only)
- (void)removeAllObjects
{
	//Remove all the objects
	while ([containedObjects count]) {
		[self removeObject:[containedObjects objectAtIndex:0]];
	}
}

//Retrieve a specific object by service and UID
- (AIListObject *)objectWithService:(AIService *)inService UID:(NSString *)inUID
{
	NSEnumerator	*enumerator = [containedObjects objectEnumerator];
	AIListObject	*object;
	
	while ((object = [enumerator nextObject])) {
		if ([inUID isEqualToString:[object UID]] && [object service] == inService) break;
	}
	
	return object;
}

- (float)smallestOrder
{
	return [super smallestOrder];
}

- (float)largestOrder
{
	return [super largestOrder];
}

- (void)listObject:(AIListObject *)listObject didSetOrderIndex:(float)inOrderIndex
{
	return [super listObject:listObject didSetOrderIndex:inOrderIndex];
}

- (float)orderIndexForObject:(AIListObject *)listObject
{
	return [super orderIndexForObject:listObject];
}


/*!
 * @brief Add an object to this group
 *
 * PRIVATE: For contact controller only. Sorting and visible count updating will be performed as needed.
 *
 * @result YES if the object was added (that is, was not already present)
 */
- (BOOL)addObject:(AIListObject *)inObject
{
	BOOL success = NO;
	
	if (![containedObjects containsObjectIdenticalTo:inObject]) {
		//Add the object
		[inObject setContainingObject:self];
		[containedObjects addObject:inObject];
		
		//Update our visible count
		[self _recomputeVisibleCount];
		
		/* Sort this object on our own.  This always comes along with a content change, so calling contact controller's
		 * sort code would invoke an extra update that we don't need.  We can skip sorting if this object is not visible,
		 * since it will add to the bottom/non-visible section of our array.
		 */
		if ([inObject visible]) {
			[self sortListObject:inObject
				  sortController:[[adium contactController] activeSortController]];
		}
		
		//
		[self setValue:[NSNumber numberWithInt:[containedObjects count]] 
					   forProperty:@"ObjectCount"
					   notify:NotifyNow];
		
		success = YES;
	}
	
	return success;
}

//Remove an object from this group (PRIVATE: For contact controller only)
- (void)removeObject:(AIListObject *)inObject
{	
	if ([containedObjects containsObject:inObject]) {		
		//Remove the object
		if ([inObject containingObject] == self)
			[inObject setContainingObject:nil];
		[containedObjects removeObject:inObject];
		
		//Update our visible count

		[self _recomputeVisibleCount];

		//
		[self setValue:[NSNumber numberWithInt:[containedObjects count]]
					   forProperty:@"ObjectCount" 
					   notify:NotifyNow];
	}
}

//Move group from one contact list to another
- (BOOL)moveGroupTo:(AIListObject<AIContainingObject> *)list
{
	return [self moveGroupFrom:[self containingObject] to:list];
}

- (BOOL)moveGroupFrom:(AIListObject<AIContainingObject> *)fromList to:(AIListObject<AIContainingObject> *)toList
{
	// Check if group is not already there
	if([toList containsObject:self])
		return NO;
	
	[fromList removeObject:self];
	[toList addObject:self];
	[self setContainingObject:toList];
	
	return YES;
}

- (BOOL)moveAllGroupsFrom:(AIListGroup *)fromContactList to:(AIListGroup *)toContactList {
	[[[containedObjects copy] autorelease] makeObjectsPerformSelector:@selector(moveGroupTo:)
														   withObject:toContactList];
	
	return YES;
}

//Sorting --------------------------------------------------------------------------------------------------------------
#pragma mark Sorting
//Resort an object in this group (PRIVATE: For contact controller only)
- (void)sortListObject:(AIListObject *)inObject sortController:(AISortController *)sortController
{
	[inObject retain];
	[containedObjects removeObject:inObject];
	[containedObjects insertObject:inObject 
						   atIndex:[sortController indexForInserting:inObject 
														 intoObjects:containedObjects]];
	[inObject release];
}

//Resorts the group contents (PRIVATE: For contact controller only)
- (void)sortGroupAndSubGroups:(BOOL)subGroups sortController:(AISortController *)sortController
{
    //Sort the groups within this group
    if (subGroups) {
		NSEnumerator		*enumerator;
		AIListObject		*object;
		
        enumerator = [containedObjects objectEnumerator];
        while ((object = [enumerator nextObject])) {
            if ([object isMemberOfClass:[AIListGroup class]]) {
                [(AIListGroup *)object sortGroupAndSubGroups:YES
											  sortController:sortController];
            }
        }
    }
	
    //Sort this group
    if (sortController) {
		NSMutableArray	*sortedListObjects;
		
		if ([containedObjects count] > 1) {
			sortedListObjects = [[sortController sortListObjects:containedObjects] mutableCopy];
			[containedObjects release]; containedObjects = sortedListObjects;
		}
    }
}


//Expanded State -------------------------------------------------------------------------------------------------------
#pragma mark Expanded State
//Set the expanded/collapsed state of this group (PRIVATE: For the contact list view to let us know our state)
- (void)setExpanded:(BOOL)inExpanded
{
    expanded = inExpanded;
	loadedExpanded = YES;
}
//Returns the current expanded/collapsed state of this group
- (BOOL)isExpanded
{
	if (!loadedExpanded) {
		loadedExpanded = YES;
		expanded = [[self preferenceForKey:@"IsExpanded"
									 group:@"Contact List"] boolValue];
	}

    return expanded;
}

- (BOOL)isExpandable
{
	return YES;
}

#pragma mark Applescript
- (NSScriptObjectSpecifier *)objectSpecifier
{
	NSScriptClassDescription *containerClassDesc = (NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[NSApp class]];
	return [[[NSNameSpecifier alloc]
		   initWithContainerClassDescription:containerClassDesc
		   containerSpecifier:nil key:@"contactGroups"
		   name:[self UID]] autorelease];
}

- (NSArray *)contacts
{
	return [self containedObjects];
}
- (id)moveContacts:(AIListObject *)contact toIndex:(int)index
{
	[[adium contactController] moveListObjects:[NSArray arrayWithObject:contact] intoObject:self index:index];
	return nil;
}
@end
