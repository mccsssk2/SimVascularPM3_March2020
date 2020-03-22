------------------------------------------------------------------------
            Compiling Instructions for svSolver on Linux
                       Revised 2019-11-17
------------------------------------------------------------------------

--------
Overview
--------

By default, SimVascular is configured to build on Windows using
makefiles.  You must override the deafult options to build on linux.

Our base test configuration for linux is:

minimim requirements:

Ubuntu 16.04 64-bit desktop (w/ patches)
Intel 7/9 processor
gcc/g++/gfortran version 5.4

Highly recommended:

Ubuntu 18.04 64-bit desktop (w/ patches)
Intel 7/9 processor
gcc/g++/gfortran version 7.4

Building with the Intel compilers (ifort/icpc/icc) should
work but this has limited testing.

-------------------------------
Major Steps (2019.06 externals)
-------------------------------

-----------
Major Steps
-----------

1. System Prerequisities
------------------------

1a. CentOS (7.6)
----------------
The following packages are required to build svsolver

### helpers for build
% yum install tcl

### cmake tools
% yum install cmake
% yum install cmake-gui

### mpi versions
% yum install openmpi
% yum install openmpi-devel
% yum install mpich
% yum install mpich-devel

1b. Ubuntu (18.04)
--------------------
The following packages are required to build simvascular

### compilers & dev tools
% sudo apt-get install g++
% sudo apt-get install gfortran
% sudo apt-get install git

### cmake tools
% sudo apt-get install cmake
% sudo apt-get install cmake-qt-gui

### for flowsolver
% sudo apt-get install libmpich-dev

### for vtk
% sudo apt-get install libglu1-mesa-dev
% sudo apt-get install libxt-dev

### some optional helpers
% sudo apt-get install dos2unix
% sudo apt-get install emacs


2. Checkout svSolver source code
--------------------------------
% git clone https://github.com/SimVascular/svSolver.git svsolver

3. Building svSolver
---------------------

By default, on Linux svSolver is built with a dummy version of MPI.
This is a single processor only version of MPI for testing.  See
below on how to use openmpi or mpich.

% cd svsolver/BuildWithMake
% module add openmpi-x86_64  (if needed on centos)
% source quick-build-linux.sh

4. Launching svSolver
---------------------

% cd BuildWithMake
% mypre  (preprocessor)
% mypost (postprocessor)
% mysolver-nompi (wrapper script for solver)

5. Building an Installer (optional)
-----------------------------------

An installer isn't needed for Linux.  The executables
are self contained and shouldn't need environment variables
to be set before running the solver.

6. Optional override options
----------------------------
You can override defaults in the make build
using one or more of the "override" files:

  * cluster_overrides.mk
  * global_overrides.mk
  * site_overrides.mk
  * pkg_overrides.mk

See include.mk for all options.

See the "quick-build" script to see what must
be set in cluster_overrides.mk to build on linux.

For example, to build with a dummy MPI (only
can use a single core), put the folllowing into
global_overrides.mk:

*** start file "global_overrides.mk"

#
# Notes on MPI:
# * default is to use dummy mpi
# * can only build one at a time

SV_USE_DUMMY_MPI=1
SV_USE_OPENMPI=0
SV_USE_MPICH=0

*** end file "global_overrides.mk"

7.  To build external open source packages (very optional)
----------------------------------------------------------

% cd Externals/Make/2019.06
% source build-sv-exeternals-linux.sh















4. Override options
-------------------
Override defaults with:

  * cluster_overrides.mk
  * global_overrides.mk
  * site_overrides.mk
  * pkg_overrides.mk

Building with gnu compilers and the vtk binaries should
build "out of the box" without required overrides.

See include.mk for all options.  Sample override files
can be found in:

SampleOverrides

to use one of these files, copy into local BuildWithMake
directory and modify as needed, e.g.:

% cd svsolver/BuildWithMake
% cp SampleOverrides/centos_6/global_overrides.mk .  (centos)
% cp SampleOverrides/ubuntu_14/global_overrides.mk .  (ubuntu)

6. Build
--------
% cd svsolver/BuildWithMake
% module add openmpi-x86_64  (if needed on centos)
% make

7. Running developer version
----------------------------
Binaries are in "BuildWithMake/Bin" directory.

8. Build release (NOTE: out-of-date!)
-----------------
% cd svsolver/BuildWithMake/Release
% make

9. Installing a distribution (NOTE: out-of-date!)
----------------------------
To be updated.
