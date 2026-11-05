# Pruebas de punta a punta del orquestador con los archivos de fixtures/.
# Necesitan el código de Rol 1 y Rol 3 en esta misma carpeta.
# Cada caso escribe sus salidas en su propia carpeta de fixtures/.
#
# Ejecución:
#   .\compilar.bat
#   elixir pruebas_integracion.exs

defmodule PruebasIntegracion do
  @salidas_rescate [
    "expansion_energia.txt",
    "recorridos_rescate.csv",
    "resumen_rescate.txt",
    "ruta_optima.svg"
  ]

  @salidas_tareas ["planes.csv", "resumen_tareas.txt", "mejor_plan.svg"]

  def main do
    casos = casos_rescate() ++ casos_tareas()
    fallos = probar(casos)

    "\n#{length(casos)} pruebas, #{fallos} fallos"
    |> Util2.mostrar(:mensaje)
  end

  # Caso base: no quedan pruebas
  defp probar([]), do: 0

  # Caso recursivo: lo obtenido es igual a lo esperado
  defp probar([{nombre, obtenido, esperado} | tail]) when obtenido == esperado do
    Util2.mostrar("OK    #{nombre}", :mensaje)
    probar(tail)
  end

  # Caso recursivo: lo obtenido es diferente
  defp probar([{nombre, obtenido, esperado} | tail]) do
    Util2.mostrar("FALLO #{nombre}", :mensaje)
    IO.inspect(esperado, label: "  esperado")
    IO.inspect(obtenido, label: "  obtenido")

    1 + probar(tail)
  end

  # -----------------------------------
  # Problema 1
  # -----------------------------------

  defp casos_rescate do
    correr_rescate("valido", {:ok, :con_recorridos}, @salidas_rescate) ++
      correr_rescate("limite_minimo", {:ok, :con_recorridos}, @salidas_rescate) ++
      correr_rescate("limite_sin_recorrido", {:ok, :sin_recorrido}, @salidas_rescate) ++
      correr_rescate("invalido", {:error, :validacion}, []) ++
      correr_rescate("falta_archivo", {:error, :faltan_archivos}, [])
  end

  defp correr_rescate(nombre, esperado, deben_generarse) do
    carpeta = "fixtures/rescate/#{nombre}"
    vaciar(carpeta, deben_generarse)
    resultado = Orquestador.rescate(carpeta)

    [{"rescate #{nombre}: resultado", resultado, esperado}] ++
      revisar_salidas("rescate #{nombre}", carpeta, @salidas_rescate, deben_generarse)
  end

  # -----------------------------------
  # Problema 2
  # -----------------------------------

  defp casos_tareas do
    correr_tareas("valido", {:ok, :con_planes}, @salidas_tareas) ++
      revisar_planes_enunciado() ++
      correr_tareas("limite_una", {:ok, :con_planes}, @salidas_tareas) ++
      correr_tareas("vacio", {:ok, :proyecto_vacio}, @salidas_tareas) ++
      correr_tareas("invalido", {:error, :validacion}, []) ++
      correr_tareas("ciclos", {:error, :validacion}, []) ++
      revisar_ciclos() ++
      correr_tareas("no_existe", {:error, :faltan_archivos}, [])
  end

  defp correr_tareas(nombre, esperado, deben_generarse) do
    carpeta = "fixtures/tareas/#{nombre}"
    vaciar(carpeta, deben_generarse)
    resultado = Orquestador.tareas(carpeta)

    [{"tareas #{nombre}: resultado", resultado, esperado}] ++
      revisar_salidas("tareas #{nombre}", carpeta, @salidas_tareas, deben_generarse)
  end

  # Las dos filas que trae el enunciado para este ejemplo
  defp revisar_planes_enunciado do
    ruta = "fixtures/tareas/valido/planes.csv"

    [
      {"tareas valido: plan 1 del enunciado", contar_lineas(ruta, "1;A → B → C → D;10;4"), 1},
      {"tareas valido: plan 2 del enunciado", contar_lineas(ruta, "2;A → C → B → D;10;6"), 1}
    ]
  end

  # Tres tareas donde cada una depende de las otras dos forman exactamente 5 ciclos
  defp revisar_ciclos do
    ruta = "fixtures/tareas/ciclos/validacion_tareas.txt"

    [{"tareas ciclos: 5 ciclos sin rotaciones repetidas", contar_lineas(ruta, "Ciclo"), 5}]
  end

  # -----------------------------------
  # Funciones auxiliares
  # -----------------------------------

  # El texto aparece en la línea si al partirla por él quedan dos pedazos o más
  defp contar_lineas(ruta, texto) do
    ruta
    |> File.stream!()
    |> Stream.filter(fn linea -> length(String.split(linea, texto)) > 1 end)
    |> Enum.count()
  end

  # Deja vacías las salidas que el caso debe generar, para que una salida
  # de una ejecución anterior no haga pasar la prueba.
  defp vaciar(_carpeta, []), do: :ok

  defp vaciar(carpeta, [archivo | tail]) do
    File.write("#{carpeta}/#{archivo}", "")
    vaciar(carpeta, tail)
  end

  # Caso base: no quedan archivos por revisar
  defp revisar_salidas(_nombre, _carpeta, [], _deben_generarse), do: []

  # Caso recursivo: el archivo se generó solo si el caso debía hacerlo
  defp revisar_salidas(nombre, carpeta, [archivo | tail], deben_generarse) do
    [
      {
        "#{nombre}: #{archivo}",
        generado?("#{carpeta}/#{archivo}"),
        contiene?(deben_generarse, archivo)
      }
      | revisar_salidas(nombre, carpeta, tail, deben_generarse)
    ]
  end

  # Un archivo cuenta como generado solo si existe y tiene contenido
  defp generado?(ruta) do
    case File.read(ruta) do
      {:ok, ""} -> false
      {:ok, _contenido} -> true
      {:error, _razon} -> false
    end
  end

  defp contiene?([], _elemento), do: false
  defp contiene?([head | _tail], elemento) when head == elemento, do: true
  defp contiene?([_head | tail], elemento), do: contiene?(tail, elemento)
end

PruebasIntegracion.main()
