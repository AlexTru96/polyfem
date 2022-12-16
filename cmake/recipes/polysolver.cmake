# Polyfem Solvers
# License: MIT

if(TARGET polysolve)
    return()
endif()

message(STATUS "Third-party: creating target 'polysolve'")

include(FetchContent)
FetchContent_Declare(
    polysolve
    GIT_REPOSITORY https://github.com/AlexTru96/polysolve.git
    GIT_TAG 96bffb16be52da331e3a773d7c5235eaa29ff8e8
    GIT_SHALLOW FALSE
)
FetchContent_MakeAvailable(polysolve)
