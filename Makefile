TARGET = OTADisabler
VERSION = $(shell defaults read $$PWD/$(TARGET)/Info.plist CFBundleVersion)

.PHONY: all clean

all: clean
	xcodebuild clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER="com.ichitaso.otadisablerapp" -sdk iphoneos -configuration Debug
	ln -sf build/Debug-iphoneos Payload
#	cp -a $(TARGET)/libdimentio.framework Payload/$(TARGET).app/Frameworks/
	ldid -SOTADisabler/dimentio/tfp0.plist Payload/$(TARGET).app/$(TARGET)
#	ldid -SOTADisabler/dimentio/tfp0.plist Payload/$(TARGET).app/Frameworks/libdimentio.framework/libdimentio
	zip -r9 $(TARGET)-$(VERSION).ipa Payload/$(TARGET).app

clean:
	rm -rf build Payload ./*.ipa