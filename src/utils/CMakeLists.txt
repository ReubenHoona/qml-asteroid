set(SRC
	src/utils_plugin.cpp
	src/devicespecs.cpp
	src/fileinfo.cpp
	src/bluetoothstatus.cpp
	src/wallclock.cpp
	src/dateformat.cpp)
set(HEADERS
	src/utils_plugin.h
	src/devicespecs.h
	src/fileinfo.h
	src/bluetoothstatus.h
	src/wallclock.h
	src/dateformat.h)

add_library(asteroidutilsplugin ${SRC} ${HEADERS})

# DateFormat: ICU skeleton patterns and ranges, as stock Android
# (DateFormat.getBestDateTimePattern, DateUtils.formatDateRange)
find_package(PkgConfig REQUIRED)
pkg_check_modules(ICU REQUIRED IMPORTED_TARGET icu-i18n icu-uc)

target_link_libraries(asteroidutilsplugin
	Qt::DBus
	Qt::Qml
	Qt::Quick
	PkgConfig::ICU)

install(TARGETS asteroidutilsplugin
	DESTINATION ${KDE_INSTALL_QMLDIR}/org/asteroid/utils)
install(FILES qmldir
	DESTINATION ${KDE_INSTALL_QMLDIR}/org/asteroid/utils)
