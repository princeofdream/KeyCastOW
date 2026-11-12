cmake_minimum_required(VERSION 3.20)

project(KeyCastOW LANGUAGES C CXX RC)

# Win32 GUI application: keystroke visualizer
add_executable(keycastow WIN32
    keycast.cpp
    keylog.cpp
    keycastow.rc
    keycastow.exe.manifest
)

target_compile_definitions(keycastow PRIVATE
    WIN32
    _WINDOWS
    UNICODE
    _UNICODE
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:NDEBUG>
)

target_link_libraries(keycastow PRIVATE
    gdiplus
    comctl32
)

# Match the previous vcxproj: Release uses the static CRT (/MT),
# Debug uses the debug dynamic CRT (/MDd).
set_target_properties(keycastow PROPERTIES
    MSVC_RUNTIME_LIBRARY "$<IF:$<CONFIG:Debug>,MultiThreadedDebugDLL,MultiThreaded>"
)

# Release: whole-program optimization (/GL + /LTCG)
set_property(TARGET keycastow PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)

if(MSVC)
    target_link_options(keycastow PRIVATE
        "/SUBSYSTEM:WINDOWS"
    )
endif()

set_target_properties(keycastow PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/output/target/Debug"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/output/target/Release"
)
