Запуск со статической компоновкой:
odin run .\launcher.odin -file -debug

Запуск через DLL (сначала положить raylib.dll в корень):
odin run .\launcher_dynlib.odin -file -define:RAYLIB_SHARED=true -debug

При запуске DLL:
- F2 --- загрузить DLL
- F3 --- выгрузить DLL
- F5 --- выгрузить DLL, перекомпилировать, и снова загрузить
