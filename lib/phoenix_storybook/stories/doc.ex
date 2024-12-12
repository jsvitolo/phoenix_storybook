defmodule PhoenixStorybook.Stories.Doc do
  @moduledoc """
  Functions to fetch component documentation and render it at HTML.
  """

  require Logger

  @doc """
  Fetch component documentation from component source and format it as HTML.
  - For a live_component, fetches @moduledoc content
  - For a function component, fetches @doc content of the relevant function

  Output HTML is splitted in paragraphs and returned as a list of paragraphs.
  """
  def fetch_doc_as_html(story, stripped? \\ true) do
    case fetch_component_doc(story.storybook_type(), story) do
      :error ->
        nil

      doc ->
        case split_header(doc) do
          [] ->
            nil

          [header] ->
            [format(header), nil]

          [header, rest] ->
            [
              format(header),
              if stripped? do
                rest |> strip_lv_attributes_doc() |> strip_lv_slots_doc() |> format()
              else
                format(rest)
              end
            ]
        end
    end
  end

  def fetch_component_doc(:component, module) do
    info = Function.info(module.function())
    fetch_function_doc(info[:module], {info[:name], info[:arity]})
  end

  def fetch_component_doc(:live_component, module) do
    fetch_module_doc(module.component())
  end

  defp fetch_function_doc(module, {fun, arity}) do
    case Code.fetch_docs(module) do
      {_, _, _, _, _, _, function_docs} ->
        case find_function_doc(function_docs, fun, arity) do
          map when is_map(map) -> map |> Map.values() |> Enum.at(0)
          _ -> nil
        end

      _ ->
        Logger.warning("could not fetch function docs from #{inspect(module)}")
        :error
    end
  end

  defp find_function_doc(docs, fun, arity) do
    Enum.find_value(
      docs,
      %{},
      fn
        {{:function, item_fun, item_arity}, _, _, doc, _} ->
          if fun == item_fun && arity == item_arity, do: doc, else: false

        _ ->
          false
      end
    )
  end

  defp fetch_module_doc(module) do
    case Code.fetch_docs(module) do
      {_, _, _, _, module_doc, _, _} ->
        case module_doc do
          map when is_map(map) -> map |> Map.values() |> Enum.at(0)
          _ -> nil
        end

      _ ->
        Logger.warning("could not fetch module doc from #{inspect(module)}")
        :error
    end
  end

  def strip_lv_attributes_doc(nil), do: nil
  def strip_lv_attributes_doc(doc), do: doc |> String.split("## Attributes\n\n") |> hd()

  def strip_lv_slots_doc(nil), do: nil
  def strip_lv_slots_doc(doc), do: doc |> String.split("## Slots\n\n") |> hd()

  defp split_header(nil), do: []
  defp split_header(doc), do: String.split(doc, "\n\n", parts: 2)

  defp format(doc) do
    case Earmark.as_html(doc) do
      {:ok, doc, _} -> String.trim(doc)
      _ -> String.trim(doc)
    end
  end
end
