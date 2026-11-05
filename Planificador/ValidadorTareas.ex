defmodule ValidadorTareas do
  # Validación previa del Problema 2: IDs, valores, dependencias y ciclos.
  #
  # Todas las funciones son recursivas con head/tail, sin Enum ni Stream.
  # Devuelven una lista de errores {linea, mensaje} y no escriben archivos.
  #
  # Datos que recibe de Rol 3:
  #   tareas = [{linea, %Tarea{}}, ...]
  #
  # Si Rol 3 no puede convertir una duración o un plazo, deja el texto tal como venía.
  # Así la tarea sigue existiendo y sus dependientes no reportan un error falso.

  def validar(tareas) do
    validar_ids(tareas, []) ++
      validar_valores(tareas) ++
      validar_dependencias(tareas, obtener_ids(tareas)) ++
      validar_ciclos(tareas)
  end

  # -----------------------------------
  # IDs
  # -----------------------------------

  # Caso base: no quedan tareas por revisar
  defp validar_ids([], _vistos), do: []

  # Caso recursivo: revisa el head y sigue con el tail, recordando el ID visto
  defp validar_ids([{linea, %Tarea{id: id}} | tail], vistos) do
    validar_duplicado(linea, id, vistos) ++
      validar_formato_id(linea, id) ++
      validar_ids(tail, [id | vistos])
  end

  defp validar_duplicado(linea, id, vistos) do
    if contiene?(vistos, id) do
      [{linea, "El ID #{id} está duplicado"}]
    else
      []
    end
  end

  defp validar_formato_id(linea, ""), do: [{linea, "La tarea no tiene ID"}]

  defp validar_formato_id(linea, id) do
    if tiene_separador?(id) do
      [{linea, "El ID #{id} no puede contener ; ni |"}]
    else
      []
    end
  end

  # Caso base: ya se revisó toda la cadena
  defp tiene_separador?(""), do: false

  # Caso recursivo: revisa el primer carácter y sigue con el resto
  defp tiene_separador?(cadena) do
    primer_caracter = String.first(cadena)
    resto = String.slice(cadena, 1..-1//1)

    es_separador?(primer_caracter) or tiene_separador?(resto)
  end

  defp es_separador?(c), do: c in [";", "|"]

  defp obtener_ids([]), do: []
  defp obtener_ids([{_linea, %Tarea{id: id}} | tail]), do: [id | obtener_ids(tail)]

  # -----------------------------------
  # Duración y plazo
  # -----------------------------------

  defp validar_valores([]), do: []

  defp validar_valores([{linea, tarea} | tail]) do
    validar_duracion(linea, tarea) ++ validar_plazo(linea, tarea) ++ validar_valores(tail)
  end

  defp validar_duracion(linea, %Tarea{id: id, duracion: duracion}) do
    if entero_minimo?(duracion, 1) do
      []
    else
      [{linea, "La duración de #{id} debe ser un entero positivo y se encontró: #{duracion}"}]
    end
  end

  defp validar_plazo(linea, %Tarea{id: id, plazo: plazo}) do
    if entero_minimo?(plazo, 0) do
      []
    else
      [{linea, "El plazo de #{id} debe ser un entero no negativo y se encontró: #{plazo}"}]
    end
  end

  # -----------------------------------
  # Dependencias
  # -----------------------------------

  defp validar_dependencias([], _ids), do: []

  defp validar_dependencias([{linea, tarea} | tail], ids) do
    revisar_dependencias(tarea.dependencias, [], linea, tarea.id, ids) ++
      validar_dependencias(tail, ids)
  end

  defp revisar_dependencias([], _vistas, _linea, _id, _ids), do: []

  defp revisar_dependencias([dependencia | tail], vistas, linea, id, ids) do
    revisar_dependencia(dependencia, vistas, linea, id, ids) ++
      revisar_dependencias(tail, [dependencia | vistas], linea, id, ids)
  end

  # Una dependencia repetida solo se reporta como repetida:
  # sus otros problemas ya se reportaron la primera vez que apareció.
  defp revisar_dependencia(dependencia, vistas, linea, id, ids) do
    cond do
      contiene?(vistas, dependencia) ->
        [{linea, "La tarea #{id} repite la dependencia #{dependencia}"}]

      dependencia == id ->
        [{linea, "La tarea #{id} depende de sí misma"}]

      contiene?(ids, dependencia) ->
        []

      true ->
        [{linea, "La tarea #{id} depende de #{dependencia}, que no existe"}]
    end
  end

  # -----------------------------------
  # Ciclos (DFS recursivo)
  # -----------------------------------

  defp validar_ciclos(tareas) do
    tareas
    |> buscar_desde(tareas, [])
    |> reportar_ciclos(tareas)
  end

  # Caso base: ya se usaron todas las tareas como punto de partida
  defp buscar_desde([], _tareas, ciclos), do: ciclos

  # Caso recursivo: hace un DFS desde el head y sigue con el tail
  defp buscar_desde([{_linea, %Tarea{id: id}} | tail], tareas, ciclos) do
    buscar_desde(tail, tareas, explorar(id, [id], tareas, ciclos))
  end

  # La ruta guarda solo el camino actual, del último ID visitado al primero.
  # No se usa una lista global de visitados porque omitiría ciclos que comparten tareas:
  # con A -> B -> D -> A y A -> C -> D -> A, D ya estaría visitada al llegar por C.
  defp explorar(id, ruta, tareas, ciclos) do
    visitar(dependencias_de(tareas, id), id, ruta, tareas, ciclos)
  end

  # Caso base: no quedan dependencias por visitar
  defp visitar([], _id, _ruta, _tareas, ciclos), do: ciclos

  # La autodependencia ya se reportó como error propio y no se cuenta como ciclo
  defp visitar([dependencia | tail], id, ruta, tareas, ciclos) when dependencia == id do
    visitar(tail, id, ruta, tareas, ciclos)
  end

  # Caso recursivo: si la dependencia ya está en la ruta se cerró un ciclo;
  # si no, se avanza por ella y al volver se sigue con las demás dependencias.
  defp visitar([dependencia | tail], id, ruta, tareas, ciclos) do
    nuevos_ciclos =
      if contiene?(ruta, dependencia) do
        ruta
        |> cortar_ciclo(dependencia, [])
        |> normalizar_ciclo()
        |> agregar_ciclo(ciclos)
      else
        explorar(dependencia, [dependencia | ruta], tareas, ciclos)
      end

    visitar(tail, id, ruta, tareas, nuevos_ciclos)
  end

  # Toma de la ruta solo el tramo que forma el ciclo, en el orden en que se recorrió
  defp cortar_ciclo([head | _tail], dependencia, ciclo) when head == dependencia do
    [head | ciclo]
  end

  defp cortar_ciclo([head | tail], dependencia, ciclo) do
    cortar_ciclo(tail, dependencia, [head | ciclo])
  end

  # Todas las rotaciones de un ciclo quedan iguales si empiezan por el menor ID.
  # Se rota y no se ordena: A -> B -> C -> A y A -> C -> B -> A son ciclos distintos.
  defp normalizar_ciclo([head | tail]), do: rotar([head | tail], minimo(tail, head))

  # Caso base: si la lista está vacía, se devuelve el menor encontrado
  defp minimo([], menor), do: menor
  # Si el head es menor, se actualiza el menor
  defp minimo([head | tail], menor) when head < menor, do: minimo(tail, head)
  # Si no, se sigue con el mismo menor
  defp minimo([_head | tail], menor), do: minimo(tail, menor)

  # Caso base: el ciclo ya empieza por el menor ID
  defp rotar([head | tail], menor) when head == menor, do: [head | tail]
  # Caso recursivo: el head pasa al final de la lista
  defp rotar([head | tail], menor), do: rotar(tail ++ [head], menor)

  defp agregar_ciclo(ciclo, ciclos) do
    if contiene?(ciclos, ciclo) do
      ciclos
    else
      ciclos ++ [ciclo]
    end
  end

  defp reportar_ciclos([], _tareas), do: []

  # Cada ciclo se ubica en la línea de su primera tarea
  defp reportar_ciclos([[primero | resto] | tail], tareas) do
    [
      {linea_de(tareas, primero),
       "Ciclo de dependencias: #{unir([primero | resto] ++ [primero])}"}
      | reportar_ciclos(tail, tareas)
    ]
  end

  defp unir([ultimo]), do: ultimo
  defp unir([head | tail]), do: "#{head} -> #{unir(tail)}"

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

  # Una dependencia desconocida no tiene dependencias: ya se reportó como error propio
  defp dependencias_de([], _id), do: []
  # Si hay IDs duplicados se usa la primera aparición
  defp dependencias_de([{_linea, %Tarea{id: actual, dependencias: dependencias}} | _tail], id)
       when actual == id do
    dependencias
  end

  defp dependencias_de([_tarea | tail], id), do: dependencias_de(tail, id)

  defp linea_de([{linea, %Tarea{id: actual}} | _tail], id) when actual == id, do: linea
  defp linea_de([_tarea | tail], id), do: linea_de(tail, id)

  # Caso base: en una lista vacía no está el elemento
  defp contiene?([], _elemento), do: false
  # El head es el elemento buscado
  defp contiene?([head | _tail], elemento) when head == elemento, do: true
  # Si no, se sigue buscando en el tail
  defp contiene?([_head | tail], elemento), do: contiene?(tail, elemento)
end
