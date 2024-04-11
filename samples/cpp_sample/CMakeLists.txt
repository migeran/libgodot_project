cmake_minimum_required(VERSION 3.2)

project(sample)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -g")

set(GODOT_CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../godot-cpp)
set(LIBGODOT_BUILD_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../build)

add_subdirectory(${GODOT_CPP_DIR} ${GODOT_CPP_DIR}/build)

set(SOURCES src/main.cpp)

add_executable(${PROJECT_NAME} ${SOURCES})
target_include_directories(${PROJECT_NAME} SYSTEM
	PRIVATE
        ${GODOT_CPP_DIR}/include
		${GODOT_CPP_DIR}/gen/include
		${GODOT_CPP_DIR}/gdextension
)
target_link_libraries(${PROJECT_NAME} dl godot-cpp Threads::Threads)
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy
                       ${LIBGODOT_BUILD_DIR}/libgodot${CMAKE_SHARED_LIBRARY_SUFFIX}
                       ${CMAKE_BINARY_DIR}
                   COMMENT "Copying ${LIBGODOT_BUILD_DIR}/libgodot.${CMAKE_SHARED_LIBRARY_SUFFIX} to '${CMAKE_BINARY_DIR}'")
