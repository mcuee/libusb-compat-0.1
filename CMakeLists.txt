cmake_minimum_required(VERSION 3.16)

# Extract version numbers dynamically from configure.ac (similar to reading version.h in libusb-cmake)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/configure.ac" CONFIGURE_AC_DATA)
string(REGEX MATCH "m4_define\\(\\[libusb_compat_version_suffix\\], \\[([0-9]+)\\]\\)" _ ${CONFIGURE_AC_DATA})
set(VERSION_SUB ${CMAKE_MATCH_1})

# Fallback default if regex fails to parse legacy m4 macros cleanly
if(NOT VERSION_SUB)
    set(VERSION_SUB 9)
endif()

project(libusb-compat
    DESCRIPTION "A libusb-0.1 compatibility layer application wrapper on top of libusb-1.0"
    VERSION 0.1.${VERSION_SUB}
    LANGUAGES C
)

message(STATUS "Building libusb-compat v${PROJECT_VERSION} for: ${CMAKE_SYSTEM_NAME}")

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(CheckCCompilerFlag)

# Build configurations
option(BUILD_SHARED_LIBS "Build shared libraries for libusb-compat" ON)
option(ENABLE_EXAMPLES "Build example applications" ON)

# Find backend dependency via pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBUSB1 REQUIRED IMPORTED_TARGET libusb-1.0>=1.0.0)

# Target Definition
add_library(usb libusb/core.c)
target_link_libraries(usb PRIVATE PkgConfig::LIBUSB1)

# Include paths mirroring libusb-cmake structure
target_include_directories(usb
    PRIVATE
        ${CMAKE_CURRENT_BINARY_DIR}
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/libusb>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Match Symbol Visibilities & Preprocessor Flags
if(CMAKE_C_COMPILER_ID MATCHES "Clang" OR CMAKE_C_COMPILER_ID STREQUAL "GNU")
    check_c_compiler_flag("-fvisibility=hidden" HAVE_VISIBILITY)
    if(HAVE_VISIBILITY)
        target_compile_options(usb PRIVATE "-fvisibility=hidden")
    endif()
    target_compile_options(usb PRIVATE "-Wall" "-Wextra")
elseif(MSVC)
    target_compile_options(usb PRIVATE "/W3")
    target_compile_definitions(usb PRIVATE _CRT_SECURE_NO_WARNINGS=1)
endif()

# Autotools matching empty macro stub for platforms not using .def definitions
target_compile_definitions(usb PRIVATE API_EXPORTED=)

# Platform OS Specific Tweaks
if(WIN32)
    # Mirror matching system dependencies logic if building targeting Windows systems
    target_link_libraries(usb PRIVATE kernel32 user32)
    
    # Handle API calling convention decoration properties
    if(MSVC)
        # Ensure library target name matches expectations (outputs libusb.lib / libusb.dll)
        set_target_properties(usb PROPERTIES PREFIX "lib")
    endif()
endif()

# Match exact library file properties for libusb-0.1 binary compatibility
set_target_properties(usb PROPERTIES
    OUTPUT_NAME usb
    VERSION 0.4.4
    SOVERSION 4
)

# Examples
if(ENABLE_EXAMPLES)
    add_executable(lsusb examples/lsusb.c)
    target_link_libraries(lsusb PRIVATE usb)
endif()

# Installation Layout
install(TARGETS usb
    EXPORT libusb-compat-targets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES libusb/usb.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# Config generation mirroring libusb-cmake's install export loop
set(prefix ${CMAKE_INSTALL_PREFIX})
set(exec_prefix \${prefix})
set(libdir \${exec_prefix}/${CMAKE_INSTALL_LIBDIR})
set(includedir \${prefix}/${CMAKE_INSTALL_INCLUDEDIR})
set(VERSION ${PROJECT_VERSION})

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/libusb.pc.in
    ${CMAKE_CURRENT_BINARY_DIR}/libusb.pc
    @ONLY
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libusb.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)

# Export modern CMake targets for downstream consumers
install(EXPORT libusb-compat-targets
    FILE libusb-compat-config.cmake
    NAMESPACE libusb::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libusb-compat
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/libusb-compat-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/libusb-compat-config-version.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/libusb-compat
)
