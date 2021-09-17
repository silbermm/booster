defmodule BoosterWeb.PageLive do
  use BoosterWeb, :live_view

  alias ExAws.Dynamo

  @table "discovery_lightyear_app"

  @impl true
  def mount(_params, _session, socket) do
    %{"TableNames" => tables} = Dynamo.list_tables() |> ExAws.request!()

    tables =
      tables
      |> Enum.filter(fn t -> String.starts_with?(t, "discovery_lightyear_defaults") end)
      |> Enum.map(fn <<"discovery_lightyear_defaults_">> <> brand -> brand end)

    # Get data from Dynamo

    countries = Req.get!("https://restcountries.eu/rest/v2/all").body

    {:ok,
     assign(socket,
       tables: tables,
       brand: "",
       show_add_form: false,
       countries: countries,
       token_apiToken: nil,
       token_firmwareToken: nil
     )}
  end

  @impl true
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

  @impl true
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

  @impl true
  def handle_event("showAddForm", %{"environment" => env}, socket) do
    # show the add form for #{env}
    {:noreply, assign(socket, show_add_form: true, add_for: env)}
  end

  @impl true
  def handle_event("cancelAdd", _, socket) do
    {:noreply, assign(socket, show_add_form: false, add_for: "")}
  end

  @impl true
  def handle_event("addNew", %{"countryCode" => cc} = form, socket) do
    rows =
      for code <- cc do
        # get the correct region for this country code
        [region, country_code] = String.split(code, "-")
        configs = socket.assigns.qa_regions

        config =
          Enum.find(configs, fn %{data: data} ->
            Enum.find(data, fn {k, v} ->
              if k == "regions" do
                Enum.find(v, &(String.downcase(&1) == String.downcase(region)))
              else
                false
              end
            end)
          end)

        {_, apiUrl} = Enum.find(get_in(config, [:data]), fn {k, v} -> k == "apiUrl" end)
        {_, dbregion} = Enum.find(get_in(config, [:data]), fn {k, v} -> k == "region" end)
        {_, environment} = Enum.find(get_in(config, [:data]), fn {k, v} -> k == "environment" end)

        {_, cognitoAppClientId} =
          Enum.find(get_in(config, [:data]), fn {k, v} -> k == "cognitoAppClientId" end)

        %{
          "region" => dbregion,
          "brand" => socket.assigns.brand,
          "environment" => environment,
          "apiUrl" => apiUrl,
          "cognitoAppClientId" => cognitoAppClientId,
          "countryCode" => country_code,
          "appName" => Map.get(form, "name"),
          "apiToken" => Map.get(form, "apiToken"),
          "firmwareToken" => Map.get(form, "firmwareToken"),
          "marketingProgram" => get_in(form, ["marketingProgram", "#{region}", "#{country_code}"])
        }
      end

    for r <- rows do
      Dynamo.put_item("discovery_lightyear_app", r) |> ExAws.request!()
    end

    {:noreply, assign(socket, show_add_form: false)}
  end

  @impl true
  def handle_event("generateToken", %{"for" => field}, socket) do
    {:noreply, assign(socket, "token_#{field}": "1234abcd")}
  end

  @impl true
  def handle_event("addChange", _, socket) do
    {:noreply, socket}
  end

  @impl true
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
          <div style="background-color: white">
          <form name="qa_form" phx-submit="addNew" phx-change="addChange">
            <label for="name"> Name <input name="name" /> </label>
            <label for="apiToken"> API Token <input name="apiToken" value={@token_apiToken} /> <a phx-click="generateToken" phx-value-for="apiToken"> Generate </a> </label>
            <label for="firmwareToken"> Firmware Token <input name="firmwareToken" value={@token_firmwareToken} /> <a phx-click="generateToken" phx-value-for="firmwareToken"> Generate </a> </label>
            
              <.show_countries countries={@countries} />
            <button type="submit"> Create </button>
            <button phx-click="cancelAdd"> Cancel </button>
          </form>
        </div>
        <% end %>

      <% end %>
    </div>
    """
  end

  def show_countries(assigns) do
    ~H"""
      <div class="row">
        <div class="column">
          <h4> Americas </h4> 
            <%= for country <- get_countries("americas", @countries) do %>
              <div>
                <input type="checkbox" value={"americas-" <> Map.get(country, "alpha2Code")} name="countryCode[]" /> <%= Map.get(country, "name") %>
                <input type="text" placeholder="Marketing Program" name={"marketingProgram[americas][" <> Map.get(country, "alpha2Code")<> "]"}/>
              </div>
            <% end %>
        </div>
        <div class="column">
          <h4> Europe </h4> 
            <%= for country <- get_countries("europe", @countries) do %>
              <div>
                <input type="checkbox" value={"europe-" <> Map.get(country, "alpha2Code")} name="countryCode[]"/> <%= Map.get(country, "name") %>
                <input type="text" placeholder="Marketing Program" name={"marketingProgram[europe][" <> Map.get(country, "alpha2Code")<>"]"} />
              </div>
            <% end %>

        </div>
        <div class="column">
          <h4> Asia </h4>
            <%= for country <- get_countries("asia", @countries) do %>
              <div>
                <input type="checkbox" value={"asia-" <> Map.get(country, "alpha2Code")} name="countryCode[]"/> <%= Map.get(country, "name") %>
                <input type="text" placeholder="Marketing Program" name={"marketingProgram[asia][" <> Map.get(country, "alpha2Code")<>"]"} />
              </div>
            <% end %>

        </div>
      </div>
    """
  end

  def get_countries(region, all) do
    all
    |> Enum.filter(fn a -> String.downcase(Map.get(a, "region")) == String.downcase(region) end)
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
      value =
        Enum.map(v, fn {k2, v2} ->
          if k2 == "L" do
            Enum.map(v2, fn %{"S" => v3} -> v3 end)
          else
            v2
          end
        end)

      {k, List.first(value)}
    end)
  end
end
