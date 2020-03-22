------------------------------------------------------------------------
            Compiling Instructions for SimVascular on MacOS
                       Revised 2019-06-14
------------------------------------------------------------------------

--------
Overview
--------

By default, SimVascular is configured to build on Windows using
makefiles.  You must override the deafult options to build on macos.

Our base test configuration for linux is:

OS X High Sierra 10.13.6 64-bit
Intel 7 processor
16 GB of memory
clang 8.1
Intel Iris Pro 1536 MB

-------------------------------
Major Steps (2019.06 externals)
-------------------------------

1. Macos prerequisities
------------------------

You must have "brew" installed and install certain
system libraries before you compile:

% cd Externals/Prep/2019.06
% ./macos-13-prep.sh

2.  Building SimVascular
------------------------

% cd BuildWithMake
% source quick-build-macosx.sh

3. Launching SimVascular
------------------------

% cd BuildWithMake
% ./sv       (default Qt gui)
% ./sv -tk   (old tcl/tk gui)

4. Building an Installer (optional)
-----------------------------------

% cd BuildWithMake/Release
% make

5. Override options (optional)
------------------------------

Override defaults with:

  * cluster_overrides.mk
  * global_overrides.mk
  * site_overrides.mk
  * pk_overrides.mk

See include.mk for all options.

6.  To build external open source packages (very optional)
----------------------------------------------------------

% cd Externals/Make/2019.06
% source build-sv-exeternals-mac_osx.sh
