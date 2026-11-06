# Parcial 2 – Programación III (Elixir)

Universidad del Quindío · Programa de Ingeniería de Sistemas y Computación
Docente: Julián Esteban Gutiérrez Posada · Grupo: G2D

Programación funcional con Elixir: recursividad, Streams y structs.

**URL del repositorio:** https://github.com/miguelAceballos2112/programacion3-parcial2.git

## Integrantes y roles

| Integrante | Rol | Responsabilidad |
|------------|-----|-----------------|
| Miguel Angel Ceballos Soler | Rol 1 | Algoritmos y Streams (`Robot`, `Planificador` y sus estadísticas) y pruebas ExUnit |
| Victor Manuel Bolaños Guzman | Rol 2 | Validación recursiva (`ValidadorEdificio`, `ValidadorTareas`) y `Orquestador` |
| Juan Jose Ramirez Londoño | Rol 3 | Entrada y salida (`Lector`, `Salida`, `Svg`) |

## Problemas elegidos

El grupo eligió la combinación válida **1 y 2**:

1. **Problema 1** – Robot de rescate con energía limitada y mapa SVG (structs y Stream infinito).
2. **Problema 2** – Planificación de tareas con dependencias y diagrama SVG (structs).

## Cómo ejecutar

Se necesita Elixir 1.14 o superior (`elixir --version`). Todos los comandos se ejecutan desde la
carpeta raíz del repositorio.

El proyecto usa Mix. La primera vez se descarga la dependencia de documentación:

```
mix deps.get
```

Después se ejecuta cada problema:

```
mix run rescate.exs
mix run tareas.exs
```

Si hay errores en los datos, el programa los reporta en el archivo de validación y no inicia la
búsqueda. Si falta un archivo requerido, muestra un aviso con su nombre.

También se puede ejecutar sin Mix, compilando con `.\compilar.bat` en Windows o con
`elixirc Orquestador.ex Util Robot Planificador Archivos` en otros sistemas, y luego con
`elixir rescate.exs` y `elixir tareas.exs`.

La documentación se genera con `mix docs` en la carpeta `doc/`.

## Archivos de entrada y salida

Las entradas se leen de la carpeta raíz y las salidas se escriben allí mismo.

| Problema | Entradas | Salidas |
|----------|----------|---------|
| 1 | `edificio.txt`, `terrenos.csv`, `bateria.txt` | `validacion_edificio.txt`, `expansion_energia.txt`, `recorridos_rescate.csv`, `resumen_rescate.txt`, `ruta_optima.svg` |
| 2 | `tareas.csv` | `validacion_tareas.txt`, `planes.csv`, `resumen_tareas.txt`, `mejor_plan.svg` |

## Pruebas

Las pruebas usan ExUnit y están en `Test/`:

```
mix test
```

`integracion_test.exs` ejecuta el programa completo con cada carpeta de `fixtures/` y deja allí sus
salidas. `svg_xml_test.exs` comprueba que los SVG sean XML bien formado y `doctest_test.exs` ejecuta
los ejemplos `iex>` de la documentación.

| Carpeta en `fixtures/` | Tipo | Resultado esperado |
|---|---|---|
| `rescate/valido` | Válido | Ejemplo del enunciado: 6 recorridos |
| `rescate/invalido` | Inválido | 9 errores y no se busca |
| `rescate/falta_archivo` | Inválido | Aviso de que falta `bateria.txt` |
| `rescate/limite_minimo` | Límite | S y M vecinas, con la energía justa |
| `rescate/limite_sin_recorrido` | Límite | La meta no alcanza y se omite la enumeración |
| `tareas/valido` | Válido | Ejemplo del enunciado: 2 planes, penalizaciones 4 y 6 |
| `tareas/invalido` | Inválido | 8 errores y no se enumera |
| `tareas/ciclos` | Inválido | Exactamente 5 ciclos |
| `tareas/no_entero` | Inválido | Un solo error, sin dependencia falsa |
| `tareas/limite_una` | Límite | Una tarea con plazo 0: un plan |
| `tareas/vacio` | Límite | Proyecto vacío, sin enumerar |

`fixtures/lector` contiene los archivos que usan las pruebas de `Lector` y `Svg`.

Para ver la comparación de tiempos entre la relajación y la enumeración, o las salidas de ejemplo
con datos escritos a mano:

```
mix run Scripts/demo_rol1.exs
mix run Scripts/demo_rol3.exs
```

## Estructura

| Carpeta o archivo | Contenido |
|---|---|
| `mix.exs` | Proyecto Mix: carpetas del código y de las pruebas, y dependencia de documentación |
| `rescate.exs`, `tareas.exs` | Puntos de entrada |
| `Orquestador.ex` | Flujo de los dos problemas: leer, validar, ejecutar y escribir |
| `Robot/` | `Terreno`, `Recorrido`, `Robot`, `Robot.Estadisticas`, `ValidadorEdificio` |
| `Planificador/` | `Tarea`, `Plan`, `Planificador`, `Planificador.Estadisticas`, `ValidadorTareas` |
| `Archivos/` | `Lector`, `Salida`, `Svg` |
| `Util/` | `Util2` y `Benchmark`, provistos por el docente |
| `Test/` | Pruebas ExUnit |
| `Scripts/` | Demostraciones |
| `fixtures/` | Casos de prueba |

## Decisiones de diseño

### Flujo

1. `Orquestador` revisa que existan los archivos y lee con `Lector`, que usa `File.stream!/1` y
   transformaciones perezosas.
2. Junta los errores de lectura con los de los validadores y escribe el reporte de validación.
3. Si no hay errores, `Robot` o `Planificador` entregan cada resultado a un receptor de `Salida`,
   que lo escribe enseguida. En memoria solo quedan las estadísticas.
4. Con las estadísticas se escriben el resumen y el SVG.

### Lectura y validación

- Las líneas físicas cuentan comentarios y líneas en blanco.
- Si una duración, un plazo, un costo o el campo transitable no se pueden convertir, el lector deja
  el texto original y el validador lo reporta. Así el registro sigue existiendo y lo que depende de
  él no da un error falso.
- Una línea con un número incorrecto de campos es un error de lectura y ese registro se descarta.
- Los validadores son recursivos con head/tail, sin `Enum` ni `Stream`, y devuelven todos los
  errores como `{linea_o_coordenada, mensaje}`.

### Problema 1 – Robot

- **Backtracking recursivo** con orden fijo arriba, derecha, abajo, izquierda y coordenadas
  `{fila, columna}` desde 0.
- **Pattern matching** para rechazar terrenos: `%Terreno{transitable: false}` descarta la casilla, y
  un símbolo no definido en `terrenos.csv` también.
- **Símbolos y costos desde `terrenos.csv`**: lo único fijo en el código son los marcadores `"S"` y
  `"M"` del enunciado.
- **Sin listas completas**: `buscar_recorridos/5` entrega cada recorrido a una función receptora.
  `Robot.Estadisticas` guarda solo el total y los empates, cada uno como `{id, recorrido}`.
- **Stream infinito**: `stream_relajacion/3` usa `Stream.iterate/2`; `expansion/3` lo consume hasta
  el primer par de estados consecutivos iguales.
- **Por qué la relajación es un filtro y no sustituye la enumeración**: calcula el costo mínimo de
  llegar a cada casilla sin exigir recorridos simples. Si la meta no tiene costo menor o igual que
  `B`, no existe ningún recorrido válido y se omite la enumeración. Pero un costo alcanzable solo
  dice que existe al menos un recorrido; no dice cuántos hay, cuáles son ni cuáles tienen menos
  movimientos, que es justo lo que pide el enunciado.

### Problema 2 – Planificador

- **Backtracking recursivo**: en cada paso se prueban las tareas habilitadas en orden alfabético por
  ID, sin pausas entre tareas.
- Para cada plan se calcula `finalizaciones` como lista `{id, inicio, fin}`, la penalización
  `suma de max(0, fin - plazo)` y la duración total.
- **Proyecto vacío**: se reporta sin enumerar ni llamar a la función receptora.

### Salidas

- Las posiciones del CSV se escriben como `(f,c)->(f,c)`, para no chocar con el separador `;`.
- Los colores del SVG salen de `terrenos.csv`: no transitables en gris oscuro y el resto por orden de
  símbolo.

## Límite conocido

La búsqueda de ciclos recorre todos los caminos simples. Con 22 tareas donde cada una depende de
todas las anteriores tarda cerca de 0,6 s, y ese tiempo se duplica con cada tarea adicional de ese
tipo.

## Informe y sustentación

- Informe PDF con la URL del repositorio, datos, resultados y pruebas (un caso válido, uno inválido y
  uno límite por problema) y la reflexión sobre el uso de inteligencia artificial.
- Video de sustentación individual explicando funciones no triviales.
