# Building the XCFramework

Updating:

```sh
brew install cmake ninja wget autoconf automake libtool
./build
swift package compute-checksum Clibgit2.xcframework.zip
```

Update the url and checksum in Package.swift then upload 'Clibgit2.xcframework.zip' to the GitHub release. 
