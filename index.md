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

Note the use of deafult value for the only parameter of the constructor. There's an in-depth discussion of this issue on [StackOverflow](http://stackoverflow.com/questions/18313509/default-argument-gcc-vs-clang)

The fix is to remove default value for `sl` parameter. Since `EarlyStopping` constructor is not referenced anywhere in the library source code it is up to you, as a library user, to provide some value to it and not to rely on any default values.

#### No `finite` for iOS
Next issue is with `finite` method. This method is not included for iOS target architectures. You will get this error when building both for iOS Device and Simulator. Here's [some reference](http://createdigitalnoise.com/discussion/1754/can-t-compile-expr-with-xcode-4-5-2-same-project-works-in-xcode-4-4-1) to this problem.

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

`p` is a public member function of `RandomVar` and `RandomVector` sublcasses `RandomVar`.

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


