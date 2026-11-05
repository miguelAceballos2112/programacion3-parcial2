@echo off

del *.beam 2>nul
elixirc Orquestador.ex Util Robot Planificador Archivos
