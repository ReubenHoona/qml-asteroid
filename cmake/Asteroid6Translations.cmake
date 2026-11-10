function(BUILD_TRANSLATIONS directory)
	if(TARGET build-translations)
		message(WARNING "The build_translations function was already called")
		return()
	endif()

	find_package(Qt6LinguistTools REQUIRED)

	file(GLOB LANGUAGE_FILES_TS ${directory}/*.ts)
	#set_source_files_properties(${LANGUAGE_FILES_TS} PROPERTIES OUTPUT_LOCATION "i18n")
	qt6_add_translation(LANGUAGE_FILES_QM ${LANGUAGE_FILES_TS} OPTIONS "-idbased")

	# The English catalog <project>.en.qm, made from the //% source texts
	# of the sources (directories in ARGN, "src" by default), unless the
	# project keeps its own <project>.en.ts. AsteroidApp installs it before
	# the locale's catalog, so an id a language has not translated shows
	# English instead of the raw id (stock apps show complete text in every
	# language). lrelease writes the source text for unfinished messages.
	if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${directory}/${PROJECT_NAME}.en.ts)
		set(source_dirs ${ARGN})
		if(NOT source_dirs)
			set(source_dirs src)
		endif()
		set(EN_SOURCES "")
		foreach(dir ${source_dirs})
			file(GLOB_RECURSE dir_sources CONFIGURE_DEPENDS
				${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.qml
				${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.js
				${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.cpp
				${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.h)
			list(APPEND EN_SOURCES ${dir_sources})
		endforeach()
		set(EN_TS ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.en.ts)
		set(EN_QM ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.en.qm)
		add_custom_command(OUTPUT ${EN_QM}
			COMMAND Qt6::lupdate -silent -locations none -source-language en -target-language en ${EN_SOURCES} -ts ${EN_TS}
			COMMAND Qt6::lrelease -silent -idbased ${EN_TS} -qm ${EN_QM}
			DEPENDS ${EN_SOURCES}
			COMMENT "Building the English fallback catalog ${PROJECT_NAME}.en.qm"
			VERBATIM)
		list(APPEND LANGUAGE_FILES_QM ${EN_QM})
	endif()
	add_custom_target(build-translations ALL
		COMMENT "Building translations in ${director}..."
		DEPENDS ${LANGUAGE_FILES_QM})

	install(FILES ${LANGUAGE_FILES_QM}
		DESTINATION ${CMAKE_INSTALL_DATADIR}/translations)
endfunction()

function(GENERATE_DESKTOP src_directory application_name)
	find_program(generate_desktop_executable
		NAMES asteroid-generate-desktop)

	set(OUTPUT_DESKTOP_FILE ${CMAKE_BINARY_DIR}/${application_name}.desktop)
	execute_process(
		COMMAND ${generate_desktop_executable} ${src_directory} ${application_name} ${OUTPUT_DESKTOP_FILE})

	install(FILES ${OUTPUT_DESKTOP_FILE}
		DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
endfunction()
