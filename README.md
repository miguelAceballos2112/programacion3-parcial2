# Parcial 2 – Programación III (Elixir)

Universidad del Quindío · Programa de Ingeniería de Sistemas y Computación
Docente: Julián Esteban Gutiérrez Posada · Grupo: G2D

Programación funcional con Elixir: recursividad, Streams y structs.

**URL del repositorio:** https://github.com/miguelAceballos2112/programacion3-parcial2.git

## Integrantes y roles

| Integrante | Rol | Responsabilidad |
|------------|-----|-----------------|
| Miguel Angel Ceballos Soler | Rol 1 | Algoritmos y Streams (`Robot`, `Planificador`) y pruebas ExUnit |
| _Nombre 2_ | Rol 2 | _(completar)_ |
| _Nombre 3_ | Rol 3 | _(completar)_ |

## Problemas elegidos

El grupo eligió las combinaciones válidas **1 y 2**:

1. **Problema 1** – Robot de rescate con energía limitada y mapa SVG (structs y Stream infinito).
2. **Problema 2** – Planificación de tareas con dependencias y diagrama SVG (structs).

## Requisitos

Elixir 1.14 o superior. Se verifica con `elixir --version`. Todo el código está en scripts `.exs`, por lo que no se necesita compilar ni crear un proyecto Mix.

## Cómo ejecutar las pruebas

Desde la carpeta raíz del repositorio:

```bash
elixir test/robot_test.exs
elixir test/planificador_test.exs
```

Las pruebas cubren, para cada problema, el ejemplo del enunciado, casos sin solución, empates y casos límite (sin ruta, `B` insuficiente, proyecto de 0 y de 1 tarea).

## Cómo ejecutar los problemas

_(Completar cuando los otros roles integren lectura, validación y escritura de archivos.)_

```bash
elixir robot/principal.exs
elixir planificador/principal.exs
```

Demostración de las funciones del Rol 1 con los datos del enunciado, incluida la comparación de tiempos entre la relajación y la enumeración completa:

```bash
elixir scripts/demo_rol1.exs
```

## Archivos de entrada y salida

| Problema | Entradas | Salidas |
|----------|----------|---------|
| 1 | `edificio.txt`, `terrenos.csv`, `bateria.txt` | `validacion_edificio.txt`, `expansion_energia.txt`, `recorridos_rescate.csv`, `resumen_rescate.txt`, `ruta_optima.svg` |
| 2 | `tareas.csv` | `validacion_tareas.txt`, `planes.csv`, `resumen_tareas.txt`, `mejor_plan.svg` |

## Decisiones de diseño (Rol 1)

### Problema 1 – Robot

- **Backtracking recursivo** con orden fijo arriba, derecha, abajo, izquierda y coordenadas `{fila, columna}` desde 0.
- **Pattern matching** para rechazar terrenos: `%Terreno{transitable: false}` descarta la casilla, y un símbolo no definido en `terrenos.csv` también.
- **Símbolos y costos desde `terrenos.csv`**: la búsqueda consulta un mapa `%{simbolo => %Terreno{}}`. Lo único fijo en el código son los marcadores del enunciado, `"S"` (inicio) y `"M"` (meta).
- **Sin listas completas**: `buscar_recorridos/5` entrega cada recorrido a una función receptora `fn recorrido, acumulador -> acumulador end`. `Robot.Estadisticas` guarda solo el total y los empates en mínimo de movimientos y mínimo de energía; el primero de cada lista es el que se dibuja en el SVG.
- **Stream infinito**: `stream_relajacion/3` usa `Stream.iterate/2`; `expansion/3` lo consume hasta el primer par de estados consecutivos iguales y devuelve `{pasos_distintos, indice_estabilizacion}`.
- **Por qué la relajación es un filtro y no sustituye la enumeración**: calcula el costo mínimo de llegar a cada casilla sin exigir recorridos simples. Si la meta no tiene costo menor o igual que `B`, no existe ningún recorrido válido y se omite la enumeración. Pero un costo alcanzable solo dice que existe al menos un recorrido; no dice cuántos hay, cuáles son ni cuáles tienen menos movimientos, que es justo lo que pide el enunciado.

### Problema 2 – Planificador

- **Backtracking recursivo**: en cada paso se prueban las tareas habilitadas (dependencias ya terminadas) en orden alfabético por ID, sin pausas entre tareas.
- Para cada plan se calcula `finalizaciones` como lista `{id, inicio, fin}`, la penalización `suma de max(0, fin - plazo)` y la duración total (`Plan.duracion_total/1`).
- **Función receptora con acumulador**: `generar_planes/3` entrega cada `%Plan{}` sin concatenar los planes en memoria.
- **Proyecto vacío**: `generar_planes([], acumulador, receptora)` devuelve el acumulador sin enumerar ni llamar a la receptora.

## Uso de las funciones del Rol 1

```elixir
# Problema 1
terrenos = Terreno.indexar(lista_de_terrenos)

estadisticas =
  Robot.buscar_recorridos(edificio, terrenos, b,
    Robot.Estadisticas.nuevo(), &Robot.Estadisticas.actualizar/2)

{pasos, indice} = Robot.expansion(edificio, terrenos, b)
Robot.meta_alcanzable?({List.last(pasos), Robot.ubicar(edificio, "M")})

# Problema 2
estadisticas =
  Planificador.generar_planes(tareas, Planificador.Estadisticas.nuevo(),
    &Planificador.Estadisticas.actualizar/2)
```

Para escribir cada recorrido o plan a medida que se produce, quien arme la salida define su propia receptora; por ejemplo, con un acumulador `{estadisticas, archivo}` que escribe una línea y llama a `actualizar/2`.

## Informe y sustentación

- Informe PDF con la URL del repositorio, datos, resultados y pruebas (un caso válido, uno inválido y uno límite por problema) y la reflexión sobre el uso de inteligencia artificial.
- Video de sustentación individual explicando funciones no triviales.
