###########
# What to do before running this script:
# - openUp needs to be installed.
# - Set VERSION, BUILD_IN_DEBUG_MODE, BETA, and OFFICIAL_BUILD below.
#    * The Adium plists will automatically updated to match these values.
#    * BETA should be TRUE for all beta builds and FALSE for all releases.
#      It primarily affects the appcast used by Adium for detecting updates.
#    * BUILD_IN_DEBUG_MODE should be set to FALSE for the last beta
#      in addition to the release itself. If FALSE, debug logging is disabled
#      and certain space optimizations for nibs and strings are done which
#      also prevent modification.
#    * OFFICIAL_BUILD is TRUE for the benefit of our Adium build machine, which signs 
#      official release builds. When building a release yourself, set this to FALSE, 
#      since you don't have the Adium certificate on your machine.
#
# How to run this script:
# - make all
###########

VERSION=1.3.10-debug
BUILD_IN_DEBUG_MODE?=TRUE
BETA?=FALSE
OFFICIAL_BUILD?=TRUE

# Always builds in debug mode.
NIGHTLY?=FALSE

###########
# To release!
# Releasing requires cachefly access and adiumx.com access.
#
# First upload to cachefly. If you don't have access and need to do a release, get with Evan or Eric.
# Triggering the version checker once the release is up:
# 1) Build Adium
# 2) Get the number out of the 'buildnum' file in Adium.app/Contents/Resources
# 3) Paste that number into the appropriate place (adium version or adium-beta version, depending on which you're triggering) in the version.plist file in our public_html folder.  *** (2) and (3) are to support the old version checker, in Adium 0.8x and earlier ***
# 4) Update and commit the appcast.xml file in the adium checkout root
# 5) Run the appcast update php script.
###########

###########
# No need for changes below this point
###########

###########
# Variables
###########
SRC_DIR=..
BUILD_DIR=build
ART_DIR=Artwork
ADIUM_DIR=$(BUILD_DIR)/Adium
RELEASE_NAME=Adium_$(VERSION)
VERSION_ESCAPED=$(VERSION)
RELEASE_NAME_ESCAPED=Adium_$(VERSION_ESCAPED)
TARBALL_DIR=adium-$(VERSION)

ifeq ($(NIGHTLY),TRUE)
	VERSION_ESCAPED:=$(VERSION_ESCAPED)\`date +%Y%m%d\`
	VERSION:=$(VERSION)`date +%Y%m%d`
	BUILD_IN_DEBUG_MODE=TRUE
	BUILDFLAGS+="ADIUM_CFLAGS=-DNIGHTLY_RELEASE"
endif

ifeq ($(BUILD_IN_DEBUG_MODE),TRUE)
    BUILDSTYLE=Deployment-Debug
else
    BUILDSTYLE=Deployment
endif

BUILDFLAGS+="BUILDCONFIGURATION=$(BUILDSTYLE)"
ifeq ($(BETA),TRUE)
	BUILDFLAGS+="ADIUM_CFLAGS=-DBETA_RELEASE"
endif

PRODUCT_DIR=$(shell defaults read com.apple.Xcode PBXProductDirectory 2> /dev/null)

ifeq ($(strip $(PRODUCT_DIR)),)
	ADIUM_BUILD_DIR=$(SRC_DIR)/build/$(BUILDSTYLE)
else
	TARGET_BUILD_DIR=$(PRODUCT_DIR)/$(BUILDSTYLE)
	ADIUM_BUILD_DIR=$(TARGET_BUILD_DIR)
endif

PLIST_DIR=`pwd`/../Plists
ADIUM_PLIST=$(PLIST_DIR)/Info

###########
# Targets
###########
.PHONY: all all-withlocalchanges all-withlocalchanges-noclean all-nopackage-noclean all-nightly update assertnochanges assertnoconflicts version compile clean release source prepare-release-bundle createfolder diskimage nightly tarball

all: update assertnochanges version clean compile release
all-withlocalchanges: update assertnoconflicts version clean compile release
all-withlocalchanges-noclean: update assertnoconflicts version compile release

#doesn't bother putting things in a dmg
#useful for builds not intended for distribution
all-nopackage-noclean: update assertnoconflicts version compile createfolder prepare-release-bundle

update:
	hg pull -u -R $(SRC_DIR)

assertnochanges: assertnoconflicts
	if [[ 0 -ne `hg st $(SRC_DIR) | egrep --invert-match '\?|Info\.plist' | wc -l` ]]; then \
		echo 'You have local changes. Please do not build releases from an unclean checkout. You must revert the changes, commit them, or check out another working copy and build from that.' 1>&2; \
		exit 1; \
	fi
assertnoconflicts:
	if [[ 0 -ne `hg st $(SRC_DIR) | egrep '^C' | wc -l` ]]; then \
		echo 'You have conflicts in your checkout. You will not be able to build until these are resolved. Also, remember that even after you have fixed all conflict marks, you must use "hg resolve"; otherwise, hg will still believe the files are conflicted.' 1>&2; \
		exit 2; \
	fi

version:
	@# update the plists
	defaults write $(ADIUM_PLIST) CFBundleGetInfoString "$(VERSION), Copyright 2001-2009 The Adium Team"
	defaults write $(ADIUM_PLIST) CFBundleVersion "$(VERSION)"
	defaults write $(ADIUM_PLIST) CFBundleShortVersionString "$(VERSION)"
	plutil -convert xml1 $(ADIUM_PLIST).plist

compile:
	$(MAKE) $(BUILDFLAGS) -C $(SRC_DIR)

testcompile:
	$(MAKE) $(BUILDFLAGS) -C $(SRC_DIR)

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) $(BUILDFLAGS) -C $(SRC_DIR) clean

release: createfolder prepare-release-bundle diskimage

prepare-release-bundle:
	@# Convert all nibs to the smaller binary format
	@echo Converting nibs to binary format...
	find $(BUILD_DIR) -name keyedobjects.nib -print0 | xargs -0 plutil -convert binary1

	@# delete unneeded nib files for non-beta builds
	@echo Cleaning Adium.app for release
ifeq ($(BUILD_IN_DEBUG_MODE),FALSE)
	find $(BUILD_DIR) \( -name classes.nib -or -name info.nib \) -type f -delete
endif
	
	@# delete backup files
	find $(BUILD_DIR) \( -name "*~" -or -name .DS_Store \) -type f -delete

	@# sign the executable
ifeq ($(OFFICIAL_BUILD),TRUE)
	if [ -e ~/adium-password ]; then \
		security unlock-keychain -p `cat ~/adium-password`; \
	fi
	codesign -v -s Adium $(ADIUM_DIR)/Adium.app/Contents/MacOS/Adium
endif

createfolder:
	@# clean build directory
	rm -rf $(BUILD_DIR)
	mkdir $(BUILD_DIR)

	mkdir $(ADIUM_DIR)
	
	@# copy the app
	cp -R $(ADIUM_BUILD_DIR)/Adium.app $(ADIUM_DIR)

	@# copy the text files
	cp $(SRC_DIR)/ChangeLogs/Changes.txt $(ADIUM_DIR)
	cp $(SRC_DIR)/License.txt $(ADIUM_DIR)
	
	@# symlink /Applications
	./mkalias -r /Applications $(ADIUM_DIR)/Applications

diskimage:
	rm "$(BUILD_DIR)/$(RELEASE_NAME).dmg" || true
	@# make Adium disk image
	mkdir -p $(ADIUM_DIR)/.background
	cp $(ART_DIR)/dmgBackground.png $(ADIUM_DIR)/.background

	./ensureCustomIconsExtracted $(ART_DIR)
	./make-diskimage.sh $(BUILD_DIR)/$(RELEASE_NAME).dmg $(ADIUM_DIR) "Adium $(VERSION)" dmg_adium.scpt $(ART_DIR)
	
	@echo Build finished. `md5 $(BUILD_DIR)/$(RELEASE_NAME_ESCAPED).dmg`

#This is what nightly builds use. Does not update because buildbot does.
nightly: assertnochanges version clean compile release
	echo $(RELEASE_NAME) > $(BUILD_DIR)/latest
	(svn info | perl -nle 's/Revision: ([0-9]+)/$$1/g and print "r".$$_') >> $(BUILD_DIR)/latest
	md5 -q $(BUILD_DIR)/$(RELEASE_NAME).dmg > $(BUILD_DIR)/$(RELEASE_NAME).dmg.md5sum

tarball:
	hg archive -t tgz ($TARBALL_DIR).tgz
