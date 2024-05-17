set BASE_DIR=%~dp0

cd %BASE_DIR%
mkdir build

cd godot

call scons platform=windows arch=x86_64 verbose=yes msvc=yes dev_build=yes debug_symbols=yes
call scons platform=windows target=template_debug arch=x86_64 verbose=yes msvc=yes library_type=shared_library dev_build=yes debug_symbols=yes

copy /y bin\godot.windows.template_debug.dev.x86_64.dll ..\build\libgodot.dll

start /wait bin\godot.windows.editor.dev.x86_64.exe --dump-extension-api
copy /y extension_api.json ..\build\extension_api.json
copy /y ..\build\extension_api.json ..\godot-cpp\gdextension
copy /y core\extension\gdextension_interface.h ..\godot-cpp\gdextension

cd ..
