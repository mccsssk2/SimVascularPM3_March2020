# Copyright (c) Stanford University, The Regents of the University of
#               California, and others.
#
# All Rights Reserved.
#
# See Copyright-SimVascular.txt for additional details.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

VTK_MAJOR_VERSION=8
VTK_MINOR_VERSION=1
VTK_PATCH_VERSION=1
VTK_VERSION=$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION).$(VTK_PATCH_VERSION)

VTK_SRCDIR = $(OPEN_SOFTWARE_SOURCES_TOPLEVEL)/vtk-$(VTK_VERSION)
VTK_BINDIR = $(OPEN_SOFTWARE_BINARIES_TOPLEVEL)/vtk-$(VTK_VERSION)
VTK_INCLUDE_DIR_BASE = $(VTK_BINDIR)/include/vtk-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)

ifeq ($(CXX_COMPILER_VERSION), mingw-gcc)
  VTK_LIBDIRS = $(VTK_BINDIR)/lib
  VTK_BINDIRS = $(VTK_BINDIR)/bin
else
  VTK_LIBDIRS = $(VTK_BINDIR)/lib
  VTK_BINDIRS = $(VTK_BINDIR)/bin
endif

VTK_SO_PATH = $(VTK_BINDIRS)
VTK_DLLS    = $(VTK_BINDIRS)/*.$(SOEXT)

VTK_SYS_LIBS  = $(LIBFLAG)kernel32$(LIBLINKEXT) $(LIBFLAG)user32$(LIBLINKEXT) \
                $(LIBFLAG)gdi32$(LIBLINKEXT) $(LIBFLAG)winspool$(LIBLINKEXT) $(LIBFLAG)shell32$(LIBLINKEXT) \
                $(LIBFLAG)ole32$(LIBLINKEXT) $(LIBFLAG)oleaut32$(LIBLINKEXT) $(LIBFLAG)uuid$(LIBLINKEXT) \
                $(LIBFLAG)comdlg32$(LIBLINKEXT) $(LIBFLAG)advapi32$(LIBLINKEXT) \
                $(LIBFLAG)comctl32$(LIBLINKEXT) $(LIBFLAG)wsock32$(LIBLINKEXT) \
                $(LIBFLAG)opengl32$(LIBLINKEXT) $(LIBFLAG)vfw32$(LIBLINKEXT)
#
#  don't include vtksys!!
#

VTK_INCDIRS = \
-I$(VTK_INCLUDE_DIR_BASE) \
-I$(VTK_INCLUDE_DIR_BASE)/vtkexpat \
-I$(VTK_INCLUDE_DIR_BASE)/vtkgl2ps \
-I$(VTK_INCLUDE_DIR_BASE)/vtkjpeg \
-I$(VTK_INCLUDE_DIR_BASE)/vtkjsoncpp \
-I$(VTK_INCLUDE_DIR_BASE)/vtklibproj4 \
-I$(VTK_INCLUDE_DIR_BASE)/vtklibxml2 \
-I$(VTK_INCLUDE_DIR_BASE)/vtkmetaio \
-I$(VTK_INCLUDE_DIR_BASE)/vtknetcdf \
-I$(VTK_INCLUDE_DIR_BASE)/vtkpng \
-I$(VTK_INCLUDE_DIR_BASE)/vtksqlite \
-I$(VTK_INCLUDE_DIR_BASE)/vtktiff \
-I$(VTK_INCLUDE_DIR_BASE)/vtkverdict \
-I$(VTK_INCLUDE_DIR_BASE)/vtkzlib \
-I$(VTK_INCLUDE_DIR_BASE)/alglib

ifneq ($(SV_USE_FREETYPE),1)
  VTK_INCDIRS += -I$(VTK_INCLUDE_DIR_BASE)/vtkfreetype
endif

#
#  libraries for svPre, svPost, svSolver
#

VTK_LIBS =      $(LIBPATH_COMPILER_FLAG)$(VTK_LIBDIRS) \
                $(LIBFLAG)vtkIOXML-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkIOXMLParser-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkFiltersExtraction-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkFiltersModeling-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkFiltersGeneral-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkFiltersGeometry-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkFiltersCore-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkCommonExecutionModel-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkCommonDataModel-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
	        $(LIBFLAG)vtkCommonSystem-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkCommonTransforms-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkCommonMisc-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkCommonMath-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkIOCore-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkCommonCore-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkzlib-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtkexpat-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
                $(LIBFLAG)vtksys-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
		$(LIBFLAG)vtklz4-$(VTK_MAJOR_VERSION).$(VTK_MINOR_VERSION)$(LIBLINKEXT) \
                $(VTK_SYS_LIBS)

