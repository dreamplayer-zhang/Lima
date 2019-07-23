###########################################################################
# This file is part of LImA, a Library for Image Acquisition
#
#  Copyright (C) : 2009-2017
#  European Synchrotron Radiation Facility
#  CS40220 38043 Grenoble Cedex 9
#  FRANCE
#
#  Contact: lima@esrf.fr
#
#  This is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This software is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, see <http://www.gnu.org/licenses/>.
############################################################################

# DEPRECATED: this function set the so vertsion according to
function(limatools_set_library_soversion lib_name version_file)
    message(AUTHOR_WARNING "limatools_set_library_soversion is DEPRECATED: check the camera plugin template \
        to update your CMakeFile to use git tags instead.")

    file(STRINGS ${version_file}  version)
    # for lib version as 1.2.3 soverion is fixed to 1.2
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)" soversion "${version}")

    set_target_properties(${lib_name} PROPERTIES VERSION "${version}" SOVERSION "${soversion}")

endfunction()

# this function runs camera's c++ tests
function(limatools_run_camera_tests test_src camera)
  if(${ARGC} GREATER 2)
    set(test_arg ${ARGV2} ${ARGV3} ${ARGV4} ${ARGV5} ${ARGV6})
  endif()
  foreach(file ${test_src})
    add_executable(${file} "${file}.cpp")
    target_link_libraries(${file} limacore)
    if (NOT ${camera} STREQUAL "core")
      target_link_libraries(${file} ${camera})
    endif()
    add_test(NAME ${file} COMMAND ${file} ${test_arg})
    if(WIN32)
      # Add the dlls to the %PATH%
      string(REPLACE ";" "\;" ESCAPED_PATH "$ENV{PATH}")
      set_tests_properties(${file} PROPERTIES ENVIRONMENT "PATH=${ESCAPED_PATH}\;$<SHELL_PATH:$<TARGET_FILE_DIR:limacore>>\;$<SHELL_PATH:$<TARGET_FILE_DIR:processlib>>\;$<SHELL_PATH:$<TARGET_FILE_DIR:lima${camera}>>")
    endif()
  endforeach(file)

endfunction()

# this function runs camera's python tests
function(limatools_run_camera_python_tests test_src camera)

  foreach(file ${test_src})
    add_test(NAME ${file}
      COMMAND ${PYTHON_EXECUTABLE}
        ${CMAKE_CURRENT_SOURCE_DIR}/${file}.py)
    if(WIN32)
        # Add the dlls to the %PATH%
        string(REPLACE ";" "\;" ESCAPED_PATH "$ENV{PATH}")
        set_tests_properties(${file} PROPERTIES ENVIRONMENT "PATH=${ESCAPED_PATH}\;$<SHELL_PATH:$<TARGET_FILE_DIR:limacore>>\;$<SHELL_PATH:$<TARGET_FILE_DIR:processlib>>\;$<SHELL_PATH:$<TARGET_FILE_DIR:lima${camera}>>;PYTHONPATH=$<SHELL_PATH:${CMAKE_BINARY_DIR}/python>\;$<SHELL_PATH:$<TARGET_FILE_DIR:python_module_limacore>>\;$<SHELL_PATH:$<TARGET_FILE_DIR:python_module_processlib>>\;$<SHELL_PATH:$<TARGET_FILE_DIR:python_module_lima${camera}>>")
    else()
        set_tests_properties(${file} PROPERTIES ENVIRONMENT "PYTHONPATH=$<SHELL_PATH:${CMAKE_BINARY_DIR}/python>:$<SHELL_PATH:$<TARGET_FILE_DIR:python_module_limacore>>:$<SHELL_PATH:$<TARGET_FILE_DIR:python_module_processlib>>:$<SHELL_PATH:$<TARGET_FILE_DIR:python_module_lima${camera}>>")
    endif()
  endforeach(file)

endfunction()

# this function is used to build camera's python binding
function(limatools_run_sip_for_camera camera)

  set(MODULE_NAME lima${camera})

  # Add %Include directives for every source files
  set(INCLUDES)
  file(GLOB sipfiles RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}/sip" "${CMAKE_CURRENT_SOURCE_DIR}/sip/*.sip")
  foreach(sipfile ${sipfiles})
    set(INCLUDES "${INCLUDES} \n%Include ${sipfile}")
  endforeach()

  # Add %import directives for every source files
  set(sipfiles "limacore.sip" )
  list(APPEND sipfiles ${IMPORTS})
  set(IMPORTS)
  foreach(sipfile ${sipfiles})
    set(IMPORTS "${IMPORTS} \n%Import ${sipfile}")
  endforeach()

  # Uses INCLUDES and IMPORTS
  find_file(module_sip_file NAMES "limamodules.sip.in" PATHS ${LIMA_SIP_INCLUDE_DIRS} NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
  configure_file(${module_sip_file} sip/${MODULE_NAME}.sip)
  unset(module_sip_file CACHE)
  list(APPEND SIP_INCLUDE_DIRS
    ${LIMA_SIP_INCLUDE_DIRS}
    ${PROCESSLIB_SIP_INCLUDE_DIRS}
    "${CMAKE_CURRENT_SOURCE_DIR}/sip"
  )

  # If Lima is an imported target, set the SIP_DISABLE_FEATURES
  set(SIP_DISABLE_FEATURES ${LIMA_SIP_DISABLE_FEATURES})

  add_sip_python_module(${MODULE_NAME} ${CMAKE_CURRENT_BINARY_DIR}/sip/${MODULE_NAME}.sip TRUE)
  target_include_directories(python_module_${MODULE_NAME} PRIVATE
    ${PYTHON_INCLUDE_DIRS}
    ${NUMPY_INCLUDE_DIRS}
  )

  target_link_libraries(python_module_${MODULE_NAME} PUBLIC ${camera} limacore ${NUMPY_LIBRARIES})
endfunction()

# this macro is used to check python/sip to build python binding
macro (limatools_check_python_and_sip)
  if(${CMAKE_VERSION} VERSION_LESS "3.12.0")
    find_package(PythonInterp REQUIRED)
    find_package(PythonLibs REQUIRED)
    # python site-packages folder
    execute_process(
      COMMAND ${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_lib; print (get_python_lib())"
      OUTPUT_VARIABLE _PYTHON_SITE_PACKAGES_DIR
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    set(PYTHON_SITE_PACKAGES_DIR ${_PYTHON_SITE_PACKAGES_DIR} CACHE PATH "where should python modules be installed?")
  else()
    find_package(Python COMPONENTS Interpreter Development REQUIRED)
    # python site-packages folder
    set(PYTHON_SITE_PACKAGES_DIR ${Python_SITELIB} CACHE PATH "where should python modules be installed?")
    set(PYTHON_INCLUDE_DIRS ${Python_INCLUDE_DIRS})
  endif()

  # numpy required
  find_package(NumPy REQUIRED)

  # sip required and some options to be set
  find_package(SIP REQUIRED)

  include(SIPMacros)

  if(WIN32)
    set(SIP_TAGS WIN32_PLATFORM)
  elseif(UNIX)
    set(SIP_TAGS POSIX_PLATFORM)
  endif(WIN32)
  set(SIP_EXTRA_OPTIONS -e -g)

endmacro()

# This function installs the camera tango plugin to the python third-party directory
# it must be called from the camera tango/ sub-directory CMakeLists.txt file
# files is a string containing files separeted by space i.e:
# limatols_install_camera_tango("Basler.py Basler_sub.py" ON)
function(limatools_install_camera_tango files check_python)
  if (${check_python})
    if(${CMAKE_VERSION} VERSION_LESS "3.12.0")
      find_package(PythonInterp REQUIRED)
      find_package(PythonLibs REQUIRED)
      # python site-packages folder
      execute_process(
	COMMAND ${PYTHON_EXECUTABLE} -c "from distutils.sysconfig import get_python_lib; print (get_python_lib())"
	OUTPUT_VARIABLE _PYTHON_SITE_PACKAGES_DIR
	OUTPUT_STRIP_TRAILING_WHITESPACE
	)
      set(PYTHON_SITE_PACKAGES_DIR ${_PYTHON_SITE_PACKAGES_DIR} CACHE PATH "where should python modules be installed?")
    else()
      find_package(Python COMPONENTS Interpreter Development REQUIRED)
      # python site-packages folder
      set(PYTHON_SITE_PACKAGES_DIR ${Python_SITELIB} CACHE PATH "where should python modules be installed?")
    endif()
  endif()

  set(file_list ${files})
  separate_arguments(file_list)
  foreach(file ${file_list})
    install (
      FILES ${CMAKE_CURRENT_SOURCE_DIR}/${file}
      DESTINATION "${PYTHON_SITE_PACKAGES_DIR}/Lima/Server/camera"
      )
  endforeach()
endfunction()
