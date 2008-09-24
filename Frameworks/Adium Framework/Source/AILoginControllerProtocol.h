/*
 *  AILoginControllerProtocol.h
 *  Adium
 *
 *  Created by Evan Schoenberg on 7/31/06.
 *
 */

#import <Adium/AIControllerProtocol.h>

#define LOGIN_PREFERENCES_FILE_NAME @"Login Preferences"	//Login preferences file name
#define LOGIN_SHOW_WINDOW 			@"Show Login Window"	//Should hide the login window 

#ifdef DEBUG_BUILD
#define LOGIN_LAST_USER				@"Last Login Name-Debug"//Last logged in user - debug
#define LOGIN_LAST_USER_FALLBACK	@"Last Login Name"		//Last logged in user
#else
#define LOGIN_LAST_USER				@"Last Login Name"		//Last logged in user
#endif

@protocol AILoginController <AIController>
- (NSString *)userDirectory;
- (NSString *)currentUser;
- (NSArray *)userArray;

- (void)addUser:(NSString *)inUserName;
- (void)deleteUser:(NSString *)inUserName;
- (void)renameUser:(NSString *)oldName to:(NSString *)newName;
- (void)loginAsUser:(NSString *)userName;
- (void)requestUserNotifyingTarget:(id)inTarget selector:(SEL)inSelector;
@end

