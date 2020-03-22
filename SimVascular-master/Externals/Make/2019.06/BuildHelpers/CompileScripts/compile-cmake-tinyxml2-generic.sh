#
# tinyxml2
#

REPLACEME_SV_SPECIAL_COMPILER_SCRIPT

export CC=REPLACEME_CC
export CXX=REPLACEME_CXX

rm -Rf REPLACEME_SV_TOP_BIN_DIR_TINYXML2
mkdir -p REPLACEME_SV_TOP_BIN_DIR_TINYXML2
chmod u+w,a+rx REPLACEME_SV_TOP_BIN_DIR_TINYXML2

rm -Rf REPLACEME_SV_TOP_BLD_DIR_TINYXML2
mkdir -p REPLACEME_SV_TOP_BLD_DIR_TINYXML2
cd REPLACEME_SV_TOP_BLD_DIR_TINYXML2

REPLACEME_SV_CMAKE_CMD -G REPLACEME_SV_CMAKE_GENERATOR \
  -DSV_EXTERNALS_TOPLEVEL_BIN_DIR:PATH=REPLACEME_SV_FULLPATH_BINDIR \
  -DCMAKE_INSTALL_PREFIX=REPLACEME_SV_TOP_BIN_DIR_TINYXML2 \
  -DCMAKE_BUILD_TYPE=REPLACEME_SV_CMAKE_BUILD_TYPE \
  -DBUILD_TESTING=OFF \
  -DBUILD_TESTS=OFF \
REPLACEME_SV_TOP_SRC_DIR_TINYXML2

REPLACEME_SV_MAKE_CMD REPLACEME_SV_TINYXML2_MAKE_FILENAME REPLACEME_SV_MAKE_BUILD_PARAMETERS

REPLACEME_SV_MAKE_CMD REPLACEME_SV_TINYXML2_MAKE_FILENAME REPLACEME_SV_MAKE_INSTALL_PARAMETERS

REPLACEME_SV_SPECIAL_COMPILER_END_SCRIPT



