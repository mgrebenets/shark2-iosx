Build Shark Framework for iOS & OSX
===
###### Using Xcode5 (armv7, armv7s, arm64, i386, x86_64)

### What is Shark?
SHARK provides libraries for the design of adaptive systems, including methods for linear and nonlinear optimization (e.g., evolutionary and gradient-based algorithms), kernel-based algorithms and neural networks, and other machine learning techniques.

Find out more on the [project website](https://sourceforge.net/projects/shark-project/)

This script is designed to build version **2.3.4** of the library, not the latest 3.0 version.

### Build Framework
With this script building the framework is as easy as

        # download (-d) and build for ios
        ./build.sh -d ios

        # build for osx
        ./build.sh osx

The framework will be created for each target platform and located in `framework` folder.

iOS framework includes support for iOS Simulator as well.

### Use Framework

You might just drag & drop the framework into your Xcode project and you're good to go.
However, I personally prefere more managed ways, that is [CocoaPods](http://cocoapods.org).

So, there's `Shark-SDK` pod which you can use both for your iOS and OS X projects.

At the moment, the search on http://cocoapods.org does not return any search results for `Shark-SDK`. But the podspec is already in the [Specs](https://github.com/CocoaPods/Specs/tree/master/Shark-SDK) repository, and it already showed up in RSS feed. So you can plug it in using your `Podfile`.

``` ruby
platform :ios, :deployment_target => '6.0'
pod 'Shark-SDK'

target :'shark2-osx-demo', :exclusive => true do
	platform :osx, :deployment_target => '10.7'
	pod 'Shark-SDK'
end
```

> Make sure you close Xcode workspace while running `pod install` or `pod update`, otherwise the workspace build settings will be messed up.

## Under the Hood
If you want to know what exactly does this script do, check out the [blog post](http://mgrebenets.github.io/shark2-iosx)
