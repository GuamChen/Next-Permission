#!/bin/sh
set -eu

test -f Package.swift
swift package dump-package >/dev/null
swift package describe --type json >/dev/null

sdk_path=$(xcrun --sdk iphonesimulator --show-sdk-path)
swift build --build-tests --sdk "$sdk_path" --triple arm64-apple-ios15.0-simulator >/dev/null
