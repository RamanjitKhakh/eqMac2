#!/bin/sh

# enable install of apps downloaded from anywhere
spctl --master-disable

# remove eqMac 1.0 driver
kextunload /System/Library/Extensions/GuruVoiceDriver.kext/
rm -rf /System/Library/Extensions/GuruVoiceDriver.kext/

# remove eqMac < 2.1 driver
kextunload /System/Library/Extensions/GuruVoiceDriver.kext/
rm -rf /System/Library/Extensions/GuruVoiceDriver.kext/

touch /System/Library/Extensions

# get current directory path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# install the new driver
cp -R $DIR/GuruVoiceDriver.kext /System/Library/Extensions/
kextload -tv /System/Library/Extensions/GuruVoiceDriver.kext
touch /System/Library/Extensions

