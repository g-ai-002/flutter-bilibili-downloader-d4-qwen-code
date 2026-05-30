# CMake configuration for Windows Flutter application
cmake_minimum_required(VERSION 3.14)
project(bilibili_downloader LANGUAGES CXX)

set(BINARY_NAME "bilibili_downloader")
set(APPLICATION_ID "com.bilibili.downloader")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Configure build type
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Include Flutter generated configuration
include("flutter/ephemeral/CMakeLists.txt" OPTIONAL)

# Add runner subdirectory
add_subdirectory("runner")

# Install rules
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")
install(DIRECTORY "flutter/ephemeral/" DESTINATION "${CMAKE_INSTALL_PREFIX}" FILES_MATCHING PATTERN "*.dll" PATTERN "*.pdb" EXCLUDE)
