# Install script for directory: /Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local/SV")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "RelWithDebInfo")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyLibrariesx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Build/svFSI-build/lib/lib_simvascular_thirdparty_metis_svfsi.a")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/lib_simvascular_thirdparty_metis_svfsi.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/lib_simvascular_thirdparty_metis_svfsi.a")
    execute_process(COMMAND "/Library/Developer/CommandLineTools/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/lib_simvascular_thirdparty_metis_svfsi.a")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyHeadersx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/thirdparty/metis_svfsi" TYPE FILE RENAME "metis_svfsi_macros.h" FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib/macros.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyHeadersx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/thirdparty/metis_svfsi" TYPE FILE RENAME "metis_svfsi_proto.h" FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib/proto.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyHeadersx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/thirdparty/metis_svfsi" TYPE FILE RENAME "metis_svfsi_rename.h" FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib/rename.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyHeadersx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/thirdparty/metis_svfsi" TYPE FILE RENAME "metis_svfsi_stdheaders.h" FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib/stdheaders.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyHeadersx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/thirdparty/metis_svfsi" TYPE FILE RENAME "metis_svfsi_struct.h" FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib/struct.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyHeadersx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/thirdparty/metis_svfsi" TYPE FILE RENAME "metis_svfsi_parmetis.h" FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib/parmetis.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xThirdPartyHeadersx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/thirdparty/metis_svfsi" TYPE FILE FILES "/Users/kharches/software/SimVascPM3/svFSI-master/Code/ThirdParty/metis_svfsi/simvascular_metis_svfsi/METISLib/temp/metis.h")
endif()

