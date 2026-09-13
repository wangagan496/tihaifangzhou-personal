cmake_minimum_required(VERSION 3.5.0)
project(audio_pcm)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_library(audiopcm SHARED audio_pcm.cpp)
target_link_libraries(audiopcm PUBLIC libace_napi.z.so libnative_media_core.so
  libnative_media_codecbase.so libnative_media_avsource.so libnative_media_avdemuxer.so libnative_media_acodec.so)
add_executable(pcm_resampler_test EXCLUDE_FROM_ALL tests/pcm_resampler_test.cpp)
target_include_directories(pcm_resampler_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
