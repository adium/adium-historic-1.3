//
//  ESDualWindowMessageWindowPreferences.m
//  Adium
//
//  Created by Evan Schoenberg on Thu Sep 18 2003.
//

#import "ESCLViewLabelsAdvancedPrefs.h"
#import "AISCLViewPlugin.h"
#import <AIUtilities/AIDictionaryAdditions.h>


@implementation ESCLViewLabelsAdvancedPrefs

//Preference pane properties
- (PREFERENCE_CATEGORY)category{
    return AIPref_Advanced_ContactList;
}
- (NSString *)label{
    return AILocalizedString(@"Labels","Contact list labels");
}
- (NSString *)nibName{
    return @"CLViewLabelsAdvancedPrefs";
}

- (NSDictionary *)restorablePreferences
{
	
	NSDictionary *defaultPrefs = [NSDictionary dictionaryNamed:SCL_DEFAULT_PREFS forClass:[self class]];
	NSDictionary *defaultsTemp = [NSDictionary dictionaryWithObjectsAndKeys:
		[defaultPrefs objectForKey:KEY_SCL_LABEL_AROUND_CONTACT],KEY_SCL_LABEL_AROUND_CONTACT,
		[defaultPrefs objectForKey:KEY_SCL_OUTLINE_LABELS],KEY_SCL_OUTLINE_LABELS,
		[defaultPrefs objectForKey:KEY_SCL_LABEL_OPACITY],KEY_SCL_LABEL_OPACITY,
		[defaultPrefs objectForKey:KEY_SCL_LABEL_GROUPS],KEY_SCL_LABEL_GROUPS,
		[defaultPrefs objectForKey:KEY_SCL_LABEL_GROUPS_COLOR],KEY_SCL_LABEL_GROUPS_COLOR,
		[defaultPrefs objectForKey:KEY_SCL_USE_GRADIENT],KEY_SCL_USE_GRADIENT,
		nil];
	
	NSDictionary *defaultsDict = [NSDictionary dictionaryWithObject:defaultsTemp forKey:PREF_GROUP_CONTACT_LIST_DISPLAY];
	return defaultsDict;
}


//Called in response to all preference controls, applies new settings
- (IBAction)changePreference:(id)sender
{
    if(sender == checkbox_labelAroundContact){
        [[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
                                             forKey:KEY_SCL_LABEL_AROUND_CONTACT
                                              group:PREF_GROUP_CONTACT_LIST_DISPLAY];       
    }else if(sender == checkbox_outlineLabels){
        [[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
                                             forKey:KEY_SCL_OUTLINE_LABELS
                                              group:PREF_GROUP_CONTACT_LIST_DISPLAY];
    }else if(sender == checkbox_useGradient){
		[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
                                             forKey:KEY_SCL_USE_GRADIENT
                                              group:PREF_GROUP_CONTACT_LIST_DISPLAY];
	}else if(sender == slider_labelOpacity){
        [[adium preferenceController] setPreference:[NSNumber numberWithFloat:[sender floatValue]]
                                             forKey:KEY_SCL_LABEL_OPACITY
                                              group:PREF_GROUP_CONTACT_LIST_DISPLAY];   
    }else if(sender == checkbox_labelGroups){
        [[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]]
                                             forKey:KEY_SCL_LABEL_GROUPS
                                              group:PREF_GROUP_CONTACT_LIST_DISPLAY];       
    }else if(sender == colorWell_labelGroupsColor){
        [[adium preferenceController] setPreference:[[sender color] stringRepresentation]
                                             forKey:KEY_SCL_LABEL_GROUPS_COLOR
                                              group:PREF_GROUP_CONTACT_LIST_DISPLAY];
    }
           
    [self configureControlDimming];
}

//Configure the preference view
- (void)viewDidLoad
{
    NSDictionary	*preferenceDict = [[adium preferenceController] preferencesForGroup:PREF_GROUP_CONTACT_LIST_DISPLAY];

    [checkbox_labelAroundContact setState:[[preferenceDict objectForKey:KEY_SCL_LABEL_AROUND_CONTACT] boolValue]];
    [checkbox_outlineLabels setState:[[preferenceDict objectForKey:KEY_SCL_OUTLINE_LABELS] boolValue]];
    
    [slider_labelOpacity setFloatValue:[[preferenceDict objectForKey:KEY_SCL_LABEL_OPACITY] floatValue]];
    [slider_labelOpacity setMinValue:0.05];
    [slider_labelOpacity setMaxValue:1.00];
    
    [checkbox_labelGroups setState:[[preferenceDict objectForKey:KEY_SCL_LABEL_GROUPS] boolValue]];
    [colorWell_labelGroupsColor setColor:[[preferenceDict objectForKey:KEY_SCL_LABEL_GROUPS_COLOR] representedColor]];
	[checkbox_useGradient setState:[[preferenceDict objectForKey:KEY_SCL_USE_GRADIENT] boolValue]];
	
    [self configureControlDimming];
}

- (void)viewWillClose
{
	if([colorWell_labelGroupsColor isActive]) [colorWell_labelGroupsColor deactivate];
}

//Enable/disable controls that are available/unavailable
- (void)configureControlDimming
{
    NSDictionary	*preferenceDict = [[adium preferenceController] preferencesForGroup:PREF_GROUP_CONTACT_LIST_DISPLAY];

    BOOL labelsAreEnabled = [[preferenceDict objectForKey:KEY_SCL_SHOW_LABELS] boolValue];
    [checkbox_labelAroundContact    setEnabled:labelsAreEnabled];
    [checkbox_outlineLabels         setEnabled:labelsAreEnabled];
    [slider_labelOpacity            setEnabled:labelsAreEnabled];
    [checkbox_labelGroups           setEnabled:labelsAreEnabled];
    [checkbox_useGradient           setEnabled:labelsAreEnabled];
    [colorWell_labelGroupsColor		setEnabled:(labelsAreEnabled ? [[preferenceDict objectForKey:KEY_SCL_LABEL_GROUPS] boolValue] : NO)];
}

@end



