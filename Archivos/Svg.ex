defmodule Svg do
  @moduledoc """
  Generación progresiva de los SVG (Rol 3).

  Cada elemento se escribe con su propio `IO.write/2` apenas se calcula; nunca se
  arma un único string con el documento completo. Todo texto que viene de los
  datos (símbolos, nombres, IDs) pasa por `escapar/1`.
  """

  @celda 40
  @px_leyenda 8
  @px_id 9
  @px_titulo 11
  @paleta [
    "#bbdefb",
    "#fff59d",
    "#ffcc80",
    "#f48fb1",
    "#ce93d8",
    "#a5d6a7",
    "#b0bec5",
    "#ffab91"
  ]
  @color_pared "#37474f"
  @color_ruta "#d50000"
  @color_inicio "#2e7d32"
  @color_meta "#1565c0"
  @color_a_tiempo "#43a047"
  @color_tarde "#e53935"

  @doc """
  Escapa texto para XML (los caracteres `&`, `<`, `>`, comilla doble y comilla simple).

  Acepta cualquier valor que se pueda convertir con `to_string/1`.

  ## Ejemplos

      iex> Svg.escapar("a < b & c")
      "a &lt; b &amp; c"

      iex> Svg.escapar(42)
      "42"
  """
  @spec escapar(term()) :: String.t()
  def escapar(texto) do
    texto
    |> to_string()
    |> String.replace(["&", "<", ">", "\"", "'"], fn
      "&" -> "&amp;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      "\"" -> "&quot;"
      "'" -> "&apos;"
    end)
  end

  @doc """
  Asigna un color a cada símbolo según los terrenos leídos de `terrenos.csv`:
  los no transitables van en gris oscuro y los transitables toman colores de la
  paleta por orden de símbolo. No hay símbolos fijos en el código.

  Devuelve `%{simbolo => color}` con colores hexadecimales.
  """
  @spec colores_terrenos(%{String.t() => Terreno.t()}) :: %{String.t() => String.t()}
  def colores_terrenos(indice) do
    terrenos = indice |> Map.values() |> Enum.sort_by(fn t -> t.simbolo end)
    transitables = Enum.filter(terrenos, fn t -> t.transitable end)
    paredes = Enum.reject(terrenos, fn t -> t.transitable end)

    base =
      transitables
      |> Enum.with_index()
      |> Map.new(fn {t, i} -> {t.simbolo, Enum.at(@paleta, rem(i, length(@paleta)))} end)

    Enum.reduce(paredes, base, fn t, acumulado -> Map.put(acumulado, t.simbolo, @color_pared) end)
  end

  # ---------------------------------------------------------------------------
  # ruta_optima.svg
  # ---------------------------------------------------------------------------

  @doc """
  Escribe `ruta_optima.svg`: edificio con casillas de 40x40 px, colores por tipo de
  terreno y el recorrido de menor energía remarcado. Si `recorrido` es `nil`
  se dibuja el mapa sin ruta y la leyenda «sin recorrido».

  `mapa` es el que devuelve `Lector.construir_mapa/1`; `indice` es
  `Lector.indice_terrenos/1`.
  """
  @spec escribir_ruta(
          Path.t(),
          Lector.mapa(),
          %{String.t() => Terreno.t()},
          Recorrido.t() | nil
        ) :: :ok
  def escribir_ruta(ruta, mapa, indice, recorrido) do
    colores = colores_terrenos(indice)
    terrenos = indice |> Map.values() |> Enum.sort_by(fn t -> t.simbolo end)
    alto_mapa = mapa.filas * @celda
    ancho = ancho_mapa(mapa, terrenos, recorrido)
    alto = alto_mapa + 30 + 24 * (length(terrenos) + 2)

    dispositivo = Salida.abrir(ruta)

    try do
      escribir_encabezado(dispositivo, ancho, alto)
      escribir_celdas(dispositivo, mapa, colores)
      escribir_recorrido(dispositivo, recorrido)
      escribir_leyenda_mapa(dispositivo, terrenos, colores, alto_mapa, recorrido)
      IO.write(dispositivo, "</svg>\n")
    after
      Salida.cerrar(dispositivo)
    end

    :ok
  end

  # El SVG no ajusta su tamaño al texto ni se puede medir aquí sin saber la fuente del
  # navegador, así que se estima con pocos píxeles de más por carácter.
  defp ancho_texto(texto, px_por_caracter), do: String.length(to_string(texto)) * px_por_caracter

  # El mapa puede ser más angosto que su leyenda, que empieza en x = 32
  defp ancho_mapa(mapa, terrenos, recorrido) do
    etiquetas = etiqueta_ruta(recorrido) ++ Enum.map(terrenos, &etiqueta_terreno/1)
    ancho_leyenda = etiquetas |> Enum.map(fn e -> 40 + ancho_texto(e, @px_leyenda) end) |> Enum.max(fn -> 0 end)

    Enum.max([mapa.columnas * @celda, 280, ancho_leyenda])
  end

  defp etiqueta_terreno(terreno), do: "#{terreno.simbolo} = #{terreno.nombre} (costo #{terreno.costo})"

  defp etiqueta_ruta(nil), do: []

  defp etiqueta_ruta(%Recorrido{} = r) do
    ["Ruta de menor energía: #{r.energia} de energía, #{Recorrido.movimientos(r)} movimientos"]
  end

  defp escribir_encabezado(dispositivo, ancho, alto) do
    IO.write(dispositivo, ~s(<?xml version="1.0" encoding="UTF-8"?>\n))

    IO.write(
      dispositivo,
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}" viewBox="0 0 #{ancho} #{alto}">\n)
    )

    IO.write(dispositivo, ~s(<rect x="0" y="0" width="#{ancho}" height="#{alto}" fill="#ffffff"/>\n))
  end

  defp escribir_celdas(dispositivo, mapa, colores) do
    mapa.celdas
    |> Enum.sort()
    |> Enum.each(fn {{fila, columna}, simbolo} ->
      x = columna * @celda
      y = fila * @celda
      color = Map.get(colores, simbolo, "#eeeeee")
      color_texto = if color == @color_pared, do: "#ffffff", else: "#263238"

      IO.write(
        dispositivo,
        ~s(<rect x="#{x}" y="#{y}" width="#{@celda}" height="#{@celda}" fill="#{color}" stroke="#90a4ae" stroke-width="1"/>\n)
      )

      IO.write(
        dispositivo,
        ~s(<text x="#{x + 20}" y="#{y + 25}" font-family="monospace" font-size="14" text-anchor="middle" fill="#{color_texto}">#{escapar(simbolo)}</text>\n)
      )
    end)
  end

  defp escribir_recorrido(_dispositivo, nil), do: :ok

  defp escribir_recorrido(dispositivo, %Recorrido{posiciones: posiciones}) do
    puntos =
      posiciones
      |> Enum.map(fn posicion ->
        {x, y} = centro(posicion)
        "#{x},#{y}"
      end)
      |> Enum.join(" ")

    IO.write(
      dispositivo,
      ~s(<polyline points="#{puntos}" fill="none" stroke="#{@color_ruta}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" opacity="0.85"/>\n)
    )

    Enum.each(posiciones, fn posicion ->
      {x, y} = centro(posicion)
      IO.write(dispositivo, ~s(<circle cx="#{x}" cy="#{y}" r="4" fill="#{@color_ruta}"/>\n))
    end)

    marcar(dispositivo, List.first(posiciones), @color_inicio)
    marcar(dispositivo, List.last(posiciones), @color_meta)
  end

  defp marcar(_dispositivo, nil, _color), do: :ok

  defp marcar(dispositivo, posicion, color) do
    {x, y} = centro(posicion)

    IO.write(
      dispositivo,
      ~s(<circle cx="#{x}" cy="#{y}" r="10" fill="none" stroke="#{color}" stroke-width="4"/>\n)
    )
  end

  defp centro({fila, columna}) do
    {columna * @celda + div(@celda, 2), fila * @celda + div(@celda, 2)}
  end

  defp escribir_leyenda_mapa(dispositivo, terrenos, colores, alto_mapa, recorrido) do
    IO.write(
      dispositivo,
      ~s(<text x="8" y="#{alto_mapa + 20}" font-family="sans-serif" font-size="13" font-weight="bold" fill="#263238">Leyenda</text>\n)
    )

    terrenos
    |> Enum.with_index()
    |> Enum.each(fn {terreno, i} ->
      y = alto_mapa + 30 + 24 * i
      color = Map.get(colores, terreno.simbolo, "#eeeeee")
      etiqueta = etiqueta_terreno(terreno)

      IO.write(
        dispositivo,
        ~s(<rect x="8" y="#{y}" width="16" height="16" fill="#{color}" stroke="#90a4ae"/>\n)
      )

      IO.write(
        dispositivo,
        ~s(<text x="32" y="#{y + 13}" font-family="sans-serif" font-size="12" fill="#263238">#{escapar(etiqueta)}</text>\n)
      )
    end)

    y_ruta = alto_mapa + 30 + 24 * length(terrenos)

    case recorrido do
      nil ->
        IO.write(
          dispositivo,
          ~s(<text x="8" y="#{y_ruta + 13}" font-family="sans-serif" font-size="12" font-weight="bold" fill="#{@color_ruta}">sin recorrido</text>\n)
        )

      %Recorrido{} = r ->
        [etiqueta] = etiqueta_ruta(r)

        IO.write(
          dispositivo,
          ~s(<line x1="8" y1="#{y_ruta + 8}" x2="24" y2="#{y_ruta + 8}" stroke="#{@color_ruta}" stroke-width="4" stroke-linecap="round"/>\n)
        )

        IO.write(
          dispositivo,
          ~s(<text x="32" y="#{y_ruta + 13}" font-family="sans-serif" font-size="12" fill="#263238">#{escapar(etiqueta)}</text>\n)
        )
    end
  end

  # ---------------------------------------------------------------------------
  # mejor_plan.svg (Gantt)
  # ---------------------------------------------------------------------------

  @margen_izq 110
  @margen_sup 70
  @paso_fila 46
  @alto_barra 24

  @doc """
  Escribe `mejor_plan.svg`: diagrama de Gantt del plan recibido. Eje horizontal en
  unidades de tiempo, una barra por tarea con su inicio y fin visibles, y las tareas
  terminadas fuera de plazo en rojo. `tareas` es la lista de `%Tarea{}` (de ahí se
  toman los plazos). Si `plan` es `nil` se dibuja una leyenda explicativa.
  """
  @spec escribir_gantt(Path.t(), Plan.t() | nil, [Tarea.t()]) :: :ok
  def escribir_gantt(ruta, nil, _tareas) do
    dispositivo = Salida.abrir(ruta)

    try do
      escribir_encabezado(dispositivo, 640, 90)

      IO.write(
        dispositivo,
        ~s(<text x="16" y="40" font-family="sans-serif" font-size="14" fill="#263238">#{escapar("Sin plan: no hay tareas o la red de dependencias es inválida.")}</text>\n)
      )

      IO.write(
        dispositivo,
        ~s(<text x="16" y="64" font-family="sans-serif" font-size="12" fill="#546e7a">#{escapar("Revise validacion_tareas.txt para ver los problemas detectados.")}</text>\n)
      )

      IO.write(dispositivo, "</svg>\n")
    after
      Salida.cerrar(dispositivo)
    end

    :ok
  end

  def escribir_gantt(ruta, %Plan{} = plan, tareas) do
    plazos = Map.new(tareas, fn %Tarea{id: id, plazo: plazo} -> {id, plazo} end)
    total = Plan.duracion_total(plan)
    limite = Enum.reduce(plazos, total, fn {_id, plazo}, acumulado -> max(plazo, acumulado) end)
    escala = escala(limite)
    filas = length(plan.finalizaciones)
    y_eje = @margen_sup + filas * @paso_fila + 6
    titulo = "Diagrama de Gantt - mejor plan: " <> Enum.join(plan.orden, " → ")
    subtitulo = "Duración total: #{total} | Penalización: #{plan.penalizacion}"
    margen = margen_izquierdo(plan.finalizaciones)

    ancho =
      Enum.max([
        520,
        margen + limite * escala + 70,
        16 + ancho_texto(titulo, @px_titulo) + 8,
        fin_etiquetas_retraso(plan.finalizaciones, plazos, margen, escala)
      ])

    alto = y_eje + 100

    dispositivo = Salida.abrir(ruta)

    try do
      escribir_encabezado(dispositivo, ancho, alto)

      IO.write(
        dispositivo,
        ~s(<text x="16" y="26" font-family="sans-serif" font-size="15" font-weight="bold" fill="#263238">#{escapar(titulo)}</text>\n)
      )

      IO.write(
        dispositivo,
        ~s(<text x="16" y="48" font-family="sans-serif" font-size="12" fill="#546e7a">#{escapar(subtitulo)}</text>\n)
      )

      plan.finalizaciones
      |> Enum.with_index()
      |> Enum.each(fn {{id, inicio, fin}, i} ->
        escribir_barra(dispositivo, {id, inicio, fin}, i, {margen, escala}, Map.get(plazos, id))
      end)

      escribir_eje(dispositivo, limite, {margen, escala}, y_eje)
      escribir_leyenda_gantt(dispositivo, y_eje + 50)
      IO.write(dispositivo, "</svg>\n")
    after
      Salida.cerrar(dispositivo)
    end

    :ok
  end

  defp escala(limite), do: max(20, min(60, div(800, max(limite, 1))))

  # Los IDs se escriben a la izquierda de las barras y terminan 10 px antes del margen
  defp margen_izquierdo(finalizaciones) do
    finalizaciones
    |> Enum.map(fn {id, _inicio, _fin} -> ancho_texto(id, @px_id) + 18 end)
    |> Enum.max(fn -> 0 end)
    |> max(@margen_izq)
  end

  # Hasta dónde llegan los avisos de retraso, que se escriben a la derecha de cada barra
  defp fin_etiquetas_retraso(finalizaciones, plazos, margen, escala) do
    finalizaciones
    |> Enum.map(fn {id, _inicio, fin} ->
      plazo = Map.get(plazos, id)

      if plazo != nil and fin > plazo do
        margen + fin * escala + 8 + ancho_texto(etiqueta_retraso(fin, plazo), @px_leyenda)
      else
        0
      end
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp etiqueta_retraso(fin, plazo), do: "fuera de plazo (+#{fin - plazo})"

  defp escribir_barra(dispositivo, {id, inicio, fin}, i, {margen, escala}, plazo) do
    y = @margen_sup + i * @paso_fila
    x = margen + inicio * escala
    ancho = (fin - inicio) * escala
    tarde = plazo != nil and fin > plazo
    {clase, color, borde} = if tarde, do: {"tarde", @color_tarde, "#b71c1c"}, else: {"a-tiempo", @color_a_tiempo, "#1b5e20"}

    IO.write(
      dispositivo,
      ~s(<text x="#{margen - 10}" y="#{y + 17}" font-family="sans-serif" font-size="13" text-anchor="end" fill="#263238">#{escapar(id)}</text>\n)
    )

    IO.write(
      dispositivo,
      ~s(<rect class="#{clase}" x="#{x}" y="#{y}" width="#{ancho}" height="#{@alto_barra}" fill="#{color}" stroke="#{borde}" stroke-width="2"/>\n)
    )

    IO.write(
      dispositivo,
      ~s(<text x="#{x}" y="#{y + @alto_barra + 13}" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#37474f">#{inicio}</text>\n)
    )

    IO.write(
      dispositivo,
      ~s(<text x="#{x + ancho}" y="#{y + @alto_barra + 13}" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#37474f">#{fin}</text>\n)
    )

    if plazo != nil do
      x_plazo = margen + plazo * escala

      IO.write(
        dispositivo,
        ~s(<line x1="#{x_plazo}" y1="#{y - 4}" x2="#{x_plazo}" y2="#{y + @alto_barra + 4}" stroke="#1a237e" stroke-width="2" stroke-dasharray="4,3"/>\n)
      )
    end

    if tarde do
      etiqueta = etiqueta_retraso(fin, plazo)

      IO.write(
        dispositivo,
        ~s(<text x="#{x + ancho + 8}" y="#{y + 17}" font-family="sans-serif" font-size="11" font-weight="bold" fill="#{@color_tarde}">#{escapar(etiqueta)}</text>\n)
      )
    end
  end

  defp escribir_eje(dispositivo, limite, {margen, escala}, y_eje) do
    paso = max(1, div(limite + 19, 20))
    x_fin = margen + limite * escala

    IO.write(
      dispositivo,
      ~s(<line x1="#{margen}" y1="#{y_eje}" x2="#{x_fin}" y2="#{y_eje}" stroke="#263238" stroke-width="1.5"/>\n)
    )

    Enum.each(0..limite//paso, fn t ->
      x = margen + t * escala

      IO.write(
        dispositivo,
        ~s(<line x1="#{x}" y1="#{y_eje}" x2="#{x}" y2="#{y_eje + 5}" stroke="#263238"/>\n)
      )

      IO.write(
        dispositivo,
        ~s(<text x="#{x}" y="#{y_eje + 18}" font-family="sans-serif" font-size="11" text-anchor="middle" fill="#263238">#{t}</text>\n)
      )
    end)

    IO.write(
      dispositivo,
      ~s(<text x="#{margen}" y="#{y_eje + 34}" font-family="sans-serif" font-size="11" fill="#546e7a">Tiempo en unidades</text>\n)
    )
  end

  defp escribir_leyenda_gantt(dispositivo, y) do
    IO.write(
      dispositivo,
      ~s(<rect class="leyenda-a-tiempo" x="16" y="#{y}" width="16" height="16" fill="#{@color_a_tiempo}" stroke="#1b5e20"/>\n)
    )

    IO.write(
      dispositivo,
      ~s(<text x="40" y="#{y + 13}" font-family="sans-serif" font-size="12" fill="#263238">Terminada a tiempo</text>\n)
    )

    IO.write(
      dispositivo,
      ~s(<rect class="leyenda-tarde" x="180" y="#{y}" width="16" height="16" fill="#{@color_tarde}" stroke="#b71c1c"/>\n)
    )

    IO.write(
      dispositivo,
      ~s(<text x="204" y="#{y + 13}" font-family="sans-serif" font-size="12" fill="#263238">Fuera de plazo</text>\n)
    )

    IO.write(
      dispositivo,
      ~s(<line x1="330" y1="#{y}" x2="330" y2="#{y + 16}" stroke="#1a237e" stroke-width="2" stroke-dasharray="4,3"/>\n)
    )

    IO.write(
      dispositivo,
      ~s(<text x="342" y="#{y + 13}" font-family="sans-serif" font-size="12" fill="#263238">Plazo de la tarea</text>\n)
    )
  end
end
