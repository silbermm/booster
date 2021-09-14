defmodule BoosterWeb.PageLive do
  use BoosterWeb, :live_view

  alias ExAws.Dynamo

  @impl true
  def mount(_params, _session, socket) do
    # get different brands
    %{"TableNames" => tables} = Dynamo.list_tables() |> ExAws.request!()

    tables =
      tables
      |> Enum.filter(fn t -> String.starts_with?(t, "discovery_lightyear_defaults") end)
      |> Enum.map(fn <<"discovery_lightyear_defaults_">> <> brand -> brand end)

    {:ok, assign(socket, tables: tables, brand: "")}
  end

  def handle_event("selectBrand", %{"brand" => brand}, socket) do
    qa_defaults =
      "discovery_lightyear_defaults_#{brand}"
      |> Dynamo.query(
        expression_attribute_values: [env: "qa"],
        key_condition_expression: "environment = :env"
      )
      |> ExAws.request!()

    qa_regions = get_regions(qa_defaults)

    {:noreply, assign(socket, qa: qa_defaults, qa_regions: qa_regions, brand: brand)}
  end

  defp get_regions(%{"Items" => items}),
    do: items |> Enum.map(&Map.get(&1, "region")) |> Enum.map(&Map.get(&1, "S"))

  defp get_regions(_), do: []

  def render(assigns) do
    ~L"""
    <div>
    <form>
      <select>
        <option selected> Select a brand </option>
        <%= for table <- @tables do %> 
          <option phx-click="selectBrand" phx-value-brand="<%= table %>">
            <%= table %> 
          </option> 
        <% end %>
      </select>
    </form>

    <%= if @brand != "" do %>
      <h1> <%= @brand %> </h1>
        <div class="row">
          <div class="column">
            <h3> QA </h3>
            <%= if @qa_regions do %>
              <ul>
              <%= for r <- @qa_regions do %>
                <li> <%= r %> </li>
              <% end %>
              </ul>
            <% end %>
          </div>
          <div class="column">
            <h3> STAGE </h3>
          </div>
          <div class="column">
            <h3> PROD </h3>
          </div>
        </div>

            
      <% end %>
    </div>
    """
  end
end
