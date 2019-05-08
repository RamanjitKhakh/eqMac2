#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

kextunload /System/Library/Extensions/GuruVoiceDriver.kext/
rm -rf /System/Library/Extensions/GuruVoiceDriver.kext/
touch /System/Library/Extensions
