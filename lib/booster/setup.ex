defmodule Booster.Setup do
  alias ExAws.Dynamo

  @discovery_table "Discovery_Config"

  def create_tables() do
    case table_exists?(@discovery_table) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        secondary_index = [
          %{
            index_name: "country-code-index",
            key_schema: [
              %{
                attribute_name: "countryCode",
                key_type: "RANGE"
              }
            ],
            provisioned_throughput: %{
              read_capacity_units: 1,
              write_capacity_units: 1
            },
            projection: %{
              projection_type: "KEYS_ONLY"
            }
          }
        ]

        # Create a provisioned users table with a primary key of email [String]
        # # and 1 unit of read and write capacity
        "Discovery_Config"
        |> Dynamo.create_table(
          [client_id: :hash, country_code: :range],
          %{client_id: :string, country_code: :string},
          1,
          1
        )
        |> ExAws.request!()
    end
  end

  def table_exists?(tablename) do
    tablename
    |> Dynamo.describe_table()
    |> ExAws.request()
  end
end
