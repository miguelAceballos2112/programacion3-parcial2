Code.require_file("terreno.exs", __DIR__)
Code.require_file("recorrido.exs", __DIR__)
Code.require_file("estadisticas_robot.exs", __DIR__)

defmodule Robot do
  @moduledoc """
  Problema 1: robot de rescate con energía limitada.

  El módulo ofrece:

  - `buscar_recorridos/5`: backtracking recursivo que entrega cada recorrido a una
    función receptora con acumulador (nunca arma la lista completa).
  - `stream_relajacion/3`: Stream infinito de mapas de costo mínimo conocido.
  - `expansion/3`: consume ese Stream hasta el primer par de estados iguales.
  - `meta_alcanzable?/1`: filtro para omitir la enumeración.

  ## Convenciones

  - El **edificio** es una lista de filas; cada fila es una lista de símbolos
    (strings), por ejemplo `[~w(X X X), ~w(X S X)]`.
  - Los **terrenos** son un mapa `%{simbolo => %Terreno{}}` (ver `Terreno.indexar/1`).
  - Las coordenadas son `{fila, columna}` con origen en 0.
  - Los símbolos y costos de los terrenos se leen siempre del mapa de terrenos. Lo
    único fijo son los marcadores del enunciado: `"S"` (inicio) y `"M"` (meta).

  ## Información

  - **Problema:** 1 – Robot de rescate
  - **Rol:** 1 – Algoritmos y Streams
  """

  @simbolo_inicio "S"
  @simbolo_meta "M"

  # Orden fijo del enunciado: arriba, derecha, abajo, izquierda  ({fila, columna})
  @direcciones [{-1, 0}, {0, 1}, {1, 0}, {0, -1}]

  # -----------------------------------
  # Enumeración de recorridos (backtracking)
  # -----------------------------------

  @doc """
  Recorre recursivamente todos los recorridos simples de S a M cuya energía no
  supere `b`.

  Por cada recorrido llama a `receptora.(recorrido, acumulador)` y usa el valor
  que retorna como nuevo acumulador.

  ## Parámetros

  - `edificio`: lista de filas de símbolos.
  - `terrenos`: mapa `%{simbolo => %Terreno{}}`.
  - `b`: presupuesto máximo de energía (el límite es inclusivo).
  - `acumulador`: valor inicial del acumulador.
  - `receptora`: función `fn recorrido, acumulador -> nuevo_acumulador end`.

  ## Retorna

  El acumulador final. Si el edificio no tiene S, retorna el acumulador inicial.

  ## Ejemplo

      Robot.buscar_recorridos(edificio, terrenos, 10, Robot.Estadisticas.nuevo(),
                              &Robot.Estadisticas.actualizar/2)
  """
  def buscar_recorridos(edificio, terrenos, b, acumulador, receptora) do
    mapa = indexar(edificio)
    contexto = %{mapa: mapa, terrenos: terrenos, b: b, receptora: receptora}

    case ubicar(mapa, @simbolo_inicio) do
      nil -> acumulador
      inicio -> explorar(contexto, inicio, [inicio], 0, acumulador)
    end
  end

  # Si la posición actual es la meta, entrega el recorrido y corta esa rama;
  # si no, prueba las cuatro direcciones.
  defp explorar(contexto, actual, posiciones_rev, energia, acumulador) do
    if Map.get(contexto.mapa, actual) == @simbolo_meta do
      recorrido = %Recorrido{posiciones: Enum.reverse(posiciones_rev), energia: energia}
      contexto.receptora.(recorrido, acumulador)
    else
      probar(@direcciones, contexto, actual, posiciones_rev, energia, acumulador)
    end
  end

  # Prueba las direcciones en orden, encadenando el acumulador de una a la siguiente.
  defp probar([], _contexto, _actual, _posiciones_rev, _energia, acumulador), do: acumulador

  defp probar([{df, dc} | resto], contexto, {f, c} = actual, posiciones_rev, energia, acumulador) do
    vecino = {f + df, c + dc}
    simbolo = Map.get(contexto.mapa, vecino)

    nuevo_acumulador = avanzar(simbolo, vecino, contexto, posiciones_rev, energia, acumulador)
    probar(resto, contexto, actual, posiciones_rev, energia, nuevo_acumulador)
  end

  # Fuera de la cuadrícula.
  defp avanzar(nil, _vecino, _contexto, _posiciones_rev, _energia, acumulador), do: acumulador

  defp avanzar(simbolo, vecino, contexto, posiciones_rev, energia, acumulador) do
    terreno = Map.get(contexto.terrenos, simbolo)
    entrar(terreno, vecino, contexto, posiciones_rev, energia, acumulador)
  end

  # Símbolo no definido en terrenos.csv: se rechaza.
  defp entrar(nil, _vecino, _contexto, _posiciones_rev, _energia, acumulador), do: acumulador

  # Pattern matching: se rechazan los terrenos no transitables.
  defp entrar(%Terreno{transitable: false}, _vecino, _contexto, _posiciones_rev, _energia, acumulador),
    do: acumulador

  # Terreno transitable: se controla B y que la casilla no se repita.
  defp entrar(%Terreno{costo: costo}, vecino, contexto, posiciones_rev, energia, acumulador) do
    nueva_energia = energia + costo

    cond do
      nueva_energia > contexto.b ->
        acumulador

      Enum.member?(posiciones_rev, vecino) ->
        acumulador

      true ->
        explorar(contexto, vecino, [vecino | posiciones_rev], nueva_energia, acumulador)
    end
  end

  # -----------------------------------
  # Stream infinito: relajación de energía mínima
  # -----------------------------------

  @doc """
  Stream infinito de estados de costo mínimo conocido por posición.

  Un estado es un mapa `%{posicion => costo_minimo}`. En el paso 0 solo S tiene
  costo 0. En cada paso siguiente se conservan los costos ya encontrados y cada
  posición transitable se actualiza con:

      menor costo de sus vecinos (paso anterior) + costo de entrada a esa posición

  descartando los costos mayores que `b`.

  ## Ejemplo

      Robot.stream_relajacion(edificio, terrenos, 10) |> Enum.take(2)
      # => [%{{1, 1} => 0}, %{{1, 1} => 0, {1, 2} => 1, {2, 1} => 1}]
  """
  def stream_relajacion(edificio, terrenos, b) do
    mapa = indexar(edificio)

    inicial =
      case ubicar(mapa, @simbolo_inicio) do
        nil -> %{}
        inicio -> %{inicio => 0}
      end

    Stream.iterate(inicial, fn estado -> relajar(estado, mapa, terrenos, b) end)
  end

  @doc """
  Consume el Stream de relajación hasta el primer par de estados consecutivos
  iguales.

  ## Retorna

  Una tupla `{pasos_distintos, indice_estabilizacion}`: `pasos_distintos` es la
  lista de estados E0..E(k-1) y `k` (el índice de estabilización) es el primer
  índice en el que el estado Ek es igual al anterior.
  """
  def expansion(edificio, terrenos, b) do
    estados = stream_relajacion(edificio, terrenos, b)

    {_pareja, indice} =
      estados
      |> Stream.chunk_every(2, 1)
      |> Stream.with_index(1)
      |> Enum.find(fn {[previo, actual], _indice} -> previo == actual end)

    {Enum.take(estados, indice), indice}
  end

  @doc """
  Filtro que indica si la meta tiene costo alcanzable en el estado final.

  ## Parámetros

  - `{estado_final, posicion_meta}`: último estado de `expansion/3` y la posición
    de la meta (ver `ubicar/2`).

  Si retorna `false` se omite la enumeración recursiva de recorridos.
  """
  def meta_alcanzable?({estado_final, posicion_meta}) do
    Map.has_key?(estado_final, posicion_meta)
  end

  # -----------------------------------
  # Utilidades
  # -----------------------------------

  @doc """
  Posición `{fila, columna}` de un símbolo en el edificio, o `nil` si no está.

  ## Ejemplo

      Robot.ubicar([~w(X S), ~w(X M)], "M")
      # => {1, 1}
  """
  def ubicar(edificio, simbolo) when is_list(edificio), do: edificio |> indexar() |> ubicar(simbolo)

  def ubicar(mapa, simbolo) when is_map(mapa) do
    case Enum.find(mapa, fn {_posicion, s} -> s == simbolo end) do
      {posicion, _simbolo} -> posicion
      nil -> nil
    end
  end

  # -----------------------------------
  # Funciones auxiliares privadas
  # -----------------------------------

  # Convierte la lista de filas en un mapa %{{fila, columna} => simbolo}.
  defp indexar(edificio) do
    edificio
    |> Enum.with_index()
    |> Enum.flat_map(fn {fila, f} ->
      fila
      |> Enum.with_index()
      |> Enum.map(fn {simbolo, c} -> {{f, c}, simbolo} end)
    end)
    |> Map.new()
  end

  # Un paso de relajación: los candidatos se calculan con el estado anterior y se
  # guardan en el estado nuevo.
  defp relajar(estado, mapa, terrenos, b) do
    Enum.reduce(mapa, estado, fn {posicion, simbolo}, nuevo ->
      case Map.get(terrenos, simbolo) do
        %Terreno{transitable: true, costo: costo} -> mejorar(nuevo, estado, posicion, costo, b)
        _ -> nuevo
      end
    end)
  end

  # Actualiza la posición si el nuevo costo es válido (<= b) y mejora el existente.
  defp mejorar(nuevo, estado, posicion, costo, b) do
    case menor_costo_vecinos(estado, posicion) do
      nil ->
        nuevo

      base ->
        candidato = base + costo
        actual = Map.get(nuevo, posicion)

        if candidato <= b and (actual == nil or candidato < actual) do
          Map.put(nuevo, posicion, candidato)
        else
          nuevo
        end
    end
  end

  # Menor costo conocido entre los cuatro vecinos, o nil si ninguno tiene costo.
  defp menor_costo_vecinos(estado, {f, c}) do
    @direcciones
    |> Enum.map(fn {df, dc} -> Map.get(estado, {f + df, c + dc}) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
  end
end
