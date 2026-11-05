@echo off

del *.beam
elixirc Orquestador.ex Util Robot Planificador Archivos
