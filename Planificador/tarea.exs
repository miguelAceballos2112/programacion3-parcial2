defmodule Tarea do
  @moduledoc """
  Tarea de un proyecto.

  - `id`: identificador de la tarea.
  - `duracion`: entero positivo.
  - `plazo`: entero no negativo.
  - `dependencias`: lista de IDs de las tareas de las que depende (lista vacía si
    en `tareas.csv` aparece `-`).

  ## Información

  - **Problema:** 2 – Planificación de tareas
  - **Rol:** 1 – Algoritmos y Streams
  """

  @enforce_keys [:id, :duracion, :plazo]
  defstruct [:id, :duracion, :plazo, dependencias: []]
end
