#
# vtk
#

REPLACEME_SV_SPECIAL_COMPILER_SCRIPT

export CC=REPLACEME_CC
export CXX=REPLACEME_CXX

rm -Rf REPLACEME_SV_TOP_BIN_DIR_VTK
mkdir -p REPLACEME_SV_TOP_BIN_DIR_VTK
chmod u+w,a+rx REPLACEME_SV_TOP_BIN_DIR_VTK

rm -Rf REPLACEME_SV_TOP_BLD_DIR_VTK
mkdir -p REPLACEME_SV_TOP_BLD_DIR_VTK
cd REPLACEME_SV_TOP_BLD_DIR_VTK

REPLACEME_SV_CMAKE_CMD -G REPLACEME_SV_CMAKE_GENERATOR \
   -DSV_EXTERNALS_TOPLEVEL_BIN_DIR:PATH=REPLACEME_SV_FULLPATH_BINDIR \
   -DCMAKE_INSTALL_PREFIX=REPLACEME_SV_TOP_BIN_DIR_VTK \
   -DCMAKE_BUILD_TYPE=REPLACEME_SV_CMAKE_BUILD_TYPE \
   -DBUILD_EXAMPLES=0 \
   -DBUILD_SHARED_LIBS=0 \
   -DVTK_Group_Imaging=0 \
   -DVTK_Group_Qt=0 \
   -DVTK_Group_Tk=0 \
   -DVTK_Group_Rendering=0 \
   -DVTK_WRAP_PYTHON=0 \
   -DVTK_WRAP_TCL=0 \
   -DVTK_QT_VERSION=5 \
   -DModule_vtkTestingRendering=0 \
REPLACEME_SV_TOP_SRC_DIR_VTK

REPLACEME_SV_MAKE_CMD REPLACEME_SV_VTK_MAKE_FILENAME REPLACEME_SV_MAKE_BUILD_PARAMETERS

REPLACEME_SV_MAKE_CMD REPLACEME_SV_VTK_MAKE_FILENAME REPLACEME_SV_MAKE_INSTALL_PARAMETERS

REPLACEME_SV_SPECIAL_COMPILER_END_SCRIPT
