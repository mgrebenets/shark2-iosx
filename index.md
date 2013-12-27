---
layout: page
title: Build Shark Framework for iOS & OSX
tagline: Supporting tagline
---
{% include JB/setup %}

## What is Shark?
SHARK provides libraries for the design of adaptive systems, including methods for linear and nonlinear optimization (e.g., evolutionary and gradient-based algorithms), kernel-based algorithms and neural networks, and other machine learning techniques.

This script is created to build framework for Shark version 2.3.4.


For a newer alpha release of Shark 3.0 please visit [http://image.diku.dk/shark](http://image.diku.dk/shark).

Unlike the GitHub project [README](https://github.com/mgrebenets/shark2-iosx) this post goes into details of the build process.

## Steps
The process of building framework consists of the following steps

- Get Source Code
- Patch Source Code
- Configure and Build
- Lipo Library
- Package Framework

### Get Source Code
This step is as simple as just downloading the zip archive.

{% highlight bash %}
# download
curl -L --progress-bar -o shark-2.3.4.zip "http://sourceforge.net/projects/shark-project/files/Shark%20Core/Shark%202.3.4/shark-2.3.4.zip/download"

# unzip
unzip -q shark-2.3.4.zip -d src
{% endhighlight %}

### Patch Source Code
That's where some fun begins. The original source code was developed with gcc 4.2, while we're trying to compile it with clang 5.0. There's been years of development since then, both in terms of compilers and c++ standards. No wonder clang fails with quite a few errors.

#### Default Constructor
Let's start with the patch that I believe might have some impact on the way you should use the library. In file `ReClam/EarlyStopping.cpp`, line 78.

{% highlight c++ %}
EarlyStopping::EarlyStopping(unsigned sl = 5)
{% endhighlight %}

Note the use of default value for the only parameter of the constructor. There's an in-depth discussion of this issue on [StackOverflow](http://stackoverflow.com/questions/18313509/default-argument-gcc-vs-clang)

The fix is to remove default value for `sl` parameter. Since `EarlyStopping` constructor is not referenced anywhere in the library source code it is up to you, as a library user, to provide some value to it and not to rely on any default values.

#### No `finite` for iOS
Next issue is with `finite` method. This method is not included for iOS target architectures. You will get this error when building both for iOS Device and Simulator. Here's [some referencee](http://createdigitalnoise.com/discussion/1754/can-t-compile-expr-with-xcode-4-5-2-same-project-works-in-xcode-4-4-1) to this problem.

The suggested fix is to replace calls to `finite` with `isfinite`. The best way to do it is to use `#define` macro and place it in the `SharkDefs.h` file.

{% highlight c++ %}
#if defined(__APPLE__) && defined(__MACH__)
/* Apple OSX and iOS (Darwin). */
#include <TargetConditionals.h>
#if TARGET_IPHONE_SIMULATOR == 1
/* iOS in Xcode simulator */
#define finite(x) isfinite(x)
#elif TARGET_OS_IPHONE == 1
/* iOS on iPhone, iPad, etc. */
#define finite(x) isfinite(x)
// #define drem(x, y) remainder(x, y)
#elif TARGET_OS_MAC == 1
/* OSX */
#endif
#endif
{% endhighlight %}

* First, check if `__APPLE__` and `__MACH___` are defined to detect Apple's OS.
* Then include `<TargetConditionals.>` to enable `TARGET_IPHONE_SIMULATOR`, `TARGET_OS_IPHONE` and `TARGET_OS_MAC` defines.
* Finally, use those three defines to redefine `finite(x)` as `isfinite(x)` for iOS Device and Simulator targets.

Note the commented line for `drem(x, y)`. This method is not available for iOS targets as well and should be replaced with `remainder(x, y)`. Shark library doesn't use it, but you'll know what to do if you ever have a problem with `drem`.

#### FileUtil Fixes
Next comes `FileUtil.h`. There's a couple of things that clang doesn't like.

First is the use of `FileUtil` namespace. Clang can't resolve references to `iotype` type, as well as references to three constants `SetDefault`, `ScanFrom` and `PrintTo`.

The fix is to use namespace scope.
{% highlight c++ %}
iotype --> FileUtil::iotype
SetDefault --> FileUtil::SetDefault
ScanFrom --> FileUtil::ScanFrom
PrintTo --> FileUtil::PrintTo
{% endhighlight %}

Finally, `io_strict` is calling `scanFrom_strict` and `printTo_strict`, which are defined further down in the header file.

The fix for this problem is simple - move declaration of `io_strict` to the bottom of the header file.

#### `double erf(double) throw();`
Compilation of `Mixture/MixtureOfGaussians.cpp` fails with error caused by the following line

{% highlight c++ %}
extern "C" double erf(double) throw();
{% endhighlight %}

Clang complains that `extern "C"` declaration doesn't match the actual prototype of `erf`. Removing `throw()` statement solves this issue.

#### RandomVector `this->p`
Line 72 in `Mixture/RandomVector.h` references `p` "as is".

{% highlight c++ %}
for (unsigned k = x.dim(0); k--;) {
    l += log(Shark::max(p(x[ k ]), 1e-100));    // !!!
}
{% endhighlight %}

`p` is a public member function of `RandomVar` and `RandomVector` subclasses `RandomVar`.

{% highlight c++ %}
// RandomVar.h
template < class T >
class RandomVar
{
public:
    // ***
    virtual double p(const T&) const = 0;
    // ***
}

// RandomVector.h
template < class T >
class RandomVector : public RandomVar< Array< T > >
{
public:
    // ***
}
{% endhighlight %}

Thus the fix is as simple as replacing reference to `p` with `this->p`. Note the triple exclamation mark comment in the original code (`// !!!`), looks like developers knew something could go wrong with this code.

#### Make It Static
The last patch is actually not a fix. Since we want to build a static library, we need to modify original `CMakeList.txt`, otherwise the dynamic library is built.

{% highlight cmake %}
ADD_LIBRARY( shark STATIC ${SRCS} )
{% endhighlight %}

If you want to build a dynamic (shared) library, you'll need to use the original line.

{% highlight cmake %}
ADD_LIBRARY( shark SHARED ${SRCS} )
{% endhighlight %}

#### Apply Patch
All the changes described above are available as a patch file [shark.patch](https://github.com/mgrebenets/shark2-iosx/blob/master/build.sh).
To create patch file use `diff` utility.

{% highlight bash %}
diff -crB shark_orig shark_patched > shark.patch
{% endhighlight %}

To apply the patch use `patch` command.
{% highlight bash %}
patch -d src/Shark -p1 --forward -r - -i ../../shark.patch
{% endhighlight %}

* The `--forward` flag will disable interactive mode and all the prompts
* `-d` flag is used to specify the source code folder, the utility will `cd` into specified folder
* `-r -` option specifies that no `.rej` files should be created if the patch is already applied (or in case of any other error)
* note the relative path for `-i ../../shark.patch`, this is needed because `-d` flag is used and patch command will be executed in `src/Shark` folder

### Configure and Build

Now when all the compile errors are fixed it's time to build static library for all target platforms.

Before we run `make` we have to configure the build (that also creates `Makefile`) and for this purpose we're going to stick with `cmake`.

We'll have to run `cmake` and then `make` 3 times to build 3 static libraries for following targets
- iOS Devices (armv7, armv7s, x86_64)
- iOS Simulator (i386, x86_64)
- Mac OS X (x86_64)

The libraries for iOS Device and Simulator will later be merged into one fat library which you can use for your iOS development and release.

#### `cmake` Basics
Each of the build targets needs to be configured differently with `cmake`.
The following options have to be configured:

- C++ Compiler (`CMAKE_CXX_COMPILER`)

By default the `/usr/bin/c++` is used as C++ compiler, but we want to build using `clang++` compiler from Xcode toolchain.

- C++ Compiler Flags (`CMAKE_CXX_FLAGS`)

The C++ compiler flags are used to specify target architectures and other important build settings.

- C Compiler (`CMAKE_C_COMPILER`)

Even though there's no plain C code, the C compiler needs to be configured, since the whole project by default is C/C++ project.

- System Root (`CMAKE_OSX_SYSROOT`)

This is where build system will look for all the standard library includes.

- Install Prefix (`CMAKE_INSTALL_PREFIX`)

This is optional, the prefix is used to tell `make install` where to install your library. Normally it's used when you build a shared library and then want to place it somewhere in your `/usr/local/lib`.

- Build System Generator (`-G` flag)
We plan to use `make` utility with `Makefile`, so this option will be `"Unix Makefile"`. 

You'd probably ask "Why not 'Xcode' generator?". I have 2 answers for that. First, I couldn't make it work. Second, with `make` you can use all the horsepower of your build machine by running multiple compilation jobs in parallel (`-j` flag), while `xcodebuild` will do it old-style one by one as slow as possible.

#### Xcode Toolchain
Let's start with asking Xcode where all the tools are.

{% highlight bash %}
XCODE_ROOT=$(xcode-select -print-path)
XCODE_ARM_ROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
XCODE_SIM_ROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
XCODE_TOOLCHAIN_BIN=$XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin
CXX_COMPILER=${XCODE_TOOLCHAIN_BIN}/clang++
C_COMPILER=${XCODE_TOOLCHAIN_BIN}/clang
{% endhighlight %}

Now we have all we need: C and C++ compiler, system roots for iOS Device and Simulator. For OS X the `cmake` is smart enough to find system root automatically.

It's time to configure build for each target.

##### iOS Device
We don't want to mess up with the original source code, so let's build in a separate folder.
{% highlight bash %}
mkdir -p build/ios
cd build/ios
{% endhighlight %}

To configure the build, we already have `CXX_COMPILER`, `C_COMPILER`. We still need to configure is C++ Compiler Flags and System Root.

Our goal is to support 3 iOS Device architectures: `armv7`, `armv7s` and `arm64`, that's where `-arch` option is used. 

The System Root is the root folder of iPhone OS 7.0 SDK, it's located in the `XCODE_ARM_ROOT`, which we defined above.

{% highlight bash %}
CXX_FLAGS="-arch armv7 -arch armv7s -arch arm64"
SYSTEM_ROOT=${XCODE_ARM_ROOT}/SDKs/iPhoneOS7.0.sdk
{% endhighlight %}

Now we can run `cmake`.
{% highlight bash %}
cmake \
  -DCMAKE_CXX_COMPILER=$CXX_COMPILER \
  -DCMAKE_OSX_SYSROOT="$SYSTEM_ROOT" \
  -DCMAKE_C_COMPILER=$C_COMPILER \
  -DCMAKE_CXX_FLAGS="$CXX_FLAGS" \
  -G "Unix Makefiles" \
  ../../src/Shark
{% endhighlight %}

> If you are trying to run this command right now, you'll face the "C Compiler Test" error. For a work-around check the "cmake Tricks" section below.

##### iOS Simulator
For iOS Simulator we're going to use `i386` and `x86_64` architectures, the latter one will allow you to test on "iPad Retina (64-bit)" and other 64-bit device simulators.

The System Root is `${XCODE_SIM_ROOT}/SDKs/iPhoneSimulator7.0.sdk`.

And then there's one more very important C++ compiler flag: `-mios-simulator-version-min=7.0`. If you don't set this flag, the build target will be OS X.

{% highlight bash %}
CXX_FLAGS="-arch i386 -arch x86_64 -mios-simulator-version-min=7.0"
SYSTEM_ROOT=${XCODE_SIM_ROOT}/SDKs/iPhoneSimulator7.0.sdk

cmake \
  -DCMAKE_CXX_COMPILER=$CXX_COMPILER \
  -DCMAKE_OSX_SYSROOT="$SYSTEM_ROOT" \
  -DCMAKE_C_COMPILER=$C_COMPILER \
  -DCMAKE_CXX_FLAGS="$CXX_FLAGS" \
  -G "Unix Makefiles" \
  ../../src/Shark
{% endhighlight %}

##### Mac OS X
For OS X we only need to configure C and C++ compilers, then leave the rest of settings to `cmake`.

{% highlight bash %}
cmake \
  -DCMAKE_CXX_COMPILER=$CXX_COMPILER \
  -DCMAKE_C_COMPILER=$C_COMPILER \
  -G "Unix Makefiles" \
  ../../src/Shark
{% endhighlight %}

#### `cmake` Tricks

##### Compiler Test
Now, if you tried to run any of the above commands you definitely face the "C Compiler Test" error. `cmake` checks `clang` compiler by trying to compile some test code and that check fails. I tried to use different approaches to pass the compiler test, such as setting project type to `NONE` in `CMakeLists.txt`, but nothing worked for me. So I had to come up with somewhat dirty trick to fix this problem:

- Run `cmake` once with no properties set, aka "Initial Run"

This will pick up default C and C++ compilers, pass the compiler test, create `CMakeCache.txt` and `CMakeFiles` folder. If you `cmake` again, the compiler test won't be performed any more.

##### Changed Parameters
If you just ran `cmake` for the 2nd time with all the properties set (compilers, system root, flags, etc.) you might think that you're good to go and can just `make` stuff.

But wait... Run `ccmake ../../src/Shark` and have a look at all the build settings. You'll notice that C++ Compiler Flags are not set. This is specifics of `cmake`. If you change some important build settings, like compiler flags, the `cmake` will detect the change and spit out a message like "C++ Compiler Flags changed, you need to configure build to apply the changes." Well, you won't see this message with `cmake`, but you can play around with `ccmake` and see it.

In short, you need to run `cmake` twice if you change some specific settings. That's why you'll see `cmakeRun` called twice in `build.sh` for iOS target. And yes, with the initial run to pass compiler test check, you'll end up calling `cmake` for up to 3 times.

#### Make It!
At last you're ready to make it!

At this point it is as simple as
{% highlight bash %}
make -j16
{% endhighlight %}

The `-j16` will parallelize the build and make it way faster than plain `make`.

It doesn't take long and in the end you'll have `libshark.a` static library. Check it with `file` utility to make sure you have all the architectures in place.

{% highlight bash %}
$ file build/ios/libshark.a
$ file build/sim/libshark.a
$ file build/osx/libshark.a
build/osx/libshark.a: current ar archive random library
{% endhighlight %}

*TODO* all the common stuff
why cmake is used, how it used, and just a note about ccmake
- what needs to be configured
- install prefix (not really used though)
- compilers c/cxx and the rest of toolchain as well
- compiler flags (cxx only), includes architecture and target (for simulator)
- system root

what are the flags for each target iOS (Device and Simulator)
OSX

### Lipo Library

### Package Framework

examples below
===
## Update Author Attributes

In `_config.yml` remember to specify your own data:

    title : My Blog =)

    author :
      name : Maksym Grebenets------
      email : mgrebenets@gmail.com
      github : mgrebenets

The theme should reference these variables whenever needed.

## Sample Posts

This blog contains sample posts which help stage pages and blog data.
When you don't need the samples anymore just delete the `_posts/core-samples` folder.

    $ rm -rf _posts/core-samples

Here's a sample "posts list".

<ul class="posts">
  {% for post in site.posts %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>

## To-Do

This theme is still unfinished. If you'd like to be added as a contributor, [please fork](http://github.com/plusjade/jekyll-bootstrap)!
We need to clean up the themes, make theme usage guides with theme-specific markup examples.

