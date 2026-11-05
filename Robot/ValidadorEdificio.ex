defmodule ValidadorEdificio do
  # Validación previa del Problema 1: edificio, terrenos y batería.
  #
  # Todas las funciones son recursivas con head/tail, sin Enum ni Stream.
  # Devuelven una lista de errores {linea_o_coordenada, mensaje} y no escriben archivos.
  # Si un error no tiene línea ni coordenada, la ubicación es "general".
  #
  # Datos que recibe de Rol 3:
  #   filas    = [{linea, ["X", "S", ...]}, ...]
  #   terrenos = [{linea, %Terreno{}}, ...]
  #   lineas   = [{linea, "10"}, ...]

  def validar(filas, terrenos) do
    validar_terrenos(terrenos, []) ++ validar_cuadricula(filas, terrenos)
  end

  # El archivo de batería no tiene ninguna línea de datos
  def validar_bateria([]), do: [{"general", "bateria.txt no tiene datos"}]

  # La primera línea debe ser el entero y no pueden sobrar más líneas
  def validar_bateria([{linea, texto} | sobrantes]) do
    validar_energia(linea, texto) ++ validar_sobrantes(sobrantes)
  end

  # -----------------------------------
  # Tabla de terrenos
  # -----------------------------------

  # Caso base: no quedan terrenos por revisar
  defp validar_terrenos([], _vistos), do: []

  # Caso recursivo: revisa el head y sigue con el tail, recordando el símbolo visto
  defp validar_terrenos([{linea, terreno} | tail], vistos) do
    validar_repetido(linea, terreno.simbolo, vistos) ++
      validar_transitable(linea, terreno) ++
      validar_costo(linea, terreno) ++
      validar_terrenos(tail, [terreno.simbolo | vistos])
  end

  defp validar_repetido(linea, simbolo, vistos) do
    if contiene?(vistos, simbolo) do
      [{linea, "El símbolo #{simbolo} está repetido en terrenos.csv"}]
    else
      []
    end
  end

  defp validar_transitable(_linea, %Terreno{transitable: transitable})
       when transitable in [true, false, "si", "no"],
       do: []

  defp validar_transitable(linea, %Terreno{simbolo: simbolo, transitable: transitable}) do
    [{linea, "El campo transitable de #{simbolo} debe ser si o no y se encontró: #{transitable}"}]
  end

  defp validar_costo(linea, terreno) do
    if entero_minimo?(terreno.costo, 0) do
      validar_costo_cero(linea, terreno)
    else
      [
        {linea,
         "El costo de #{terreno.simbolo} debe ser un entero no negativo y se encontró: #{terreno.costo}"}
      ]
    end
  end

  # La casilla S no consume energía: es la única transitable que puede costar 0
  defp validar_costo_cero(_linea, %Terreno{simbolo: "S"}), do: []

  defp validar_costo_cero(linea, %Terreno{simbolo: simbolo, transitable: transitable, costo: 0})
       when transitable in [true, "si"] do
    [{linea, "El terreno transitable #{simbolo} debe tener costo positivo"}]
  end

  defp validar_costo_cero(_linea, _terreno), do: []

  # -----------------------------------
  # Cuadrícula
  # -----------------------------------

  # Sin filas no hay nada más que revisar
  defp validar_cuadricula([], _terrenos), do: [{"general", "La cuadrícula está vacía"}]

  # Las filas se convierten en celdas para revisar cada regla con una sola recursión
  defp validar_cuadricula(filas, terrenos) do
    celdas = obtener_celdas(filas, 0, length(filas) - 1)

    validar_rectangular(filas, ancho_esperado(filas)) ++
      validar_definidos(celdas, obtener_simbolos(terrenos)) ++
      validar_unico(celdas, "S") ++
      validar_unico(celdas, "M") ++
      validar_borde(celdas)
  end

  # El ancho esperado es el de la primera fila
  defp ancho_esperado([{_linea, simbolos} | _tail]), do: length(simbolos)

  # Caso base: no quedan filas
  defp validar_rectangular([], _ancho), do: []

  # Caso recursivo: revisa el ancho del head y sigue con el tail
  defp validar_rectangular([{linea, simbolos} | tail], ancho) do
    if length(simbolos) == ancho do
      validar_rectangular(tail, ancho)
    else
      [
        {linea, "La fila tiene #{length(simbolos)} columnas y se esperaban #{ancho}"}
        | validar_rectangular(tail, ancho)
      ]
    end
  end

  # Convierte las filas en una lista de celdas {{fila, columna}, simbolo, borde?}.
  # El número de fila cuenta solo filas de datos; la línea física queda para otros errores.
  defp obtener_celdas([], _fila, _ultima_fila), do: []

  defp obtener_celdas([{_linea, simbolos} | tail], fila, ultima_fila) do
    obtener_celdas_fila(simbolos, fila, 0, ultima_fila, length(simbolos) - 1) ++
      obtener_celdas(tail, fila + 1, ultima_fila)
  end

  defp obtener_celdas_fila([], _fila, _columna, _ultima_fila, _ultima_columna), do: []

  defp obtener_celdas_fila([simbolo | tail], fila, columna, ultima_fila, ultima_columna) do
    borde = fila == 0 or fila == ultima_fila or columna == 0 or columna == ultima_columna

    [
      {{fila, columna}, simbolo, borde}
      | obtener_celdas_fila(tail, fila, columna + 1, ultima_fila, ultima_columna)
    ]
  end

  defp obtener_simbolos([]), do: []

  defp obtener_simbolos([{_linea, terreno} | tail]) do
    [terreno.simbolo | obtener_simbolos(tail)]
  end

  # Caso base: no quedan celdas
  defp validar_definidos([], _simbolos), do: []

  # Caso recursivo: revisa si el símbolo del head existe en terrenos.csv
  defp validar_definidos([{posicion, simbolo, _borde} | tail], simbolos) do
    if contiene?(simbolos, simbolo) do
      validar_definidos(tail, simbolos)
    else
      [
        {posicion, "El símbolo #{simbolo} no está definido en terrenos.csv"}
        | validar_definidos(tail, simbolos)
      ]
    end
  end

  # Debe existir exactamente una casilla con el símbolo
  defp validar_unico(celdas, simbolo) do
    case posiciones_de(celdas, simbolo) do
      [] -> [{"general", "No existe ninguna casilla #{simbolo}"}]
      [_unica] -> []
      posiciones -> reportar_repetidas(posiciones, simbolo)
    end
  end

  # Caso base: no quedan celdas
  defp posiciones_de([], _simbolo), do: []

  # Caso recursivo: la celda tiene el símbolo buscado
  defp posiciones_de([{posicion, actual, _borde} | tail], simbolo) when actual == simbolo do
    [posicion | posiciones_de(tail, simbolo)]
  end

  # Caso recursivo: la celda tiene otro símbolo
  defp posiciones_de([_celda | tail], simbolo), do: posiciones_de(tail, simbolo)

  defp reportar_repetidas([], _simbolo), do: []

  defp reportar_repetidas([posicion | tail], simbolo) do
    [{posicion, "Debe existir una sola casilla #{simbolo}"} | reportar_repetidas(tail, simbolo)]
  end

  # Se revisa celda por celda para que una esquina no se reporte dos veces.
  # Caso base: no quedan celdas
  defp validar_borde([]), do: []

  # Caso recursivo: la celda es X, esté o no en el borde
  defp validar_borde([{_posicion, "X", _borde} | tail]), do: validar_borde(tail)

  # Caso recursivo: la celda no está en el borde
  defp validar_borde([{_posicion, _simbolo, false} | tail]), do: validar_borde(tail)

  # Caso recursivo: la celda está en el borde y no es X
  defp validar_borde([{posicion, simbolo, true} | tail]) do
    [{posicion, "El borde debe ser X y se encontró: #{simbolo}"} | validar_borde(tail)]
  end

  # -----------------------------------
  # Batería
  # -----------------------------------

  defp validar_energia(linea, texto) do
    if entero_minimo?(String.trim(texto), 1) do
      []
    else
      [{linea, "La batería debe ser un entero positivo y se encontró: #{texto}"}]
    end
  end

  defp validar_sobrantes([]), do: []

  defp validar_sobrantes([{linea, _texto} | tail]) do
    [{linea, "bateria.txt debe tener una sola línea de datos"} | validar_sobrantes(tail)]
  end

  # -----------------------------------
  # Funciones auxiliares
  # -----------------------------------

  # Igual que en Util2: el valor es un entero solo si no queda texto después del número
  defp entero_minimo?(valor, minimo) do
    case Integer.parse("#{valor}") do
      {numero, ""} -> numero >= minimo
      _ -> false
    end
  end

  # Caso base: en una lista vacía no está el elemento
  defp contiene?([], _elemento), do: false
  # El head es el elemento buscado
  defp contiene?([head | _tail], elemento) when head == elemento, do: true
  # Si no, se sigue buscando en el tail
  defp contiene?([_head | tail], elemento), do: contiene?(tail, elemento)
end
