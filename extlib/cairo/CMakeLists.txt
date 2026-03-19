project(cairo C)
cmake_minimum_required(VERSION 3.18...3.25)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH}
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/")

include(CheckTypeSize)
include(CheckInline)
include(CheckIncludeFile)

# Versioning
file(READ src/cairo-version.h cairo_version_h)
string(REGEX REPLACE ".*#define CAIRO_VERSION_MAJOR ([0-9]+)\n.*" "\\1"
                     CAIRO_VERSION_MAJOR ${cairo_version_h})
string(REGEX REPLACE ".*#define CAIRO_VERSION_MINOR ([0-9]+)\n.*" "\\1"
                     CAIRO_VERSION_MINOR ${cairo_version_h})
string(REGEX REPLACE ".*#define CAIRO_VERSION_MICRO ([0-9]+)\n.*" "\\1"
                     CAIRO_VERSION_MICRO ${cairo_version_h})
set(CAIRO_VERSION "${CAIRO_VERSION_MAJOR}.${CAIRO_VERSION_MINOR}.${CAIRO_VERSION_MICRO}")
message(STATUS "Building cairo version ${CAIRO_VERSION}")

# Configuration
include_directories(
    ${CMAKE_CURRENT_BINARY_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

if(CMAKE_COMPILER_IS_GNUCC)
    set(COMMON_WARNINGS "-Wall -Wextra \
        -Wmissing-declarations -Werror-implicit-function-declaration \
        -Wpointer-arith -Wwrite-strings -Wsign-compare -Wpacked \
        -Wswitch-enum -Wmissing-format-attribute -Wvolatile-register-var \
        -Wstrict-aliasing=2 -Winit-self -Wunsafe-loop-optimizations \
        -Wno-missing-field-initializers -Wno-unused-parameter \
        -Wno-attributes -Wno-long-long -Winline -Wno-unused-but-set-variable")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${COMMON_WARNINGS} -Wold-style-definition \
        -Wdeclaration-after-statement -Wstrict-prototypes \
        -Wmissing-prototypes -Wbad-function-cast -Wnested-externs")
    add_compile_options(-fno-strict-aliasing -fno-common)
endif()

set(WORDS_BIGENDIAN ${CMAKE_WORDS_BIGENDIAN})
check_inline()

check_type_size("void *" SIZEOF_VOID_P)
check_type_size("int" SIZEOF_INT)
check_type_size("long" SIZEOF_LONG)
check_type_size("long long" SIZEOF_LONG_LONG)
check_type_size("size_t" SIZEOF_SIZE_T)

find_library(LIBM_LIBRARY m)
if(LIBM_LIBRARY)
    set(CMAKE_REQUIRED_LIBRARIES ${LIBM_LIBRARY})
endif()

check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(inttypes.h HAVE_INTTYPES_H)
check_include_file(sys/int_types.h HAVE_SYS_INT_TYPES_H)

check_type_size(uint64_t HAVE_UINT64_T)
check_type_size(uint128_t HAVE_UINT128_T)
check_type_size(__uint128_t HAVE___UINT128_T)

find_package(Threads)
set(CAIRO_HAS_PTHREAD ${CMAKE_USE_PTHREADS_INIT})
set(CAIRO_HAS_REAL_PTHREAD ${HAVE_PTHREADS})
link_libraries(${CMAKE_THREAD_LIBS_INIT})

# Dependencies
if(NOT PIXMAN_FOUND)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(PIXMAN REQUIRED "pixman-1 >= 0.30.0")
endif()

include_directories(
    ${PIXMAN_INCLUDE_DIRS})

link_directories(
    ${PIXMAN_LIBRARY_DIRS})

link_libraries(
    ${PIXMAN_LIBRARIES})

# Configuration files
add_definitions(-DHAVE_CONFIG_H)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/config.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/src/config.h)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/cairo-features.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/src/cairo-features.h)

add_subdirectory(src)
