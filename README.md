Build Shark 2.3.4 Framework for iOS & OSX
===
###### Using Xcode5 (armv7, armv7s, arm64, i386, x86_64)

### What is Shark?
SHARK provides libraries for the design of adaptive systems, including methods for linear and nonlinear optimization (e.g., evolutionary and gradient-based algorithms), kernel-based algorithms and neural networks, and other machine learning techniques.

Find out more on the [project website](https://sourceforge.net/projects/shark-project/)

This script is designed to build version 2.3.4 of the library, not the latest 3.0 version.

### Build Framework
With this script building the framework is as easy as

        # download (-d) and build for ios
        ./build.sh -d ios

        # build for osx
        ./build.sh osx

The framework will be created for each target platform and located in `framework` folder.

iOS framework includes support for iOS Simulator as well.

Now just drag & drop the framework into your Xcode project and you're good to go.

## Under the Hood
If you want to know what exactly does this script do, check out the blog post (http://mgrebenets.github.io/shark2-iosx)
