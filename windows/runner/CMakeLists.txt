cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "bilibili_downloader")
set(APPLICATION_ID "com.bilibili.downloader")

# Define application sources
set(SOURCES
  main.cpp
  flutter_window.cpp
  win32_window.cpp
  utils.cpp
)

# Define application headers
set(HEADERS
  flutter_window.h
  win32_window.h
  utils.h
  resource.h
)

# Add executable
add_executable(${BINARY_NAME}
  ${SOURCES}
  ${HEADERS}
  "resources/bilibili_downloader.rc"
)

# Include directories
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

# Link Flutter library
target_link_libraries(${BINARY_NAME} PRIVATE flutter_wrapper_app)

# Link Windows libraries
target_link_libraries(${BINARY_NAME} PRIVATE
  dwmapi.lib
  shlwapi.lib
  comctl32.lib
  ole32.lib
  shcore.lib
  imm32.lib
)

# Set application properties
set_target_properties(${BINARY_NAME} PROPERTIES
  WIN32_EXECUTABLE TRUE
  OUTPUT_NAME "${BINARY_NAME}"
)

# Install rules
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")
