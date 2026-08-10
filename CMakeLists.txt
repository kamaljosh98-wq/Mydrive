##########################################################################
# CMakeLists.txt - Root build configuration for thumbnail-camera
#
# Project: RDK Thumbnail Camera
# Purpose: Top-level build configuration for RDK camera thumbnail generation,
#          smart thumbnail processing, and event notification services.
#
# Components:
#   - imagetools: Shared image processing library
#   - src: Thumbnail upload daemon (thumbnail_upload)
#   - smart_thumbnail: AI-based smart thumbnail generation daemon
#   - smart_thumbnail_cvr_lite: Lightweight CVR thumbnail daemon
#   - event_notifications: Event notification service daemon
#
# Requirements:
#   - CMake 3.5.1+, RDK build environment, Yocto cross-compile toolchain
#   - OpenCV 3.x/4.x, RDKLogger, RTMessage (required)
#   - FFMPEG, RBUS, ConfigMgr, HTTPClient (optional, configurable)
##########################################################################

cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)

# Project declaration with version
project(thumbnail-camera
    VERSION 1.0.0
    LANGUAGES C CXX
)

# Option: aggregated feature summary across all targets
option(THUMBNAIL_GLOBAL_SUMMARY "Print aggregated feature summary after configuring all targets" ON)
# Verbose target summaries (per-target option lists)
option(THUMBNAIL_VERBOSE_SUMMARY "Print per-target feature option summaries" OFF)

# ======================================================
# Build Configuration & Validation
# ======================================================

# Require out-of-source builds
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR
        "In-source builds are not allowed. Please create a separate build directory:\n"
        "  mkdir build && cd build && cmake ..\n")
endif()

# Set default build type
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo")
endif()

# ======================================================
# Project Configuration
# ======================================================

# Set module path and include common configurations
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake-modules ${CMAKE_MODULE_PATH})
include(ThumbnailPaths)     # Path configuration (Yocto/non-Yocto detection)
include(ThumbnailOptions)   # Centralized option management
include(ThumbnailTargets)   # Target creation helpers (must be before subdirectories)

# Generate centralized version header
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/version.h.in
               ${CMAKE_CURRENT_BINARY_DIR}/version/include/thumbnail-camera/version.h
               @ONLY)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/version/include)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/version/include/thumbnail-camera/version.h
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/thumbnail-camera)

# Print configuration summary
print_thumbnail_config()

# ======================================================
# Global Settings
# ======================================================

# Set consistent C++ standard across all targets
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Enable position independent code for all targets
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ======================================================
# Subdirectories
# ======================================================

# Build imagetools library first (dependency for thumbnail_upload on XHB1)
add_subdirectory(imagetools)

# Build all thumbnail components
add_subdirectory(src)                      # Upload service
add_subdirectory(smart_thumbnail)          # Smart thumbnail daemon
add_subdirectory(smart_thumbnail_cvr_lite) # CVR lite daemon
add_subdirectory(event_notifications)      # Event service

# ======================================================
# Aggregated Feature Summary
# ======================================================
if(THUMBNAIL_GLOBAL_SUMMARY)
    message(STATUS "=== Aggregated Thumbnail Feature Summary ===")
    # Target list mapped to feature prefix list (parallel arrays)
    set(_AGG_TARGETS
        thumbnail_upload
        smartthumbnail
        smartthumbnail_cvr_lite
        eventnotification
        normal_thumbnail
    )
    set(_AGG_PREFIXES
        THUMB_UPLOAD_FEATURES
        SMART_THUMB_FEATURES
        SMART_THUMB_CVR_FEATURES
        EVENT_NOTIF_FEATURES
        NORMAL_THUMB_FEATURES
    )
    list(LENGTH _AGG_TARGETS _agg_len)
    math(EXPR _last "${_agg_len} - 1")
    foreach(idx RANGE 0 ${_last})
        list(GET _AGG_TARGETS ${idx} _tgt)
        list(GET _AGG_PREFIXES ${idx} _prefix)
        # Handle test harness alternative name for eventnotification
        if(NOT TARGET ${_tgt})
            if(_tgt STREQUAL "eventnotification" AND TARGET eventnotification_TH)
                set(_tgt eventnotification_TH)
            else()
                continue()
            endif()
        endif()
        # Fetch defined options variable
        if(DEFINED ${_prefix}_DEFINED_OPTIONS)
            message(STATUS "-- ${_tgt} (${_prefix}) --")
            foreach(opt IN LISTS ${_prefix}_DEFINED_OPTIONS)
                if(DEFINED ${opt})
                    message(STATUS "   ${opt}: ${${opt}}")
                else()
                    message(STATUS "   ${opt}: (undefined)")
                endif()
            endforeach()
        else()
            message(STATUS "-- ${_tgt}: (no collected options) --")
        endif()
    endforeach()
    message(STATUS "=============================================")
endif()

# ======================================================
# Installation & Packaging
# ======================================================

# Summary at end of configuration
message(STATUS "Build configuration complete. Use 'make' to build all targets.")
