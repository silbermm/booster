defmodule BoosterWeb.PageLive do
  use BoosterWeb, :live_view

  alias ExAws.Dynamo

  @impl true
  def mount(_params, _session, socket) do
    %{"TableNames" => tables} = Dynamo.list_tables() |> ExAws.request!()

    tables =
      tables
      |> Enum.filter(fn t -> String.starts_with?(t, "discovery_lightyear_defaults") end)
      |> Enum.map(fn <<"discovery_lightyear_defaults_">> <> brand -> brand end)

    {:ok, assign(socket, tables: tables, brand: "", show_add_form: false)}
  end

  def handle_event("toggleRegion", %{"region" => region, "environment" => env}, socket) do
    key = :"#{env}_regions"
    regions = Map.get(socket.assigns, key)

    regions =
      for r <- regions do
        if r.name == region do
          %{r | show: !r.show}
        else
          r
        end
      end

    {:noreply, assign(socket, key, regions)}
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

  def handle_event("showAddForm", %{"environment" => env}, socket) do
    # show the add form for #{env}
    {:noreply, assign(socket, show_add_form: true, add_for: env)}
  end

  def handle_event("cancelAdd", _, socket) do
    {:noreply, assign(socket, show_add_form: false, add_for: "")}
  end

  def render(assigns) do
    ~H"""
    <div>
      <form>
        <select>
          <option selected={@brand==""}> Select a brand </option>
          <%= for table <- @tables do %> 
            <option phx-click="selectBrand" phx-value-brand={table} selected={@brand==table}>
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
                <li phx-click="toggleRegion" phx-value-environment="qa" phx-value-region={r.name}> <%= r.name %> </li>
                <%= if r.show do %>
                  <ul>
                    <%= for {k, v} <- r.data do %>
                      <li> <%= k %> --- <%= v %> </li>
                    <% end %>
                  </ul>
                <% end %>
              <% end %>
              </ul>
              <button phx-click="showAddForm" phx-value-environment="qa"> Add QA Application </button>
            <% end %>
          </div>
          <div class="column">
            <h3> STAGE </h3>
          </div>
          <div class="column">
            <h3> PROD </h3>
          </div>
        </div>

        <%= if @show_add_form do %>
          <form>
            
          </form>
          <button phx-click="cancelAdd"> Cancel </button>
        <% end %>

      <% end %>
    </div>
    """
  end

  defp get_regions(%{"Items" => items}) do
    items
    |> Enum.map(fn i ->
      region = Map.get(i, "region") |> Map.get("S")

      %{
        show: false,
        name: region,
        data: decode_item(i)
      }
    end)
  end

  defp get_regions(_), do: []

  defp decode_item(item) do
    Enum.map(item, fn {k, v} ->
      value = Enum.map(v, fn {k2, v2} -> v2 end)
      {k, List.first(value)}
    end)
  end
end
