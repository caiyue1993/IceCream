#!/usr/bin/env bash

source ~/.rvm/scripts/rvm
rvm use default
pod trunk push IceCream.podspec --allow-warnings
