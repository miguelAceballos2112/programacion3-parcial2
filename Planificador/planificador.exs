Code.require_file("tarea.exs", __DIR__)
Code.require_file("plan.exs", __DIR__)
Code.require_file("estadisticas_planificador.exs", __DIR__)

defmodule Planificador do
  @moduledoc """
  Problema 2: planificación de tareas con dependencias.

  `generar_planes/3` enumera recursivamente (backtracking) todos los órdenes
  válidos de ejecución y entrega cada `%Plan{}` a una función receptora con
  acumulador, sin armar la lista de planes.

  Solo se ejecuta una tarea a la vez y no hay pausas entre tareas: cada tarea
  empieza cuando termina la anterior. Una tarea está habilitada cuando todas sus
  dependencias ya terminaron.

  ## Información

  - **Problema:** 2 – Planificación de tareas
  - **Rol:** 1 – Algoritmos y Streams
  """

  # -----------------------------------
  # Enumeración de planes (backtracking)
  # -----------------------------------

  @doc """
  Genera todos los planes válidos y los entrega a la función receptora.

  En cada paso prueba las tareas habilitadas en orden alfabético por ID, por lo
  que el resultado es reproducible.

  ## Parámetros

  - `tareas`: lista de `%Tarea{}` (se asume una red válida y sin ciclos).
  - `acumulador`: valor inicial del acumulador.
  - `receptora`: función `fn plan, acumulador -> nuevo_acumulador end`.

  ## Retorna

  El acumulador final. Si el proyecto está vacío retorna el acumulador inicial sin
  enumerar ni llamar a la función receptora.

  ## Ejemplo

      Planificador.generar_planes(tareas, Planificador.Estadisticas.nuevo(),
                                  &Planificador.Estadisticas.actualizar/2)
  """
  def generar_planes([], acumulador, _receptora), do: acumulador

  def generar_planes(tareas, acumulador, receptora) do
    pendientes = Enum.sort_by(tareas, fn %Tarea{id: id} -> id end)

    estado = %{
      terminadas: [],
      orden: [],
      finalizaciones: [],
      tiempo: 0,
      penalizacion: 0
    }

    construir(pendientes, estado, acumulador, receptora)
  end

  # -----------------------------------
  # Funciones auxiliares privadas
  # -----------------------------------

  # Caso base: no quedan tareas pendientes, hay un plan completo que se entrega.
  defp construir([], estado, acumulador, receptora) do
    plan = %Plan{
      orden: Enum.reverse(estado.orden),
      finalizaciones: Enum.reverse(estado.finalizaciones),
      penalizacion: estado.penalizacion
    }

    receptora.(plan, acumulador)
  end

  # Caso recursivo: se prueban las tareas habilitadas. Si no hay ninguna (red con
  # ciclo), esa rama termina sin producir plan.
  defp construir(pendientes, estado, acumulador, receptora) do
    habilitadas = Enum.filter(pendientes, fn tarea -> habilitada?(tarea, estado.terminadas) end)
    probar(habilitadas, pendientes, estado, acumulador, receptora)
  end

  # Elige cada tarea habilitada (backtracking), encadenando el acumulador.
  defp probar([], _pendientes, _estado, acumulador, _receptora), do: acumulador

  defp probar([tarea | resto], pendientes, estado, acumulador, receptora) do
    nuevo_acumulador =
      construir(List.delete(pendientes, tarea), ejecutar(tarea, estado), acumulador, receptora)

    probar(resto, pendientes, estado, nuevo_acumulador, receptora)
  end

  # Una tarea está habilitada si todas sus dependencias ya terminaron.
  defp habilitada?(%Tarea{dependencias: dependencias}, terminadas) do
    Enum.all?(dependencias, fn id -> Enum.member?(terminadas, id) end)
  end

  # Ejecuta la tarea sin pausas: empieza al terminar la anterior. Las listas se
  # construyen al revés (más eficiente) y se invierten al completar el plan.
  defp ejecutar(%Tarea{id: id, duracion: duracion, plazo: plazo}, estado) do
    inicio = estado.tiempo
    fin = inicio + duracion

    %{
      estado
      | terminadas: [id | estado.terminadas],
        orden: [id | estado.orden],
        finalizaciones: [{id, inicio, fin} | estado.finalizaciones],
        tiempo: fin,
        penalizacion: estado.penalizacion + max(0, fin - plazo)
    }
  end
end
