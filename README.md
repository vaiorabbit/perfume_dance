# Perfume Dance #

*   Created : 2014-05-12
*   Last modified : 2018-10-09

<img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_00.png" width="200"> <img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_01.png" width="200"> <img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_02.png" width="200">

<img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_03.png" width="200"> <img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_04.png" width="200"> <img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_05.png" width="200">

<img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_06.png" width="200"> <img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_07.png" width="200"> <img src="https://raw.githubusercontent.com/vaiorabbit/perfume_dance/master/doc/perfume_dance_08.png" width="200">


A BVH motion parser and playback implementation used to make the video:

* Perfume BVH playback test
  * [![](http://img.youtube.com/vi/byxKHVvCwt0/mqdefault.jpg)](https://www.youtube.com/watch?v=byxKHVvCwt0a)


## Prerequisites ##

*   OpenGL 4.1 capable GPU

*   Ruby OpenGL Bindings ( https://github.com/vaiorabbit/ruby-opengl )
    *   $ gem install opengl-bindings

*   GLFW DLL
    *   https://www.glfw.org (Windows)
    *   $ brew install glfw3 (macOS)

*   3D math module
    *   Use rmath3d_plain ( https://rubygems.org/gems/rmath3d_plain ) . No building processes are required.
        *   $ gem install rmath3d_plain
    *   If you can build and install ruby C extension, consider using rmath3d instead ( https://rubygems.org/gems/rmath3d ) for speeding up this application.
        *   $ gem install rmath3d

## How to run ##

1.  Get the archive of motion data 'bvhfiles.zip' via http://perfume-dev.github.io
2.  Copy BVH files (aachan.bvh, kashiyuka.bvh and nocchi.bvh) into ./data
3.  Put glfw3.dll (Windows) / libglfw.dylib (macOS) here
    *   or specify path to the GLFW DLL as the argument of 'GLFW.load_lib()'. See perfume_dance.rb
        *   ex.) GLFW.load_lib('libglfw3.dylib', '/usr/local/lib')  (macOS)
4.  $ ruby perfume_dance.rb


## Operation ##

*   Esc       : quit.
*   Mouse L/R : move eye position.


## License ##

All source codes are available under the terms of the zlib/libpng license.

    Perfume Dance
    Copyright (c) 2014-2018 vaiorabbit

    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any damages
    arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:

        1. The origin of this software must not be misrepresented; you must not
        claim that you wrote the original software. If you use this software
        in a product, an acknowledgment in the product documentation would be
        appreciated but is not required.

        2. Altered source versions must be plainly marked as such, and must not be
        misrepresented as being the original software.

        3. This notice may not be removed or altered from any source
        distribution.
