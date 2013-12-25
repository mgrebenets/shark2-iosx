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

Unlike the GitHub project README this post goes into details of the build process.



## Steps
- [Get Source Code](#step_get)
- [Patch Source Code](#step_patch)
- [Configure and Build](#step_build)
- [Lipo Library](#step_lipo)
- [Package Framework](#step_package)

<a name="step_get"></a>
### Get Source Code
This step is as simple as just downloading the zip archive.

{% highlight bash %}
# download
curl -L --progress-bar -o shark-2.3.4.zip "http://sourceforge.net/projects/shark-project/files/Shark%20Core/Shark%202.3.4/shark-2.3.4.zip/download"

# unzip
unzip -q shark-2.3.4.zip -d src

{% endhighlight %}

<a name="step_patch"></a>
### Patch Source Code
That's where some fun begins. The original source code was developed with gcc 4.2, while we're trying to compile it with clang 5.0. There's been years of development since then, both in terms of compilers and c++ standards. No wonder clang fails with quite a few errors.

<a name="step_build"></a>
### Configure and Build

<a name="step_lipo"></a>
### Lipo Library

<a name="step_package"></a>
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


