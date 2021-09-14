defmodule Booster.Setup do
  alias ExAws.Dynamo

  defmodule AppRow do
    @derive [ExAws.Dynamo.Encodable]
    defstruct [
      :apiToken,
      :brandName,
      :appName,
      :environment,
      :createdAt,
      :countryCode,
      :countryCodeEnabled,
      :market,
      :marketingProgram,
      :region,
      :cognitoAppClientId,
      :cognitoAppClientSecret,
      :cognitoUserPoolId,
      :cognitoServerClientId,
      :cognitoWebClientId,
      :cognitoIdentityPoolId,
      :countryCodeIsoThree,
      :segmentApiKey,
      :segmentSourceId,
      :apiUrl,
      :internalApiKey,
      :internalApiUrl,
      :admin
    ]
  end

  @discovery_table "discovery_app"

  def table_exists?(tablename) do
    tablename
    |> Dynamo.describe_table()
    |> ExAws.request()
  end
end
