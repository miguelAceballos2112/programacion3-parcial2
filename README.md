# Parcial 2 - Programación III (Elixir)

Problemas elegidos: **1** (robot de rescate) y **2** (planificación de tareas).

Este repositorio contiene, por ahora, la parte del **Rol 3**: entrada de datos con
Streams y Structs, y generación de archivos y SVG progresivos.

## Ejecutar las pruebas

```bash
mix test
```

## Documentación

El código sigue las convenciones de documentación de Elixir:

* `@moduledoc` en cada módulo y `@doc` en cada función pública, con Markdown y secciones `##`.
* `@typedoc` y `@spec` para los tipos y las firmas públicas.
* Ejemplos `iex>` en las funciones puras. Se ejecutan como pruebas (doctests) desde
  `test/doctest_test.exs`, así que `mix test` también comprueba la documentación.

Para generar el sitio HTML con ExDoc:

```bash
mix deps.get   # solo la primera vez (descarga ex_doc)
mix docs
open doc/index.html
```

La carpeta `doc/` se genera y no se sube al repositorio. ExDoc solo se carga en
desarrollo, por lo que `mix test` funciona aunque no ejecutes `mix deps.get`.

## Módulos del Rol 3

| Módulo   | Archivo           | Responsabilidad |
|----------|-------------------|-----------------|
| `Terreno`, `Recorrido`, `Tarea`, `Plan` | `lib/structs/` | Structs del enunciado (`Plan.duracion_total/1`, `Recorrido.movimientos/1`) |
| `Lector` | `lib/lector.ex`   | `File.stream!/1`, filtrado perezoso de vacíos y `#`, línea física, archivos faltantes |
| `Salida` | `lib/salida.ex`   | CSV (`;`), resúmenes (archivo + pantalla), `expansion_energia.txt`, `validacion_*.txt` |
| `Svg`    | `lib/svg.ex`      | `ruta_optima.svg` (casillas 40x40) y `mejor_plan.svg` (Gantt), escritura por fragmentos |

## Contrato con los otros roles

### Lectura (`Lector`)

```elixir
{:ok, registros, errores} = Lector.leer_terrenos("terrenos.csv")  # [{linea, %Terreno{}}]
{:ok, filas, errores}     = Lector.leer_edificio("edificio.txt")  # [{linea, ["X", "S", ...]}]
{:ok, [{1, "10"}], []}    = Lector.leer_bateria("bateria.txt")    # texto crudo
{:ok, registros, errores} = Lector.leer_tareas("tareas.csv")      # [{linea, %Tarea{}}]
{:error, :archivo_no_encontrado, ruta}                            # si falta el archivo
```

* `errores` es `[{linea, mensaje}]` (registros que no se pudieron convertir). Se
  pasan junto con los del validador a `Salida.escribir_validacion/3`.
* El lector **no** aplica reglas de negocio: duplicados, rectangularidad, bordes, ciclos,
  duración > 0, plazo >= 0, etc. son del validador (Rol 2), que usa estas líneas.
* Tras validar: `Lector.construir_mapa(filas)` y `Lector.indice_terrenos(terrenos)`.
  El mapa es `%{celdas: %{{f, c} => simbolo}, filas:, columnas:, inicio:, meta:}`.

### Escritura progresiva (Rol 1 -> Rol 3)

Rol 1 entrega cada recorrido o plan a una función receptora con acumulador:

```elixir
dispositivo = Salida.abrir_recorridos("salida/recorridos_rescate.csv")

receptor =
  Salida.receptor_recorridos(dispositivo, fn id, recorrido, estadisticas ->
    Robot.Estadisticas.actualizar(estadisticas, id, recorrido)
  end)

{total, estadisticas} = Robot.buscar_recorridos(mapa, indice, bateria, {0, Robot.Estadisticas.nuevo()}, receptor)
Salida.cerrar(dispositivo)
```

El acumulador es `{cantidad_escrita, estado}`. Lo mismo aplica a
`Salida.abrir_planes/1` y `Salida.receptor_planes/2`.

### Datos que esperan los resúmenes

* `Salida.resumen_rescate/3`: `%{total:, bateria:, menos_movimientos: [{id, %Recorrido{}}], menor_energia: [{id, %Recorrido{}}]}`
* `Salida.resumen_tareas/3`: `%{total:, vacio:, penalizacion_minima:, mejores: [{id, %Plan{}}]}`
* `Salida.escribir_expansion/3`: lista de mapas `%{{f, c} => costo}` y el índice de estabilización
* `%Plan{finalizaciones}` es una lista de `{id, inicio, fin}` en orden de ejecución
* `Svg.escribir_ruta/4` recibe el mapa, el índice de terrenos y `%Recorrido{}` o `nil`
* `Svg.escribir_gantt/3` recibe `%Plan{}` o `nil` y la lista de `%Tarea{}` (para los plazos)

## Decisiones de diseño

* Los colores del SVG salen de `terrenos.csv` (no transitables en gris oscuro, el resto
  por orden de símbolo); no hay símbolos fijos en el código de dibujo.
* Posiciones en el CSV: `(f,c)->(f,c)`, para no chocar con el separador `;`.
* Orden de planes en `planes.csv`: IDs separados por ` → `.
* Cada archivo de salida se reemplaza; las carpetas faltantes se crean.
