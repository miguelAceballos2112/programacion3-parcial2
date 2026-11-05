defmodule Parcial2.MixProject do
  use Mix.Project

  def project do
    [
      app: :parcial2,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      # El código está organizado por carpetas de rol en lugar de lib/ y test/
      elixirc_paths: ["Orquestador.ex", "Util", "Robot", "Planificador", "Archivos"],
      test_paths: ["Test"],
      deps: deps(),
      name: "Parcial2",
      docs: &docs/0
    ]
  end

  def application do
    [extra_applications: [:logger, :xmerl]]
  end

  # ExDoc solo se usa en desarrollo para generar la documentación (mix docs).
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        Structs: [Terreno, Recorrido, Tarea, Plan],
        Algoritmos: [Robot, Robot.Estadisticas, Planificador, Planificador.Estadisticas],
        Validadores: [ValidadorEdificio, ValidadorTareas],
        "Entrada y salida": [Lector, Salida, Svg]
      ]
    ]
  end
end
