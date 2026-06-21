cmake_minimum_required(VERSION 3.16)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/configure.ac" CONFIGURE_AC_DATA)
string(REGEX MATCH "m4_define\\(\\[libusb_compat_version_suffix\\], \\[([0-9]+)\\]\\)" _ ${CONFIGURE_AC_DATA})
set(VERSION_SUB ${CMAKE_MATCH_1})
if(NOT VERSION_SUB)
    set(VERSION_SUB 9)
endif()

project(libusb-compat
    DESCRIPTION "A libusb-0.1 compatibility layer on top of libusb-1.0"
    VERSION 0.1.${VERSION_SUB}
    LANGUAGES C
)

message(STATUS "Building libusb-compat v${PROJECT_VERSION} for: ${CMAKE_SYSTEM_NAME}")

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(FetchContent)

option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(ENABLE_EXAMPLES "Build example applications" ON)

# Fetch libusb via libusb-cmake
FetchContent_Declare(libusb_cmake
    GIT_REPOSITORY https://github.com/libusb/libusb-cmake.git
    GIT_TAG        main
)

FetchContent_MakeAvailable(libusb_cmake)

# Sources
add_library(usb libusb/core.c)

# Link to the target provided by libusb-cmake (usually usb-1.0)
target_link_libraries(usb PRIVATE usb-1.0)

# API & platform defines
if(WIN32)
    target_compile_definitions(usb PRIVATE
        API_EXPORTED=__declspec(dllexport)
        BUILDING_LIBUSB_COMPAT=1
        _CRT_SECURE_NO_WARNINGS=1
        _WIN32_WINNT=0x0600
    )
    if(MSVC)
        set_target_properties(usb PROPERTIES PREFIX "lib")
    endif()
    target_link_libraries(usb PRIVATE kernel32 user32)
else()
    target_compile_definitions(usb PRIVATE
        API_EXPORTED=__attribute__((visibility("default")))
    )
endif()

# Generated headers
set(GENERATED_CONFIG_DIR "${CMAKE_CURRENT_BINARY_DIR}/compat_config")
file(MAKE_DIRECTORY "${GENERATED_CONFIG_DIR}")

file(WRITE "${GENERATED_CONFIG_DIR}/config.h" "
#ifndef CONFIG_H
#define CONFIG_H
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#if defined(_WIN32) || defined(__MINGW32__)
#  define HAVE_WINDOWS_H 1
#  define HAVE_UNISTD_H 0
#else
#  define HAVE_UNISTD_H 1
#endif
#endif
")

if(WIN32)
    file(WRITE "${GENERATED_CONFIG_DIR}/unistd.h" "
#ifndef UNISTD_H_SHIM
#define UNISTD_H_SHIM
#include <io.h>
#include <process.h>
#include <windows.h>
#define sleep(x) Sleep((x)*1000)
#endif
")
endif()

target_include_directories(usb
    PRIVATE
        ${GENERATED_CONFIG_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/libusb>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

if(MSVC)
    target_compile_options(usb PRIVATE /W3 /wd4244)
elseif(CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(usb PRIVATE -fvisibility=hidden -Wno-pointer-sign -Wall -Wextra)
endif()

set_target_properties(usb PROPERTIES
    OUTPUT_NAME usb
    VERSION 0.4.4
    SOVERSION 4
)

if(ENABLE_EXAMPLES)
    add_executable(lsusb examples/lsusb.c)
    target_link_libraries(lsusb PRIVATE usb)
endif()

# Installation
install(TARGETS usb
    EXPORT libusb-compat-targets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES libusb/usb.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/libusb)

# pkg-config
set(prefix ${CMAKE_INSTALL_PREFIX})
set(exec_prefix \${prefix})
set(libdir \${exec_prefix}/${CMAKE_INSTALL_LIBDIR})
set(includedir \${prefix}/${CMAKE_INSTALL_INCLUDEDIR})
set(VERSION ${PROJECT_VERSION})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libusb.pc.in
               ${CMAKE_CURRENT_BINARY_DIR}/libusb.pc @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libusb.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)

# CMake package
install(EXPORT libusb-compat-targets
    FILE libusb-compat-config.cmake
    NAMESPACE libusb::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libusb-compat
)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/libusb-compat-config-version.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libusb-compat-config-version.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libusb-compat
)
