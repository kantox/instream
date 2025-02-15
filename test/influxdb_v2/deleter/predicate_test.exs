defmodule Instream.InfluxDBv2.Deleter.PredicateTest do
  use ExUnit.Case, async: true

  @moduletag :"influxdb_include_2.x"

  alias Instream.TestHelpers.TestConnection

  defmodule EmptyTagSeries do
    use Instream.Series

    series do
      measurement "empty_predicate_tags"

      tag :filled
      tag :defaulting, default: "default_value"
      tag :empty

      field :value
    end
  end

  setup_all do
    {:ok, data_origin: ~U[2021-01-01T00:00:00Z]}
  end

  test "deleting no points returns error" do
    assert_raise FunctionClauseError, fn -> TestConnection.delete(%{}) end
  end

  test "deleting with predicate", %{data_origin: data_origin} do
    measurement = EmptyTagSeries.__meta__(:measurement)

    :ok =
      %{
        filled: "filled_tag",
        value: 100
      }
      |> EmptyTagSeries.from_map()
      |> TestConnection.write()

    :ok =
      %{
        filled: "keep",
        value: 100
      }
      |> EmptyTagSeries.from_map()
      |> TestConnection.write()

    :ok =
      %{
        predicate: "filled=\"filled_tag\"",
        start: DateTime.to_iso8601(data_origin),
        stop: DateTime.to_iso8601(DateTime.utc_now())
      }
      |> TestConnection.delete()

    result =
      TestConnection.query("""
        from(bucket: "#{TestConnection.config(:bucket)}")
        |> range(start: -5m)
        |> filter(fn: (r) =>
          r._measurement == "#{measurement}"
        )
        |> last()
      """)

    assert [
             %{
               "_field" => "value",
               "_measurement" => "empty_predicate_tags",
               "_value" => 100,
               "defaulting" => "default_value",
               "filled" => "keep",
               "result" => "_result",
               "table" => 0
             }
           ] = result
  end

  test "deleting without predicate", %{data_origin: data_origin} do
    measurement = EmptyTagSeries.__meta__(:measurement)

    :ok =
      %{
        filled: "filled_tag",
        value: 100
      }
      |> EmptyTagSeries.from_map()
      |> TestConnection.write()

    :ok =
      %{
        filled: "filled_tag",
        value: 100
      }
      |> EmptyTagSeries.from_map()
      |> TestConnection.write()

    :ok =
      %{
        start: DateTime.to_iso8601(data_origin),
        stop: DateTime.to_iso8601(DateTime.utc_now())
      }
      |> TestConnection.delete()

    result =
      TestConnection.query("""
        from(bucket: "#{TestConnection.config(:bucket)}")
        |> range(start: -5m)
        |> filter(fn: (r) =>
          r._measurement == "#{measurement}"
        )
        |> last()
      """)

    assert [] == result
  end
end
