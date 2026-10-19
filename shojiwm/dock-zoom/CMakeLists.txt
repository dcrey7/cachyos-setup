# KDE's taskbar (Icons-only Task Manager) from plasma-desktop, built on its
# own, with a Mac-style hover zoom added. See README.md.
cmake_minimum_required(VERSION 3.16)
project(dock-zoom)

set(QT_MAJOR_VERSION 6)
set(QT_DEFAULT_MAJOR_VERSION 6)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQtDeclareLoggingCategory)

# The plugin lands in <build>/bin/plasma/applets/.
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)
find_package(KF6 REQUIRED COMPONENTS Config I18n KIO Notifications Service WindowSystem)
find_package(Plasma REQUIRED)
find_package(PlasmaActivities REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
find_package(KSysGuard REQUIRED)
find_package(LibNotificationManager REQUIRED)

add_subdirectory(taskmanager)
