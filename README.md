# programacion3-parcial2

Solución en Elixir para el Parcial 2 de Programación III (G2D - Universidad del Quindío). Implementación de algoritmos de backtracking, streams infinitos, structs y procesamiento perezoso para el Robot de Rescate y Planificador de Tareas.

Problemas elegidos: 1 (robot de rescate) y 2 (planificación de tareas).

## Ejecución

Se necesita Elixir instalado. Desde esta carpeta:

```
.\compilar.bat
elixir rescate.exs
elixir tareas.exs
```

Fuera de Windows, compilar con `elixirc *.ex`.

- `rescate.exs` lee `edificio.txt`, `terrenos.csv` y `bateria.txt`.
- `tareas.exs` lee `tareas.csv`.
- Las salidas se escriben en esta misma carpeta.

Si hay errores en los datos, el programa los reporta en `validacion_edificio.txt` o
`validacion_tareas.txt` y no ejecuta la búsqueda.

## Pruebas

```
.\compilar.bat
elixir pruebas_validadores.exs
elixir pruebas_integracion.exs
```

Cada prueba muestra `OK` o `FALLO` y al final el total. Las de integración escriben las salidas
de cada caso en su propia carpeta de `fixtures/`.

| Carpeta en `fixtures/` | Tipo | Resultado esperado |
|---|---|---|
| `rescate/valido` | Válido | Ejemplo del enunciado, con recorridos |
| `rescate/invalido` | Inválido | 9 errores y no se busca |
| `rescate/falta_archivo` | Inválido | Aviso de que falta `bateria.txt` |
| `rescate/limite_minimo` | Límite | S y M vecinas, con la energía justa |
| `rescate/limite_sin_recorrido` | Límite | La meta no alcanza y se omite la enumeración |
| `tareas/valido` | Válido | Ejemplo del enunciado: 2 planes, penalizaciones 4 y 6 |
| `tareas/invalido` | Inválido | 8 errores y no se enumera |
| `tareas/ciclos` | Inválido | Exactamente 5 ciclos |
| `tareas/limite_una` | Límite | Una tarea con plazo 0: un plan |
| `tareas/vacio` | Límite | Proyecto vacío, sin enumerar |

## Archivos de Rol 2

| Archivo | Contenido |
|---|---|
| `ValidadorEdificio.ex` | `validar/2` y `validar_bateria/1` |
| `ValidadorTareas.ex` | `validar/1`, incluida la búsqueda de ciclos |
| `Orquestador.ex` | Flujo de los dos problemas |
| `rescate.exs`, `tareas.exs` | Puntos de entrada |
| `Terreno.ex`, `Tarea.ex` | Structs definidos por el enunciado |
| `Util2.ex` | Utilidades del curso |

## Datos que esperan los validadores

Los validadores son recursivos con head/tail, sin `Enum` ni `Stream`. No escriben archivos:
devuelven una lista de errores `{linea_o_coordenada, mensaje}`. La ubicación es `:general`
cuando el error no tiene línea ni coordenada, como una cuadrícula vacía.

```
filas    = [{linea, ["X", "S", ...]}, ...]
terrenos = [{linea, %Terreno{}}, ...]
bateria  = [{linea, "10"}, ...]
tareas   = [{linea, %Tarea{}}, ...]
```

- `linea` es el número de línea física del archivo, contando comentarios y líneas en blanco.
- `dependencias` es una lista de IDs, vacía cuando el archivo trae `-`.
- Si `duracion`, `plazo` o `costo` no se pueden convertir a entero, se deja el texto original
  para que el validador lo reporte. Así la tarea sigue existiendo y las que dependen de ella no
  reportan un error falso.
- Una línea con un número incorrecto de campos es un error de lectura de Rol 3. Un ID con `;`
  cae en este caso, porque `A;B;3;4;-` se parte en 5 campos.

Las firmas que `Orquestador.ex` espera de Rol 1 y Rol 3 están listadas al inicio de ese archivo.

## Límite conocido

La búsqueda de ciclos recorre todos los caminos simples. Con 22 tareas donde cada una depende de
todas las anteriores tarda cerca de 0,6 s, y ese tiempo se duplica con cada tarea adicional de
ese tipo.
